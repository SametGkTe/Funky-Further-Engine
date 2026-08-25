package states;

import lime.app.Future;
import sys.thread.FixedThreadPool;
import haxe.Json;
import lime.utils.Assets;
import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets;
import flixel.FlxState;
import flixel.text.FlxText.FlxTextBorderStyle;

import flash.media.Sound;

import backend.Song;
import backend.StageData;
import objects.Character;

import sys.thread.Thread;
import sys.thread.Mutex;

import objects.Note;
import objects.NoteSplash;

#if HSCRIPT_ALLOWED
import psychlua.HScript;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
#end

class LoadingState extends MusicBeatState
{
	public static var loaded:Int = 0;
	public static var loadMax:Int = 0;
	public static var loadStatus:String = 'Hazırlanıyor...';

	static var originalBitmapKeys:Map<String, String> = [];
	static var requestedBitmaps:Map<String, BitmapData> = [];
	static var imageStatus:Map<String, String> = new Map();
	static var mutex:Mutex;
	static var threadPool:FixedThreadPool = null;
	var statusTxt:FlxText;

	function new(target:FlxState, stopMusic:Bool)
	{
		this.target = target;
		this.stopMusic = stopMusic;
		
		super();
	}

	inline static public function loadAndSwitchState(target:FlxState, stopMusic = false, intrusive:Bool = true)
		MusicBeatState.switchState(getNextState(target, stopMusic, intrusive));
	
	var target:FlxState = null;
	var stopMusic:Bool = false;
	var dontUpdate:Bool = false;

	var barGroup:FlxSpriteGroup;
	var bar:FlxSprite;
	var barWidth:Int = 0;
	var intendedPercent:Float = 0;
	var curPercent:Float = 0;
	var stateChangeDelay:Float = 0;

	#if PSYCH_WATERMARKS
	var logo:FlxSprite;
	var pessy:FlxSprite;

	var timePassed:Float = 0;
	var shakeFl:Float = 0;
	var shakeMult:Float = 0;
	
	var isSpinning:Bool = false;
	var spawnedPessy:Bool = false;
	var pressedTimes:Int = 0;
	#else
	var funkay:FlxSprite;
	#end

	#if HSCRIPT_ALLOWED
	var hscript:HScript;
	#end
	override function create()
	{
		persistentUpdate = true;
		barGroup = new FlxSpriteGroup();
		add(barGroup);

		var barBack:FlxSprite = new FlxSprite(0, 660).makeGraphic(1, 1, FlxColor.BLACK);
		barBack.scale.set(FlxG.width - 300, 25);
		barBack.updateHitbox();
		barBack.screenCenter(X);
		barGroup.add(barBack);

		bar = new FlxSprite(barBack.x + 5, barBack.y + 5).makeGraphic(1, 1, FlxColor.WHITE);
		bar.scale.set(0, 15);
		bar.updateHitbox();
		barGroup.add(bar);
		barWidth = Std.int(barBack.width - 10);

		statusTxt = new FlxText(0, barBack.y - 34, FlxG.width, loadStatus, 18);
		statusTxt.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		statusTxt.borderSize = 2;
		statusTxt.scrollFactor.set();
		add(statusTxt);

		#if HSCRIPT_ALLOWED
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.trim().length > 0)
		{
			var scriptPath:String = 'mods/${Mods.currentModDirectory}/data/LoadingScreen.hx';
			if(FileSystem.exists(scriptPath))
			{
				try
				{
					hscript = new HScript(null, scriptPath);
					hscript.set('getLoaded', function() return loaded);
					hscript.set('getLoadMax', function() return loadMax);
					hscript.set('getLoadStatus', function() return loadStatus);
					hscript.set('barBack', barBack);
					hscript.set('bar', bar);
	
					if(hscript.exists('onCreate'))
					{
						hscript.call('onCreate');
						trace('hscript yorumlayıcısı başarıyla başlatıldı: $scriptPath');
						return super.create();
					}
					else
					{
						trace('"$scriptPath" dosyasında "onCreate" fonksiyonu bulunamadı, betik durduruluyor.');
					}
				}
				catch(e:IrisError)
				{
					var pos:HScriptInfos = cast {fileName: scriptPath, showLine: false};
					Iris.error(Printer.errorToString(e, false), pos);
					var hscript:HScript = cast (Iris.instances.get(scriptPath), HScript);
				}
				if(hscript != null) hscript.destroy();
				hscript = null;
			}
		}
		#end

		#if PSYCH_WATERMARKS

		if(ClientPrefs.data.petloadingscreen)
		{
				var style:String = ClientPrefs.data.petloadingscreenimage;
				switch (style.toUpperCase())
				{
					case 'ONLINE': style = 'online';
					case 'V1': style = 'V1';
					case 'V2': style = 'V2';
					case 'V2U': style = 'V2U';
					default: style = 'online';
				}
				var randomIndex:Int = FlxG.random.int(1, 5);
				var bgPath:String = 'pet/petscreens/$style/loadingscreen$randomIndex';

				var bg:FlxSprite = new FlxSprite();
				var bgGraphic = Paths.image(bgPath);
				if(bgGraphic != null)
					bg.loadGraphic(bgGraphic);
				else
				{
					bg.loadGraphic(Paths.image('menuDesat'));
					bg.color = 0xFFD16FFF;
				}
			bg.antialiasing = ClientPrefs.data.antialiasing;
			bg.setGraphicSize(FlxG.width, FlxG.height);
			bg.updateHitbox();
			bg.screenCenter();
			addBehindBar(bg);

				logo = new FlxSprite(0, 0);
				var logoGraphic = Paths.image('pet/petlogos/fe');
				if (logoGraphic == null) logoGraphic = Paths.image('loading_screen/icon');
				logo.loadGraphic(logoGraphic);
			logo.antialiasing = ClientPrefs.data.antialiasing;
			logo.scale.set(0.75, 0.75);
			logo.updateHitbox();
			logo.screenCenter();
			logo.x -= 50;
			logo.y -= 40;
			addBehindBar(logo);
		}
		else
		{
			var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
			bg.antialiasing = ClientPrefs.data.antialiasing;
			bg.setGraphicSize(Std.int(FlxG.width));
			bg.color = 0xFFD16FFF;
			bg.updateHitbox();
			addBehindBar(bg);
		
			logo = new FlxSprite(0, 0).loadGraphic(Paths.image('loading_screen/icon'));
			logo.antialiasing = ClientPrefs.data.antialiasing;
			logo.scale.set(0.75, 0.75);
			logo.updateHitbox();
			logo.screenCenter();
			logo.x -= 50;
			logo.y -= 40;
			addBehindBar(logo);
		}

		#else
		var bg = new FlxSprite().makeGraphic(1, 1, 0xFFCAFF4D);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.screenCenter();
		addBehindBar(bg);

		funkay = new FlxSprite(0, 0).loadGraphic(Paths.image('funkay'));
		funkay.antialiasing = ClientPrefs.data.antialiasing;
		funkay.setGraphicSize(0, FlxG.height);
		funkay.updateHitbox();
		addBehindBar(funkay);
		#end
		super.create();

		if (stateChangeDelay <= 0 && checkLoaded())
		{
			dontUpdate = true;
			onLoad();
		}
	}

	function addBehindBar(obj:flixel.FlxBasic)
	{
		insert(members.indexOf(barGroup), obj);
	}

	var transitioning:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (dontUpdate) return;

		if (!transitioning)
		{
			if (!finishedLoading && checkLoaded())
			{
				if (ClientPrefs.data.shaders)
					loadStatus = 'Gölgeler yükleniyor';
				else
					loadStatus = 'Tamamlanıyor...';
				if(stateChangeDelay <= 0)
				{
					transitioning = true;
					onLoad();
					return;
				}
				else stateChangeDelay = Math.max(0, stateChangeDelay - elapsed);
			}
			intendedPercent = loaded / loadMax;
		}

		if (curPercent != intendedPercent)
		{
			if (Math.abs(curPercent - intendedPercent) < 0.001) curPercent = intendedPercent;
			else curPercent = FlxMath.lerp(intendedPercent, curPercent, Math.exp(-elapsed * 15));

			bar.scale.x = barWidth * curPercent;
			bar.updateHitbox();
		}

		if (statusTxt != null)
		{
			var label:String = loadStatus;
			if (label == null || label.length < 1)
				label = 'Yükleniyor...';
			if (loadMax > 0)
				statusTxt.text = label + '  (' + loaded + '/' + loadMax + ')';
			else
				statusTxt.text = label;
		}
		
		#if HSCRIPT_ALLOWED
		if(hscript != null)
		{
			if(hscript.exists('onUpdate')) hscript.call('onUpdate', [elapsed]);
			return;
		}
		#end

		#if PSYCH_WATERMARKS
		timePassed += elapsed;
		shakeFl += elapsed * 3000;

		if(!spawnedPessy)
		{
			if(!transitioning && (controls.ACCEPT || FlxG.touches.getFirst() != null && FlxG.touches.getFirst().justPressed))
			{
				shakeMult = 1;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				pressedTimes++;
			}
			shakeMult = Math.max(0, shakeMult - elapsed * 5);
			logo.offset.x = Math.sin(shakeFl * Math.PI / 180) * shakeMult * 100;

			if(pressedTimes >= 5)
			{
				FlxG.camera.fade(0xAAFFFFFF, 0.5, true);
				logo.visible = false;
				spawnedPessy = true;
				stateChangeDelay = 5;
				FlxG.sound.play(Paths.sound('secret'));

				pessy = new FlxSprite(700, 140);
				pessy.frames = Paths.getSparrowAtlas('loading_screen/pessy');
				pessy.animation.addByPrefix('run', 'run', 24, true);
				pessy.animation.addByPrefix('spin', 'spin', 24, true);
				pessy.antialiasing = ClientPrefs.data.antialiasing;
				pessy.flipX = (logo.offset.x > 0);
				pessy.visible = false;

				new FlxTimer().start(0.01, function(tmr:FlxTimer) {
					pessy.x = FlxG.width + 200;
					pessy.velocity.x = -1100;
					if(pessy.flipX)
					{
						pessy.x = -pessy.width - 200;
						pessy.velocity.x *= -1;
					}
		
					pessy.visible = true;
					pessy.animation.play('run', true);
					#if ACHIEVEMENTS_ALLOWED Achievements.unlock('pessy_easter_egg'); #end
					
					insert(members.indexOf(barGroup), pessy);
				});
			}
		}
		else if(!isSpinning && (pessy.flipX && pessy.x > FlxG.width) || (!pessy.flipX && pessy.x < -pessy.width))
		{
			isSpinning = true;
			pessy.animation.play('spin', true);
			pessy.flipX = false;
			pessy.x = 500;
			pessy.y = FlxG.height + 500;
			pessy.velocity.x = 0;
			FlxTween.tween(pessy, {y: 10}, 0.65, {ease: FlxEase.quadOut});
		}
		#end
	}

	#if HSCRIPT_ALLOWED
	override function destroy()
	{
		if(hscript != null)
		{
			if(hscript.exists('onDestroy')) hscript.call('onDestroy');
			hscript.destroy();
		}
		hscript = null;
		super.destroy();
	}
	#end
	
	var finishedLoading:Bool = false;
	function onLoad()
	{
		loadStatus = 'Tamamlanıyor...';
		_loaded();

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		FlxG.camera.visible = false;
		MusicBeatState.switchState(target);
		transitioning = true;
		finishedLoading = true;
	}

	static function _loaded()
	{
		loaded = 0;
		loadMax = 0;
		loadStatus = 'Hazırlanıyor...';
		imageStatus = new Map();
		initialThreadCompleted = true;
		isIntrusive = false;

		FlxTransitionableState.skipNextTransIn = true;
		if (threadPool != null) threadPool.shutdown();
		threadPool = null;
		mutex = null;
	}

	public static function checkLoaded():Bool
	{
		for (key => bitmap in requestedBitmaps)
		{
				if (bitmap != null && Paths.cacheBitmap(originalBitmapKeys.get(key), null, bitmap) != null) {}
				else trace('görsel önbelleğe alınamadı: $key');
		}
		requestedBitmaps.clear();
		originalBitmapKeys.clear();
		return (loaded >= loadMax && initialThreadCompleted);
	}

	public static function loadNextDirectory()
	{
		var directory:String = 'shared';
		var weekDir:String = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;

		if (weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Varlık klasörü ayarlanıyor: ' + directory);
	}

	static var isIntrusive:Bool = false;
	static function getNextState(target:FlxState, stopMusic = false, intrusive:Bool = true):FlxState
	{
		#if !SHOW_LOADING_SCREEN
		intrusive = false;
		#end

		LoadingState.isIntrusive = intrusive;
		_startPool();
		loadNextDirectory();

		if(intrusive)
			return new LoadingState(target, stopMusic);
		
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		while(true)
		{
			if(checkLoaded())
			{
				_loaded();
				break;
			}
			else Sys.sleep(0.001);
		}
		return target;
	}

	static var imagesToPrepare:Array<String> = [];
	static var soundsToPrepare:Array<String> = [];
	static var musicToPrepare:Array<String> = [];
	static var songsToPrepare:Array<String> = [];
	public static function prepare(images:Array<String> = null, sounds:Array<String> = null, music:Array<String> = null, ?status:String)
	{
		if (images != null)
		{
			var st:String = (status != null && status.length > 0) ? status : 'Görseller yükleniyor';
			for (img in images)
				queueImage(img, st);
		}
		appendUnique(soundsToPrepare, sounds);
		appendUnique(musicToPrepare, music);
	}

	static function queueImage(path:String, status:String):Void
	{
		if (path == null)
			return;
		var nam:String = path.trim();
		if (nam.length < 1)
			return;
		if (!imagesToPrepare.contains(nam))
			imagesToPrepare.push(nam);
		imageStatus.set(nam, status);
	}

	static function setLoadStatus(status:String):Void
	{
		if (mutex != null)
			mutex.acquire();
		loadStatus = status;
		if (mutex != null)
			mutex.release();
	}

	static function appendUnique(target:Array<String>, values:Array<String>):Void
	{
		if (values == null) return;
		for (value in values)
			if (value != null && !target.contains(value)) target.push(value);
	}

	static function dedupeQueue(queue:Array<String>):Void
	{
		var seen:Map<String, Bool> = [];
		var i:Int = 0;
		while (i < queue.length)
		{
			var value = queue[i];
			if (value == null || seen.exists(value)) queue.splice(i, 1);
			else { seen.set(value, true); i++; }
		}
	}

	static var initialThreadCompleted:Bool = true;
	static var dontPreloadDefaultVoices:Bool = false;
	static function _startPool()
	{
		if (threadPool != null) return;
		#if MULTITHREADED_LOADING
		var platformMax:Int = #if mobile 2 #else 4 #end;
		var available:Int = Std.int(Math.max(1, CoolUtil.getCPUThreadsCount() - #if DISCORD_ALLOWED 2 #else 1 #end));
		var requested:Int = ClientPrefs.data.loadThreads;
		#if mobile
		requested = 2;
		#end
		if (requested < 1) requested = 1;
		var threadCount:Int = Std.int(Math.max(1, Math.min(platformMax, Math.min(available, requested))));
		#else
		var threadCount:Int = 1;
		#end
		trace('[LoadingState] Preload thread sayısı: $threadCount');
		threadPool = new FixedThreadPool(threadCount);
	}

	public static function prepareToSong()
	{
		if(PlayState.SONG == null)
		{
			imagesToPrepare = [];
			soundsToPrepare = [];
			musicToPrepare = [];
			songsToPrepare = [];
			imageStatus = new Map();
			loaded = 0;
			loadMax = 0;
			loadStatus = 'Hazırlanıyor...';
			initialThreadCompleted = true;
			isIntrusive = false;
			return;
		}

		_startPool();
		imagesToPrepare = [];
		soundsToPrepare = [];
		musicToPrepare = [];
		songsToPrepare = [];
		imageStatus = new Map();
		loadStatus = 'Şarkı hazırlanıyor...';

		initialThreadCompleted = false;
			var threadsCompleted:Int = 0;
			var threadsMax:Int = 0;
			var completionMutex:Mutex = new Mutex();
			var preloadStarted:Bool = false;
			var schedulingComplete:Bool = false;

			function tryStartPreload():Void
			{
				var shouldStart:Bool = false;
				completionMutex.acquire();
				if (schedulingComplete && !preloadStarted && threadsCompleted >= threadsMax)
				{
					preloadStarted = true;
					shouldStart = true;
				}
				completionMutex.release();
				if (shouldStart)
				{
					clearInvalids();
					startThreads();
					initialThreadCompleted = true;
				}
			}

			function completedThread()
			{
				completionMutex.acquire();
				threadsCompleted++;
				completionMutex.release();
				tryStartPreload();
			}

		var song:SwagSong = PlayState.SONG;
		var folder:String = Paths.formatToSongPath(Song.loadedSongName);
		new Future<Bool>(() -> {
			var noteSkin:String = Note.defaultNoteSkin;
			if(PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1) noteSkin = PlayState.SONG.arrowSkin;
	
			var customSkin:String = noteSkin + Note.getNoteSkinPostfix();
			if(Paths.fileExists('images/$customSkin.png', IMAGE)) noteSkin = customSkin;
			queueImage(noteSkin, 'Notalar yükleniyor');

			var noteSplash:String = NoteSplash.defaultNoteSplash;
			if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) noteSplash = PlayState.SONG.splashSkin;
			else noteSplash += NoteSplash.getSplashSkinPostfix();
			queueImage(noteSplash, 'Notalar yükleniyor');

			try
			{
				var path:String = Paths.json('$folder/preload');
				var json:Dynamic = null;

				#if MODS_ALLOWED
				var moddyFile:String = Paths.modsJson('$folder/preload');
				if (FileSystem.exists(moddyFile)) json = Json.parse(File.getContent(moddyFile));
				else json = Json.parse(File.getContent(path));
				#else
				json = Json.parse(Assets.getText(path));
				#end

				if(json != null)
				{
					var imgs:Array<String> = [];
					var snds:Array<String> = [];
					var mscs:Array<String> = [];
					for (asset in Reflect.fields(json))
					{
						var filters:Int = Reflect.field(json, asset);
						var asset:String = asset.trim();

						if(filters < 0 || StageData.validateVisibility(filters))
						{
							if(asset.startsWith('images/'))
								imgs.push(asset.substr('images/'.length));
							else if(asset.startsWith('sounds/'))
								snds.push(asset.substr('sounds/'.length));
							else if(asset.startsWith('music/'))
								mscs.push(asset.substr('music/'.length));
						}
					}
					prepare(imgs, snds, mscs, 'Görseller yükleniyor');
				}
			}
			catch(e:Dynamic) {}
			return true;
		}, isIntrusive)
		.then((_) -> new Future<Bool>(() -> {
			if (song.stage == null || song.stage.length < 1)
				song.stage = StageData.vanillaSongStage(folder);

			var stageData:StageFile = StageData.getStageFile(song.stage);
			if (stageData != null)
			{
				var imgs:Array<String> = [];
				var snds:Array<String> = [];
				var mscs:Array<String> = [];
				if(stageData.preload != null)
				{
					for (asset in Reflect.fields(stageData.preload))
					{
						var filters:Int = Reflect.field(stageData.preload, asset);
						var asset:String = asset.trim();

						if(filters < 0 || StageData.validateVisibility(filters))
						{
							if(asset.startsWith('images/'))
								imgs.push(asset.substr('images/'.length));
							else if(asset.startsWith('sounds/'))
								snds.push(asset.substr('sounds/'.length));
							else if(asset.startsWith('music/'))
								mscs.push(asset.substr('music/'.length));
						}
					}
				}
				
				if (stageData.objects != null)
				{
					for (sprite in stageData.objects)
					{
						if(sprite.type == 'sprite' || sprite.type == 'animatedSprite')
							if((sprite.filters < 0 || StageData.validateVisibility(sprite.filters)) && !imgs.contains(sprite.image))
								imgs.push(sprite.image);
					}
				}
				prepare(imgs, snds, mscs, 'Stage yükleniyor');
			}

			loadStatus = 'Karakterler yükleniyor';
			songsToPrepare.push('$folder/Inst');

			var player1:String = song.player1;
			var player2:String = song.player2;
			var gfVersion:String = song.gfVersion;
			var prefixVocals:String = song.needsVoices ? '$folder/Voices' : null;
			if (gfVersion == null) gfVersion = 'gf';

			dontPreloadDefaultVoices = false;
			preloadCharacter(player1, prefixVocals);
			if (!dontPreloadDefaultVoices && prefixVocals != null)
			{
				if(Paths.fileExists('$prefixVocals-Player.${Paths.SOUND_EXT}', SOUND, false, 'songs') && Paths.fileExists('$prefixVocals-Opponent.${Paths.SOUND_EXT}', SOUND, false, 'songs'))
				{
					songsToPrepare.push('$prefixVocals-Player');
					songsToPrepare.push('$prefixVocals-Opponent');
				}
				else if(Paths.fileExists('$prefixVocals.${Paths.SOUND_EXT}', SOUND, false, 'songs'))
					songsToPrepare.push(prefixVocals);
			}

			if (player2 != player1)
			{
				threadsMax++;
				threadPool.run(() -> {
					try { preloadCharacter(player2, prefixVocals); } catch (e:Dynamic) {}
					completedThread();
				});
			}
			if (!stageData.hide_girlfriend && gfVersion != player2 && gfVersion != player1)
			{
				threadsMax++;
				threadPool.run(() -> {
					try { preloadCharacter(gfVersion); } catch (e:Dynamic) {}
					completedThread();
				});
			}

			completionMutex.acquire();
			schedulingComplete = true;
			completionMutex.release();
			tryStartPreload();
			return true;
		}, isIntrusive))
		.onError((err:Dynamic) -> {
			trace('HATA! şarkı hazırlanırken: $err');
			trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack(true)));
			try
			{
				clearInvalids();
				startThreads();
			}
			catch (fallbackError:Dynamic)
			{
				trace('HATA! preload fallback başlatılamadı: $fallbackError');
				loaded = loadMax = 0;
			}
			initialThreadCompleted = true;
		});
	}

	public static function clearInvalids()
	{
		dedupeQueue(imagesToPrepare);
		dedupeQueue(soundsToPrepare);
		dedupeQueue(musicToPrepare);
		dedupeQueue(songsToPrepare);
		clearInvalidFrom(imagesToPrepare, 'images', '.png', IMAGE);
		clearInvalidFrom(soundsToPrepare, 'sounds', '.${Paths.SOUND_EXT}', SOUND);
		clearInvalidFrom(musicToPrepare, 'music',' .${Paths.SOUND_EXT}', SOUND);
		clearInvalidFrom(songsToPrepare, 'songs', '.${Paths.SOUND_EXT}', SOUND, 'songs');

		for (arr in [imagesToPrepare, soundsToPrepare, musicToPrepare, songsToPrepare])
			while (arr.contains(null))
				arr.remove(null);
	}

	static function clearInvalidFrom(arr:Array<String>, prefix:String, ext:String, type:AssetType, ?parentFolder:String = null)
	{
		for (folder in arr.copy())
		{
			var nam:String = folder.trim();
			if(nam.endsWith('/'))
			{
				for (subfolder in Mods.directoriesWithFile(Paths.getSharedPath(), '$prefix/$nam'))
				{
					for (file in Paths.readDirectory(subfolder))
					{
						if(file.endsWith(ext))
						{
							var toAdd:String = nam + haxe.io.Path.withoutExtension(file);
							if(!arr.contains(toAdd)) arr.push(toAdd);
						}
					}
				}
			}
		}

		var i:Int = 0;
		while(i < arr.length)
		{
			var member:String = arr[i];
			var myKey = '$prefix/$member$ext';
			if(parentFolder == 'songs') myKey = '$member$ext';

			var doTrace:Bool = false;
			if(member.endsWith('/') || (!Paths.fileExists(myKey, type, false, parentFolder) && (doTrace = true)))
			{
				arr.remove(member);
				if(doTrace) trace('Geçersiz $prefix kaldırıldı: $member');
			}
			else i++;
		}
	}

	public static function startThreads()
	{
		mutex = new Mutex();
		#if mobile
		imagesToPrepare = [];
		#end
		loadMax = imagesToPrepare.length + soundsToPrepare.length + musicToPrepare.length + songsToPrepare.length;
		loaded = 0;

		_threadFunc();
	}

	static function _threadFunc()
	{
		if (threadPool == null) _startPool();
		for (sound in soundsToPrepare) initThread(() -> preloadSound('sounds/$sound'), 'Sesler yükleniyor');
		for (music in musicToPrepare) initThread(() -> preloadSound('music/$music'), 'Müzik yükleniyor');
		for (song in songsToPrepare) initThread(() -> preloadSound(song, 'songs', true, false), 'Müzik yükleniyor');

		#if mobile
		imagesToPrepare = [];
		#else
		for (image in imagesToPrepare)
		{
			var st:String = imageStatus.exists(image) ? imageStatus.get(image) : 'Görseller yükleniyor';
			initThread(() -> preloadGraphic(image), st);
		}
		#end
	}

	static function initThread(func:Void->Dynamic, traceData:String)
	{
		#if debug
		var threadSchedule = Sys.time();
		#end
		threadPool.run(() -> {
			#if debug
			var threadStart = Sys.time();
			trace('$traceData ön yüklemeye başlamak ${threadStart - threadSchedule}s sürdü');
			#end
			setLoadStatus(traceData);

			try {
				if (func() != null) {
					#if debug
					var diff = Sys.time() - threadStart;
					trace('$traceData ön yüklemesi ${diff}s\'de tamamlandı');
					#end
				} else trace('HATA! $traceData ön yüklemesi başarısız');
			}
			catch(e:Dynamic) {
				trace('HATA! $traceData ön yüklemesi başarısız: $e');
			}
			if (mutex != null) mutex.acquire();
			loaded++;
			if (mutex != null) mutex.release();
		});
	}

	inline private static function preloadCharacter(char:String, ?prefixVocals:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end

			var isAnimateAtlas:Bool = false;
			var img:String = character.image;
			img = img.trim();
			#if flxanimate
			var animToFind:String = Paths.getPath('images/$img/Animation.json', TEXT);
			if (#if MODS_ALLOWED FileSystem.exists(animToFind) || #end Assets.exists(animToFind))
				isAnimateAtlas = true;
			#end

			if(!isAnimateAtlas)
			{
				var split:Array<String> = img.split(',');
				for (file in split)
				{
					queueImage(file.trim(), 'Karakterler yükleniyor');
				}
			}
			#if flxanimate
			else
			{
				for (i in 0...10)
				{
					var st:String = '$i';
					if(i == 0) st = '';
	
					if(Paths.fileExists('images/$img/spritemap$st.png', IMAGE))
					{
						queueImage('$img/spritemap$st', 'Karakterler yükleniyor');
						break;
					}
				}
			}
			#end
	
			if (prefixVocals != null && character.vocals_file != null && character.vocals_file.length > 0)
			{
				songsToPrepare.push(prefixVocals + "-" + character.vocals_file);
				if(char == PlayState.SONG.player1) dontPreloadDefaultVoices = true;
			}
		}
		catch(e:haxe.Exception)
		{
			trace(e.details());
		}
	}

	static function preloadSound(key:String, ?path:String, ?modsAllowed:Bool = true, ?beepOnNull:Bool = true):Null<Sound>
	{
		if (path == 'songs' && key != null)
		{
			var slash:Int = key.lastIndexOf('/');
			if (slash > 0)
			{
				var songDir:String = key.substr(0, slash);
				var stem:String = key.substr(slash + 1);
				var stemLower:String = stem.toLowerCase();
				var preloaded:Sound = null;
				if (stemLower == 'inst')
					preloaded = Paths.inst(songDir);
				else if (stemLower == 'voices')
					preloaded = Paths.voices(songDir);
				else if (stemLower.startsWith('voices-'))
					preloaded = Paths.voices(songDir, stem.substr(7));
				if (preloaded != null)
					return preloaded;
			}
		}
		var file:String = Paths.getPath(Language.getFileTranslation(key) + '.${Paths.SOUND_EXT}', SOUND, path, modsAllowed);

		if(!Paths.currentTrackedSounds.exists(file))
		{
			if (#if sys FileSystem.exists(file) || #end OpenFlAssets.exists(file, SOUND))
			{
				var sound:Sound = #if sys Sound.fromFile(file) #else OpenFlAssets.getSound(file, false) #end;
				mutex.acquire();
				Paths.currentTrackedSounds.set(file, sound);
				mutex.release();
			}
			else if (beepOnNull)
			{
				trace('SES BULUNAMADI: $key, YOL: $path');
				FlxG.log.error('SES BULUNAMADI: $key, YOL: $path');
				return FlxAssets.getSound('flixel/sounds/beep');
			}
		}
		mutex.acquire();
		Paths.localTrackedAssets.push(file);
		mutex.release();

		return Paths.currentTrackedSounds.get(file);
	}

	static function preloadGraphic(key:String):Null<BitmapData>
	{
		try {
			var requestKey:String = 'images/$key';
			#if TRANSLATIONS_ALLOWED requestKey = Language.getFileTranslation(requestKey); #end
			if(requestKey.lastIndexOf('.') < 0) requestKey += '.png';

			if (!Paths.currentTrackedAssets.exists(requestKey))
			{
				var file:String = Paths.getPath(requestKey, IMAGE);
				if (#if sys FileSystem.exists(file) || #end OpenFlAssets.exists(file, IMAGE))
				{
					#if sys
					var bitmap:BitmapData = BitmapData.fromFile(file);
					#else
					var bitmap:BitmapData = OpenFlAssets.getBitmapData(file, false);
					#end

					mutex.acquire();
					requestedBitmaps.set(file, bitmap);
					originalBitmapKeys.set(file, requestKey);
					mutex.release();
					return bitmap;
				}
				else trace('böyle bir görsel mevcut değil: $key');
			}

				var tracked = Paths.currentTrackedAssets.get(requestKey);
				return tracked != null ? tracked.bitmap : null;
			}
		catch(e:haxe.Exception)
		{
			trace('HATA! $key görseli ön yüklenirken başarısız');
		}

		return null;
	}
}
package backend;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;
import backend.Log;

import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.system.System;
import openfl.geom.Rectangle;

import lime.utils.Assets;
import flash.media.Sound;

import haxe.Json;


#if MODS_ALLOWED
import backend.Mods;
#end

@:access(openfl.display.BitmapData)
class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = ['assets/shared/music/freakyMenu.$SOUND_EXT', 'assets/shared/mobile/touchpad/bg.png'];
	// NovaFlare'ın state-geçişi cache politikasından uyarlanan güvenli temizlik.
	// Her menü geçişinde senkron major GC çalıştırmak ciddi frame hitch üretir.
	public static function clearUnusedMemory(?forceMajorGc:Bool = false)
	{
		for (key in currentTrackedAssets.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				var graphic = currentTrackedAssets.get(key);
				currentTrackedAssets.remove(key);
				releaseGraphicWhenUnused(graphic);
			}
		}

		// Normal geçişlerde hxcpp kendi GC zamanlamasını kullansın. Bu seçenek
		// yalnızca gerçek bellek baskısı veya tanılama için zorlanmalıdır.
		if (forceMajorGc)
		{
			System.gc();
			#if cpp
			cpp.NativeGc.run(true);
			#end
		}
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			var cachedGraphic = FlxG.bitmap.get(key);
			// Further'da currentTrackedAssets bazen logical asset ID ile, Flixel
			// cache ise gerçek mod dosya yoluyla anahtarlanır. Sadece key'e bakmak
			// hâlâ kullanılan karakter texture'ını yanlışlıkla serbest bırakıyordu.
			if (!currentTrackedAssets.exists(key) && !isTrackedGraphic(cachedGraphic))
				releaseGraphicWhenUnused(cachedGraphic);
		}

		// clear all sounds that are cached
		// KORUMA: şu an ÇALAN müziğin sesini asla temizleme (inst ölümü / anında biten şarkı)
		var playingSound:Sound = null;
		if (FlxG.sound.music != null)
			playingSound = @:privateAccess FlxG.sound.music._sound;
		for (key => asset in currentTrackedSounds)
		{
			if (asset != null && asset == playingSound) continue;
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = [];
		function checkForGraphics(spr:Dynamic)
		{
			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
				if(grp != null)
				{
					//trace('is actually a group');
					for (member in grp)
					{
						checkForGraphics(member);
					}
					return;
				}
			}

			//trace('check...');
			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
				if(gfx != null)
				{
					protectedGfx.push(gfx);
					//trace('gfx added to the list successfully!');
				}
			}
			//catch(haxe.Exception) {}
		}

		for (member in FlxG.state.members)
			checkForGraphics(member);

		if(FlxG.state.subState != null)
			for (member in FlxG.state.subState.members)
				checkForGraphics(member);

		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);
				if(!protectedGfx.contains(graphic))
				{
					destroyGraphic(graphic); // get rid of the graphic
					currentTrackedAssets.remove(key); // and remove the key from local cache map
					//trace('deleted $key');
				}
			}
		}
	}

	static function isTrackedGraphic(graphic:FlxGraphic):Bool
	{
		if (graphic == null) return false;
		for (tracked in currentTrackedAssets)
			if (tracked == graphic) return true;
		return false;
	}

	static function releaseGraphicWhenUnused(graphic:FlxGraphic):Void
	{
		if (graphic == null || graphic.isDestroyed) return;
		// Eski state son draw/update turundayken texture'ı anında dispose etmek
		// native GL hatasına yol açabilir. Aktif owner varsa Flixel'e bırak.
		if (graphic.useCount > 0)
		{
			graphic.persist = false;
			graphic.destroyOnNoUse = true;
			return;
		}
		destroyGraphic(graphic);
	}

	inline static function destroyGraphic(graphic:FlxGraphic)
	{
		if (graphic == null || graphic.isDestroyed) return;
		// BitmapFrontEnd.remove, CPU/GPU kaynaklarını Flixel'in doğru yaşam
		// döngüsünde serbest bırakır; texture'ı önceden elle dispose etme.
		FlxG.bitmap.remove(graphic);
	}

	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
		currentLevel = name.toLowerCase();

	public static function getPath(file:String, ?type:AssetType = TEXT, ?parentfolder:String, ?modsAllowed:Bool = true):String
	{
		#if MODS_ALLOWED
		if(modsAllowed)
		{
			var customFile:String = file;
			if (parentfolder != null) customFile = '$parentfolder/$file';

			var modded:String = modFolders(customFile);
			if(FileSystem.exists(modded)) return modded;
		}
		#end
		if(parentfolder == "mobile")
			return getSharedPath('mobile/$file');

		if (parentfolder != null)
			return getFolderPath(file, parentfolder);

		if (currentLevel != null && currentLevel != 'shared')
		{
			var levelPath = getFolderPath(file, currentLevel);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}
		return getSharedPath(file);
	}

	inline static public function getFolderPath(file:String, folder = "shared")
		return 'assets/$folder/$file';

	inline public static function getSharedPath(file:String = '')
		return 'assets/shared/$file';

	inline static public function txt(key:String, ?folder:String)
		return getPath('data/$key.txt', TEXT, folder, true);

	inline static public function xml(key:String, ?folder:String)
		return getPath('data/$key.xml', TEXT, folder, true);

	inline static public function json(key:String, ?folder:String)
		return getPath('data/$key.json', TEXT, folder, true);

	inline static public function shaderFragment(key:String, ?folder:String)
		return getPath('shaders/$key.frag', TEXT, folder, true);

	inline static public function shaderVertex(key:String, ?folder:String)
		return getPath('shaders/$key.vert', TEXT, folder, true);

	inline static public function lua(key:String, ?folder:String)
		return getPath('$key.lua', TEXT, folder, true);

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) return file;
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	inline static public function sound(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('sounds/$key', modsAllowed);

	inline static public function music(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('music/$key', modsAllowed);

	public static function inst(song:String, ?modsAllowed:Bool = true):Sound
	{
		#if MODS_ALLOWED
		// V-SLICE KÖPRÜSÜ: V-Slice modları sesi songs/<Song>/Inst.ogg altında
		// tutar (büyük/küçük harf farkı olabilir). Önce normal Psych yolunu dene,
		// bulunamazsa V-Slice ses yolunu case-insensitive bul.
		var found:String = findVSliceAudio('songs', formatToSongPath(song), 'Inst');
		if (found != null) return returnSoundFromPath(found);
		// CODENAME ENGINE KÖPRÜSÜ: CNE sesleri assets/songs/<song>/song/ altındadır.
		var cneFound:String = cne.compatibility.CNECompat.findSongAudio(song, 'Inst');
		if (cneFound != null) return returnSoundFromPath(cneFound);
		#end
		return returnSound('${formatToSongPath(song)}/Inst', 'songs', modsAllowed);
	}

	public static function voices(song:String, postfix:String = null, ?modsAllowed:Bool = true):Sound
	{
		var songKey:String = '${formatToSongPath(song)}/Voices';
		if(postfix != null) songKey += '-' + postfix;

		#if MODS_ALLOWED
		// V-SLICE KÖPRÜSÜ: V-Slice modları çift vokal kullanır (Voices-Bf.ogg +
		// Voices-Zardy.ogg). Psych tek Voices.ogg bekler; önce normal yolu dene,
		// bulunamazsa Voices-Bf.ogg'u Voices olarak kullan (case-insensitive).
		var found:String = findVSliceAudio('songs', formatToSongPath(song), 'Voices', postfix);
		if (found != null) return returnSoundFromPath(found);
		// CODENAME ENGINE KÖPRÜSÜ: CNE sesleri assets/songs/<song>/song/ altındadır.
		var cneFound:String = cne.compatibility.CNECompat.findSongAudio(song, 'Voices');
		if (cneFound != null) return returnSoundFromPath(cneFound);
		#end
		return returnSound(songKey, 'songs', modsAllowed, false);
	}

	/** V-Slice modundaki ses dosyasını case-insensitive olarak bulur (yol döner). */
	static function findVSliceAudio(lib:String, song:String, name:String, ?postfix:String):String
	{
		#if (MODS_ALLOWED && sys)
		var searchDirs:Array<String> = [];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			searchDirs.push(Mods.currentModDirectory);
		for (mod in Mods.getGlobalMods())
			if (!searchDirs.contains(mod)) searchDirs.push(mod);

		// Postfix (karakter id / 'Player' / 'Opponent') dosya adına birebir
		// eşleşme olarak denenir; jenerik isimler yedek olarak kalır.
		var pf:String = (postfix != null && postfix.length > 0) ? postfix.toLowerCase() : null;

		for (mod in searchDirs)
		{
			var base:String = mods(mod) + '$lib/';
			if (!FileSystem.exists(base)) continue;
			// şarkı klasörünü case-insensitive bul
			for (dir in FileSystem.readDirectory(base))
			{
				if (dir.toLowerCase() != song.toLowerCase()) continue;
				var sdir:String = base + dir + '/';
				if (!FileSystem.isDirectory(sdir)) continue;
				// V-Slice sesleri: Voices.ogg / Voices-<karakter>.ogg /
				// Voices-bf.ogg / ilk Voices-* — öncelik sırasıyla tara.
				var files:Array<String> = FileSystem.readDirectory(sdir);
				var want:String = name.toLowerCase();
				function findExact(suffix:String):String
				{
					for (ext in ['.ogg', '.mp3'])
						for (f in files)
							if (f.toLowerCase() == want + suffix + ext) return sdir + f;
					return null;
				}
				var hit:String = findExact('');
				if (hit != null) return hit;
				if (pf != null)
				{
					hit = findExact('-' + pf);
					if (hit != null) return hit;
				}
				hit = findExact('-bf');
				if (hit != null) return hit;
				for (ext in ['.ogg', '.mp3'])
					for (f in files)
					{
						var fl:String = f.toLowerCase();
						if (StringTools.startsWith(fl, want + '-') && StringTools.endsWith(fl, ext))
							return sdir + f;
					}
			}
		}
		#end
		return null;
	}

	/** Verilen dosya yolundan ses yükler (returnSound mantığıyla). */
	static function returnSoundFromPath(file:String):Sound
	{
		#if sys
		if (FileSystem.exists(file) && !currentTrackedSounds.exists(file))
			currentTrackedSounds.set(file, Sound.fromFile(file));
		if (currentTrackedSounds.exists(file))
		{
			// KRİTİK: stok returnSound gibi bunu da 'yerel' işaretle.
			// İşaretlenmezse clearUnusedMemory bu sesi 'kullanılmıyor' sanıp
			// şarkı ÇALARKEN cache'ten siliyordu → inst ölüyordu → şarkı anında bitiyordu.
			localTrackedAssets.push(file);
			return currentTrackedSounds.get(file);
		}
		#else
		if (OpenFlAssets.exists(file, SOUND))
		{
			localTrackedAssets.push(file);
			return OpenFlAssets.getSound(file);
		}
		#end
		return FlxAssets.getSound('flixel/sounds/beep');
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?modsAllowed:Bool = true)
		return sound(key + FlxG.random.int(min, max), modsAllowed);

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	static public function image(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		key = Language.getFileTranslation('images/$key') + '.png';
		var bitmap:BitmapData = null;
		if (currentTrackedAssets.exists(key))
		{
			localTrackedAssets.push(key);
			return currentTrackedAssets.get(key);
		}
		return cacheBitmap(key, parentFolder, bitmap, allowGPU);
	}

	public static function cacheBitmap(key:String, ?parentFolder:String = null, ?bitmap:BitmapData, ?allowGPU:Bool = true):FlxGraphic
	{
		if (bitmap == null)
		{
			var file:String = getPath(key, IMAGE, parentFolder, true);
			#if MODS_ALLOWED
			if (FileSystem.exists(file))
				bitmap = BitmapData.fromFile(file);
			else #end if (OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);

			if (bitmap == null)
			{
				Log.warn('asset', 'Bitmap not found: $file | key: $key');
				return null;
			}
		}

		if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null)
		{
			bitmap.lock();
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.image.data = null;
			bitmap.image = null;
			bitmap.readable = true;
		}

		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(key, graph);
		localTrackedAssets.push(key);
		return graph;
	}

	inline static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		var path:String = getPath(key, TEXT, !ignoreMods);
		#if sys
		return (FileSystem.exists(path)) ? File.getContent(path) : null;
		#else
		return (OpenFlAssets.exists(path, TEXT)) ? Assets.getText(path) : null;
		#end
	}

	inline static public function font(key:String)
	{
		var folderKey:String = Language.getFileTranslation('fonts/$key');
		#if MODS_ALLOWED
		var file:String = modFolders(folderKey);
		if(FileSystem.exists(file)) return file;
		#end
		return 'assets/$folderKey';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?parentFolder:String = null)
	{
		#if MODS_ALLOWED
		if(!ignoreMods && !SafeMode.active)
		{
			var modKey:String = key;
			if(parentFolder == 'songs') modKey = 'songs/$key';

			for(mod in Mods.getGlobalMods())
				if (FileSystem.exists(mods('$mod/$modKey')))
					return true;
				// CODENAME ENGINE KÖPRÜSÜ
				else if (cne.compatibility.CNECompat.cneFile(mod, modKey) != null)
					return true;
				#if linux
				else if (FileSystem.exists(findFile('$mod/$modKey')))
					return true;
				#end

			if (FileSystem.exists(mods(Mods.currentModDirectory + '/' + modKey)) || FileSystem.exists(mods(modKey))
				|| cne.compatibility.CNECompat.cneFile(Mods.currentModDirectory, modKey) != null)
				return true;
			#if linux
			else if (FileSystem.exists(findFile(modKey)))
				return true;
			#end
		}
		#end
		return (OpenFlAssets.exists(getPath(key, type, parentFolder, false)));
	}

	static public function getAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var useMod = false;
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		if (imageLoaded == null)
		{
			trace('[Paths] Atlas PNG yüklenemedi: $key');
			return null;
		}

		var myXml:Dynamic = getPath('images/$key.xml', TEXT, parentFolder, true);
		if(OpenFlAssets.exists(myXml) #if MODS_ALLOWED || (FileSystem.exists(myXml) && (useMod = true)) #end )
		{
			#if MODS_ALLOWED
			return FlxAtlasFrames.fromSparrow(imageLoaded, (useMod ? File.getContent(myXml) : myXml));
			#else
			return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
			#end
		}
		else
		{
			var myJson:Dynamic = getPath('images/$key.json', TEXT, parentFolder, true);
			if(OpenFlAssets.exists(myJson) #if MODS_ALLOWED || (FileSystem.exists(myJson) && (useMod = true)) #end )
			{
				#if MODS_ALLOWED
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (useMod ? File.getContent(myJson) : myJson));
				#else
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
				#end
			}
		}
		return getPackerAtlas(key, parentFolder);
	}
	
	static public function getMultiAtlas(keys:Array<String>, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		
		if (keys == null || keys.length == 0) return null;
		var parentFrames:FlxAtlasFrames = Paths.getAtlas(keys[0].trim(), parentFolder, allowGPU);
		if (parentFrames == null) return null;
		if(keys.length > 1)
		{
			var original:FlxAtlasFrames = parentFrames;
			parentFrames = new FlxAtlasFrames(parentFrames.parent);
			parentFrames.addAtlas(original, true);
			for (i in 1...keys.length)
			{
				var extraFrames:FlxAtlasFrames = Paths.getAtlas(keys[i].trim(), parentFolder, allowGPU);
				if(extraFrames != null)
					parentFrames.addAtlas(extraFrames, true);
			}
		}
		return parentFrames;
	}

	inline static public function getSparrowAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		#if debug
		if(key.contains('psychic')) Log.debug('asset', 'Sparrow atlas: $key (folder=$parentFolder, gpu=$allowGPU)');
		#end
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		if (imageLoaded == null) { Log.warn('asset', 'Sparrow PNG yüklenemedi: $key'); return null; }
		#if MODS_ALLOWED
		var xmlExists:Bool = false;

		var xml:String = modsXml(key);
		if(FileSystem.exists(xml)) xmlExists = true;

		return FlxAtlasFrames.fromSparrow(imageLoaded, (xmlExists ? File.getContent(xml) : getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromSparrow(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder));
		#end
	}

	inline static public function getPackerAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		if (imageLoaded == null) { Log.warn('asset', 'Packer PNG yüklenemedi: $key'); return null; }
		#if MODS_ALLOWED
		var txtExists:Bool = false;
		
		var txt:String = modsTxt(key);
		if(FileSystem.exists(txt)) txtExists = true;

		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, (txtExists ? File.getContent(txt) : getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder));
		#end
	}

	inline static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		if (imageLoaded == null) { Log.warn('asset', 'Aseprite PNG yüklenemedi: $key'); return null; }
		#if MODS_ALLOWED
		var jsonExists:Bool = false;

		var json:String = modsImagesJson(key);
		if(FileSystem.exists(json)) jsonExists = true;

		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (jsonExists ? File.getContent(json) : getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder));
		#end
	}

	inline static public function formatToSongPath(path:String) {
		var invalidChars = ~/[~&;:<>#\s]/g;
		var hideChars = ~/[.,'"%?!]/g;

		return hideChars.replace(invalidChars.replace(path, '-'), '').trim().toLowerCase();
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(key:String, ?path:String, ?modsAllowed:Bool = true, ?beepOnNull:Bool = true)
	{
		var file:String = getPath(Language.getFileTranslation(key) + '.$SOUND_EXT', SOUND, path, modsAllowed);

		//trace('precaching sound: $file');
		if(!currentTrackedSounds.exists(file))
		{
			#if sys
			if(FileSystem.exists(file))
				currentTrackedSounds.set(file, Sound.fromFile(file));
			#else
			if(OpenFlAssets.exists(file, SOUND))
				currentTrackedSounds.set(file, OpenFlAssets.getSound(file));
			#end
			else if(beepOnNull)
			{
				Log.warn('audio', 'SOUND NOT FOUND: $key, PATH: $path');
				FlxG.log.error('SOUND NOT FOUND: $key, PATH: $path');
				return FlxAssets.getSound('flixel/sounds/beep');
			}
		}
		localTrackedAssets.push(file);
		return currentTrackedSounds.get(file);
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '')
		return #if android StorageUtil.getExternalStorageDirectory() + #else Sys.getCwd() + #end 'mods/' + key;

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsVideo(key:String)
		return modFolders('videos/' + key + '.' + VIDEO_EXT);

	inline static public function modsSounds(path:String, key:String)
		return modFolders(path + '/' + key + '.' + SOUND_EXT);

	inline static public function modsImages(key:String)
		return modFolders('images/' + key + '.png');

	inline static public function modsXml(key:String)
		return modFolders('images/' + key + '.xml');

	inline static public function modsTxt(key:String)
		return modFolders('images/' + key + '.txt');

	inline static public function modsImagesJson(key:String)
		return modFolders('images/' + key + '.json');

	static public function modFolders(key:String)
	{
		if (SafeMode.active)
			return (#if android StorageUtil.getExternalStorageDirectory() + #else Sys.getCwd() + #end 'mods/__SAFE_MODE_DISABLED__/' + key);

		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var fileToCheck:String = mods(Mods.currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
			// CODENAME ENGINE KÖPRÜSÜ: CNE modları asset'lerini 'assets/' altında tutar.
			var cneCheck:String = cne.compatibility.CNECompat.cneFile(Mods.currentModDirectory, key);
			if(cneCheck != null)
				return cneCheck;
			// V-SLICE KÖPRÜSÜ: V-Slice modları asset'lerini 'shared/' altında tutar.
			// Psych '<key>' ararken, mods/<mod>/shared/<key> de denensin.
			var vsliceCheck:String = mods(Mods.currentModDirectory + '/shared/' + key);
			if(FileSystem.exists(vsliceCheck))
				return vsliceCheck;
			#if linux
			else
			{
				var newPath:String = findFile(key);
				if (newPath != null)
					return newPath;
			}
			#end
		}

		for(mod in Mods.getGlobalMods())
		{
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
			// CODENAME ENGINE KÖPRÜSÜ: global CNE modlarında assets/ altını dene.
			var cneCheck:String = cne.compatibility.CNECompat.cneFile(mod, key);
			if(cneCheck != null)
				return cneCheck;
			// V-SLICE KÖPRÜSÜ: global modlarda da shared/ altını dene.
			var vsliceCheck:String = mods(mod + '/shared/' + key);
			if(FileSystem.exists(vsliceCheck))
				return vsliceCheck;
			#if linux
			else
			{
				var newPath:String = findFile(key);
				if (newPath != null)
					return newPath;
			}
			#end
		}
		return (#if android StorageUtil.getExternalStorageDirectory() + #else Sys.getCwd() + #end 'mods/' + key);
	}

	#if linux
	static function findFile(key:String):String {
		var targetParts:Array<String> = key.replace('\\', '/').split('/');
		if (targetParts.length == 0) return null;

		var baseDir:String = targetParts.shift();
		var searchDirs:Array<String> = [
			mods(Mods.currentModDirectory + '/' + baseDir),
			mods(baseDir)
		];

		for (part in targetParts) {
			if (part == '') continue;

			var nextDir:String = findNodeInDirs(searchDirs, part);
			if (nextDir == null) {
				return null;
			}

			searchDirs = [nextDir];
		}

		return searchDirs[0];
	}

	static function findNodeInDirs(dirs:Array<String>, key:String):String {
		for (dir in dirs) {
			var node:String = findNode(dir, key);
			if (node != null) {
				return dir + '/' + node;
			}
		}
		return null;
	}

	static function findNode(dir:String, key:String):String {
		try {
			var allFiles:Array<String> = Paths.readDirectory(dir);
			var fileMap:Map<String, String> = new Map();

			for (file in allFiles) {
				fileMap.set(file.toLowerCase(), file);
			}

			return fileMap.get(key.toLowerCase());
		} catch (e:Dynamic) {
			return null;
		}
	}
	#end
	#end

	#if flxanimate
	public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null)
	{
		var changedAnimJson = false;
		var changedAtlasJson = false;
		var changedImage = false;
		
		if(spriteJson != null)
		{
			changedAtlasJson = true;
			spriteJson = File.getContent(spriteJson);
		}

		if(animationJson != null) 
		{
			changedAnimJson = true;
			animationJson = File.getContent(animationJson);
		}

		// is folder or image path
		if(Std.isOfType(folderOrImg, String))
		{
			var originalPath:String = folderOrImg;
			for (i in 0...10)
			{
				var st:String = '$i';
				if(i == 0) st = '';

				if(!changedAtlasJson)
				{
					spriteJson = getTextFromFile('images/$originalPath/spritemap$st.json');
					if(spriteJson != null)
					{
						//trace('found Sprite Json');
						changedImage = true;
						changedAtlasJson = true;
						folderOrImg = image('$originalPath/spritemap$st');
						break;
					}
				}
				else if(fileExists('images/$originalPath/spritemap$st.png', IMAGE))
				{
					//trace('found Sprite PNG');
					changedImage = true;
					folderOrImg = image('$originalPath/spritemap$st');
					break;
				}
			}

			if(!changedImage)
			{
				//trace('Changing folderOrImg to FlxGraphic');
				changedImage = true;
				folderOrImg = image(originalPath);
			}

			if(!changedAnimJson)
			{
				//trace('found Animation Json');
				changedAnimJson = true;
				animationJson = getTextFromFile('images/$originalPath/Animation.json');
			}
		}

		//trace(folderOrImg);
		//trace(spriteJson);
		//trace(animationJson);
		spr.loadAtlasEx(folderOrImg, spriteJson, animationJson);
	}
	#end

	public static function readDirectory(directory:String):Array<String>
	{
		#if MODS_ALLOWED
		return FileSystem.readDirectory(directory);
		#else
		var dirs:Array<String> = [];
		for(dir in Assets.list().filter(folder -> folder.startsWith(directory)))
		{
			@:privateAccess
			for(library in lime.utils.Assets.libraries.keys())
			{
				if(library != 'default' && Assets.exists('$library:$dir') && (!dirs.contains('$library:$dir') || !dirs.contains(dir)))
					dirs.push('$library:$dir');
				else if(Assets.exists(dir) && !dirs.contains(dir))
					dirs.push(dir);
			}
		}
		return dirs.map(dir -> dir.substr(dir.lastIndexOf("/") + 1));
		#end
	}
}

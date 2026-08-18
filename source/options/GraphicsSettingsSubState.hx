package options;

import objects.Character;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	public function new()
	{
		title = Language.getPhrase('graphics_menu', 'Grafik Ayarları');
		rpcTitle = 'Graphics Settings Menu';

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		boyfriend.animation.finishCallback = function (name:String) boyfriend.dance();
		boyfriend.visible = false;

		var option:Option = new Option('Düşük Kalite',
			'Aktif edildiğinde, bazı arka plan detaylarını devre dışı bırakır,\nyükleme sürelerini kısaltır ve performansı artırır. ÖNERİ: AÇIK',
			'lowQuality',
			BOOL);
		addOption(option);

		var option:Option = new Option('Kenar Yumuşatma',
			'Devre dışı bırakıldığında, kenar yumuşatma kapatılır,\nperformans artar ancak görseller daha keskin olur. ÖNERİ: KAPALI',
			'antialiasing',
			BOOL);
		option.onChange = onChangeAntiAliasing;
		addOption(option);
		antialiasingOption = optionsArray.length-1;

		var option:Option = new Option('Gölgeler',
			'Devre dışı bırakıldığında, gölgelendiriciler kapatılır.\nBazı görsel efektler için kullanılır ve zayıf ' + Main.platform + ' için yoğundur. ÖNERİ: KAPALI',
			'shaders',
			BOOL);
		addOption(option);

		var option:Option = new Option('GPU Önbellekleme',
			'Aktif edildiğinde, GPU dokuları önbelleğe alarak RAM kullanımını azaltır.\nZayıf bir ekran kartınız varsa bunu açmayın.',
			'cacheOnGPU',
			BOOL);
		addOption(option);

		#if !html5
		var option:Option = new Option('FPS:',
			'Bence gayet açık?',
			'framerate',
			INT);
		addOption(option);

		final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
		option.minValue = 60;
		option.maxValue = 240;
		option.defaultValue = Std.int(FlxMath.bound(refreshRate, option.minValue, option.maxValue));
		option.displayFormat = '%v';
		option.onChange = onChangeFramerate;
		#end

		#if cpp
		var option:Option = new Option('Yükleme iş Parçacığı',
			'Şarkı varlıklarını aynı anda yükleyen iş sayısı. Çok yüksek değerler özellikle mobilde RAM taşmasına neden olabilir.',
			'loadThreads',
			INT);
		option.minValue = 1;
		option.maxValue = #if mobile 2 #else 4 #end;
		option.changeValue = 1;
		option.decimals = 0;
		option.displayFormat = '%v Thread';
		addOption(option);
		#end

		var option:Option = new Option('Yeni FPS Sistemi',
			'Aktif edildiğinde, mevcut FPS sınırın altında olduğunda\noyunun "yavaş" ve "yumuşak" hissettirmesini önler.',
			'fpsRework',
			BOOL);
		addOption(option);

		super();
		insert(1, boyfriend);
	}

	function onChangeAntiAliasing()
	{
		for (sprite in members)
		{
			var sprite:FlxSprite = cast sprite;
			if(sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
				sprite.antialiasing = ClientPrefs.data.antialiasing;
			}
		}
	}

	function onChangeFramerate()
	{
		if(ClientPrefs.data.framerate > FlxG.drawFramerate)
		{
			if (ClientPrefs.data.fpsRework)
				FlxG.stage.window.frameRate = ClientPrefs.data.framerate;
			else
			{
				FlxG.updateFramerate = ClientPrefs.data.framerate;
				FlxG.drawFramerate = ClientPrefs.data.framerate;
			}
		}
		else
		{
			if (ClientPrefs.data.fpsRework)
				FlxG.stage.window.frameRate = ClientPrefs.data.framerate;
			else
			{
				FlxG.drawFramerate = ClientPrefs.data.framerate;
				FlxG.updateFramerate = ClientPrefs.data.framerate;
			}
		}
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}
package options;

class DevInfoSubState extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var titleText:Alphabet;
	var infoText:FlxText;
	var hintText:FlxText;
	var statusText:FlxText;
	var refreshTimer:Float = 0;

	override function create()
	{
		controls.isInSubstate = true;
		super.create();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF0D1B12;
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		titleText = new Alphabet(70, 40, Language.getPhrase('dev_info_title', 'Sistem Paneli'), true);
		titleText.setScale(0.75);
		titleText.scrollFactor.set();
		add(titleText);

		infoText = new FlxText(50, 100, FlxG.width - 100, '', 18);
		infoText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoText.borderSize = 1.8;
		infoText.scrollFactor.set();
		add(infoText);

		statusText = new FlxText(50, FlxG.height - 80, FlxG.width - 100, '', 16);
		statusText.setFormat(Paths.font('vcr.ttf'), 16, 0xFFFFD94D, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		statusText.borderSize = 1.5;
		statusText.scrollFactor.set();
		add(statusText);

		hintText = new FlxText(0, FlxG.height - 36, FlxG.width, 'A: Panoya Kopyala    B: Kapat', 16);
		hintText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hintText.borderSize = 1.5;
		hintText.scrollFactor.set();
		add(hintText);

		addTouchPad('UP_DOWN', 'A_B');

		refreshInfo();
	}

	function platformName():String
	{
		#if windows return 'Windows'; #end
		#if linux return 'Linux'; #end
		#if mac return 'macOS'; #end
		#if android return 'Android'; #end
		#if ios return 'iOS'; #end
		#if html5 return 'HTML5'; #end
		return 'Bilinmiyor';
	}

	function buildInfo():String
	{
		var lines:Array<String> = [];

		lines.push('Motor: ' + UpdateConfig.ENGINE_NAME + '  v' + UpdateConfig.CURRENT_ENGINE_VERSION);
		lines.push('Kanal: ' + (ClientPrefs.data.betaProgram ? 'BETA (pre-release)' : 'Kararlı (stable)'));
		lines.push('Geliştirici Modu: ' + (ClientPrefs.data.devMode ? 'AÇIK' : 'kapalı'));
		lines.push('Güvenli Mod: ' + (backend.SafeMode.active ? 'AKTİF' : 'kapalı'));
		lines.push('');

		lines.push('Aktif State: ' + Type.getClassName(Type.getClass(FlxG.state)));

		var fpsNum:Dynamic = null;
		try fpsNum = Reflect.field(Main.fpsVar, 'currentFPS') catch (e:Dynamic) {};
		lines.push('FPS: ' + (fpsNum == null ? '?' : Std.string(fpsNum)));

		#if cpp
		var mem:Float = 0;
		try mem = openfl.system.System.totalMemory catch (e:Dynamic) {};
		if (mem > 0)
			lines.push('Bellek (totalMemory): ' + FlxMath.roundDecimal(mem / 1048576, 1) + ' MB');
		#end

		lines.push('Mod Dizini: ' + (Mods.currentModDirectory == '' ? '(yok)' : Mods.currentModDirectory));
		lines.push('GPU Cache: ' + ClientPrefs.data.cacheOnGPU + '  /  Load Threads: ' + ClientPrefs.data.loadThreads);

		#if FURTHER_ONLINE
		lines.push('Further Online: derlemede AÇIK');
		#else
		lines.push('Further Online: derlemede kapalı');
		#end

		lines.push('');
		lines.push('Platform: ' + platformName());

		#if sys
		lines.push('Çalışma Dizini: ' + Sys.getCwd());
		#end

		var pkg:String = null;
		try pkg = lime.app.Application.current.meta.get('package') catch (e:Dynamic) {};
		if (pkg != null)
			lines.push('Paket: ' + pkg);

		return lines.join('\n');
	}

	function refreshInfo():Void
	{
		infoText.text = buildInfo();
	}

	function copyToClipboard():Void
	{
		var ok:Bool = false;
		try
		{
			lime.system.Clipboard.text = infoText.text;
			ok = true;
		}
		catch (e:Dynamic)
		{
			try
			{
				openfl.system.System.setClipboard(infoText.text);
				ok = true;
			}
			catch (e2:Dynamic) {}
		}

		if (ok)
		{
			statusText.text = 'Panoya kopyalandı. Hata bildirirken bu metni yapıştırabilirsin.';
			FlxG.sound.play(Paths.sound('confirmMenu'));
		}
		else
		{
			statusText.text = 'Pano erişimi bu platformda yok.';
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		refreshTimer += elapsed;
		if (refreshTimer >= 0.5)
		{
			refreshTimer = 0;
			refreshInfo();
		}

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
			return;
		}

		if (controls.ACCEPT)
			copyToClipboard();
	}
}

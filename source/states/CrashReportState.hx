package states;

import backend.SafeMode;
import lime.system.Clipboard;

class CrashReportState extends MusicBeatState
{
	final report:String;
	final logPath:String;
	var selected:Int = 0;
	var optionText:FlxText;
	var statusText:FlxText;
	final options:Array<String> = ['TAMAM', 'LOGU KOPYALA', 'LOG KLASÖRÜNÜ AÇ', 'GÜVENLİ MODDA YENİDEN BAŞLAT'];

	public function new(report:String, logPath:String)
	{
		this.report = report;
		this.logPath = logPath;
		super();
	}

	override function create():Void
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK));

		var title = new FlxText(0, 36, FlxG.width, 'FURTHER ENGINE BİR HATAYLA KARŞILAŞTI', 30);
		title.setFormat(Paths.font('vcr.ttf'), 30, 0xFFFF5252, CENTER);
		title.screenCenter(X);
		add(title);

		var bodyText = report;
		if (bodyText.length > 2600) bodyText = bodyText.substr(0, 2600) + '\n\n[Log ekranda kısaltıldı. Tam ayrıntı log dosyasındadır.]';
		var body = new FlxText(48, title.y + title.height + 28, FlxG.width - 96, bodyText, 16);
		body.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER);
		add(body);

		optionText = new FlxText(16, FlxG.height - 86, FlxG.width - 32, '', 16);
		optionText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER);
		add(optionText);

		statusText = new FlxText(16, FlxG.height - 42, FlxG.width - 32, '', 14);
		statusText.setFormat(Paths.font('vcr.ttf'), 14, 0xFFAAAAAA, CENTER);
		add(statusText);
		refreshOptions();

		super.create();
		try
		{
			addTouchPad('LEFT_RIGHT', 'A_B');
			addTouchPadCamera();
		}
		catch (e:Dynamic) {}
	}

	override function update(elapsed:Float):Void
	{
		if (controls.UI_LEFT_P)
		{
			selected = FlxMath.wrap(selected - 1, 0, options.length - 1);
			refreshOptions();
		}
		else if (controls.UI_RIGHT_P)
		{
			selected = FlxMath.wrap(selected + 1, 0, options.length - 1);
			refreshOptions();
		}

		if (controls.ACCEPT)
		{
			switch (selected)
			{
				case 0:
					lime.system.System.exit(1);
				case 1:
					copyLog();
				case 2:
					CoolUtil.openFolder('logs/');
					statusText.text = logPath.length > 0 ? 'Log: $logPath' : 'Log klasörü açıldı.';
				case 3:
					var restarted = SafeMode.restart();
					#if desktop
					if (restarted) lime.system.System.exit(1);
					statusText.text = 'Otomatik yeniden başlatılamadı. Oyunu tekrar açtığınızda güvenli mod etkinleşecek.';
					#else
					statusText.text = 'Güvenli mod hazır. Oyunu kapatıp yeniden açın.';
					#end
			}
		}
		else if (controls.BACK)
			lime.system.System.exit(1);

		super.update(elapsed);
	}

	function copyLog():Void
	{
		try
		{
			Clipboard.text = report;
			#if android
			try
			{
				mobile.ScreenUtil.clipboardSetText(report);
			}
			catch (e:Dynamic) {}
			#end
			statusText.text = 'Log panoya kopyalandı.';
		}
		catch (e:Dynamic)
		{
			statusText.text = 'Log kopyalanamadı.';
		}
	}

	function refreshOptions():Void
	{
		var labels:Array<String> = [];
		for (i in 0...options.length)
			labels.push(i == selected ? '[ ${options[i]} ]' : options[i]);
		optionText.text = labels.join('   ');
	}
}

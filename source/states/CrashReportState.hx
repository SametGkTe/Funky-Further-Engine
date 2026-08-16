package states;

import backend.SafeMode;

/**
 * Kurtarılabilir çalışma zamanı hataları için Further Engine çökme ekranı.
 * Tam ekran önce CrashHandler tarafından kapatılır; böylece kullanıcı pencereye
 * ve işletim sistemi kontrollerine erişmeye devam eder.
 */
class CrashReportState extends MusicBeatState
{
	final report:String;
	final logPath:String;
	var selected:Int = 0;
	var optionText:FlxText;
	var statusText:FlxText;
	final options:Array<String> = ['TAMAM', 'LOG KLASÖRÜNÜ AÇ', 'GÜVENLİ MODDA YENİDEN BAŞLAT'];

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

		var title = new FlxText(24, 20, FlxG.width - 48, 'FURTHER ENGINE BİR HATAYLA KARŞILAŞTI', 30);
		title.setFormat(Paths.font('vcr.ttf'), 30, 0xFFFF5252, LEFT);
		add(title);

		var bodyText = report;
		if (bodyText.length > 2600) bodyText = bodyText.substr(0, 2600) + '\n\n[Log ekranda kısaltıldı. Tam ayrıntı log dosyasındadır.]';
		var body = new FlxText(24, 72, FlxG.width - 48, bodyText, 16);
		body.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT);
		add(body);

		optionText = new FlxText(24, FlxG.height - 86, FlxG.width - 48, '', 18);
		optionText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER);
		add(optionText);

		statusText = new FlxText(24, FlxG.height - 42, FlxG.width - 48, '', 14);
		statusText.setFormat(Paths.font('vcr.ttf'), 14, 0xFFAAAAAA, CENTER);
		add(statusText);
		refreshOptions();

		super.create();
		addTouchPad('LEFT_RIGHT', 'A_B');
		addTouchPadCamera();
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
					CoolUtil.openFolder('logs/');
					statusText.text = logPath.length > 0 ? 'Log: $logPath' : 'Log klasörü açıldı.';
				case 2:
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

	function refreshOptions():Void
	{
		var labels:Array<String> = [];
		for (i in 0...options.length)
			labels.push(i == selected ? '[ ${options[i]} ]' : options[i]);
		optionText.text = labels.join('     ');
	}
}

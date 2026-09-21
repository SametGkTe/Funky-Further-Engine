package options;

class DeveloperSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('developer_settings_menu', 'Geliştirici Ayarları');
		rpcTitle = 'Developer Settings Menu';

		var option:Option = new Option('Beta Programı',
			'Beta sürümlerine erken erişim programını açar. Katılım, beta güncelleme denetimi ve ayrılma bu ekrandan yapılır.',
			'',
			OPEN);
		option.onOpen = function() openSubState(new BetaProgramSubState());
		addOption(option);

		var option:Option = new Option('Geliştirici Modu',
			'Deneysel özellikleri ve geliştirici araçlarını etkinleştirir. Normal oynanış için kapalı tutmanız önerilir.',
			'devMode',
			BOOL,
			null,
			'dev_mode');
		addOption(option);

		var option:Option = new Option('Editör Araçları',
			'Tüm editörlere (Chart, Karakter, Stage, Week, Note Splash, Diyalog, Mod Porter) hızlı erişim menüsünü açar.',
			'',
			OPEN);
		option.onOpen = function() openSubState(new EditorToolsSubState());
		addOption(option);

		var option:Option = new Option('Sistem Paneli',
			'Canlı sistem bilgisi paneli: sürüm, kanal, FPS, bellek, mod dizini, platform. A ile panoya kopyalanır; hata bildiriminde kullanışlıdır.',
			'',
			OPEN);
		option.onOpen = function() openSubState(new DevInfoSubState());
		addOption(option);

		var option:Option = new Option('Log Klasörünü Aç',
			'Oyunun kayıt (log) klasörünü dosya yöneticisinde açar. Yalnızca masaüstünde çalışır.',
			'',
			OPEN);
		option.onOpen = openLogsFolder;
		addOption(option);

		var option:Option = new Option('Grafik Önbelleğini Temizle',
			'Bellekteki önbelleğe alınmış grafikleri boşaltır. Kasma veya takılmalarda deneyin.',
			'',
			OPEN);
		option.onOpen = clearGraphicsCache;
		addOption(option);

		var option:Option = new Option('Dokunmaları Göster',
			'Dokunmatik testlerinde her dokunuşu ekranda görselleştirir (mobil geliştirme aracı).',
			'showTouches',
			BOOL,
			null,
			'show_touches');
		addOption(option);

		var option:Option = new Option('Güvenli Mod ile Yeniden Başlat',
			'Oyunu güvenli modda yeniden başlatır (hiçbir mod yüklenmez). Mobilde bayrak yazılır; oyunu elle kapatıp açın.',
			'',
			OPEN);
		option.onOpen = restartSafeMode;
		addOption(option);

		super();
	}

	function openLogsFolder():Void
	{
		#if desktop
		try
		{
			var path:String = Sys.getCwd();
			if (!StringTools.endsWith(path, '/') && !StringTools.endsWith(path, '\\'))
				path += '/';
			var logs:String = path + 'logs';
			if (!FileSystem.exists(logs))
				FileSystem.createDirectory(logs);
			#if windows
			new sys.io.Process('explorer', [logs]);
			#elseif linux
			new sys.io.Process('xdg-open', [logs]);
			#elseif mac
			new sys.io.Process('open', [logs]);
			#end
			FlxG.sound.play(Paths.sound('confirmMenu'));
		}
		catch (e:Dynamic)
		{
			trace('[DevSettings] Log klasörü açılamadı: ' + e);
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
		#else
		trace('[DevSettings] Log klasörü açma bu platformda desteklenmiyor.');
		FlxG.sound.play(Paths.sound('cancelMenu'));
		#end
	}

	function clearGraphicsCache():Void
	{
		try
		{
			CacheSystem.freeGraphicsFromMemory();
			CacheSystem.clearUnusedMemory(true);
			FlxG.sound.play(Paths.sound('confirmMenu'));
		}
		catch (e:Dynamic)
		{
			trace('[DevSettings] Önbellek temizleme hatası: ' + e);
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	function restartSafeMode():Void
	{
		#if desktop
		try
		{
			if (backend.SafeMode.restart())
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				new FlxTimer().start(0.4, function(_) Sys.exit(0));
				return;
			}
		}
		catch (e:Dynamic)
			trace('[DevSettings] SafeMode: ' + e);
		FlxG.sound.play(Paths.sound('cancelMenu'));
		#elseif sys
		try
		{
			if (backend.SafeMode.requestNextLaunch())
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				return;
			}
		}
		catch (e:Dynamic)
			trace('[DevSettings] SafeMode: ' + e);
		FlxG.sound.play(Paths.sound('cancelMenu'));
		#else
		FlxG.sound.play(Paths.sound('cancelMenu'));
		#end
	}
}

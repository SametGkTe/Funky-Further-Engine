package options;

class GameplaySettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('gameplay_menu', 'Oynanış Ayarları');
		rpcTitle = 'Gameplay Settings Menu'; //for Discord Rich Presence

		//I'd suggest using "Downscroll" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Aşağı Oklar', //Name
			'Aktif edildiğinde, notalar yukarı yerine aşağı doğru gider.', //Description
			'downScroll', //Save data variable name
			BOOL); //Variable type
		addOption(option);

		var option:Option = new Option('Orta Oklar',
			'Aktif edildiğinde, notalarınız ortaya hizalanır.',
			'middleScroll',
			BOOL);
		addOption(option);

		var option:Option = new Option('Rakip Okları',
			'Devre dışı bırakıldığında, rakibin notaları gizlenir.',
			'opponentStrums',
			BOOL);
		addOption(option);
		
		var option:Option = new Option('Mania Modu',
			'Şarkıyı mania düzenine çevirir (4K/5K/6K/7K/8K/9K). Notalar geniş şeritlere yayılır, oklar ve hitbox mania düzenine geçer.',
			'mania',
			INT);
		option.scrollSpeed = 1;
		option.minValue = 4;
		option.maxValue = 9;
		option.changeValue = 1;
		option.decimals = 0;
		option.displayFormat = '%vK';
		addOption(option);

		var option:Option = new Option('Hayalet Vuruş',
			'Aktif edildiğinde, vurulabilecek nota yokken tuşlara\nbasmanız miss sayılmaz.',
			'ghostTapping',
			BOOL);
		addOption(option);
		
		var option:Option = new Option('Otomatik Duraklatma',
			'Aktif edildiğinde, oyun pencere odakta değilse otomatik duraklar.',
			'autoPause',
			BOOL);
		addOption(option);
		option.onChange = onChangeAutoPause;

		var option:Option = new Option('Skor Yazıları',
			'Devre dışı bırakıldığında, notalara vurunca "sick", "good".. ve kombo yazıları görünmez.\n(Düşük donanımlı ' + Main.platform + ' için kullanışlıdır.)',
			'popUpRating',
			BOOL);
		addOption(option);

		var option:Option = new Option('Reset Tuşunu Kapat',
			'Aktif edildiğinde, Reset tuşuna basmak hiçbir şey yapmaz.',
			'noReset',
			BOOL);
		addOption(option);
		
		var option:Option = new Option('Sunucu Bağlantısı',
			'Devre dışı bırakıldığında, Online özellikler devre-dışı kalır ve skorlarınız / başarımlarınız sunucuya gönderilmez.',
			'serverConnection',
			BOOL);
		addOption(option);

		var option:Option = new Option('Ölüm Titreşimi',
			'Aktif edildiğinde, öldüğünüzde cihazınız titreşir.',
			'gameOverVibration',
			BOOL);
		addOption(option);
		option.onChange = onChangeVibration;

		var option:Option = new Option('Tekil Uzun Notalar',
			'Aktif edildiğinde, uzun notalar ana nota kaçırıldıysa basılamaz\nve tek bir Vuruş/Kaçırma olarak sayılır.\nEski giriş sistemini tercih ediyorsanız bunu kapatın.',
			'guitarHeroSustains',
			BOOL);
		addOption(option);

		var option:Option = new Option('Vuruş Sesi Seviyesi',
			'Notalara vurduğunuzda eğlenceli bir "Tık!" sesi çalar.',
			'hitsoundVolume',
			PERCENT);
		addOption(option);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = onChangeHitsoundVolume;

		var option:Option = new Option('Derecelendirme Ayarı',
			'"Sick!" almanız için ne kadar geç/erken vurmanız gerektiğini değiştirir.\nDaha yüksek değerler daha geç vurmanız gerektiği anlamına gelir.',
			'ratingOffset',
			INT);
		option.displayFormat = '%vms';
		option.scrollSpeed = 20;
		option.minValue = -30;
		option.maxValue = 30;
		addOption(option);

		var option:Option = new Option('Müq! Vuruş Gecikmesi',
			'"Sick!" almanız için sahip olduğunuz süreyi\nmilisaniye cinsinden değiştirir.',
			'sickWindow',
			FLOAT);
		option.displayFormat = '%vms';
		option.scrollSpeed = 15;
		option.minValue = 15.0;
		option.maxValue = 45.0;
		option.changeValue = 0.1;
		addOption(option);

		var option:Option = new Option('iyi Vuruş Gecikmesi',
			'"Good" almanız için sahip olduğunuz süreyi\nmilisaniye cinsinden değiştirir.',
			'goodWindow',
			FLOAT);
		option.displayFormat = '%vms';
		option.scrollSpeed = 30;
		option.minValue = 15.0;
		option.maxValue = 90.0;
		option.changeValue = 0.1;
		addOption(option);

		var option:Option = new Option('Kötü Vuruş Gecikmesi',
			'"Bad" almanız için sahip olduğunuz süreyi\nmilisaniye cinsinden değiştirir.',
			'badWindow',
			FLOAT);
		option.displayFormat = '%vms';
		option.scrollSpeed = 60;
		option.minValue = 15.0;
		option.maxValue = 135.0;
		option.changeValue = 0.1;
		addOption(option);

		var option:Option = new Option('Güvenli Gecikme',
			'Bir notaya erken veya geç vurmanız için sahip olduğunuz\nkare sayısını değiştirir.',
			'safeFrames',
			FLOAT);
		option.scrollSpeed = 5;
		option.minValue = 2;
		option.maxValue = 10;
		option.changeValue = 0.1;
		addOption(option);
		
		var option:Option = new Option('FPS Sayacı',
			'Devre dışı bırakıldığında, Fps göstergesi ve diğer istatistikler gözükmez.',
			'fpsCounter',
			BOOL);
		addOption(option);
		
		var option = new Option(
			'FPS Sayacı Opaklığı',
			'FPS Sayacının arkasındaki siyah kutunun opaklığını ayarlar.',
			'fpsCounterOpacity',
			INT);
		option.minValue = 0;
		option.maxValue = 100;
		option.changeValue = 10;
		addOption(option);

		super();
	}

	function onChangeHitsoundVolume()
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);

	function onChangeAutoPause()
		FlxG.autoPause = ClientPrefs.data.autoPause;

	function onChangeVibration()
	{
		if(ClientPrefs.data.gameOverVibration)
			lime.ui.Haptic.vibrate(0, 500);
	}
}
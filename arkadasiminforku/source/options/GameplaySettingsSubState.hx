package options;

class GameplaySettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Oynanis';
		rpcTitle = 'Oynanış Ayarları Menüsünde'; //for Discord Rich Presence

		//I'd suggest using "Downscroll" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Asagi Oklar', //Name
			'Aktif Edildiğinde, notalarınız aşağıya sıralanır.', //Description
			'downScroll', //Save data variable name
			'bool'); //Variable type
		addOption(option);

		var option:Option = new Option('Orta Oklar',
			'Aktif Edildiğinde, notalarınız ortalanır.',
			'middleScroll',
			'bool');
		addOption(option);

		var option:Option = new Option('Rakip Notalari',
			'Aktif Edilmezse, rakibin notları gizlenir.',
			'opponentStrums',
			'bool');
		addOption(option);

		var option:Option = new Option('Hayalet Dokunus',
			"Aktif Edildiğinde, çalınabilecek nota olmadığı halde\ntuşlara basarak kaçırma yapmazsınız.",
			'ghostTapping',
			'bool');
		addOption(option);
		
		var option:Option = new Option('Otomatik Durdurma',
			"Aktif Edildiğinde, ekran odaklanmadığında oyun otomatik olarak duraklatılır.",
			'autoPause',
			'bool');
		addOption(option);
		option.onChange = onChangeAutoPause;

		var option:Option = new Option('Reset Butonunu Kapat',
			"Aktif Edildiğinde, Sıfırla düğmesine basmak hiçbir şey yapmaz.",
			'noReset',
			'bool');
		addOption(option);

		var option:Option = new Option('Tus Sesi',
			'Notalara Basıldığında \"Tik!\" Sesi çıkarır"',
			'hitsoundVolume',
			'percent');
		addOption(option);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = onChangeHitsoundVolume;

		var option:Option = new Option('Derece Ayari',
			'"Sick!"\nİçin ne kadar geç/erken vurmanız gerektiğini değiştirir. Daha yüksek değerler, daha geç vurmanız gerektiği anlamına gelir.',
			'ratingOffset',
			'int');
		option.displayFormat = '%vms';
		option.scrollSpeed = 20;
		option.minValue = -30;
		option.maxValue = 30;
		addOption(option);

		// phantom ass options

		// var option:Option = new Option('Sick! Hit Window',
		// 	'Changes the amount of time you have\nfor hitting a "Sick!" in milliseconds.',
		// 	'sickWindow',
		// 	'int');
		// option.displayFormat = '%vms';
		// option.scrollSpeed = 15;
		// option.minValue = 15;
		// option.maxValue = 45;
		// addOption(option);

		// var option:Option = new Option('Good Hit Window',
		// 	'Changes the amount of time you have\nfor hitting a "Good" in milliseconds.',
		// 	'goodWindow',
		// 	'int');
		// option.displayFormat = '%vms';
		// option.scrollSpeed = 30;
		// option.minValue = 15;
		// option.maxValue = 90;
		// addOption(option);

		// var option:Option = new Option('Bad Hit Window',
		// 	'Changes the amount of time you have\nfor hitting a "Bad" in milliseconds.',
		// 	'badWindow',
		// 	'int');
		// option.displayFormat = '%vms';
		// option.scrollSpeed = 60;
		// option.minValue = 15;
		// option.maxValue = 135;
		// addOption(option);

		var option:Option = new Option('Güvenli Kareler',
			'Notaya erken veya geç vurmak için sahip olunan\nkare (frame) sayısını değiştirir.',
			'safeFrames',
			'float');
		option.scrollSpeed = 5;
		option.minValue = 2;
		option.maxValue = 10;
		option.changeValue = 0.1;
		addOption(option);

		var option:Option = new Option('Oynamaz Notalar',
			'Seçilirse, vuruş notaları artık hareket etmeyecek veya görünürlükleri değişmeyecek.',
			'disableStrumMovement',
			'bool');
		addOption(option);

		var option:Option = new Option('Tekrarlari Kaydet',
			'Aktif edilirse, oyun oynanışınızı kaydeder ve skorlarınız liderlik tablosuna gönderilir (V1 Sürümünde Çalışmayabilir).',
			'disableReplays',
			'bool');
		addOption(option);

		var option:Option = new Option('Istatislik Gönder',
			'Aktif Edilirse, oyun tekrarlarınızı liderlik tablosuna gönderir. Oyun sırasında F2 tuşu ile açılıp kapatılabilir. (V1 Sürümünde Çalışmayabilir)',
			'disableSubmiting',
			'bool');
		addOption(option);

		var option:Option = new Option('Gecikme Algilamayi Kapat',
			'Aktif edilirse, oyunda veya modda bir gecikme (lag) algıladığında 3 saniye geri sarma yapmayacaktır.',
			'disableLagDetection',
			'bool');
		addOption(option);

		var option:Option = new Option('Mod Kostüm Degisikligi',
			'Aktif edilirse, şarkı olayları (song events) aktif olan görünümünüzdeki (skin) karakteri değiştirecektir.',
			'modchartSkinChanges',
			'bool');
		addOption(option);

		var option:Option = new Option('Alt Nota Opakligi', 'If higher than 0%, an underlay will be displayed behind player notes.', 'noteUnderlayOpacity', 'percent');
		addOption(option);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.05;
		option.decimals = 2;

		var option:Option = new Option('Alt Nota Tipi:',
			"Oyun notaların altını nasıl göstermeli?",
			'noteUnderlayType',
			'string',
			['Hepsi-Bir-Arada', 'Notaya Göre']);
		addOption(option);

		super();
	}

	function onChangeHitsoundVolume()
	{
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);
	}

	function onChangeAutoPause()
	{
		FlxG.autoPause = ClientPrefs.data.autoPause;
	}
}
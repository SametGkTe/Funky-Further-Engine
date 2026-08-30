package options;

import lime.system.System as LimeSystem;

class ExtraSettingsState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('extra_settings_menu', 'Ekstra Ayarlar');
		rpcTitle = 'Extra Settings Menu';

		var option:Option = new Option('Sonuç Ekranı',
			'Şarkı bitiminde detaylı sonuç ekranını gösterir.',
			'vsliceResults',
			BOOL);
		addOption(option);

		var option:Option = new Option('Sonuç Ekranı Aşımı',
			'Sonuç ekranı ayarlanan süre sonunda otomatik kapanır (saniye).\n0 = kapalı.',
			'resultsAutoSkip',
			INT);
		option.minValue = 0;
		option.maxValue = 30;
		option.changeValue = 1;
		option.displayFormat = '%v sn';
		addOption(option);

		var option:Option = new Option('Freeplay Renkleri',
			'Freeplay menüsünde arka kartların karakter temalı renklenmesini sağlar.',
			'vsliceFreeplayColors',
			BOOL);
		addOption(option);

		var option:Option = new Option('Freeplay Özel Kartlar',
			'Yeni Freeplay listesinde karaktere özel kart ve animasyonları gösterir.',
			'vsliceSpecialCards',
			BOOL);
		addOption(option);

		var option:Option = new Option('Eski Skor Barı',
			'Klasik (eski stilde) skor barı görünümünü kullanır.',
			'vsliceLegacyBar',
			BOOL);
		addOption(option);

		var option:Option = new Option('Yumuşak Sağlık Barı',
			'Sağlık barının ani değil, yumuşak geçişle dolup boşalmasını sağlar.',
			'vsliceSmoothBar',
			BOOL);
		addOption(option);

		var option:Option = new Option('YENİ Etiketini Zorla',
			'Yeni Freeplay listesinde YENİ etiketinin her şarkıda görünmesini sağlar.',
			'vsliceForceNewTag',
			BOOL);
		addOption(option);

		var option:Option = new Option('Uyarı içerikleri',
			'Sonuç ekranı ve diyaloglardaki uyarı içeriklerini gösterir.',
			'vsliceNaughtyness',
			BOOL);
		addOption(option);

		var option:Option = new Option('Çökme Kayıtları',
			'Hata kayıtlarının nereye yazılacağını seçer.\nFile: Log dosyasına, Console: Konsola yazar.',
			'loggingType',
			STRING,
			['None', 'Console', 'File']);
		addOption(option);

		var option:Option = new Option('Titreşim',
			'Oyun içi bazı olaylarda cihazın titreşmesini sağlar.',
			'vibrating',
			BOOL);
		addOption(option);

		var option:Option = new Option('Titreşim Şiddeti',
			'Titreşimlerin gücünü ayarlar.',
			'vibrationIntensity',
			PERCENT,
			null,
			'vibration_intensity');
		option.scrollSpeed = 1;
		option.minValue = 0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Uyku Modu',
			'Aktif edildiğinde sistem ekran zaman aşımına izin verir.\nKAPALI: Oyun açıkken ekran hep yanık kalır.',
			'screensaver',
			BOOL);
		option.onChange = onChangeScreensaver;
		addOption(option);

		super();
	}

	function onChangeScreensaver()
	{
		LimeSystem.allowScreenTimeout = ClientPrefs.data.screensaver;
	}

	function onChangeShowFPS()
	{
		if (Main.fpsVar != null)
			Main.fpsVar.visible = ClientPrefs.data.showFPS;
	}
}

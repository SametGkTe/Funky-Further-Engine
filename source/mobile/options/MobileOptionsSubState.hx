package mobile.options;

import flixel.input.keyboard.FlxKey;
import backend.ClientPrefs;
import options.BaseOptionsMenu;
import options.Option;

class MobileOptionsSubState extends BaseOptionsMenu
{
	#if android
	var storageTypes:Array<String> = ["EXTERNAL_PE", "EXTERNAL_PE073", "EXTERNAL_PEO", "EXTERNAL_PEU", "EXTERNAL_FE", "EXTERNAL_DATA", "EXTERNAL_OBB", "EXTERNAL_MEDIA"];
	var externalPaths:Array<String> = StorageUtil.checkExternalPaths(true);
	var customPaths:Array<String> = StorageUtil.getCustomStorageDirectories(false);
	final lastStorageType:String = ClientPrefs.data.storageType;
	#end

	var option:Option;
	var HitboxTypes:Array<String>;

	inline function phrase(key:String, fallback:String):String
	{
		return Language.getPhrase(key, fallback);
	}


	public function new()
	{
		title = phrase('mobile_options_title', 'Mobil Ayarlar');
		rpcTitle = phrase('rpc_mobile_options_menu', 'Mobil Ayarlar Menüsü');

		#if android
		storageTypes = storageTypes.concat(customPaths); // Get Custom Paths From File
		storageTypes = storageTypes.concat(externalPaths); // Get SD Card Path
		#end

		HitboxTypes = Mods.mergeAllTextsNamed('mobile/Hitbox/HitboxModes/hitboxModeList.txt');

		option = new Option(
			'Mobil Kontrol Opaklığı',
			'Mobil tuşların saydamlığını ayarlar. Değeri 0 yapıp tuşları kaybetmemeye dikkat edin.',
			'mobilePadAlpha',
			PERCENT,
			null,
			'mobile_controls_opacity'
		);
		option.scrollSpeed = 1;
		option.minValue = 0.001;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = () ->
		{
			var st:MusicBeatState = MusicBeatState.getState();
			if (st.touchPad != null) st.touchPad.alpha = curOption.getValue();
			if (st.mobileControls != null && st.mobileControls.instance != null)
				st.mobileControls.instance.alpha = curOption.getValue();
			var mgr = st.mobileManager;
			if (mgr != null && mgr.mobilePad != null) mgr.mobilePad.alpha = curOption.getValue();
			ClientPrefs.toggleVolumeKeys();
		};
		addOption(option);

		option = new Option(
			'Ekstra Kontroller',
			'Kaç adet ekstra mobil kontrol istediğinizi seçin. Özel mekaniklere sahip modlarda kullanılabilirler.',
			'extraKeys',
			INT,
			null,
			'extra_controls'
		);
		option.scrollSpeed = 1;
		option.minValue = 0;
		option.maxValue = 4;
		option.changeValue = 1;
		option.decimals = 0;
		addOption(option);
		
		option = new Option(
			'Dokunmaları Göster',
			'Ekrana dokunduğunuz yerde kısa süreli, beyaz bir nokta gösterir.',
			'showTouches',
			BOOL,
			null,
			'show_touches'
		);
		addOption(option);

		var goption:Option = new Option(
			'Ekstra Kontrol Konumu',
			'Ekstra kontrollerin konumunu seçin.',
			'hitboxLocation',
			STRING,
			['Bottom', 'Top', 'Middle'],
			'extra_control_position'
		);
		goption.displayOptions = ['Alt', 'Üst', 'Orta'];
		addOption(goption);

		// HitboxTypes.insert(0, "Classic");
		goption = new Option(
			'Hitbox Stili',
			'Tercih ettiğiniz Hitbox stilini seçin.',
			'hitboxMode',
			STRING,
			HitboxTypes,
			'hitbox_design'
		);
		goption.displayOptions = [for (value in HitboxTypes) value == 'Classic' ? 'Klasik' : value];
		addOption(goption);

		goption = new Option(
			'Hitbox Görünümü',
			'Hitbox kontrollerinin nasıl görüneceğini seçin.',
			'hitboxType',
			STRING,
			['Gradient', 'No Gradient', 'No Gradient (Old)', 'Hidden'],
			'hitbox_type'
		);
		goption.displayOptions = ['Gradyanlı', 'Gradyansız', 'Gradyansız (Eski)', 'Gizli'];
		addOption(goption);

		option = new Option(
			'Hitbox ipucusu',
			'Hitbox ipuçlarının görünümünü açar veya kapatır.',
			'hitboxHint',
			BOOL,
			null,
			'hitbox_hint'
		);
		addOption(option);

	option = new Option(
		'Kontrol Tipi',
		'Menü ve gezinti kontrollerinin türünü seçin.\nTuşlu: ekran tuşları (A/B/ok padleri)\nDokunmatik: dokun = onay, kaydırma = gezinme, uzun basış = sıfırla',
		'mobileControlType',
		STRING,
		['Buttons', 'Touch'],
		'control_type'
	);
	option.displayOptions = ['Tuşlu', 'Dokunmatik'];
	option.onChange = function():Void
	{
		refreshTouchPad();
	};
	addOption(option);

	option = new Option(
		'Scroll Hassasiyeti',
		'Dokunmatik kaydırmanın hızını ayarlar.\nYüksek = daha çok öğe atlanır, düşük = daha yavaş kaydırma.',
		'touchScrollSens',
		INT,
		null,
		'scroll_sensitivity'
	);
	option.scrollSpeed = 1;
	option.minValue = 25;
	option.maxValue = 300;
	option.changeValue = 5;
	option.decimals = 0;
	addOption(option);

	option = new Option(
		'V-Slice Kontrolleri',
		'Etkinleştirildiğinde kontroller orijinal FNF gibi çalışır.\n(UYARI: Bu seçenek nota hareketleri gibi bazı mekanikleri bozabilir. Lütfen yalnızca temel modlarda kullanın.)',
		'ogGameControls',
		BOOL,
		null,
		'v_slice_controls'
	);
	option.onChange = function():Void {
		if (ClientPrefs.data.ogGameControls) {
			// V-Slice açılınca Sabitlenmiş Notalar otomatik açılır (oyuncu istersen kapatabilir)
			ClientPrefs.data.pinnedNotes = true;
			ClientPrefs.data.ogAutoPinDone = true;
		} else {
			ClientPrefs.data.ogAutoPinDone = false; // tekrar açılırsa yine otomatik açılsın
		}
	};
	addOption(option);

		option = new Option(
			'V-Slice Kontrol Aralığı',
			'V-Slice kontrolleri açıkken okların birbirinden ne kadar uzakta olacağını ayarlar.',
			'vSliceSpacing',
			PERCENT,
			null,
			'v_slice_spacing'
		);
		option.scrollSpeed = 1.6;
		option.minValue = 0;
		option.maxValue = 1;
		option.changeValue = 0.01;
		option.decimals = 2;
		option.displayFormat = '%v%';
		addOption(option);

		option = new Option(
			'Hitbox Saydamlığı',
			'Hitbox saydamlığını ayarlar. Sanırım',
			'hitboxAlpha',
			PERCENT,
			null,
			'hitbox_opacity'
		);
		option.scrollSpeed = 1;
		option.minValue = 0.001;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		#if mobile
		option = new Option(
			'Tam Ekran Modu',
			'Etkinleştirildiğinde oyun ekranı dolduracak şekilde genişler. (UYARI: Görüntü bozulmalarına neden olabilir ve oyunu veya kameraları yeniden boyutlandıran bazı modları bozabilir.)',
			'wideScreen',
			BOOL,
			null,
			'wide_screen_mode'
		);
		option.onChange = () -> ScreenUtil.wideScreen.enabled = ClientPrefs.data.wideScreen;
		addOption(option);
		#end

		#if android
		goption = new Option(
			'Depolama Türü',
			'Further Engine tarafından kullanılacak klasörü seçin.',
			'storageType',
			STRING,
			storageTypes,
			'storage_type'
		);
		goption.displayOptions = storageTypes.copy();
		addOption(goption);

		option = new Option(
			'Data Klasörünü Aç',
			'Android 13 ve üzerindeki Dosyalar uygulamasında Further Engine Data klasörünün kökünü açar. (Android/data/com.sametgkte.furtherengine)',
			'openDataFolder',
			BOOL,
			null,
			'open_data_folder'
		);
		option.onChange = () ->
		{
			StorageUtil.openDataFolder();
			ClientPrefs.data.openDataFolder = false;
		};
		addOption(option);
		#end

		super();
	}

	override public function destroy()
	{
		super.destroy();

		#if android
		if (ClientPrefs.data.storageType != lastStorageType)
		{
			File.saveContent(lime.system.System.applicationStorageDirectory + 'storagetype.txt', ClientPrefs.data.storageType);
			ClientPrefs.saveSettings();
			StorageUtil.currentExternalStorageDirectory = null;
			StorageUtil.maybeRequestAllFilesAccess(ClientPrefs.data.storageType, true);
			StorageUtil.initExternalStorageDirectory();
		}
		#end
	}
}
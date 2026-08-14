package mobile.options;

import flixel.input.keyboard.FlxKey;
import options.BaseOptionsMenu;
import options.Option;

class MobileOptionsSubState extends BaseOptionsMenu {
	#if android
	var storageTypes:Array<String> = ["EXTERNAL_PE", "EXTERNAL_PEO", "EXTERNAL_PEU", "EXTERNAL_FE", "EXTERNAL_DATA", "EXTERNAL_OBB", "EXTERNAL_MEDIA"];
	var externalPaths:Array<String> = StorageUtil.checkExternalPaths(true);
	var customPaths:Array<String> = StorageUtil.getCustomStorageDirectories(false);
	final lastStorageType:String = ClientPrefs.data.storageType;
	#end

	var option:Option;
	var HitboxTypes:Array<String>;
	public function new() {
		title = 'Mobil Ayarlar';
		rpcTitle = 'Mobile Options Menu'; // for Discord Rich Presence, fuck it
		#if android
		storageTypes = storageTypes.concat(customPaths); //Get Custom Paths From File
		storageTypes = storageTypes.concat(externalPaths); //Get SD Card Path
		#end

		HitboxTypes = Mods.mergeAllTextsNamed('mobile/Hitbox/HitboxModes/hitboxModeList.txt');

		option = new Option('Mobil Kontrol Opaklığı',
			'Mobil tuşların saydamlığını ayarlar (0 yapıp tuşları kaybetmemeye dikkat edin).', 'mobilePadAlpha', PERCENT);
		option.scrollSpeed = 1;
		option.minValue = 0.001;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = () -> {
			var st:MusicBeatState = MusicBeatState.getState();
			if (st.touchPad != null) st.touchPad.alpha = curOption.getValue();
			if (st.mobileControls != null && st.mobileControls.instance != null) st.mobileControls.instance.alpha = curOption.getValue();
			var mgr = st.mobileManager;
			if (mgr != null && mgr.mobilePad != null) mgr.mobilePad.alpha = curOption.getValue();
			ClientPrefs.toggleVolumeKeys();
		};
		addOption(option);

		var option:Option = new Option('Ekstra Kontroller',
			'Mobil Ekstra Kontrolleri etkinleştirir, mekanikli modlar için kullanılabilir.',
			'extraKeys',
			'INT');
		option.scrollSpeed = 1;
		option.minValue = 0;
		option.maxValue = 4;
		option.changeValue = 1;
		option.decimals = 0;
		addOption(option);

			option = new Option('Ekstra Kontrol Konumu',
				'Ekstra Kontrol Konumunu Seçin',
				'hitboxLocation',
				STRING,
				['Bottom', 'Top', 'Middle']
			);
		addOption(option);
		
		//HitboxTypes.insert(0, "Classic");
		option = new Option('Hitbox Stili',
			'Hitbox Stilinizi Seçin!',
			'hitboxMode',
			STRING,
			HitboxTypes
		);
		addOption(option);
		
		option = new Option('Hitbox Görünümü',
			'Hitbox kontrolünün nasıl gözükeceğini ayarlar.',
			'hitboxType',
			STRING,
			['Gradient', 'No Gradient', 'No Gradient (Old)', 'Hidden']
		);
		addOption(option);

		option = new Option('Hitbox ipucusu',
			'Hitbox İpucu Kontrolü',
			'hitboxHint',
			'BOOL');
		addOption(option);

		option = new Option('V-Slice Kontrolü',
			'Aktif Edildiğinde, kontrol orijinal FNF gibi olacaktır.\n(UYARI: Bu seçenek bazı mekanikleri bozabilir, Nota Hareketleri vb. lütfen temel modlar için kullanın.)',
			'ogGameControls',
			'BOOL');
		addOption(option);
		
		var option:Option = new Option('V-Slice Kontrol Aralığı',
			'V-Slice açıkken okların (strum) birbirinden ne kadar uzak olacağını ayarlar.\n%0 orijinal FNF Mobile, %100 tam ekran yayılımı.\nŞarkıyı yeniden başlatınca uygulanır.',
			'vSliceSpacing',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0;
		option.maxValue = 1;
		option.changeValue = 0.01;
		option.decimals = 2;
		option.displayFormat = '%v%';
		addOption(option);
		
		option = new Option('Hitbox Saydamligi',
			'Hitbox düğmelerinin saydamlığını seçer.',
			'hitboxAlpha',
			PERCENT
		);
		option.scrollSpeed = 1;
		option.minValue = 0.001;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		#if mobile
		option = new Option('Tam Ekran Modu',
			'Aktif Edildiğinde, oyun tüm ekranınızı kaplayacak şekilde genişler. (UYARI: Görüntü bozulmalarına neden olabilir ve oyunu/kameraları yeniden boyutlandıran bazı modları bozabilir)',
			'wideScreen', 'BOOL');
		option.onChange = () -> ScreenUtil.wideScreen.enabled = ClientPrefs.data.wideScreen;
		addOption(option);
		#end

		#if android
		option = new Option('Depolama Türü',
			'Further Engine hangi klasörü kullanmalı?\nEXTERNAL_DATA izin gerektirmez (önerilir).\nEXTERNAL_PE / FE gibi gizli klasörler için "Tüm dosyalara erişim" gerekir.',
			'storageType',
			STRING,
			storageTypes
		);
		addOption(option);

		option = new Option('Veri Klasörünü Aç',
			'Android 13+ için sistem Dosyalar uygulamasında Further Engine Data Folder kökünü açar.\nEXTERNAL_DATA seçiliyse mods/ buradadır: Android/data/com.sametgkte.furtherengine/files/mods/',
			'openDataFolder',
			BOOL
		);
		option.onChange = () -> {
			StorageUtil.openDataFolder();
			ClientPrefs.data.openDataFolder = false;
		};
		addOption(option);
		#end

		super();
	}

	override public function destroy() {
		super.destroy();

		#if android
		if (ClientPrefs.data.storageType != lastStorageType) {
			File.saveContent(lime.system.System.applicationStorageDirectory + 'storagetype.txt', ClientPrefs.data.storageType);
			ClientPrefs.saveSettings();
			StorageUtil.initExternalStorageDirectory();
		}
		#end
	}
}

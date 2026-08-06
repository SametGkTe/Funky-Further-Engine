package mobile.options;

import flixel.input.keyboard.FlxKey;
import options.BaseOptionsMenu;
import options.Option;

class MobileOptionsSubState extends BaseOptionsMenu {
	#if android
	var storageTypes:Array<String> = ["EXTERNAL_DATA", "EXTERNAL_OBB", "EXTERNAL_MEDIA", "EXTERNAL"];
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

		option = new Option('Mobil Buton Saydamligi',
			'Mobil tuşların saydamlığını ayarlar (0 yapıp tuşları kaybetmemeye dikkat edin).', 'mobilePadAlpha', 'percent');
		option.scrollSpeed = 1;
		option.minValue = 0.001;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = () -> {
			mobileManager.mobilePad.alpha = curOption.getValue();
			ClientPrefs.toggleVolumeKeys();
		};
		addOption(option);

		var option:Option = new Option('Ekstra Kontroller',
			'Mobil Ekstra Kontrolleri Etkinleştirir.',
			'extraKeys',
			'int');
		option.scrollSpeed = 1;
		option.minValue = 0;
		option.maxValue = 4;
		option.changeValue = 1;
		option.decimals = 0;
		addOption(option);

		option = new Option('Ekstra Kontrol Konumu',
			'Ekstra Kontrol Konumunu Seçin',
			'hitboxLocation',
			'string',
			['Alt', 'Üst', 'Orta']
		);
		addOption(option);
		
		//HitboxTypes.insert(0, "Classic");
		option = new Option('Hitbox Stili',
			'Hitbox Stilinizi Seçin!',
			'hitboxMode',
			'string',
			HitboxTypes
		);
		addOption(option);
		
		option = new Option('Hitbox Görünümü',
			'Hitbox kontrolünün nasıl gözükeceğini ayarlar.',
			'hitboxType',
			'string',
			['Alt Renk', 'Gizli' , 'Alt Renk Yok (Eski)']
		);
		addOption(option);

		option = new Option('Hitbox Ipucusu',
			'Hitbox İpucu Kontrolü',
			'hitboxHint',
			'bool');
		addOption(option);

		option = new Option('Orjinal Fnf Kontrolü',
			'Aktif Edildiğinde, oyunun kontrolü orijinal Friday Night Funkin: Mobile gibi olacaktır.\n(UYARI: Bu seçenek bazı mekanikleri bozabilir, lütfen temel modlar için kullanın.)',
			'ogGameControls',
			'bool');
		addOption(option);
		
		var option:Option = new Option('V-Slice Araligi',
			'V-Slice butonlarinin birbirinden ne kadar uzak olacagini ayarlar.\n%0 orjinal, %100 tam ekran yayilimi.',
			'vSliceSpacing',
			'percent');
		option.scrollSpeed = 1.6;
		option.minValue = 0;
		option.maxValue = 1;
		option.changeValue = 0.01;
		option.displayFormat = '%v%';
		addOption(option);
		
		option = new Option('Hitbox Saydamligi',
			'Hitbox düğmelerinin saydamlığını seçer.',
			'hitboxAlpha',
			'percent'
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
			'wideScreen', 'bool');
		option.onChange = () -> ScreenUtil.wideScreen.enabled = ClientPrefs.data.wideScreen;
		addOption(option);
		#end

		#if android
		option = new Option('Depolama Türü',
			'Psych Engine Türkiye Online hangi klasörü kullanmalı?',
			'storageType',
			'string',
			storageTypes
		);
		addOption(option);
		#end

		/* doesn't work fine for now
		option = new Option('Hile Menüsü',
			'Aktif Edildiğinde, Psych Online için bir mod menüsü gösterilecektir.\n(UYARI: Bunu hile yapmak için kullanmayın!)',
			'showTweakMenu',
			'bool');
		option.onChange = () -> Main.toggleTweakMenu(ClientPrefs.data.showTweakMenu);
		addOption(option);
		*/
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
package states;

import backend.SafeMode;
import flixel.FlxG;
import flixel.FlxState;

/**
 * Mod altyapısı kurulmadan önce güvenli mod isteğini yakalayan hafif başlangıç
 * durumu. Kısa bekleme, oyun açılırken basılı tutulan SHIFT'in algılanmasını
 * sağlar.
 */
class StartupState extends FlxState
{
	static inline var SHIFT_WINDOW:Float = 0.35;
	var elapsedStartup:Float = 0;
	var finished:Bool = false;

	override public function create():Void
	{
		super.create();
		#if android
		// FlxG.save artık bağlı: storage seçimini modlar taranmadan önce gerçek
		// runtime yolu ve storagetype.txt ile eşitle.
		mobile.backend.StorageUtil.syncStorageTypeFromSave();
		backend.PolymodHandler.MODS_FOLDER = mobile.backend.StorageUtil.getExternalStorageDirectory() + 'mods';
		#end
		SafeMode.detectPersistentRequest();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (finished) return;

		elapsedStartup += elapsed;
		#if desktop
		if (FlxG.keys.pressed.SHIFT) SafeMode.activate();
		#end

		if (SafeMode.active || elapsedStartup >= SHIFT_WINDOW)
			finishStartup();
	}

	function finishStartup():Void
	{
		if (finished) return;
		finished = true;

		if (!SafeMode.active)
		{
			// FPS Plus'ın "yüklemeden önce metadata doğrulama" yaklaşımından
			// bağımsız olarak uyarlandı. Uyumsuz mod scripti çalışmadan engellenir.
			backend.ModCompatibility.preflightEnabledMods();
			#if LUA_ALLOWED
			Mods.pushGlobalMods();
			#end
			Mods.loadTopMod();
			backend.PolymodHandler.init();
			backend.modpack.ModImportQueue.hook();
		}
		else
		{
			Mods.currentModDirectory = '';
			trace('[SafeMode] Modlar ve Polymod yüklenmeden oyun başlatılıyor.');
		}

		ClientPrefs.loadPrefs();
		MobileConfig.initDefault();
		if (!ClientPrefs.data.disableIntroVideo)
			FlxG.switchState(new FurtherIntroState());
		else
			FlxG.switchState(new TitleState());
	}
}

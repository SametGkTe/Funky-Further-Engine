package backend;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
import haxe.Json;

/**
 * PolymodHandler — Further-Engine'e Polymod + V-Slice mod desteği katan gerçek
 * Polymod entegrasyonu.
 *
 * FPS Plus'ın (ThatRozebudDude/FPS-Plus-Public) `source/modding/PolymodHandler.hx`
 * dosyasından uyarlanmıştır. Kilit nokta: FLIXEL backend'in kasmasını önlemek için
 * `frameworkParams.coreAssetRedirect` kullanılır. Bu sayede:
 *   - `Polymod.init` gerçekten çalışır (asset override + mod yükleme),
 *   - FLIXEL asset cache çakışması olmaz (performans düşmez),
 *   - Psych'in kendi mod sistemi (`Mods`, `modsList.txt`, `modFolders`) korunur.
 *
 * ÇALIŞMA MODLARI:
 *   - Psych modları: mevcut sistemle (mods/<mod>/, modsList.txt) — değişmez.
 *   - V-Slice / Polymod modları: `mods/<mod>/_polymod_meta.json` içeren klasörler
 *     Polymod ile yüklenir. Asset'leri (`shared/`, `data/`, `images/` vb.) OPENFL
 *     Assets üzerinden override edilir.
 *
 * KAPSAM: `useScriptedClasses = false` (scripted class / .hxc script API'si bu
 * pakette yüklü değil). Sadece asset + veri modları. İleride `funkin.*` shim'leri
 * eklendikçe `useScriptedClasses = true`'ya geçilebilir.
 */
class PolymodHandler
{
	/** Psych'in kendi V-Slice API sürümü (metadata doğrulama için). */
	public static final API_VERSION:String = '0.8.0';

	/**
	 * Base asset klasörü. `coreAssetRedirect` bunu Polymod'a verir.
	 * Android dış depolamada veya masaüstünde assets/ klasörü.
	 */
	public static final ASSETS_FOLDER:String = 'assets';

	/** Polymod mod kök dizini (Psych'in Paths.mods() ile aynı konum). */
	public static var MODS_FOLDER:String = #if android StorageUtil.getExternalStorageDirectory() + #else Sys.getCwd() + #end 'mods';

	/** Yüklenmiş V-Slice/Polymod modlarının dizin adları. */
	public static var loadedModDirs:Array<String> = [];

	/** Yüklenmiş modların metadata'ları (Dynamic; sürüm farkına dayanıklı). */
	public static var loadedModMetadata:Array<Dynamic> = [];

	/** Polymod bir kez init edildi mi? */
	static var initialized:Bool = false;

	/**
	 * Polymod'u başlatır. `Main.hx` içinde, mevcut `Mods.pushGlobalMods()` /
	 * `Mods.loadTopMod()` çağrılarının yanında çalıştırılır.
	 */
	public static function init():Void
	{
		#if sys
		if (!FileSystem.exists(MODS_FOLDER)) FileSystem.createDirectory(MODS_FOLDER);
		#end

		#if POLYMOD_ALLOWED
		try
		{
			// Mod klasörlerini tarayıp "meta.json benzeri" _polymod_meta.json olanları seç.
			buildModDirectories();
			if (loadedModDirs.length == 0)
			{
				// Psych/Lua modları Polymod gerektirmez. Boş init bile özel asset
				// library doğrulaması yapıp yanıltıcı ERROR üretiyordu.
				loadedModMetadata = [];
				initialized = true;
				return;
			}

			// FPS Plus modeli: framework belirtilmez (FLIXEL otomatik) ama
			// coreAssetRedirect verilir -> FLIXEL backend kasması önlenir.
			var result:Array<Dynamic> = cast polymod.Polymod.init({
				modRoot: MODS_FOLDER,
				dirs: loadedModDirs,
				useScriptedClasses: false,      // şimdilik asset-only
				loadScriptsAsync: false,
				errorCallback: onPolymodError,
				ignoredFiles: buildIgnoreList(),
				frameworkParams: {
					coreAssetRedirect: ASSETS_FOLDER
				}
			});

			loadedModMetadata = [];
			if (result != null)
			{
				for (mod in result)
				{
					trace('[Polymod] Yüklendi: ${mod.title} v${mod.modVersion} [${mod.id}]');
					loadedModMetadata.push(mod);
				}
			}
			initialized = true;
		}
		catch (e:Dynamic)
		{
			trace('[Polymod] init hatası: $e');
		}
		#end
	}

	/**
	 * `mods/` klasörünü tarar, `_polymod_meta.json` içeren mod klasörlerini
	 * `loadedModDirs`'a doldurur. (FPS Plus `meta.json`; V-Slice `_polymod_meta.json`
	 * kullanır — bu yüzden `_polymod_meta.json`'u ararız.)
	 */
	public static function buildModDirectories():Void
	{
		loadedModDirs = [];
		#if (MODS_ALLOWED && sys)
		try
		{
			if (!FileSystem.exists(MODS_FOLDER)) return;
			// Sadece modsList.txt içinde etkin ve preflight tarafından kabul edilen
			// modlar Polymod'a gönderilir. Önceki kod devre dışı modları da yüklüyordu.
			var enabledMods = Mods.parseList().enabled;

			for (entry in FileSystem.readDirectory(MODS_FOLDER))
			{
				if (!enabledMods.contains(entry) || Mods.isBlocked(entry)) continue;
				var full:String = haxe.io.Path.join([MODS_FOLDER, entry]);
				if (!FileSystem.isDirectory(full)) continue;

				// Hem _polymod_meta.json (V-Slice) hem meta.json (FPS Plus) kabul et.
				if (FileSystem.exists(haxe.io.Path.join([full, '_polymod_meta.json']))
				 || FileSystem.exists(haxe.io.Path.join([full, 'meta.json'])))
				{
					if (!loadedModDirs.contains(entry)) loadedModDirs.push(entry);
				}
			}
		}
		catch (e:Dynamic)
		{
			trace('[Polymod] buildModDirectories hatası: $e');
		}
		#end
	}

	/** Polymod tarafından yoksayılacak dosyalar. */
	static function buildIgnoreList():Array<String>
	{
		var list:Array<String> = polymod.Polymod.getDefaultIgnoreList();
		if (list == null) list = [];
		list.push('.vscode');
		list.push('.git');
		list.push('README.md');
		return list;
	}

	/** Metadata yeniden tarama / hot-reload. Aşama 4'teki "Reload" butonu çağırır. */
	public static function forceReload():Void
	{
		initialized = false;
		init();
	}

	/** Polymod hata/uyarı geri çağrısı. Dynamic kullanır (sürüm farkına dayanıklı). */
	static function onPolymodError(error:Dynamic):Void
	{
		if (error == null) return;
		if (Std.isOfType(error, String))
		{
			trace('[Polymod] $error');
			return;
		}
		var msg:Dynamic = Reflect.field(error, 'message');
		var sev:Dynamic = Reflect.field(error, 'severity');
		if (msg != null)
		{
			if (sev == 'WARNING' || sev == 'ERROR')
				trace('[Polymod] $sev: $msg');
			// INFO / NOTICE / DEBUG gürültü yapmasın
		}
		else
		{
			trace('[Polymod] $error');
		}
	}
}

package backend.modpack;

#if sys
import haxe.Json;
import haxe.crypto.Sha256;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#if target.threaded
import sys.thread.Thread;
#end
import backend.modpack.ModpackTypes;
import backend.modpack.ModpackPaths;
import backend.modpack.ModpackTier;
import backend.modpack.ModpackCatalogTypes;
import backend.modpack.StorageGuard;
import backend.modpack.DownloadManager;
import backend.modpack.zip.ZipExtractorFactory;
import backend.modpack.zip.ZipSecurity;
import backend.modpack.zip.ZipTypes;
import backend.modpack.zip.ZipTypes.ExtractProgressInfo;
import backend.modpack.zip.ZipTypes.ExtractCompleteInfo;
import backend.modpack.zip.ZipTypes.ExtractError;
import backend.modpack.zip.IZipExtractor;
import backend.update.UpdateConfig;
#end

/**
 * Mod-bazlı (delta) kurulum motoru.
 *
 * İçerik kataloğu (modpack.json) ile kurulu manifest'i karşılaştırır:
 *   - sürümü tutan modlar ATLANIR (yeniden indirilmez)
 *   - eksik/sürümü değişen modlar tek tek indirilip kurulur
 *   - kaldırılan (removed) modların klasörleri silinir
 *
 * Paralel çalışır: mevcut full-ZIP ModpackInstaller yolu dokunulmadan kalır.
 * Mağaza, paket girişinde "contentCatalogUrl" görürse bu sınıfı kullanır.
 */

typedef DeltaPlan = {
	var downloads:Array<ContentCatalogMod>;
	var removes:Array<ContentCatalogMod>;
	var skips:Int;
	var totalDownloadBytes:Float;
}

class ModDeltaInstaller {

	#if sys

	var _downloader:DownloadManager;
	var _extractor:IZipExtractor;
	var _installing:Bool = false;
	var _cancelled:Bool = false;

	/** Bu boyut üstü zip'lerde sha256 doğrulaması atlanır (hız için). */
	static inline var SHA_VERIFY_MAX_BYTES:Float = 100 * 1024 * 1024;

	public function new() {
		_downloader = new DownloadManager();
		_extractor = ZipExtractorFactory.createSafe();
		trace('[ModDeltaInstaller] Hazır. ZIP backend: ${_extractor.getBackendName()}');
	}

	public function isInstalling():Bool return _installing;

	public function cancel():Void {
		if (!_installing) return;
		_cancelled = true;
		_downloader.cancel();
		_extractor.cancel();
		trace('[ModDeltaInstaller] İptal isteği gönderildi.');
	}

	// ─────────────────────────────────────────────────────────────────────
	// PLAN
	// ─────────────────────────────────────────────────────────────────────

	public function getInstalledManifest(packId:String):Null<ModpackManifest> {
		var manifestPath = ModpackPaths.getInstalledManifestPath(packId);
		if (!FileSystem.exists(manifestPath)) return null;
		try {
			return (Json.parse(File.getContent(manifestPath)) : ModpackManifest);
		} catch (e:Dynamic) {
			trace('[ModDeltaInstaller] Manifest okunamadı: ${Std.string(e)}');
			return null;
		}
	}

	public function getInstalledModVersions(packId:String):Map<String, String> {
		var out:Map<String, String> = new Map();
		var manifest = getInstalledManifest(packId);
		if (manifest == null || manifest.modVersions == null) return out;
		try {
			var fields = Reflect.fields(manifest.modVersions);
			for (f in fields)
				out.set(f, Std.string(Reflect.field(manifest.modVersions, f)));
		} catch (e:Dynamic) {
			trace('[ModDeltaInstaller] modVersions okunamadı: ${Std.string(e)}');
		}
		return out;
	}

	public function buildPlan(catalog:ContentCatalog, packId:String):DeltaPlan {
		var installed = getInstalledModVersions(packId);
		var plan:DeltaPlan = {
			downloads: [],
			removes: [],
			skips: 0,
			totalDownloadBytes: 0.0
		};

		for (mod in catalog.mods) {
			if (mod == null || mod.folder == null || mod.folder.length == 0) continue;

			if (mod.removed == true) {
				if (installed.exists(mod.folder))
					plan.removes.push(mod);
				continue;
			}

			if (mod.url == null || mod.url.length == 0) continue;

			var cur = installed.get(mod.folder);
			if (cur == mod.version) {
				plan.skips++;
				continue;
			}

			plan.downloads.push(mod);
			if (mod.sizeBytes != null && mod.sizeBytes > 0)
				plan.totalDownloadBytes += mod.sizeBytes;
		}

		return plan;
	}

	/** Güncelleme var mı? (rozet/mağaza göstergesi için) */
	public function hasPending(catalog:ContentCatalog):Bool {
		var plan = buildPlan(catalog, catalog.packId);
		return plan.downloads.length > 0 || plan.removes.length > 0;
	}

	// ─────────────────────────────────────────────────────────────────────
	// KURULUM
	// ─────────────────────────────────────────────────────────────────────

	public function install(
		catalog:ContentCatalog,
		callbacks:ModpackInstallCallbacks
	):Void {
		if (_installing) {
			warn(callbacks, "Zaten bir kurulum devam ediyor.");
			return;
		}

		if (catalog == null || catalog.mods == null || catalog.mods.length == 0) {
			fail(callbacks, "İçerik kataloğu boş.");
			return;
		}

		var packId:String = catalog.packId;
		var plan = buildPlan(catalog, packId);

		if (plan.downloads.length == 0 && plan.removes.length == 0) {
			var manifest = getInstalledManifest(packId);
			if (manifest != null) {
				if (callbacks != null && callbacks.onComplete != null) callbacks.onComplete(manifest);
				return;
			}
			fail(callbacks, "Kurulum gerektiren mod bulunamadı.");
			return;
		}

		var spaceError = StorageGuard.checkDownloadSpace(plan.totalDownloadBytes);
		if (spaceError != null) {
			fail(callbacks, spaceError);
			return;
		}

		_installing = true;
		_cancelled = false;

		trace('[ModDeltaInstaller] Kurulum başladı: ${catalog.displayName} '
			+ '(${plan.downloads.length} indirilecek, ${plan.removes.length} silinecek, '
			+ '${plan.skips} atlanacak)');

		ModpackPaths.ensureDirectories();

		#if target.threaded
		Thread.create(() -> {
			runSteps(catalog, plan, callbacks);
		});
		#else
		runSteps(catalog, plan, callbacks);
		#end
	}

	function runSteps(
		catalog:ContentCatalog,
		plan:DeltaPlan,
		callbacks:ModpackInstallCallbacks
	):Void {
		var modsDir = ModpackPaths.getModsDirectory();
		var packId:String = catalog.packId;
		var total:Int = plan.downloads.length + plan.removes.length;
		var step:Int = 0;

		var advance:String->String->Float->Void = function(folder:String, message:String, fraction:Float):Void {
			var overall:Float = total > 0 ? (step + fraction) / total : 1.0;
			report(callbacks, InstallingMods, folder, message, overall);
		};

		// 1) kaldırılanlar
		for (mod in plan.removes) {
			if (checkCancelled(callbacks)) return;
			advance(mod.folder, 'Kaldırılıyor: ${mod.folder}', 1.0);
			var folderPath = Path.join([modsDir, mod.folder]);
			if (FileSystem.exists(folderPath)) {
				deleteDirectory(folderPath);
				trace('[ModDeltaInstaller] Kaldırıldı: ${mod.folder}');
			}
			step++;
		}

		// 2) indirme + kurma
		for (mod in plan.downloads) {
			if (checkCancelled(callbacks)) return;

			var zipName:String = mod.zipName != null && mod.zipName.length > 0
				? mod.zipName : Path.withoutDirectory(mod.url);
			var savePath:String = ModpackPaths.getDownloadedZipPath(zipName);

			// 2a) indir
			var dlMessage:String = plan.downloads.length > 1
				? 'İndiriliyor (${step - plan.removes.length + 1}/${plan.downloads.length}): ${mod.folder}'
				: 'İndiriliyor: ${mod.folder}';

			var dlResult = blockingDownload(mod.url, savePath, mod.sizeBytes, function(pct:Float) {
				advance(mod.folder, '$dlMessage ${Math.round(pct * 100)}%', 0.6 * pct);
			});

			if (checkCancelled(callbacks)) return;

			if (dlResult.error != null) {
				fail(callbacks, '"${mod.folder}" indirilemedi: ${dlResult.error}', savePath);
				return;
			}

			// 2b) sha256 doğrula (küçük dosyalarda)
			if (mod.sha256 != null && mod.sha256.length > 0) {
				try {
					var stat = FileSystem.stat(savePath);
					if (stat.size <= SHA_VERIFY_MAX_BYTES) {
						advance(mod.folder, 'Doğrulanıyor: ${mod.folder}', 0.62);
						var local:String = Sha256.make(File.getBytes(savePath)).toHex().toLowerCase();
						var remote:String = StringTools.trim(mod.sha256).toLowerCase();
						if (local != remote) {
							fail(callbacks, '"${mod.folder}" doğrulama hatası (sha256 uyuşmuyor). ZIP bozuk olabilir.', savePath);
							return;
						}
					} else {
						trace('[ModDeltaInstaller] sha256 atlandı (boyut > limit): ${mod.folder}');
					}
				} catch (e:Dynamic) {
					trace('[ModDeltaInstaller] sha256 okunamadı: ${Std.string(e)}');
				}
			}

			// 2c) çıkar (güvenlik taraması ile)
			var extractRoot:String = getExtractRoot(packId, mod.folder);
			var exResult = blockingExtract(savePath, extractRoot, function(frac:Float) {
				advance(mod.folder, 'Çıkarılıyor: ${mod.folder}', 0.62 + 0.23 * frac);
			});

			if (checkCancelled(callbacks)) return;

			if (exResult.error != null) {
				deleteDirectory(extractRoot);
				fail(callbacks, '"${mod.folder}" çıkarılamadı: ${exResult.error}', savePath);
				return;
			}

			// 2d) yerleştir (yerleşimi normalize et: kök pack.json → sar, tek klasör → al)
			var srcDir:Null<String> = normalizeExtractedLayout(extractRoot, mod.folder);
			if (srcDir == null) {
				deleteDirectory(extractRoot);
				fail(callbacks, '"${mod.folder}" ZIP içeriği tanınamadı (mod klasörü/pack.json bulunamadı).', savePath);
				return;
			}

			advance(mod.folder, 'Kuruluyor: ${mod.folder}', 0.9);

			var dstPath = Path.join([modsDir, mod.folder]);
			try {
				if (FileSystem.exists(dstPath))
					deleteDirectory(dstPath);
				copyDirectory(srcDir, dstPath);
				trace('[ModDeltaInstaller] Kuruldu: ${mod.folder} v${mod.version}');
			} catch (e:Dynamic) {
				fail(callbacks, '"${mod.folder}" kopyalanamadı: ${e.message}', savePath);
				return;
			}

			// 2e) temizle
			deleteDirectory(extractRoot);
			try {
				if (FileSystem.exists(savePath)) FileSystem.deleteFile(savePath);
			} catch (e:Dynamic) {}

			step++;
		}

		// 3) manifest kaydet
		saveManifest(catalog, callbacks);

		report(callbacks, Complete, "", '${catalog.displayName} güncellendi!', 1.0);
		_installing = false;
		_cancelled = false;

		if (callbacks != null && callbacks.onComplete != null) {
			var manifest = getInstalledManifest(catalog.packId);
			if (manifest != null) callbacks.onComplete(manifest);
		}
	}

	// ─────────────────────────────────────────────────────────────────────
	// YARDIMCILAR
	// ─────────────────────────────────────────────────────────────────────

	function getExtractRoot(packId:String, folder:String):String {
		return Path.join([ModpackPaths.getTempDirectory(), packId + "-delta", sanitizeFileName(folder)]);
	}

	function sanitizeFileName(name:String):String {
		var out:String = "";
		for (i in 0...name.length) {
			var c:String = name.charAt(i);
			var bad:Bool = switch (c) {
				case "/", "\\", ":", "*", "?", "\"", "<", ">", "|": true;
				default: false;
			}
			out += bad ? "_" : c;
		}
		return out.length > 0 ? out : "mod";
	}

	/** Asenkron işlem bitene kadar bekler (sys.thread.Event yerine taşınabilir yol). */
	function waitUntil(getDone:Void->Bool):Void {
		#if target.threaded
		var spins:Int = 0;
		while (!getDone()) {
			Sys.sleep(0.05);
			spins++;
			if (spins > 60 * 60 * 24) break; // ~24 saat emniyet supabı
		}
		#end
	}

	/** smartDownload'u iş parçacığı içinde bloke ederek bekler. */
	function blockingDownload(
		url:String, savePath:String, expectedBytes:Null<Float>,
		onProgress:Float->Void
	):{error:Null<String>, cancelled:Bool} {
		var result:{error:Null<String>, cancelled:Bool} = {error: null, cancelled: false};
		var done:Bool = false;

		_downloader.smartDownload(url, savePath, {
			onProgress: function(progress:DownloadProgress) {
				if (progress.percent > 0)
					onProgress(progress.percent);
			},
			onComplete: function(path:String) {
				result.error = null;
				result.cancelled = false;
				done = true;
			},
			onError: function(error:String) {
				result.error = error;
				done = true;
			},
			onCancelled: function() {
				result.cancelled = true;
				done = true;
			}
		}, expectedBytes != null && expectedBytes > 0 ? expectedBytes : -1);

		waitUntil(function() return done);
		return result;
	}

	/** ZIP'i temp'e çıkarır (güvenlik taraması + alan kontrolu dahil), bloke eder. */
	function blockingExtract(
		zipPath:String,
		extractRoot:String,
		onProgress:Float->Void
	):{error:Null<String>, cancelled:Bool} {
		var result:{error:Null<String>, cancelled:Bool} = {error: null, cancelled: false};

		try {
			if (FileSystem.exists(extractRoot))
				deleteDirectory(extractRoot);
			FileSystem.createDirectory(extractRoot);
		} catch (e:Dynamic) {
			result.error = 'temp klasörü hazırlanamadı: ${e.message}';
			return result;
		}

		// güvenlik taraması + açılmış boyut tahmini
		var estimated:Float = 0.0;
		var zipBytes:Float = 0.0;
		try {
			zipBytes = FileSystem.stat(zipPath).size;
		} catch (_) {}

		switch (_extractor.listEntries(zipPath)) {
			case Failure(error):
				result.error = Std.string(error);
				return result;

			case Success(entries):
				switch (ZipSecurity.scanEntries(entries, extractRoot)) {
					case Dangerous(reasons):
						result.error = 'Güvenlik ihlali: ${reasons.join(", ")}';
						return result;
					case Clean:
				}
				for (entry in entries)
					if (entry.uncompressedSize > 0) estimated += entry.uncompressedSize;
		}

		var spaceError = StorageGuard.checkExtractionSpace(estimated, zipBytes);
		if (spaceError != null) {
			result.error = spaceError;
			return result;
		}

		// bloke eden çıkarma
		var done:Bool = false;

		_extractor.extract(zipPath, extractRoot, {
			onProgress: function(info:ExtractProgressInfo) {
				var pct:Float = info.totalEntries > 0 ? info.currentEntries / info.totalEntries : 0.0;
				onProgress(pct);
			},
			onComplete: function(info:ExtractCompleteInfo) {
				done = true;
			},
			onError: function(error:ExtractError) {
				result.error = Std.string(error);
				done = true;
			},
			onCancelled: function() {
				result.cancelled = true;
				done = true;
			}
		});

		waitUntil(function() return done);
		return result;
	}

	/**
	 * Çıkarılan içeriği mods/{folder} olacak şekilde normalize eder.
	 * - zip kökünde pack.json varsa → tüm kökü {folder} altına sarar
	 * - tek kök klasör varsa → o klasörü döndürür
	 * Kaynak klasörü döndürür; tanınamazsa null.
	 */
	function normalizeExtractedLayout(extractRoot:String, folder:String):Null<String> {
		try {
			var packAtRoot:Bool = FileSystem.exists(Path.join([extractRoot, "pack.json"]));
			if (packAtRoot) {
				var wrapDir = Path.join([extractRoot, "__mod__"]);
				FileSystem.createDirectory(wrapDir);
				for (entry in FileSystem.readDirectory(extractRoot)) {
					if (entry == "__mod__") continue;
					var src = Path.join([extractRoot, entry]);
					var dst = Path.join([wrapDir, entry]);
					try {
						FileSystem.rename(src, dst);
					} catch (e:Dynamic) {
						// rename başarısızsa (cihazlar arası) kopyala
						if (FileSystem.isDirectory(src)) {
							copyDirectory(src, dst);
							deleteDirectory(src);
						} else {
							File.copy(src, dst);
							FileSystem.deleteFile(src);
						}
					}
				}
				return wrapDir;
			}

			var dirs:Array<String> = [];
			for (entry in FileSystem.readDirectory(extractRoot)) {
				if (StringTools.startsWith(entry, ".")) continue;
				if (FileSystem.isDirectory(Path.join([extractRoot, entry])))
					dirs.push(entry);
			}
			if (dirs.length == 1)
				return Path.join([extractRoot, dirs[0]]);

		} catch (e:Dynamic) {
			trace('[ModDeltaInstaller] normalize hatası: ${Std.string(e)}');
		}
		return null;
	}

	function saveManifest(catalog:ContentCatalog, callbacks:ModpackInstallCallbacks):Void {
		// güncel durum: katalogdaki aktif modlar
		var activeFolders:Array<String> = [];
		var modVersions:Dynamic = {};
		for (mod in catalog.mods) {
			if (mod.removed == true) continue;
			if (mod.folder == null || mod.folder.length == 0) continue;
			activeFolders.push(mod.folder);
			Reflect.setField(modVersions, mod.folder, mod.version);
		}

		var tier:Null<ModpackTier> = ModpackTier.fromString(catalog.packId);

		var manifest:ModpackManifest = {
			packId: catalog.packId,
			displayName: catalog.displayName != null ? catalog.displayName : catalog.packId,
			version: ModpackCatalog.getDisplayVersion(catalog),
			engineVersion: catalog.engineVersion != null ? catalog.engineVersion : UpdateConfig.CURRENT_ENGINE_VERSION,
			modFolders: activeFolders,
			modVersions: modVersions,
			tier: tier,
			installedAt: Date.now().toString(),
			installedEngineVersion: UpdateConfig.CURRENT_ENGINE_VERSION,
			modCount: activeFolders.length
		};

		if (catalog.totalSizeBytes != null)
			manifest.estimatedSizeBytes = catalog.totalSizeBytes;

		try {
			var installedPath = ModpackPaths.getInstalledManifestPath(catalog.packId);
			var installedDir = ModpackPaths.getInstalledDirectory();
			if (!FileSystem.exists(installedDir))
				FileSystem.createDirectory(installedDir);
			File.saveContent(installedPath, Json.stringify(manifest, null, "  "));
			trace('[ModDeltaInstaller] Manifest kaydedildi: $installedPath (${activeFolders.length} mod)');
		} catch (e:Dynamic) {
			warn(callbacks, 'Manifest kaydedilemedi: ${e.message}');
		}
	}

	function report(
		callbacks:ModpackInstallCallbacks,
		phase:ModpackInstallPhase,
		currentFile:String,
		message:String,
		overall:Float
	):Void {
		if (callbacks == null || callbacks.onProgress == null) return;
		if (overall < 0) overall = 0;
		if (overall > 1) overall = 1;
		callbacks.onProgress({
			phase: phase,
			phaseProgress: overall,
			overallProgress: overall,
			currentFile: currentFile != null ? currentFile : "",
			message: message != null ? message : ""
		});
	}

	function fail(callbacks:ModpackInstallCallbacks, message:String, ?cleanupFile:String):Void {
		_installing = false;
		_cancelled = false;
		trace('[ModDeltaInstaller] ✗ Hata: $message');

		if (cleanupFile != null) {
			try {
				if (FileSystem.exists(cleanupFile)) FileSystem.deleteFile(cleanupFile);
			} catch (_) {}
		}

		report(callbacks, Failed, "", message, 0);

		if (callbacks != null && callbacks.onError != null)
			callbacks.onError(message);
	}

	function warn(callbacks:ModpackInstallCallbacks, message:String):Void {
		trace('[ModDeltaInstaller] ⚠ Uyarı: $message');
		if (callbacks != null && callbacks.onWarning != null)
			callbacks.onWarning(message);
	}

	function checkCancelled(callbacks:ModpackInstallCallbacks):Bool {
		if (_cancelled) {
			_installing = false;
			_cancelled = false;
			trace('[ModDeltaInstaller] İptal edildi.');
			if (callbacks != null && callbacks.onCancelled != null)
				callbacks.onCancelled();
			return true;
		}
		return false;
	}

	function deleteDirectory(path:String):Void {
		if (path == null || !FileSystem.exists(path)) return;
		try {
			if (FileSystem.isDirectory(path)) {
				for (entry in FileSystem.readDirectory(path)) {
					var full = Path.join([path, entry]);
					if (FileSystem.isDirectory(full))
						deleteDirectory(full);
					else
						FileSystem.deleteFile(full);
				}
				FileSystem.deleteDirectory(path);
			} else {
				FileSystem.deleteFile(path);
			}
		} catch (e:Dynamic) {
			trace('[ModDeltaInstaller] Silme hatası: $path — ${Std.string(e)}');
		}
	}

	function copyDirectory(src:String, dst:String):Void {
		if (!FileSystem.exists(dst))
			FileSystem.createDirectory(dst);
		for (entry in FileSystem.readDirectory(src)) {
			var srcPath = Path.join([src, entry]);
			var dstPath = Path.join([dst, entry]);
			if (FileSystem.isDirectory(srcPath))
				copyDirectory(srcPath, dstPath);
			else
				File.copy(srcPath, dstPath);
		}
	}

	#else

	public function new() {}

	public function isInstalling():Bool return false;
	public function cancel():Void {}
	public function hasPending(catalog:Dynamic):Bool return false;

	public function install(catalog:Dynamic, callbacks:ModpackInstallCallbacks):Void {
		if (callbacks != null && callbacks.onError != null)
			callbacks.onError("Bu platformda delta kurulum desteklenmiyor.");
	}

	#end
}
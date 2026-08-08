package backend.modpack;

#if sys
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import backend.modpack.ModpackTypes;
import backend.modpack.ModpackPaths;
import backend.modpack.ModpackTier;
import backend.modpack.StorageGuard;
import backend.modpack.zip.ZipExtractorFactory;
import backend.modpack.zip.ZipSecurity;
import backend.modpack.zip.ZipTypes;
import backend.modpack.zip.IZipExtractor;
import backend.update.UpdateConfig;
#end

class ModpackInstaller {
	// ─────────────────────────────────────────────
	//  Sabitler
	// ─────────────────────────────────────────────

	static final MANIFEST_FILE:String = "_modpack.json";

	// Faz ağırlıkları (toplam 1.0 olmalı)
	static final WEIGHT_VALIDATING:Float = 0.05;
	static final WEIGHT_EXTRACTING:Float = 0.60;
	static final WEIGHT_VERIFYING:Float = 0.05;
	static final WEIGHT_INSTALLING:Float = 0.25;
	static final WEIGHT_CLEANUP:Float = 0.05;

	// ─────────────────────────────────────────────
	//  State
	// ─────────────────────────────────────────────

	#if sys
	var _extractor:IZipExtractor;
	var _installing:Bool = false;
	var _cancelled:Bool = false;

	// ─────────────────────────────────────────────
	//  Constructor
	// ─────────────────────────────────────────────

	public function new() {
		_extractor = ZipExtractorFactory.createSafe();
		trace('[ModpackInstaller] Oluşturuldu. Backend: ${_extractor.getBackendName()}');
	}

	// ─────────────────────────────────────────────
	//  Public API
	// ─────────────────────────────────────────────

	/**
	 * Modpack kurulumunu başlat.
	 *
	 * @param zipPath   İndirilen ZIP dosyasının tam yolu
	 * @param packId    Modpack kimliği (tier id: "lite", "medium", "further").
	 *                  Eski id'ler (minimal/high/full) otomatik eşlenir.
	 * @param callbacks İlerleme ve sonuç callback'leri
	 */
	public function install(zipPath:String, packId:String, callbacks:ModpackInstallCallbacks):Void {
		if (_installing) {
			warn(callbacks, "Zaten bir kurulum devam ediyor.");
			return;
		}

		if (!_extractor.isSupported()) {
			fail(callbacks, "Bu platformda ZIP çıkarma desteklenmiyor.");
			return;
		}

		if (packId == null || packId.length == 0) {
			fail(callbacks, "Geçersiz packId.");
			return;
		}

		// Tier doğrulaması: packId = tier id olmalı (lite/medium/further).
		// Eski id'ler (minimal/high/full) ModpackTier ile otomatik eşlenir.
		var tier:Null<ModpackTier> = ModpackTier.fromPackId(packId);
		if (tier == null) {
			warn(callbacks, 'Bilinmeyen packId "$packId" — tier tanınamadı. '
				+ 'Beklenen: lite / medium / further. Kurulum yine de devam edecek.');
		} else {
			trace('[ModpackInstaller] Tier: ${tier.getLabel()} (${tier})');
		}

		_installing = true;
		_cancelled = false;

		trace('[ModpackInstaller] Kurulum başladı. packId=$packId zipPath=$zipPath');

		ModpackPaths.ensureDirectories();

		#if target.threaded
		sys.thread.Thread.create(() -> {
			step_validate(zipPath, packId, callbacks);
		});
		#else
		step_validate(zipPath, packId, callbacks);
		#end
	}

	/**
	 * Devam eden kurulumu iptal et.
	 */
	public function cancel():Void {
		if (!_installing) return;
		_cancelled = true;
		_extractor.cancel();
		trace('[ModpackInstaller] İptal isteği gönderildi.');
	}

	public function isInstalling():Bool {
		return _installing;
	}

	/**
	 * Kurulu bir modpack'in manifest'ini oku.
	 * Kurulu değilse null döner.
	 */
	public function getInstalledManifest(packId:String):Null<ModpackManifest> {
		var manifestPath = ModpackPaths.getInstalledManifestPath(packId);

		if (!FileSystem.exists(manifestPath))
			return null;

		try {
			var raw = File.getContent(manifestPath);
			return (Json.parse(raw) : ModpackManifest);
		} catch (e:Dynamic) {
			trace('[ModpackInstaller] Manifest okunamadı: ${e.message}');
			return null;
		}
	}

	/**
	 * Bir modpack kurulu mu?
	 */
	public function isInstalled(packId:String):Bool {
		return getInstalledManifest(packId) != null;
	}

	/**
	 * Kurulu paketin tier'ını döner (lite/medium/further).
	 * Kurulu değilse veya tier çözülemezse null.
	 */
	public function getInstalledTier(packId:String):Null<ModpackTier> {
		var manifest = getInstalledManifest(packId);
		if (manifest == null) return null;

		return ModpackTier.fromString(manifest.tier != null ? manifest.tier : manifest.packId);
	}

	/**
	 * Kurulu diğer paketlerin id'lerini döner (manifest dosyalarından tarar).
	 * excludePackId hariç tutulur.
	 */
	public function getOtherInstalledPackIds(excludePackId:String):Array<String> {
		var ids:Array<String> = [];
		var dir = ModpackPaths.getInstalledDirectory();

		if (!FileSystem.exists(dir)) return ids;

		for (entry in FileSystem.readDirectory(dir)) {
			if (!StringTools.endsWith(entry, ".json")) continue;

			var id = entry.substr(0, entry.length - ".json".length);
			if (id == excludePackId || id.length == 0) continue;

			if (getInstalledManifest(id) != null)
				ids.push(id);
		}

		return ids;
	}

	/** Kurulum manifest dosyasını siler (varsa). */
	function deleteInstalledManifest(packId:String):Void {
		try {
			var manifestPath = ModpackPaths.getInstalledManifestPath(packId);
			if (FileSystem.exists(manifestPath))
				FileSystem.deleteFile(manifestPath);
		} catch (e:Dynamic) {
			trace('[ModpackInstaller] Manifest silinemedi ($packId): ${Std.string(e)}');
		}
	}

	/**
	 * ZIP'teki dosyaların açılmış (uncompressed) toplam boyutunu tahmin eder.
	 * ZIP okunamazsa -1 döner.
	 */
	public function estimateUnpackedSize(zipPath:String):Float {
		#if sys
		if (!_extractor.isSupported()) return -1;
		if (zipPath == null || !FileSystem.exists(zipPath)) return -1;

		var result = _extractor.listEntries(zipPath);
		return switch (result) {
			case Success(entries):
				var total:Float = 0.0;
				for (entry in entries) {
					if (entry.uncompressedSize > 0)
						total += entry.uncompressedSize;
				}
				total;
			case Failure(_):
				-1.0;
		}
		#else
		return -1.0;
		#end
	}

	/**
	 * Kurulu bir modpack'i kaldırır:
	 * manifest'teki tüm mod klasörlerini mods/ altından siler ve
	 * kurulum manifestini temizler.
	 *
	 * onComplete → kaldırılan paketin eski manifesti
	 * onWarning  → silinemeyen klasörler
	 */
	public function uninstall(packId:String, callbacks:ModpackInstallCallbacks):Void {
		#if sys
		if (_installing) {
			warn(callbacks, "Zaten bir kurulum/kaldırma işlemi devam ediyor.");
			return;
		}

		var manifest = getInstalledManifest(packId);
		if (manifest == null) {
			fail(callbacks, 'Kurulu paket bulunamadı: $packId');
			return;
		}

		_installing = true;
		_cancelled = false;

		trace('[ModpackInstaller] Kaldırma başladı: ${manifest.displayName} v${manifest.version}');

		#if target.threaded
		sys.thread.Thread.create(() -> {
			doUninstall(packId, manifest, callbacks);
		});
		#else
		doUninstall(packId, manifest, callbacks);
		#end
		#else
		if (callbacks != null && callbacks.onError != null)
			callbacks.onError("Bu platformda kaldırma desteklenmiyor.");
		#end
	}

	function doUninstall(packId:String, manifest:ModpackManifest, callbacks:ModpackInstallCallbacks):Void {
		var modsDir = ModpackPaths.getModsDirectory();

		for (folder in manifest.modFolders) {
			var folderPath = Path.join([modsDir, folder]);
			if (FileSystem.exists(folderPath)) {
				deleteDirectory(folderPath);
				trace('[ModpackInstaller] Kaldırıldı: $folder');
			} else {
				warn(callbacks, '"$folder" bulunamadı, zaten silinmiş olabilir.');
			}
		}

		// Kurulum manifestini sil
		try {
			var manifestPath = ModpackPaths.getInstalledManifestPath(packId);
			if (FileSystem.exists(manifestPath))
				FileSystem.deleteFile(manifestPath);
			trace('[ModpackInstaller] Kurulum manifesti silindi: $manifestPath');
		} catch (e:Dynamic) {
			warn(callbacks, 'Kurulum manifesti silinemedi: ${e.message}');
		}

		_installing = false;
		_cancelled = false;

		trace('[ModpackInstaller] ✓ Kaldırma tamamlandı: ${manifest.packId}');

		if (callbacks != null && callbacks.onComplete != null)
			callbacks.onComplete(manifest);
	}

	// ─────────────────────────────────────────────
	//  Adım 1 — Doğrulama
	// ─────────────────────────────────────────────

	function step_validate(zipPath:String, packId:String, callbacks:ModpackInstallCallbacks):Void {
		reportPhase(callbacks, Validating, 0.0, "", "ZIP dosyası kontrol ediliyor...");

		if (checkCancelled(callbacks)) return;

		// ZIP var mı?
		if (!FileSystem.exists(zipPath)) {
			fail(callbacks, 'ZIP dosyası bulunamadı: $zipPath');
			return;
		}

		// ZIP boyutu sıfır mı?
		var stat = FileSystem.stat(zipPath);
		if (stat.size <= 0) {
			fail(callbacks, 'ZIP dosyası boş: $zipPath');
			return;
		}

		// Hedef temp klasörünü hazırla
		var tempDir = ModpackPaths.getTempPackDirectory(packId);
		try {
			deleteDirectory(tempDir);
			FileSystem.createDirectory(tempDir);
		} catch (e:Dynamic) {
			fail(callbacks, 'Temp klasörü hazırlanamadı: ${e.message}');
			return;
		}

		reportPhase(callbacks, Validating, 0.5, "", "ZIP içeriği taranıyor...");

		if (checkCancelled(callbacks)) return;

		// Entry listesi al
		var entriesResult = _extractor.listEntries(zipPath);

		switch (entriesResult) {
			case Success(entries):
				if (entries.length == 0) {
					fail(callbacks, 'ZIP dosyası boş görünüyor.');
					return;
				}

				// Güvenlik taraması
				var scanResult = ZipSecurity.scanEntries(entries, tempDir);
				switch (scanResult) {
					case Dangerous(reasons):
						fail(callbacks, 'Güvenlik ihlali:\n${reasons.join("\n")}');
						return;

					case Clean:
						// devam
				}

				// ── Depolama alanı kontrolü (çıkarma öncesi) ──
				// ZIP'teki tüm dosyaların açılmış boyutları toplanır;
				// ZIP + açılmış hal + güvenlik payı kadar boş alan aranır.
				var estimatedUnpacked:Float = 0.0;
				for (entry in entries) {
					if (entry.uncompressedSize > 0)
						estimatedUnpacked += entry.uncompressedSize;
				}

				var spaceError:Null<String> = StorageGuard.checkExtractionSpace(estimatedUnpacked, stat.size);
				if (spaceError != null) {
					fail(callbacks, spaceError);
					return;
				}

				trace('[ModpackInstaller] Tahmini açılmış boyut: ${StorageGuard.formatBytes(estimatedUnpacked)}');

				reportPhase(callbacks, Validating, 1.0, "", "Doğrulama tamamlandı.");
				step_extract(zipPath, packId, tempDir, callbacks);

			case Failure(error):
				fail(callbacks, 'ZIP okunamadı: ${formatError(error)}');
		}
	}

	// ─────────────────────────────────────────────
	//  Adım 2 — Temp'e Extract
	// ─────────────────────────────────────────────

	function step_extract(
		zipPath:String, packId:String, tempDir:String,
		callbacks:ModpackInstallCallbacks
	):Void {
		reportPhase(callbacks, Extracting, 0.0, "", "Dosyalar çıkarılıyor...");

		if (checkCancelled(callbacks)) return;

		_extractor.extract(zipPath, tempDir, {
			onProgress: function(info:ExtractProgressInfo) {
				if (checkCancelled(callbacks)) return;

				var pct = info.totalEntries > 0 ? info.currentEntries / info.totalEntries : 0.0;

				reportPhase(
					callbacks,
					Extracting,
					pct,
					info.currentFile,
					'Çıkarılıyor: ${info.currentEntries} / ${info.totalEntries}'
				);
			},

			onComplete: function(info:ExtractCompleteInfo) {
				trace('[ModpackInstaller] Extract tamamlandı. ${info.extractedEntries} dosya.');
				step_verify(packId, tempDir, callbacks, zipPath);
			},

			onError: function(error:ExtractError) {
				deleteDirectory(tempDir);
				fail(callbacks, 'Çıkarma hatası: ${formatError(error)}');
			},

			onCancelled: function() {
				deleteDirectory(tempDir);
				handleCancel(callbacks);
			}
		});
	}

	// ─────────────────────────────────────────────
	//  Adım 3 — Manifest Doğrulama
	// ─────────────────────────────────────────────

	function step_verify(
		packId:String, tempDir:String,
		callbacks:ModpackInstallCallbacks,
		?zipPath:String
	):Void {
		reportPhase(callbacks, Verifying, 0.0, "", "Modpack doğrulanıyor...");

		if (checkCancelled(callbacks)) return;

		var manifestPath = Path.join([tempDir, MANIFEST_FILE]);
		var manifest:ModpackManifest;

		if (!FileSystem.exists(manifestPath)) {
			// Manifest yok, otomatik oluştur
			warn(callbacks, '_modpack.json bulunamadı. Modpack otomatik taranacak.');
			manifest = buildAutoManifest(packId, tempDir);

			if (manifest.modFolders.length == 0) {
				fail(callbacks, 'Modpack içinde hiç mod klasörü bulunamadı.');
				return;
			}
		} else {
			// Manifest'i oku
			try {
				var raw = File.getContent(manifestPath);
				manifest = (Json.parse(raw) : ModpackManifest);
			} catch (e:Dynamic) {
				fail(callbacks, '_modpack.json okunamadı: ${e.message}');
				return;
			}

			// packId kontrolü
			if (manifest.packId != packId) {
				warn(callbacks, 'Manifest packId uyuşmuyor. '
					+ 'Beklenen: $packId, Gelen: ${manifest.packId}. '
					+ 'Devam ediliyor.');
				// Override et, kullanıcının seçtiği packId doğru kabul edilir
				manifest = overridePackId(manifest, packId);
			}

			// Mod klasörleri gerçekten var mı?
			for (folder in manifest.modFolders) {
				var folderPath = Path.join([tempDir, folder]);
				if (!FileSystem.exists(folderPath)) {
					warn(callbacks, 'Manifest\'te "$folder" var ama ZIP\'te yok. Atlanacak.');
				}
			}

			// Engine sürüm uyumluluğu
			if (manifest.minEngineVersion != null) {
				// Basit string karşılaştırma, VersionParser entegre edilebilir
				trace('[ModpackInstaller] minEngineVersion: ${manifest.minEngineVersion}');
			}
		}

		reportPhase(callbacks, Verifying, 1.0, "", "Doğrulama tamamlandı.");

		step_detectOldMods(packId, tempDir, manifest, callbacks, zipPath);
	}

	// ─────────────────────────────────────────────
	//  Adım 4 — Eski Modları Tespit Et
	// ─────────────────────────────────────────────

	function step_detectOldMods(
		packId:String, tempDir:String,
		newManifest:ModpackManifest,
		callbacks:ModpackInstallCallbacks,
		?zipPath:String
	):Void {
		reportPhase(callbacks, InstallingMods, 0.0, "", "Eski modlar kontrol ediliyor...");

		if (checkCancelled(callbacks)) return;

		var foldersToRemove:Array<String> = [];
		var newTier:Null<ModpackTier> = ModpackTier.fromPackId(packId);

		// ── 1) Aynı paketin önceki kurulumu ──
		var oldManifest = getInstalledManifest(packId);

		if (oldManifest != null) {
			trace('[ModpackInstaller] Önceki kurulum bulundu: v${oldManifest.version}');

			var oldTier:Null<ModpackTier> = ModpackTier.fromString(oldManifest.tier != null ? oldManifest.tier : oldManifest.packId);

			if (oldTier != null && newTier != null) {
				if (newTier.isHigherThan(oldTier)) {
					trace('[ModpackInstaller] Tier yükseltme: ${oldTier.getLabel()} → ${newTier.getLabel()}');
				} else if (newTier.isLowerThan(oldTier)) {
					warn(callbacks, 'Tier düşürme: ${oldTier.getLabel()} → ${newTier.getLabel()}. '
						+ 'Bu pakette olmayan modlar kaldırılacak.');
				}
			}

			for (oldFolder in oldManifest.modFolders) {
				// Yeni modFolders listesinde yoksa silinecek
				if (newManifest.modFolders.indexOf(oldFolder) == -1) {
					foldersToRemove.push(oldFolder);
					trace('[ModpackInstaller] Kaldırılacak: $oldFolder');
				}
			}
		} else {
			trace('[ModpackInstaller] İlk kurulum, eski mod silinmeyecek.');
		}

		// ── 2) Diğer kurulu paketler (tek aktif paket modeli) ──
		// Lite / Medium / Further birbirinin yerine geçer: yeni paket kurulunca
		// önceki resmî paketin manifesti silinir ve yeni pakette olmayan
		// modları kaldırılır. Böylece Lite'a geçiş GERÇEKTEN yer açar.
		// Kullanıcının kendi eliyle kurduğu modlar (manifest'i olmayanlar)
		// ve bilinmeyen/özel packId'ler ASLA dokunulmaz.
		var otherPacks = getOtherInstalledPackIds(packId);

		for (otherId in otherPacks) {
			var otherManifest = getInstalledManifest(otherId);
			if (otherManifest == null) continue;

			var otherTier:Null<ModpackTier> = ModpackTier.fromString(otherManifest.tier != null ? otherManifest.tier : otherManifest.packId);

			// Tier'ı bilinmeyen paketlere dokunma (özel/custom paketler).
			if (otherTier == null) {
				trace('[ModpackInstaller] Custom paket atlanıyor (dokunulmadı): $otherId');
				continue;
			}

			var removedFolders:Array<String> = [];
			for (folder in otherManifest.modFolders) {
				if (newManifest.modFolders.indexOf(folder) == -1 && foldersToRemove.indexOf(folder) == -1) {
					foldersToRemove.push(folder);
					removedFolders.push(folder);
					trace('[ModpackInstaller] Diğer paketten kaldırılacak: $folder');
				}
			}

			// Eski paketin kaydını sil (yerini yeni paket aldı).
			deleteInstalledManifest(otherId);

			if (newTier != null && otherTier != null && newTier.isLowerThan(otherTier)) {
				warn(callbacks, 'Tier düşürme: ${otherTier.getLabel()} → ${newTier.getLabel()}. '
					+ (removedFolders.length > 0
						? 'Bu pakete özel modlar kaldırılıyor (${removedFolders.join(", ")}).'
						: 'Tüm modlar yeni pakette mevcut.'));
			} else if (newTier != null && otherTier != null && newTier.isHigherThan(otherTier)) {
				trace('[ModpackInstaller] Tier yükseltme: ${otherTier.getLabel()} → ${newTier.getLabel()}. Eski paket kaydı silindi.');
			} else {
				trace('[ModpackInstaller] Paket değişimi: $otherId → $packId');
			}
		}

		step_install(packId, tempDir, newManifest, foldersToRemove, callbacks, zipPath);
	}

	// ─────────────────────────────────────────────
	//  Adım 5 — Mods Klasörüne Kur
	// ─────────────────────────────────────────────

	function step_install(
		packId:String, tempDir:String,
		manifest:ModpackManifest,
		foldersToRemove:Array<String>,
		callbacks:ModpackInstallCallbacks,
		?zipPath:String
	):Void {
		var modsDir = ModpackPaths.getModsDirectory();

		// mods/ klasörü yoksa oluştur
		try {
			if (!FileSystem.exists(modsDir))
				FileSystem.createDirectory(modsDir);
		} catch (e:Dynamic) {
			fail(callbacks, 'mods/ klasörü oluşturulamadı: ${e.message}');
			return;
		}

		var totalSteps = foldersToRemove.length + manifest.modFolders.length;
		var currentStep = 0;

		// ── a) Eski mod klasörlerini kaldır

		for (folder in foldersToRemove) {
			if (checkCancelled(callbacks)) return;

			var oldPath = Path.join([modsDir, folder]);
			if (FileSystem.exists(oldPath)) {
				reportPhase(
					callbacks, InstallingMods,
					totalSteps > 0 ? currentStep / totalSteps : 0.0,
					folder,
					'Kaldırılıyor: $folder'
				);
				deleteDirectory(oldPath);
				trace('[ModpackInstaller] Kaldırıldı: $oldPath');
			}
			currentStep++;
		}

		// ── b) Yeni mod klasörlerini kopyala

		for (folder in manifest.modFolders) {
			if (checkCancelled(callbacks)) return;

			var srcPath = Path.join([tempDir, folder]);
			var dstPath = Path.join([modsDir, folder]);

			if (!FileSystem.exists(srcPath)) {
				warn(callbacks, '"$folder" temp klasöründe bulunamadı, atlandı.');
				currentStep++;
				continue;
			}

			reportPhase(
				callbacks, InstallingMods,
				totalSteps > 0 ? currentStep / totalSteps : 0.0,
				folder,
				'Kuruluyor: $folder'
			);

			// Varsa üzerine yaz (önce sil)
			if (FileSystem.exists(dstPath)) {
				deleteDirectory(dstPath);
			}

			try {
				copyDirectory(srcPath, dstPath);
				trace('[ModpackInstaller] Kuruldu: $folder');
			} catch (e:Dynamic) {
				fail(callbacks, '"$folder" kopyalanamadı: ${e.message}');
				return;
			}

			currentStep++;
		}

		// ── c) Manifest'i damgala ve kaydet ──

		// Tier: manifest'teki değer geçerliyse onu koru, yoksa packId'den çöz.
		var resolvedTier:Null<ModpackTier> = ModpackTier.fromString(manifest.tier);
		if (resolvedTier == null)
			resolvedTier = ModpackTier.fromPackId(packId);

		if (resolvedTier != null)
			manifest.tier = resolvedTier;

		manifest.installedAt = Date.now().toString();
		manifest.installedEngineVersion = UpdateConfig.CURRENT_ENGINE_VERSION;
		manifest.modCount = manifest.modFolders.length;

		try {
			var installedPath = ModpackPaths.getInstalledManifestPath(packId);
			var installedDir = ModpackPaths.getInstalledDirectory();

			if (!FileSystem.exists(installedDir))
				FileSystem.createDirectory(installedDir);

			File.saveContent(installedPath, Json.stringify(manifest, null, "  "));
			trace('[ModpackInstaller] Manifest kaydedildi: $installedPath'
				+ (manifest.tier != null ? ' (tier: $manifest.tier)' : ''));
		} catch (e:Dynamic) {
			// Manifest kaydedilemese bile kurulum başarılı sayılır
			// ama uyarı ver
			warn(callbacks, 'Manifest kaydedilemedi: ${e.message}');
		}

		reportPhase(callbacks, InstallingMods, 1.0, "", "Kurulum tamamlandı.");

		step_cleanup(packId, tempDir, manifest, callbacks, zipPath);
	}

	function step_cleanup(
		packId:String, tempDir:String,
		manifest:ModpackManifest,
		callbacks:ModpackInstallCallbacks,
		?zipPath:String
	):Void {
		reportPhase(callbacks, Cleanup, 0.0, "", "Geçici dosyalar temizleniyor...");

		// Temp klasörünü sil
		try {
			deleteDirectory(tempDir);
			trace('[ModpackInstaller] Temp temizlendi: $tempDir');
		} catch (e:Dynamic) {
			trace('[ModpackInstaller] Temp silinemedi: ${Std.string(e)}');
		}

		// İndirilen ZIP dosyasını sil
		if (zipPath != null && zipPath.length > 0) {
			try {
				if (FileSystem.exists(zipPath)) {
					FileSystem.deleteFile(zipPath);
					trace('[ModpackInstaller] ZIP silindi: $zipPath');
				}
			} catch (e:Dynamic) {
				trace('[ModpackInstaller] ZIP silinemedi: ${Std.string(e)}');
			}
		}

		reportPhase(callbacks, Cleanup, 1.0, "", "Temizlik tamamlandı.");
		step_complete(manifest, callbacks);
	}

	// ─────────────────────────────────────────────
	//  Adım 7 — Tamamlandı
	// ─────────────────────────────────────────────

	function step_complete(manifest:ModpackManifest, callbacks:ModpackInstallCallbacks):Void {
		_installing = false;
		_cancelled = false;

		reportPhase(
			callbacks, Complete, 1.0, "",
			'${manifest.displayName} v${manifest.version} başarıyla kuruldu!'
		);

		trace('[ModpackInstaller] ✓ Kurulum başarılı: ${manifest.packId} v${manifest.version}');

		if (callbacks != null && callbacks.onComplete != null)
			callbacks.onComplete(manifest);
	}

	// ─────────────────────────────────────────────
	//  Progress Yardımcıları
	// ─────────────────────────────────────────────

	function reportPhase(
		callbacks:ModpackInstallCallbacks,
		phase:ModpackInstallPhase,
		phaseProgress:Float,
		currentFile:String,
		message:String
	):Void {
		if (callbacks == null || callbacks.onProgress == null) return;

		var overall = calcOverallProgress(phase, phaseProgress);

		callbacks.onProgress({
			phase: phase,
			phaseProgress: phaseProgress,
			overallProgress: overall,
			currentFile: currentFile != null ? currentFile : "",
			message: message != null ? message : ""
		});
	}

	function calcOverallProgress(phase:ModpackInstallPhase, phaseProgress:Float):Float {
		var base:Float = 0.0;

		switch (phase) {
			case Validating:
				base = 0.0;
				return base + WEIGHT_VALIDATING * phaseProgress;

			case Extracting:
				base = WEIGHT_VALIDATING;
				return base + WEIGHT_EXTRACTING * phaseProgress;

			case Verifying:
				base = WEIGHT_VALIDATING + WEIGHT_EXTRACTING;
				return base + WEIGHT_VERIFYING * phaseProgress;

			case InstallingMods:
				base = WEIGHT_VALIDATING + WEIGHT_EXTRACTING + WEIGHT_VERIFYING;
				return base + WEIGHT_INSTALLING * phaseProgress;

			case Cleanup:
				base = WEIGHT_VALIDATING + WEIGHT_EXTRACTING + WEIGHT_VERIFYING + WEIGHT_INSTALLING;
				return base + WEIGHT_CLEANUP * phaseProgress;

			case Complete:
				return 1.0;

			case Failed:
				return 0.0;
		}
	}

	function fail(callbacks:ModpackInstallCallbacks, message:String, ?cleanupPath:String):Void {
		_installing = false;
		_cancelled = false;

		trace('[ModpackInstaller] ✗ Hata: $message');

		// Hata durumunda geçici dosyaları temizle
		if (cleanupPath != null) {
			try {
				deleteDirectory(cleanupPath);
			} catch (_) {}
		}

		reportPhase(callbacks, Failed, 0.0, "", message);

		if (callbacks != null && callbacks.onError != null)
			callbacks.onError(message);
	}

	function warn(callbacks:ModpackInstallCallbacks, message:String):Void {
		trace('[ModpackInstaller] ⚠ Uyarı: $message');

		if (callbacks != null && callbacks.onWarning != null)
			callbacks.onWarning(message);
	}

	function handleCancel(callbacks:ModpackInstallCallbacks):Void {
		_installing = false;
		_cancelled = false;

		trace('[ModpackInstaller] Kurulum iptal edildi.');

		if (callbacks != null && callbacks.onCancelled != null)
			callbacks.onCancelled();
	}

	function checkCancelled(callbacks:ModpackInstallCallbacks):Bool {
		if (_cancelled) {
			handleCancel(callbacks);
			return true;
		}
		return false;
	}

	function formatError(error:ExtractError):String {
		return switch (error) {
			case FileNotFound(path): 'Dosya bulunamadı: $path';
			case CorruptArchive(detail): 'Bozuk arşiv: $detail';
			case DiskFull(req, avail): 'Disk dolu. Gerekli: ${req} B, Mevcut: ${avail} B';
			case PermissionDenied(path): 'İzin reddedildi: $path';
			case PathTraversal(entry): 'Güvenlik ihlali: $entry';
			case UnsupportedFormat(detail): 'Desteklenmeyen format: $detail';
			case NotSupported(detail): 'Desteklenmiyor: $detail';
			case CommandFailed(cmd, code, err): 'Komut hatası ($cmd, exit $code): $err';
			case Cancelled: 'İptal edildi.';
			case Unknown(msg): 'Bilinmeyen hata: $msg';
		}
	}

	// ─────────────────────────────────────────────
	//  Manifest Yardımcıları
	// ─────────────────────────────────────────────

	/**
	 * _modpack.json yoksa temp klasörünü tarayıp
	 * otomatik manifest oluşturur.
	 */
	function buildAutoManifest(packId:String, tempDir:String):ModpackManifest {
		var folders:Array<String> = [];
		var hasPackJson:Bool = false;

		try {
			for (entry in FileSystem.readDirectory(tempDir)) {
				if (StringTools.startsWith(entry, ".")) continue;
				if (StringTools.startsWith(entry, "_")) continue;

				var fullPath = Path.join([tempDir, entry]);
				if (FileSystem.isDirectory(fullPath)) {
					folders.push(entry);
				}

				// pack.json varsa bu muhtemelen tek bir mod
				if (entry == "pack.json") hasPackJson = true;
			}
		} catch (e:Dynamic) {
			trace('[ModpackInstaller] Auto manifest tarama hatası: ${Std.string(e)}');
		}

		// Tek mod algılama:
		// Eğer root'ta pack.json varsa ve klasörler
		// tipik mod iç klasörleriyse (data, images, songs, etc.)
		// bu tek bir moddur, tüm temp root'u tek mod olarak kur
		if (hasPackJson || isSingleModLayout(folders)) {
			trace('[ModpackInstaller] Tek mod algılandı. Tüm içerik tek mod olarak kurulacak.');

			// Temp içeriğini packId adlı alt klasöre taşı
			var modSubDir = Path.join([tempDir, packId]);
			try {
				FileSystem.createDirectory(modSubDir);

				for (entry in FileSystem.readDirectory(tempDir)) {
					if (entry == packId) continue; // kendini atla

					var srcPath = Path.join([tempDir, entry]);
					var dstPath = Path.join([modSubDir, entry]);

					if (FileSystem.isDirectory(srcPath))
						copyDirectory(srcPath, dstPath);
					else
						File.copy(srcPath, dstPath);
				}

				// Eski dosyaları temizle (taşınan klasör hariç)
				for (entry in FileSystem.readDirectory(tempDir)) {
					if (entry == packId) continue;
					var fullPath = Path.join([tempDir, entry]);
					if (FileSystem.isDirectory(fullPath))
						deleteDirectory(fullPath);
					else
						FileSystem.deleteFile(fullPath);
				}
			} catch (e:Dynamic) {
				trace('[ModpackInstaller] Tek mod düzenleme hatası: ${Std.string(e)}');
			}

			folders = [packId];
		}

		trace('[ModpackInstaller] Auto manifest oluşturuldu. Klasörler: $folders');

		var tier:Null<ModpackTier> = ModpackTier.fromPackId(packId);

		return {
			packId: packId,
			displayName: capitalize(packId) + " Modpack",
			version: "unknown",
			engineVersion: "unknown",
			modFolders: folders,
			tier: tier != null ? tier : null,
			installedAt: Date.now().toString(),
			installedEngineVersion: UpdateConfig.CURRENT_ENGINE_VERSION
		};
	}

	/**
	 * Klasör listesinin tipik mod iç yapısına benzeyip
	 * benzemediğini kontrol eder.
	 * Eğer klasörler "data", "images", "songs", "sounds",
	 * "characters", "stages", "scripts" gibi şeyler içeriyorsa
	 * bu tek bir moddur, modpack değil.
	 */
	function isSingleModLayout(folders:Array<String>):Bool {
		var modInternalFolders = [
			"data", "images", "songs", "sounds", "music",
			"characters", "stages", "scripts", "videos",
			"fonts", "weeks", "shared", "custom_events",
			"custom_notetypes", "achievements"
		];

		var matchCount:Int = 0;
		for (folder in folders) {
			var lower = folder.toLowerCase();
			if (modInternalFolders.indexOf(lower) != -1)
				matchCount++;
		}

		// Klasörlerin yarısından fazlası iç klasörse tek mod
		return folders.length > 0 && matchCount >= folders.length * 0.5;
	}

	function overridePackId(manifest:ModpackManifest, packId:String):ModpackManifest {
		return {
			packId: packId,
			displayName: manifest.displayName,
			version: manifest.version,
			engineVersion: manifest.engineVersion,
			modFolders: manifest.modFolders,
			author: manifest.author,
			description: manifest.description,
			totalFileCount: manifest.totalFileCount,
			totalSizeBytes: manifest.totalSizeBytes,
			minEngineVersion: manifest.minEngineVersion,
			maxEngineVersion: manifest.maxEngineVersion,
			checksum: manifest.checksum,
			changelog: manifest.changelog
		};
	}

	function capitalize(s:String):String {
		if (s == null || s.length == 0) return s;
		return s.charAt(0).toUpperCase() + s.substr(1);
	}

	// ─────────────────────────────────────────────
	//  Dosya Sistemi Yardımcıları
	// ─────────────────────────────────────────────

	function deleteDirectory(path:String):Void {
		if (path == null || !FileSystem.exists(path)) return;

		try {
			if (FileSystem.isDirectory(path)) {
				for (entry in FileSystem.readDirectory(path)) {
					var fullPath = Path.join([path, entry]);
					if (FileSystem.isDirectory(fullPath))
						deleteDirectory(fullPath);
					else
						FileSystem.deleteFile(fullPath);
				}
				FileSystem.deleteDirectory(path);
			} else {
				FileSystem.deleteFile(path);
			}
		} catch (e:Dynamic) {
			trace('[ModpackInstaller] Silme hatası: $path — ${e.message}');
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
	// ─────────────────────────────────────────────
	//  sys yoksa stub
	// ─────────────────────────────────────────────

	public function new() {}

	public function install(zipPath:String, packId:String, callbacks:ModpackInstallCallbacks):Void {
		if (callbacks != null && callbacks.onError != null)
			callbacks.onError("Bu platformda kurulum desteklenmiyor.");
	}

	public function cancel():Void {}
	public function isInstalling():Bool return false;
	public function isInstalled(packId:String):Bool return false;
	public function getInstalledManifest(packId:String):Null<ModpackManifest> return null;
	public function getInstalledTier(packId:String):Null<ModpackTier> return null;
	public function estimateUnpackedSize(zipPath:String):Float return -1.0;

	public function uninstall(packId:String, callbacks:ModpackInstallCallbacks):Void {
		if (callbacks != null && callbacks.onError != null)
			callbacks.onError("Bu platformda kaldırma desteklenmiyor.");
	}
	#end
}
package backend.modpack;

/**
 * Further Engine — Depolama Alanı Koruyucusu (StorageGuard)
 *
 * Lite / Medium / Further tier ayrımının en kritik parçası:
 * indirme başlamadan ÖNCE ve ZIP'ten çıkarma başlamadan ÖNCE
 * cihazda yeterli alan olup olmadığını kontrol eder.
 *
 * Boş alan yalnızca Android'de okunabilir (JNI → java.io.File.getFreeSpace()).
 * Diğer platformlarda veya JNI hatasında -1 döner ve kontrol sessizce atlanır
 * (yanlış pozitif engelleme yapılmaz).
 */
class StorageGuard {
	/** ZIP indirme için: beklenen zip boyutunun bu katı kadar alan istenir (çıkarma payı ile). */
	public static final DOWNLOAD_MARGIN_FACTOR:Float = 2.2;

	/** Çıkarma için: zip + açılmış hali + bu kadar ekstra güvenlik payı. */
	public static final EXTRACT_EXTRA_BUFFER:Float = 64 * 1024 * 1024;

	/** Tier boyut uyarısı toleransı: hedef boyutun %25 üzerine çıkınca uyar. */
	public static final TIER_SIZE_TOLERANCE:Float = 1.25;

	/**
	 * Debug/test için boş alanı elle ver.
	 * null ise gerçek cihaz değeri okunur. (Masaüstünde test için.)
	 */
	public static var DEBUG_OVERRIDE_FREE_SPACE:Null<Float> = null;

	// ─────────────────────────────────────────────
	//  Boş alan sorgulama
	// ─────────────────────────────────────────────

	/**
	 * Cihazda kullanılabilir depolama alanı (bayt).
	 * Okunamıyorsa (masaüstü, JNI hatası vb.) -1 döner.
	 */
	public static function getFreeSpaceBytes():Float {
		if (DEBUG_OVERRIDE_FREE_SPACE != null)
			return DEBUG_OVERRIDE_FREE_SPACE;

		#if android
		return androidFreeSpace();
		#else
		return -1;
		#end
	}

	// ─────────────────────────────────────────────
	//  Kontroller
	// ─────────────────────────────────────────────

	/**
	 * İndirme öncesi alan kontrolü.
	 * Yeterli alan yoksa hata mesajı, sorun yoksa (veya alan
	 * bilinmiyorsa) null döner.
	 *
	 * @param expectedZipBytes Katalogdaki fileSizeBytes (beklenen ZIP boyutu)
	 */
	public static function checkDownloadSpace(expectedZipBytes:Float):Null<String> {
		if (expectedZipBytes <= 0) return null;

		var required:Float = requiredDownloadBytes(expectedZipBytes);
		var free:Float = getFreeSpaceBytes();

		if (free < 0) return null;

		if (free < required) {
			return 'Yetersiz depolama alanı!\n'
				+ 'Gerekli: ~${formatBytes(required)}  ·  Kullanılabilir: ${formatBytes(free)}\n'
				+ '(ZIP + kurulum sonrası alan hesaba katıldı.)';
		}

		return null;
	}

	/**
	 * Çıkarma öncesi alan kontrolü (ZIP zaten inmiş durumda).
	 * ZIP boyutu + tahmini açılmış boyut + güvenlik payı kadar alan arar.
	 */
	public static function checkExtractionSpace(estimatedUnpackedBytes:Float, zipBytes:Float):Null<String> {
		if (estimatedUnpackedBytes <= 0 && zipBytes <= 0) return null;

		var required:Float = zipBytes + estimatedUnpackedBytes + EXTRACT_EXTRA_BUFFER;
		var free:Float = getFreeSpaceBytes();

		if (free < 0) return null;

		if (free < required) {
			return 'Yetersiz depolama alanı!\n'
				+ 'Gerekli: ~${formatBytes(required)}  ·  Kullanılabilir: ${formatBytes(free)}\n'
				+ '(ZIP dosyası + açılmış içerik hesaba katıldı.)';
		}

		return null;
	}

	/**
	 * Tier boyut tutarlılığı uyarısı.
	 * Ör: Lite tier'ındaki bir kayıt 500 MB görünüyorsa katalog hatasıdır.
	 * Bu bir UYARI'dır, engel değildir.
	 */
	public static function checkTierSize(tier:ModpackTier, fileSizeBytes:Float):Null<String> {
		if (tier == null || fileSizeBytes <= 0) return null;

		var hint:Float = tier.getSizeHintBytes();
		if (hint <= 0) return null; // further = sınırsız

		if (fileSizeBytes > hint * TIER_SIZE_TOLERANCE) {
			return '${tier.getLabel()} tierı için beklenen boyut ${tier.getSizeLabel()} iken '
				+ 'katalogda ${formatBytes(fileSizeBytes)} görünüyor. Katalog hatası olabilir.';
		}

		return null;
	}

	// ─────────────────────────────────────────────
	//  Yardımcılar
	// ─────────────────────────────────────────────

	public static function requiredDownloadBytes(expectedZipBytes:Float):Float {
		return expectedZipBytes * DOWNLOAD_MARGIN_FACTOR + EXTRACT_EXTRA_BUFFER;
	}

	public static function formatBytes(bytes:Float):String {
		if (bytes < 1024) return Std.int(bytes) + " B";

		var kb:Float = bytes / 1024;
		if (kb < 1024) return Math.round(kb * 10) / 10 + " KB";

		var mb:Float = kb / 1024;
		if (mb < 1024) return Math.round(mb * 10) / 10 + " MB";

		var gb:Float = mb / 1024;
		return Math.round(gb * 100) / 100 + " GB";
	}

	// ─────────────────────────────────────────────
	//  Android (JNI)
	// ─────────────────────────────────────────────

	#if android
	static var _jniReady:Bool = false;
	static var _getExternalStorageDir:Null<Dynamic> = null;
	static var _getDataDir:Null<Dynamic> = null;
	static var _fileGetFreeSpace:Null<Dynamic> = null;

	static function androidFreeSpace():Float {
		try {
			jniInit();

			var file:Dynamic = null;
			if (_getExternalStorageDir != null) {
				try { file = _getExternalStorageDir(); } catch (_) {}
			}
			if (file == null && _getDataDir != null) {
				try { file = _getDataDir(); } catch (_) {}
			}
			if (file == null || _fileGetFreeSpace == null) return -1;

			var space:Dynamic = _fileGetFreeSpace(file);
			var parsed:Float = Std.parseFloat(Std.string(space));

			return Math.isNaN(parsed) ? -1 : parsed;
		} catch (e:Dynamic) {
			trace('[StorageGuard] Boş alan okunamadı: ${Std.string(e)}');
			return -1;
		}
	}

	static function jniInit():Void {
		if (_jniReady) return;
		_jniReady = true;

		try {
			if (_getExternalStorageDir == null)
				_getExternalStorageDir = lime.system.JNI.createStaticMethod(
					"android/os/Environment", "getExternalStorageDirectory", "()Ljava/io/File;"
				);

			if (_getDataDir == null)
				_getDataDir = lime.system.JNI.createStaticMethod(
					"android/os/Environment", "getDataDirectory", "()Ljava/io/File;"
				);

			if (_fileGetFreeSpace == null)
				// lime'da sadece createStaticMethod var; 4. parametre isStatic=false
				// olursa INSTANCE method döner ve çağrı (obj, args...) alır.
				_fileGetFreeSpace = lime.system.JNI.createStaticMethod(
					"java/io/File", "getFreeSpace", "()J", false
				);
		} catch (e:Dynamic) {
			trace('[StorageGuard] JNI init hatası: ${Std.string(e)}');
		}
	}
	#end
}

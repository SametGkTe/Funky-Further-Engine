package backend.modpack;

class StorageGuard {

	public static final DOWNLOAD_MARGIN_FACTOR:Float = 2.2;

	public static final EXTRACT_EXTRA_BUFFER:Float = 64 * 1024 * 1024;

	public static final TIER_SIZE_TOLERANCE:Float = 1.25;

	public static var DEBUG_OVERRIDE_FREE_SPACE:Null<Float> = null;

	public static function getFreeSpaceBytes():Float {
		if (DEBUG_OVERRIDE_FREE_SPACE != null)
			return DEBUG_OVERRIDE_FREE_SPACE;

		#if android
		return androidFreeSpace();
		#else
		return -1;
		#end
	}

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

	public static function checkTierSize(tier:ModpackTier, fileSizeBytes:Float):Null<String> {
		if (tier == null || fileSizeBytes <= 0) return null;

		var hint:Float = tier.getSizeHintBytes();
		if (hint <= 0) return null;

		if (fileSizeBytes > hint * TIER_SIZE_TOLERANCE) {
			return '${tier.getLabel()} tierı için beklenen boyut ${tier.getSizeLabel()} iken '
				+ 'katalogda ${formatBytes(fileSizeBytes)} görünüyor. Katalog hatası olabilir.';
		}

		return null;
	}

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

				_fileGetFreeSpace = lime.system.JNI.createStaticMethod(
					"java/io/File", "getFreeSpace", "()J", false
				);
		} catch (e:Dynamic) {
			trace('[StorageGuard] JNI init hatası: ${Std.string(e)}');
		}
	}
	#end
}

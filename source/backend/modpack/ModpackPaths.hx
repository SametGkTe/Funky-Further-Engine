package backend.modpack;

import haxe.io.Path;
import mobile.backend.StorageUtil;

class ModpackPaths {
	public static inline function getRootDirectory():String {
		return normalizeDir(StorageUtil.getStorageRootDirectory());
	}

	public static inline function getModsDirectory():String {
		return normalizeDir(StorageUtil.getModsDirectory());
	}

	public static inline function getCacheDirectory():String {
		return normalizeDir(StorageUtil.getModpackCacheDirectory());
	}

	public static inline function getDownloadDirectory():String {
		return normalizeDir(StorageUtil.getModpackDownloadDirectory());
	}

	public static inline function getTempDirectory():String {
		return normalizeDir(StorageUtil.getModpackTempDirectory());
	}

	public static inline function getInstalledDirectory():String {
		return normalizeDir(StorageUtil.getModpackInstalledDirectory());
	}

	public static inline function getTempPackDirectory(packId:String):String {
		return normalizeDir(Path.join([getTempDirectory(), packId]));
	}

	public static inline function getInstalledManifestPath(packId:String):String {
		return Path.join([getInstalledDirectory(), packId + ".json"]);
	}

	public static inline function getDownloadedZipPath(fileName:String):String {
		return Path.join([getDownloadDirectory(), fileName]);
	}

	public static inline function ensureDirectories():Void {
		StorageUtil.ensureModpackDirectories();
	}

	static function normalizeDir(path:String):String {
		if (path == null || path.length == 0) return "./";

		var normalized = Path.normalize(path);
		normalized = StringTools.replace(normalized, "\\", "/");

		if (!StringTools.endsWith(normalized, "/"))
			normalized += "/";

		return normalized;
	}
}

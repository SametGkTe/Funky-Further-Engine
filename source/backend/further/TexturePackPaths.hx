package backend.further;

import haxe.io.Path;
import mobile.backend.StorageUtil;

/**
 * Texture Pack dizinleri — mods/ klasöründen tamamen bağımsız global konum.
 * Kalıp: backend/modpack/ModpackPaths ile aynıdır.
 */
class TexturePackPaths
{
	/** <storageRoot>/further/texturepacks/ */
	public static function getPacksDirectory():String
	{
		return normalizeDir(Path.join([StorageUtil.getStorageRootDirectory(), 'further', 'texturepacks']));
	}

	/** Yığın yapılandırması (sıra + açık/kapalı). */
	public static inline function getStackConfigPath():String
	{
		return getPacksDirectory() + 'texturepacks.json';
	}

	public static function ensureDirectories():Void
	{
		StorageUtil.ensureDirectory(getPacksDirectory());
	}

	public static function normalizeDir(path:String):String
	{
		if (path == null || path.length == 0) return './';

		var normalized = Path.normalize(path);
		normalized = StringTools.replace(normalized, '\\', '/');

		if (!StringTools.endsWith(normalized, '/'))
			normalized += '/';
		return normalized;
	}
}

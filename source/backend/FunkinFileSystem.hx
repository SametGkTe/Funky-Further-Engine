package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
import openfl.utils.Assets;

/**
 * CNE HScript portu için basit dosya sistemi yardımcısı.
 * Psych Extended Online'daki FunkinFileSystem'ın Further'a uyarlanmış sürümü.
 */
class FunkinFileSystem
{
	public static function exists(path:String):Bool
	{
		if (path == null) return false;
		#if sys
		if (FileSystem.exists(path)) return true;
		#end
		return Assets.exists(path);
	}

	public static function getText(path:String):String
	{
		if (path == null) return null;
		#if sys
		if (FileSystem.exists(path))
		{
			try { return File.getContent(path); } catch (e:Dynamic) {}
		}
		#end
		try { return Assets.getText(path); } catch (e:Dynamic) {}
		return null;
	}

	public static function readDirectory(path:String):Array<String>
	{
		#if sys
		if (path != null && FileSystem.exists(path) && FileSystem.isDirectory(path))
			return FileSystem.readDirectory(path);
		#end
		return [];
	}
}

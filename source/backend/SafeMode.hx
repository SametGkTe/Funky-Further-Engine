package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

/**
 * Further Engine güvenli mod yaşam döngüsü.
 *
 * Güvenli mod; komut satırı, tek kullanımlık bayrak dosyası veya açılışta SHIFT
 * basılı tutularak etkinleştirilir. Etkinken hiçbir mod dizini yüklenmez.
 */
class SafeMode
{
	public static var active(default, null):Bool = false;
	public static var pendingNotice:Bool = false;
	static var childProcess:Dynamic;

	public static function detectPersistentRequest():Bool
	{
		#if sys
		try
		{
			if (Sys.args().indexOf('--safe-mode') != -1)
			{
				activate();
				return true;
			}

			var flag = getFlagPath();
			if (FileSystem.exists(flag))
			{
				try FileSystem.deleteFile(flag) catch (_:Dynamic) {}
				activate();
				return true;
			}
		}
		catch (e:Dynamic)
		{
			trace('[SafeMode] Açılış isteği okunamadı: $e');
		}
		#end
		return false;
	}

	public static function activate():Void
	{
		active = true;
		pendingNotice = true;
		Mods.currentModDirectory = '';
	}

	public static function consumeNotice():Bool
	{
		if (!pendingNotice) return false;
		pendingNotice = false;
		return true;
	}

	/** Bir sonraki açılış için güvenli mod bayrağı yazar. */
	public static function requestNextLaunch():Bool
	{
		#if sys
		try
		{
			File.saveContent(getFlagPath(), 'Further Engine safe mode\n');
			return true;
		}
		catch (e:Dynamic)
		{
			trace('[SafeMode] Bayrak yazılamadı: $e');
		}
		#end
		return false;
	}

	/**
	 * Masaüstünde yeni süreci başlatır. Mobilde bayrak yazılır; kullanıcı oyunu
	 * yeniden açtığında güvenli mod otomatik olarak etkinleşir.
	 */
	public static function restart():Bool
	{
		if (!requestNextLaunch()) return false;

		#if desktop
		try
		{
			childProcess = new Process(Sys.programPath(), []);
			return true;
		}
		catch (e:Dynamic)
		{
			trace('[SafeMode] Yeniden başlatma başarısız: $e');
			return false;
		}
		#elseif mobile
		return false;
		#else
		return false;
		#end
	}

	#if sys
	static function getFlagPath():String
	{
		var root:String = #if android StorageUtil.getExternalStorageDirectory() #else Sys.getCwd() #end;
		if (root == null || root.length == 0) root = Sys.getCwd();
		if (!StringTools.endsWith(root, '/') && !StringTools.endsWith(root, '\\')) root += '/';
		return root + '.further-safe-mode';
	}
	#end
}

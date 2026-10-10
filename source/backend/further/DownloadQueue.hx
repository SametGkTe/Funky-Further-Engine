package backend.further;

import backend.modpack.DownloadManager;
import backend.modpack.ModpackPaths;
import haxe.io.Path;

/**
 * Arka plan indirme kuyruğu — state geçişlerinden ETKİLENMEZ.
 * DownloadManager'ın thread'li akışını kullanır; iş parçacığı → ana iş parçacığı
 * haberleşmesi pushMain()/poll() ile yapılır (Flixel/OpenFL thread-safe değildir).
 *
 * Durumlar: queued → downloading → installing → done | error | cancelled
 * kind: 'mod' | 'texturepack' | 'extensionpack' | 'file'
 */
typedef DLItem =
{
	var id:Int;
	var title:String;
	var url:String;
	var fileName:String;
	var savePath:String;
	var kind:String;
	var state:String;
	var percent:Float;
	var speed:Float;
	var sizeText:String;
	var status:String;
	var error:String;
}

class DownloadQueue
{
	public static var items:Array<DLItem> = [];

	/** Büyük durum değişimlerinde (kurulum bitti, hata vs.) çağrılır. */
	public static var listeners:Array<Void->Void> = [];

	static inline var MAX_ACTIVE:Int = 2;

	static var nextId:Int = 1;
	static var activeCount:Int = 0;
	static var managers:Map<Int, DownloadManager> = new Map();

	static var pending:Array<Void->Void> = [];
	static var majorDirty:Bool = false;
	#if target.threaded
	static var mutex:sys.thread.Mutex = null;
	#end

	/** İş parçacığından güvenli bildirim kuyruğu. */
	public static function pushMain(fn:Void->Void, major:Bool = false):Void
	{
		#if target.threaded
		if (mutex == null)
			mutex = new sys.thread.Mutex();
		mutex.acquire();
		pending.push(fn);
		if (major)
			majorDirty = true;
		mutex.release();
		#else
		pending.push(fn);
		if (major)
			majorDirty = true;
		#end
	}

	/** Ana iş parçacığından her kare çağrılır (DownloadHUD ENTER_FRAME). */
	public static function poll():Void
	{
		while (true)
		{
			var fn:Void->Void = null;
			#if target.threaded
			if (mutex == null)
				mutex = new sys.thread.Mutex();
			mutex.acquire();
			if (pending.length > 0)
				fn = pending.shift();
			mutex.release();
			#else
			if (pending.length > 0)
				fn = pending.shift();
			#end
			if (fn == null)
				break;
			fn();
		}

		pump();

		if (majorDirty)
		{
			majorDirty = false;
			for (l in listeners)
				if (l != null)
					l();
		}
	}

	public static function addListener(fn:Void->Void):Void
	{
		if (fn != null && !listeners.contains(fn))
			listeners.push(fn);
	}

	public static function removeListener(fn:Void->Void):Void
	{
		listeners.remove(fn);
	}

	public static function enqueue(title:String, url:String, fileName:String, kind:String, ?sizeText:String):DLItem
	{
		ModpackPaths.ensureDirectories();
		if (fileName == null || fileName.length == 0)
			fileName = 'download_$nextId.zip';
		fileName = sanitizeName(fileName);

		var item:DLItem = {
			id: nextId++,
			title: title,
			url: url,
			fileName: fileName,
			savePath: Path.join([ModpackPaths.getDownloadDirectory(), fileName]),
			kind: (kind == null) ? 'file' : kind,
			state: 'queued',
			percent: 0,
			speed: 0,
			sizeText: (sizeText != null) ? sizeText : '',
			status: 'SIRADA',
			error: ''
		};
		items.push(item);
		majorDirty = true;
		return item;
	}

	public static function cancel(id:Int):Void
	{
		var item:DLItem = find(id);
		if (item == null)
			return;
		if (item.state == 'downloading')
		{
			var mgr:DownloadManager = managers.get(id);
			if (mgr != null)
				mgr.cancel();
		}
		item.state = 'cancelled';
		item.status = 'DURDURULDU';
		item.speed = 0;
		majorDirty = true;
	}

	public static function retry(id:Int):Void
	{
		var item:DLItem = find(id);
		if (item == null)
			return;
		if (item.state == 'downloading' || item.state == 'installing' || item.state == 'queued')
			return;
		item.state = 'queued';
		item.percent = 0;
		item.speed = 0;
		item.error = '';
		item.status = 'SIRADA';
		majorDirty = true;
	}

	public static function remove(id:Int):Void
	{
		var item:DLItem = find(id);
		if (item == null)
			return;
		if (item.state == 'downloading')
			cancel(id);
		items.remove(item);
		majorDirty = true;
	}

	public static function clearFinished():Void
	{
		var i:Int = 0;
		while (i < items.length)
		{
			var s:String = items[i].state;
			if (s == 'done' || s == 'error' || s == 'cancelled')
				items.splice(i, 1);
			else
				i++;
		}
		majorDirty = true;
	}

	public static function activeTotal():Int
	{
		var n:Int = 0;
		for (it in items)
			if (it.state == 'downloading' || it.state == 'installing' || it.state == 'queued')
				n++;
		return n;
	}

	static function find(id:Int):DLItem
	{
		for (it in items)
			if (it.id == id)
				return it;
		return null;
	}

	static function pump():Void
	{
		if (activeCount >= MAX_ACTIVE)
			return;
		for (item in items)
		{
			if (activeCount >= MAX_ACTIVE)
				break;
			if (item.state != 'queued')
				continue;
			startDownload(item);
		}
	}

	static function startDownload(item:DLItem):Void
	{
		activeCount++;
		item.state = 'downloading';
		item.status = 'INDIRILIYOR';
		item.percent = 0;
		majorDirty = true;

		var mgr:DownloadManager = new DownloadManager();
		managers.set(item.id, mgr);

		mgr.smartDownload(item.url, item.savePath, {
			onProgress: function(p:DownloadProgress)
			{
				var id:Int = item.id;
				var pct:Float = p.percent;
				var spd:Float = p.speed;
				var msg:String = '';
				if (p.totalBytes > 0)
					msg = fmtMB(p.downloadedBytes) + ' / ' + fmtMB(p.totalBytes);
				pushMain(function()
				{
					var it:DLItem = find(id);
					if (it == null || it.state != 'downloading')
						return;
					it.percent = pct;
					it.speed = spd;
					it.sizeText = msg;
				});
			},
			onComplete: function(path:String)
			{
				pushMain(function()
				{
					var it:DLItem = find(item.id);
					activeCount--;
					managers.remove(item.id);
					if (it == null)
						return;
					if (it.state == 'cancelled')
						return;
					it.percent = 100;
					it.speed = 0;
					it.state = 'installing';
					it.status = 'KURULUYOR';
					majorDirty = true;
					startInstall(it);
				}, true);
			},
			onError: function(msg:String)
			{
				pushMain(function()
				{
					var it:DLItem = find(item.id);
					activeCount--;
					managers.remove(item.id);
					if (it == null || it.state == 'cancelled')
						return;
					it.state = 'error';
					it.error = msg;
					it.status = 'HATA';
					it.speed = 0;
					majorDirty = true;
				}, true);
			},
			onCancelled: function()
			{
				pushMain(function()
				{
					var it:DLItem = find(item.id);
					activeCount--;
					managers.remove(item.id);
					if (it != null && it.state != 'cancelled')
					{
						it.state = 'cancelled';
						it.status = 'DURDURULDU';
						majorDirty = true;
					}
				}, true);
			}
		});
	}

	static function startInstall(item:DLItem):Void
	{
		var ext:String = item.fileName.toLowerCase();
		var isZip:Bool = StringTools.endsWith(ext, '.zip');

		if (item.kind == 'file' || !isZip)
		{
			// Yalnız indir: 7z/rar/7zz otomatik kurulumu desteklenmiyor (yalnız .zip)
			item.state = 'done';
			if (!isZip && item.kind != 'file')
				item.status = 'INDIRILDI (7z/rar kurulumu desteklenmiyor)';
			else
				item.status = 'INDIRILDI';
			majorDirty = true;
			return;
		}

		var expectedMd5:String = untyped item.md5; // yoksa null
		if (expectedMd5 == null)
			expectedMd5 = Reflect.field(item, 'md5');

		QuickModInstaller.installZip(item.savePath, item.kind, expectedMd5,
			function(msg:String)
			{
				pushMain(function()
				{
					var it:DLItem = find(item.id);
					if (it != null && it.state == 'installing')
						it.status = msg;
				});
			},
			function(ok:Bool, result:String)
			{
				pushMain(function()
				{
					var it:DLItem = find(item.id);
					if (it == null)
						return;
					if (ok)
					{
						it.state = 'done';
						it.status = 'KURULDU: ' + result;
						afterInstall(it.kind);
					}
					else
					{
						it.state = 'error';
						it.error = result;
						it.status = 'HATA';
					}
					majorDirty = true;
				}, true);
			});
	}

	static function afterInstall(kind:String):Void
	{
		// ana iş parçacığından çağrılır
		try
		{
			backend.Paths.clearFileExistsCache();
			backend.Paths.invalidateExistsCache();
			if (kind == 'texturepack')
			{
				TexturePackManager.rescan();
				TexturePackManager.applyTheme();
			}
			else if (kind == 'extensionpack')
			{
				ExtensionPackManager.rescan();
			}
			else
			{
				#if MODS_ALLOWED
				backend.Mods.pushGlobalMods();
				#end
			}
		}
		catch (e:Dynamic)
		{
			trace('[DownloadQueue] kurulum sonrası yenileme hatası: ' + Std.string(e));
		}
	}

	static function sanitizeName(name:String):String
	{
		var out:String = StringTools.replace(name, '\\', '_');
		out = StringTools.replace(out, '/', '_');
		out = StringTools.replace(out, '..', '_');
		out = StringTools.replace(out, ':', '_');
		return (out.length > 0) ? out : 'download.zip';
	}

	static function fmtMB(bytes:Float):String
	{
		if (bytes >= 1024 * 1024)
			return (Math.round(bytes / (1024 * 1024) * 10) / 10) + ' MB';
		if (bytes >= 1024)
			return Math.round(bytes / 1024) + ' KB';
		return Math.round(bytes) + ' B';
	}
}

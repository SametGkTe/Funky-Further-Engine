package backend.fs;

#if sys
import sys.FileSystem;
#end

/**
 * DİZİN LİSTESİ ÖNBELLEĞİ — forkun TEK dosya sistemi hızlandırma katmanı.
 *
 * NEDEN VAR?
 *  `sys.FileSystem.exists()` / `isDirectory()` her çağrıda işletim sistemine iner.
 *  Android'de depolama EXTERNAL_PE (/storage/emulated/0/...) olduğunda bu yollar
 *  FUSE üzerinden geçer: tek bir "var mı?" ~1-8 ms. Android/data altında ise
 *  doğrudan ext4 (~0.03 ms). Bu yüzden aynı kod harici depolamada 100 kata kadar
 *  yavaş çalışıyor.
 *
 *  Menüler tek bir açılışta binlerce böyle sorgu yapıyor (hafta taraması, V-Slice
 *  şarkı-klasörü aramaları, asset çözümleme). Çözüm: her dizini oturumda BİR kez
 *  listele (readdir), tüm "var mı?" sorularını bellekten yanıtla.
 *
 * GÜVENLİK
 *  - readdir başarısız olursa (izin / SAF / yol yok) ham `sys.FileSystem`'a düşer,
 *    yani davranış eskisiyle aynı kalır.
 *  - `ClientPrefs.data.fastFS` false ise tamamen devre dışı (eski davranış).
 *  - cpp'de yükleme thread'leri için mutex (Haxe Map eşzamanlı erişimde çöker).
 *
 * KULLANIM
 *  DirCache.list(dir)                 -> dizin içeriği
 *  DirCache.has(dir, "file.json")     -> belirli isim var mı
 *  DirCache.hasPath("mods/X/a.json")  -> tam yol var mı
 *  DirCache.isDir(path)               -> dizin mi
 *  DirCache.filesWithExt(dir, ".json")-> uzantıya göre filtre
 *  DirCache.invalidate(dir | null)    -> değişiklik sonrası tazele
 */
class DirCache
{
	#if sys
	static inline var TTL_DESKTOP:Float = 20.0;
	static inline var TTL_ANDROID:Float = 90.0;
	static inline var MAX_ENTRIES:Int = 8192;
	#end

	/** Önbellek açık mı? `ClientPrefs.data.fastFS` ile senkron tutulur. */
	public static var enabled:Bool = true;

	// Ölçüm sayaçları (DirCache.stats())
	public static var readdirCount:Int = 0;
	public static var statCount:Int = 0;
	public static var hits:Int = 0;
	public static var misses:Int = 0;

	#if sys
	static var _cache:Map<String, DirEntry> = new Map();

	// Yükleme thread'leri (loadThreads) aynı anda sorgu atabiliyor.
	#if cpp
	static var _mutex:cpp.vm.Mutex = null;
	static inline function lock():Void
	{
		if (_mutex == null) _mutex = new cpp.vm.Mutex();
		_mutex.acquire();
	}
	static inline function unlock():Void
	{
		if (_mutex != null) _mutex.release();
	}
	#else
	static inline function lock():Void {}
	static inline function unlock():Void {}
	#end

	inline static function ttl():Float
	{
		#if android
		return TTL_ANDROID;
		#else
		return TTL_DESKTOP;
		#end
	}

	inline static function now():Float
	{
		return openfl.Lib.getTimer() / 1000.0;
	}

	// ------------------------------------------------------------------ İÇ ÇEKİRDEK

	/** KİLİT ALINMIŞKEN çağrılır. Gerekirse tazeler, asla kilit almaz. */
	static function entryLocked(dir:String, allowRefresh:Bool):DirEntry
	{
		var key:String = normalize(dir);
		var entry:DirEntry = _cache.get(key);
		var stamp:Float = now();

		var fresh:Bool = (entry != null && entry.stamp > 0 && (stamp - entry.stamp) < ttl());
		if (fresh || !allowRefresh)
			return entry;

		if (entryCountLocked() > MAX_ENTRIES)
			_cache = new Map();

		entry = new DirEntry();
		var names:Array<String> = null;
		if (enabled)
		{
			readdirCount++;
			try
			{
				names = FileSystem.readDirectory(key);
			}
			catch (e:Dynamic)
			{
				names = null;
			}
		}

		entry.listed = (names != null);
		entry.failed = (names == null);
		entry.names = (names != null) ? names : [];
		// Başarısızlık da önbelleğe alınır (negatif önbellek). Aksi halde var
		// olmayan her dizin için her sorguda yeniden readdir denenirdi.
		entry.stamp = stamp;
		_cache.set(key, entry);
		misses++;
		return entry;
	}

	static function entryCountLocked():Int
	{
		var n:Int = 0;
		for (k in _cache.keys()) n++;
		return n;
	}

	/** KİLİT ALINMIŞKEN çağrılır. Büyük/küçük harf duyarlı (Android/Linux). */
	static function hasInEntryLocked(entry:DirEntry, name:String):Bool
	{
		#if windows
		if (entry.lower == null)
		{
			entry.lower = new Map();
			for (n in entry.names)
				if (n != null) entry.lower.set(n.toLowerCase(), n);
		}
		return entry.lower.exists(name.toLowerCase());
		#else
		if (entry.exact == null)
		{
			entry.exact = new Map();
			for (n in entry.names)
				if (n != null) entry.exact.set(n, true);
		}
		return entry.exact.exists(name);
		#end
	}

	// ------------------------------------------------------------------ GENEL API

	/** Dizindeki isimler. Dizin yoksa/okunamıyorsa boş dizi. */
	public static function list(dir:String):Array<String>
	{
		#if sys
		if (dir == null || dir.length == 0) return [];

		// Önbellek kapalıysa doğrudan diske sor.
		if (!enabled)
		{
			readdirCount++;
			try
			{
				var raw:Array<String> = FileSystem.readDirectory(dir);
				return raw != null ? raw : [];
			}
			catch (e:Dynamic)
			{
				return [];
			}
		}

		lock();
		var entry:DirEntry = entryLocked(dir, true);
		var names:Array<String> = (entry != null && entry.names != null) ? entry.names : [];
		unlock();
		return names;
		#else
		return [];
		#end
	}

	/** `dir` içinde `name` var mı? */
	public static function has(dir:String, name:String):Bool
	{
		#if sys
		if (dir == null || name == null || name.length == 0) return false;

		if (!enabled)
		{
			statCount++;
			try
			{
				return FileSystem.exists(joinPath(normalize(dir), name));
			}
			catch (e:Dynamic)
			{
				return false;
			}
		}

		lock();
		var entry:DirEntry = entryLocked(dir, true);
		if (entry != null && entry.failed)
		{
			// Dizin yok/okunamıyor → içindeki dosya da yok sayılır.
			unlock();
			return false;
		}
		var found:Bool = false;
		if (entry != null && entry.listed)
		{
			found = hasInEntryLocked(entry, name);
			if (found) hits++;
		}
		unlock();

		if (entry != null && entry.listed)
			return found;

		// Liste alınamadı → ham kontrol (davranış eskisiyle aynı)
		statCount++;
		try
		{
			return FileSystem.exists(joinPath(normalize(dir), name));
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	/** Tam yol için "var mı?" — parent dizin listesinden yanıtlanır. */
	public static function hasPath(path:String):Bool
	{
		#if sys
		if (path == null || path.length == 0) return false;

		var p:String = normalize(path);
		var idx:Int = p.lastIndexOf('/');
		if (idx <= 0)
		{
			statCount++;
			try
			{
				return FileSystem.exists(p);
			}
			catch (e:Dynamic)
			{
				return false;
			}
		}
		return has(p.substr(0, idx), p.substr(idx + 1));
		#else
		return false;
		#end
	}

	/** Yol bir dizin mi? (sonuç önbellekte tutulur) */
	public static function isDir(path:String):Bool
	{
		#if sys
		if (path == null || path.length == 0) return false;

		if (!enabled)
		{
			statCount++;
			try
			{
				return FileSystem.isDirectory(path);
			}
			catch (e:Dynamic)
			{
				return false;
			}
		}

		var key:String = 'dir:' + normalize(path);
		lock();
		var cached:DirEntry = _cache.get(key);
		if (cached != null && cached.stamp > 0 && (now() - cached.stamp) < ttl())
		{
			var hit:Bool = cached.listed;
			hits++;
			unlock();
			return hit;
		}
		unlock();

		statCount++;
		var res:Bool = false;
		try
		{
			res = FileSystem.isDirectory(path);
		}
		catch (e:Dynamic)
		{
			res = false;
		}

		lock();
		var e2:DirEntry = new DirEntry();
		e2.listed = res;
		e2.names = [];
		e2.stamp = now();
		_cache.set(key, e2);
		unlock();
		return res;
		#else
		return false;
		#end
	}

	/** Dizindeki belirli uzantılı dosyalar (ör. ".json"). */
	public static function filesWithExt(dir:String, ext:String):Array<String>
	{
		var out:Array<String> = [];
		var e:String = ext.toLowerCase();
		for (name in list(dir))
			if (name != null && name.toLowerCase().endsWith(e)) out.push(name);
		return out;
	}

	// ------------------------------------------------------------------ YÖNETİM

	public static function invalidate(?dir:String):Void
	{
		#if sys
		if (dir == null)
		{
			invalidateAll();
			return;
		}
		var key:String = normalize(dir);
		lock();
		_cache.remove(key);
		_cache.remove('dir:' + key);
		unlock();
		#end
	}

	public static function invalidateAll():Void
	{
		#if sys
		lock();
		_cache = new Map();
		unlock();
		#end
	}

	/** Isıtma: menüye girmeden önce sık kullanılan dizinleri listele. */
	public static function prefetch(dirs:Array<String>):Void
	{
		#if sys
		if (dirs == null) return;
		for (d in dirs)
			if (d != null && d.length > 0) list(d);
		#end
	}

	/** Ölçüm: "readdir=12 stat=0 hits=340 misses=12" */
	public static function stats():String
	{
		return 'readdir=$readdirCount stat=$statCount hits=$hits misses=$misses';
	}

	public static function resetStats():Void
	{
		readdirCount = 0;
		statCount = 0;
		hits = 0;
		misses = 0;
	}

	// ------------------------------------------------------------------ YARDIMCI

	inline static function normalize(path:String):String
	{
		var p:String = path.split('\\').join('/');
		while (p.length > 1 && p.charAt(p.length - 1) == '/') p = p.substr(0, p.length - 1);
		return p;
	}

	inline static function joinPath(dir:String, name:String):String
	{
		return (dir.charAt(dir.length - 1) == '/') ? dir + name : dir + '/' + name;
	}
	#else
	public static function list(dir:String):Array<String> return [];
	public static function has(dir:String, name:String):Bool return false;
	public static function hasPath(path:String):Bool return false;
	public static function isDir(path:String):Bool return false;
	public static function filesWithExt(dir:String, ext:String):Array<String> return [];
	public static function invalidate(?dir:String):Void {}
	public static function invalidateAll():Void {}
	public static function prefetch(dirs:Array<String>):Void {}
	public static function stats():String return 'dir-cache disabled';
	public static function resetStats():Void {}
	#end
}

class DirEntry
{
	public var names:Array<String>;
	public var lower:Map<String, String>;
	public var exact:Map<String, Bool>;
	/** readdir başarılı oldu mu? false → ham stat'a düşülür. */
	public var listed:Bool = false;
	/** readdir başarısız oldu (dizin yok veya okunamıyor). */
	public var failed:Bool = false;
	/** 0 = geçersiz (yeniden denenmeli). */
	public var stamp:Float = 0;

	public function new() {}
}

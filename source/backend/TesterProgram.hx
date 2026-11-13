package backend;

import haxe.Json;

/**
 * TESTER PROGRAMI — istemci tarafı.
 *
 * Tek dosya, tek sorumluluk: sunucudan (Supabase) tester durumunu ve tester
 * credits listesini okumak, katılma/ayrılma çağrılarını yapmak.
 *
 * ÖNEMLİ GÜVENLİK NOTU
 *  Bu dosyadaki hiçbir değer "yetki" değildir; sadece görünüm/UX içindir.
 *  Oyun açık kaynak olduğu için `ClientPrefs.data.betaProgram = true` yazan
 *  biri kolayca istemciyi kandırabilir. Gerçek kontrol SUNUCUDA:
 *    - tester_program tablosuna istemci yazamaz (RLS + revoke),
 *    - karar sadece SECURITY DEFINER fonksiyonlarla verilir,
 *    - beta dosyaları private bucket'ta tutulup imzalı URL sunucuda üretilir
 *      (get_beta_build_url), böylece tester olmayan indiremez.
 *  Şema: supabase/migrations/20261020_tester_program.sql
 *
 * KULLANIM
 *   TesterProgram.refresh();                       // durumu sunucudan çek
 *   if (TesterProgram.isTester) ...                // sunucu onayı
 *   TesterProgram.joinProgram(cb);                 // programa katıl
 *   var list = TesterProgram.cachedCredits();      // Credits için (disk cache)
 *   TesterProgram.fetchCredits();                  // arka planda tazele
 */
class TesterProgram
{
	// --- Sunucudan gelen durum ---
	/** unknown | anonymous | none | pending | approved | rejected | left | error */
	public static var status:String = 'unknown';
	/** approved dışındaki durumların sebebi: not_logged_in, account_too_new, ... */
	public static var reason:String = '';
	public static var programOpen:Bool = true;
	public static var autoApprove:Bool = false;
	public static var approvedCount:Int = 0;
	public static var maxTesters:Int = 0;
	public static var emailVerified:Bool = false;
	public static var accountAgeDays:Int = 0;

	public static var lastError:String = '';
	public static var isBusy:Bool = false;
	/** Sunucuya hiç ulaşılamadıysa true (çevrimdışı bilgi gösterimi için). */
	public static var offline:Bool = false;

	static var _credits:Array<TesterCredit> = [];
	static var _creditsStamp:Float = 0;
	static var _statusStamp:Float = 0;
	static var _loadedCache:Bool = false;

	static inline var CREDITS_TTL:Float = 6 * 3600; // 6 saat
	static inline var STATUS_TTL:Float = 10 * 60;   // 10 dakika

	public static inline function isTester():Bool
	{
		return status == 'approved';
	}

	public static inline function isLoggedIn():Bool
	{
		return SupabaseClient.hasToken();
	}

	/** UI'da gösterilecek kısa durum metni. */
	public static function statusLabel():String
	{
		return switch (status)
		{
			case 'approved': 'Onaylı tester';
			case 'pending': 'Onay bekliyor';
			case 'rejected': 'Başvuru reddedildi';
			case 'left': 'Ayrıldı';
			case 'none': 'Kayıtlı değil';
			case 'anonymous': 'Giriş yapılmadı';
			case 'error': 'Sunucuya ulaşılamadı';
			default: 'Bilinmiyor';
		}
	}

	/** Sunucunun "neden uygun değilsin" cevabını okunabilir metne çevirir. */
	public static function reasonLabel():String
	{
		return switch (reason)
		{
			case 'not_logged_in': 'Önce hesabına giriş yapmalısın.';
			case 'email_not_verified': 'E-posta adresini doğrulaman gerekiyor.';
			case 'account_too_new': 'Hesabın çok yeni (' + accountAgeDays + ' gün).';
			case 'program_full': 'Program şu an dolu (' + approvedCount + '/' + maxTesters + ').';
			case 'cooldown': 'Kısa süre önce ayrıldın, tekrar katılmak için bekle.';
			case 'program_closed': 'Programa yeni katılım şu an kapalı.';
			case '': '';
			default: reason;
		}
	}

	// ---------------------------------------------------------------- DURUM ÇEK

	/**
	 * Sunucudan tester durumunu çeker. Önbellek taze ise ağa çıkmaz.
	 * @param cb başarılı mı? (çevrimdışıysa false)
	 */
	public static function refresh(?cb:Bool->Void, force:Bool = false):Void
	{
		if (isBusy)
		{
			if (cb != null) cb(false);
			return;
		}

		if (!isLoggedIn())
		{
			status = 'anonymous';
			reason = 'not_logged_in';
			if (cb != null) cb(false);
			return;
		}

		var stamp:Float = now();
		if (!force && _statusStamp > 0 && (stamp - _statusStamp) < STATUS_TTL && status != 'unknown')
		{
			if (cb != null) cb(true);
			return;
		}

		isBusy = true;
		var token:String = SupabaseClient.getToken();
		SupabaseClient.postAsync('/rest/v1/rpc/tester_status', {}, token, function(httpStatus:Int, data:String)
		{
			isBusy = false;
			if (!_parseStatus(httpStatus, data))
			{
				offline = true;
				if (status == 'unknown') status = 'error';
				if (cb != null) cb(false);
				return;
			}
			offline = false;
			_statusStamp = now();
			syncPrefs();
			fetchCredits(null);
			if (cb != null) cb(true);
		});
	}

	static function _parseStatus(httpStatus:Int, data:String):Bool
	{
		if (httpStatus != 200 || data == null) return false;
		try
		{
			var o:Dynamic = Json.parse(data);
			if (o == null) return false;
			// Supabase tek nesne döndürür; bazı sürümler dizi sarar.
			if (Std.isOfType(o, Array))
			{
				var arr:Array<Dynamic> = cast o;
				o = (arr.length > 0) ? arr[0] : null;
			}
			if (o == null) return false;

			status = str(o.status, 'none');
			reason = str(o.reason, '');
			programOpen = bool(o.program_open, true);
			autoApprove = bool(o.auto_approve, false);
			approvedCount = num(o.approved_count);
			maxTesters = num(o.max_testers);
			emailVerified = bool(o.email_verified, false);
			accountAgeDays = num(o.account_age_days);
			return true;
		}
		catch (e:Dynamic)
		{
			lastError = '' + e;
			return false;
		}
	}

	// -------------------------------------------------------------- KATIL / AYRIL

	public static function joinProgram(?cb:(Bool, String)->Void):Void
	{
		if (!isLoggedIn())
		{
			if (cb != null) cb(false, 'not_logged_in');
			return;
		}
		if (isBusy)
		{
			if (cb != null) cb(false, 'busy');
			return;
		}

		isBusy = true;
		SupabaseClient.postAsync('/rest/v1/rpc/tester_join', {}, SupabaseClient.getToken(), function(s:Int, data:String)
		{
			isBusy = false;
			var err:String = _rpcError(s, data);
			if (err != null)
			{
				if (cb != null) cb(false, err);
				return;
			}
			refresh(function(_) {
				if (cb != null) cb(true, status);
			}, true);
		});
	}

	public static function leaveProgram(?cb:(Bool, String)->Void):Void
	{
		if (!isLoggedIn())
		{
			if (cb != null) cb(false, 'not_logged_in');
			return;
		}
		if (isBusy)
		{
			if (cb != null) cb(false, 'busy');
			return;
		}

		isBusy = true;
		SupabaseClient.postAsync('/rest/v1/rpc/tester_leave', {}, SupabaseClient.getToken(), function(s:Int, data:String)
		{
			isBusy = false;
			_credits = [];
			saveCache();
			refresh(function(_) {
				if (cb != null) cb(_rpcError(s, data) == null, status);
			}, true);
		});
	}

	/** RPC cevabındaki {ok:false,error:"..."} durumunu döndürür, sorun yoksa null. */
	static function _rpcError(httpStatus:Int, data:String):String
	{
		if (httpStatus != 200) return 'http_' + httpStatus;
		try
		{
			var o:Dynamic = Json.parse(data);
			if (o != null && Std.isOfType(o, Array)) o = (cast o : Array<Dynamic>)[0];
			if (o == null) return 'bad_response';
			if (bool(o.ok, false)) return null;
			return str(o.error, 'unknown');
		}
		catch (e:Dynamic)
		{
			return 'parse';
		}
	}

	// ----------------------------------------------------------------- CREDITS

	/** Credits ekranı için: önce disk önbelleğini yükler, tazeyse ağa çıkmaz. */
	public static function fetchCredits(?cb:Array<TesterCredit>->Void, force:Bool = false):Void
	{
		loadCache();

		var stamp:Float = now();
		if (!force && _creditsStamp > 0 && (stamp - _creditsStamp) < CREDITS_TTL)
		{
			if (cb != null) cb(_credits);
			return;
		}

		if (!isLoggedIn()) return; // anon da okuyabilir ama gereksiz istek atmayalım

		// Credits listesi herkese açık RPC; token yine de gönderilir (RLS dostu).
		SupabaseClient.postAsync('/rest/v1/rpc/get_tester_credits', {}, SupabaseClient.getToken(), function(httpStatus:Int, data:String)
		{
			if (httpStatus != 200 || data == null) return;
			try
			{
				var arr:Array<Dynamic> = cast Json.parse(data);
				if (arr == null) return;

				var list:Array<TesterCredit> = [];
				for (item in arr)
				{
					if (item == null) continue;
					var name:String = str(item.credit_name, '');
					if (name.length == 0) continue;
					list.push({
						name: name,
						color: str(item.credit_color, 'FFE7C0'),
						icon: str(item.credit_icon, 'tester')
					});
				}
				_credits = list;
				_creditsStamp = now();
				saveCache();
				if (cb != null) cb(_credits);
			}
			catch (e:Dynamic) {}
		});
	}

	/** Disk önbelleğindeki tester listesi (asenkron iş yapmaz). */
	public static function cachedCredits():Array<TesterCredit>
	{
		loadCache();
		return _credits;
	}

	// ------------------------------------------------------------------ ÖNBELLEK

	static var _cachePath:String = null;

	static function cachePath():String
	{
		if (_cachePath != null) return _cachePath;
		var dir:String = './';
		try
		{
			dir = lime.system.System.applicationStorageDirectory;
		}
		catch (e:Dynamic) {}

		if (dir == null || dir == '') dir = './';
		var last:String = dir.charAt(dir.length - 1);
		if (last != '/' && last != '\\') dir += '/';
		_cachePath = dir + 'tester_cache.json';
		return _cachePath;
	}

	public static function loadCache():Void
	{
		#if sys
		if (_loadedCache) return;
		_loadedCache = true;
		try
		{
			var path:String = cachePath();
			if (!sys.FileSystem.exists(path)) return;
			var o:Dynamic = Json.parse(sys.io.File.getContent(path));
			if (o == null) return;

			_creditsStamp = fnum(o.ts);
			if (o.status != null) status = str(o.status, status);

			var arr:Array<Dynamic> = cast o.credits;
			if (arr != null)
			{
				var list:Array<TesterCredit> = [];
				for (item in arr)
				{
					if (item == null) continue;
					var name:String = str(item.n, '');
					if (name.length == 0) continue;
					list.push({name: name, color: str(item.c, 'FFE7C0'), icon: str(item.i, 'tester')});
				}
				_credits = list;
			}
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function saveCache():Void
	{
		#if sys
		try
		{
			var list:Array<Dynamic> = [];
			for (c in _credits)
				list.push({n: c.name, c: c.color, i: c.icon});

			var o:Dynamic = {
				ts: _creditsStamp,
				status: status,
				credits: list
			};
			sys.io.File.saveContent(cachePath(), Json.stringify(o));
		}
		catch (e:Dynamic) {}
		#end
	}

	// -------------------------------------------------------------- KÜÇÜK YARDIMCI

	/** Sunucu onayını yerel tercihe yansıtır (güncelleme kanalı bunu kullanıyor). */
	static function syncPrefs():Void
	{
		var want:Bool = isTester();
		if (ClientPrefs.data.betaProgram == want) return;
		ClientPrefs.data.betaProgram = want;
		ClientPrefs.saveSettings();
	}

	inline static function now():Float
	{
		return openfl.Lib.getTimer() / 1000.0;
	}

	static inline function str(v:Dynamic, def:String):String
	{
		if (v == null) return def;
		var s:String = Std.string(v);
		return s == 'null' ? def : s;
	}

	static inline function num(v:Dynamic):Int
	{
		if (v == null) return 0;
		var n:Null<Int> = Std.parseInt(Std.string(v));
		if (n == null)
		{
			var f:Null<Float> = Std.parseFloat(Std.string(v));
			return (f == null) ? 0 : Std.int(f);
		}
		return n;
	}

	static inline function fnum(v:Dynamic):Float
	{
		if (v == null) return 0;
		var f:Null<Float> = Std.parseFloat(Std.string(v));
		return (f == null) ? 0 : f;
	}

	static inline function bool(v:Dynamic, def:Bool):Bool
	{
		if (v == null) return def;
		if (Std.isOfType(v, Bool)) return cast v;
		var s:String = Std.string(v).toLowerCase();
		if (s == 'true' || s == '1') return true;
		if (s == 'false' || s == '0') return false;
		return def;
	}
}

typedef TesterCredit =
{
	var name:String;
	var color:String;
	var icon:String;
}

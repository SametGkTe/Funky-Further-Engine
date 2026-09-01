package vslice.compatibility.script;

#if sys
import sys.io.File;
#end

import backend.Mods;
import backend.Paths;
import psychlua.HScript;
#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
#end

/**
 * VSliceScriptLoader — V-Slice (Polymod) modlarındaki `.hxc` / `.hx` script dosyalarını
 * Psych Engine'in mevcut HScript altyapısına yükler.
 *
 * Amaç ve yaklaşım:
 * -----------------
 * Psych'in `PlayState`'i zaten `scripts/` klasöründeki `.hx` dosyalarını yükleyip
 * `hscriptArray`'e atar ve `callOnHScript(funcToCall, args)` ile çağırır. Biz bu
 * mevcut altyapıya **dokunmadan**, V-Slice modlarının `scripts/` klasörlerindeki
 * `.hxc` dosyalarını da aynı listeye ekliyoruz. Böylece `PlayState`'te kapsamlı
 * değişiklik yapmadan flat-function tarzı V-Slice scriptleri çalışır.
 *
 * Çağrı akışı:
 *   1. Etkin V-Slice mod klasörlerini tara (Mods.parseList().enabled + global).
 *   2. Her modun `scripts/*.hxc` ve `scripts/*.hx` dosyalarını bul.
 *   3. Her dosyayı `PlayState.initHScript()` üzerinden yükle (hscriptArray'e eklenir).
 *   4. Mevcut `callOnHScript` mekanizması olayları otomatik dağıtır (onCreate, onUpdate...).
 *
 * DESTEKLENEN ALT KÜME (önemli sınırlama):
 * ----------------------------------------
 * - Çalışan: Düz fonksiyonlar tanımlayan .hxc/.hx dosyaları. Fonksiyon adları Psych'in
 *   callback adlarıyla eşleşmeli (onCreate, onUpdate, onBeatHit, onStepHit, goodNoteHit,
 *   noteMiss, onSongStart, onPause, onResume, onGameOver...). `ScriptEventBridge` bu
 *   eşleştirmeyi belgeler.
 * - Class-tabanlı .hxc dosyaları (`class X extends ...`) ARTIK AYRI KÖPRÜDE:
 *   VSScriptRegistry + Polymod (vslice/scripting/, bkz. docs/VSLICE_HSCRIPT.md).
 *   Bu yükleyici o dosyaları atlar (Iris parse edemez).
 */
class VSliceScriptLoader
{
	/**
	 * Etkin V-Slice modlarının `scripts/` klasörlerini tarayıp `.hxc`/`.hx` scriptlerini
	 * PlayState'in mevcut HScript sistemine yükler. `PlayState.create()` içinde, diğer
	 * script yükleme kodunun olduğu bölümden çağrılmalıdır.
	 */
	public static function loadPlayStateScripts():Void
	{
		#if (HSCRIPT_ALLOWED && MODS_ALLOWED && sys)
		if (PlayState.instance == null) return;

		var dirs:Array<String> = [];

		// Etkin (enabled) modlar + global modlar
		var enabled:Array<String> = Mods.parseList().enabled;
		var global:Array<String> = Mods.getGlobalMods();
		for (d in enabled) if (!dirs.contains(d)) dirs.push(d);
		for (d in global) if (!dirs.contains(d)) dirs.push(d);

		for (modDir in dirs)
		{
			var scriptsPath:String = Paths.mods(modDir + '/scripts/');
			if (scriptsPath == null || !FileSystem.exists(scriptsPath)) continue;

			// Sıralı ve deterministik olsun
			var files:Array<String> = CoolUtil.sortAlphabetically(Paths.readDirectory(scriptsPath));
			for (file in files)
			{
				var lower:String = file.toLowerCase();
				if (!lower.endsWith('.hxc') && !lower.endsWith('.hx')) continue;

				var fullPath:String = haxe.io.Path.join([scriptsPath, file]);
				loadScript(fullPath);
			}
		}
		#end
	}

	/**
	 * Tek bir script dosyasını PlayState'in mevcut HScript sistemine yükler.
	 * Zaten yüklüyse atlar. Hata olursa sessizce loglar (oyunu çökertmez).
	 *
	 * NOT (v2): Class-tabanlı script'ler (`class X extends ... { ... }`)
	 * Iris'e yüklenmez — onlar VSScriptRegistry/Polymod köprüsüne kaydedilir
	 * (bkz. docs/VSLICE_HSCRIPT.md). Burada yalnızca düz fonksiyon script'leri yüklenir.
	 */
	public static function loadScript(path:String):Bool
	{
		#if (HSCRIPT_ALLOWED && MODS_ALLOWED && sys)
		if (path == null || !FileSystem.exists(path)) return false;

		// Class-tabanlı .hxc/.hx dosyaları Polymod köprüsüne aittir (startup'ta
		// VSScriptRegistry tarafından kaydedildiler). Iris bunları parse edemez.
		#if POLYMOD_ALLOWED
		var text:String = null;
		try { text = File.getContent(path); } catch (e:Dynamic) {}
		if (text != null && text.indexOf('class ') >= 0)
		{
			trace('[VSliceScriptLoader] Class-tabanli script atlandi (VSScriptRegistry yonetir): $path');
			return true;
		}
		#end

		// Iris, aynı yolu tekrar yüklemesin (mevcut davranış).
		if (Iris.instances.exists(path)) return true;

		try
		{
			PlayState.instance.initHScript(path);
			return true;
		}
		catch (e:Dynamic)
		{
			trace('[VSliceScriptLoader] Script yüklenemedi: $path — $e');
			return false;
		}
		#end
		return false;
	}

	/**
	 * Belirli bir event'i tüm yüklü scriptlere dağıtır.
	 * V-Slice ScriptEventType adını Psych callback'ine çevirip `callOnHScript` çağırır.
	 * (Opsiyonel: flat-function scriptleri zaten callOnHScript ile çağrılıyorsa gerekmez.)
	 */
	public static function dispatchEvent(eventName:String, args:Array<Dynamic> = null):Dynamic
	{
		#if (HSCRIPT_ALLOWED && MODS_ALLOWED)
		if (PlayState.instance == null) return null;
		var callback:String = ScriptEventBridge.eventToCallback(eventName);
		if (callback == null) return null;
		return PlayState.instance.callOnHScript(callback, args);
		#end
		return null;
	}
}

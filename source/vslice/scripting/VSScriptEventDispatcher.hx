package vslice.scripting;

/**
 * VSScriptEventDispatcher — V-Slice tarzı script olaylarının dağıtıcısı.
 *
 * FNF'de script'ler `onCreate(event)`, `onBeatHit(event)`, `onNoteHit(event)`
 * gibi metodları override eder. Polymod köprüsünde script'in tanımladığı her
 * fonksiyon `scriptCall` ile çağrılabilir; `scriptHas` ile önceden yoklanır.
 * Bu sınıf o iki çağrıyı güvenli şekilde paketler.
 *
 * Olay objesi basit bir yapıdır: { type: 'onBeatHit', cancelled: false, data: ... }
 * Script tarafında `event.type`, `event.data` alanları kullanılabilir.
 */
class VSScriptEventDispatcher
{
	/** Olay objesi üretir. `data` opsiyonel (nota, beat numarası, vb.). */
	public static function make(type:String, ?data:Dynamic):Dynamic
	{
		var ev:Dynamic = {type: type, cancelled: false, data: data};
		// FNF uyumluluğu: nota olaylarında event.note da olsun.
		if (data != null && Std.isOfType(data, objects.Note))
			ev.note = data;
		return ev;
	}

	/**
	 * Tek bir hedefe olay gönderir. Hedef scripted değilse veya script'te
	 * o fonksiyon yoksa sessizce false döner.
	 */
	public static function dispatch(target:Dynamic, funcName:String, ?event:Dynamic = null):Bool
	{
		if (target == null || funcName == null) return false;

		var t:IHScriptedEvents = null;
		try { t = cast target; } catch (e:Dynamic) { return false; }
		if (t == null) return false;

		try
		{
			if (!t.scriptHas(funcName)) return false;
			t.scriptCall(funcName, event == null ? [] : [event]);
			return true;
		}
		catch (e:Dynamic)
		{
			trace('[VSScriptEventDispatcher] $funcName hatasi: $e');
			return false;
		}
	}

	/**
	 * PlayState'in tipik hedeflerine (dad, boyfriend, gf, şarkı script'i,
	 * module'ler + tüm stage'ler) olayı yayar ve OLay objesini DÖNDÜRÜR
	 * (script'ler `event.cancelled = true` yapabilir — onPause gibi yerlerde
	 * kontrol edilir). `data` opsiyonel; olayın `data` alanına konur.
	 */
	public static function dispatchPlayState(funcName:String, ?data:Dynamic = null):Dynamic
	{
		#if POLYMOD_ALLOWED
		var event:Dynamic = make(funcName, data);
		var state = states.PlayState.instance;
		if (state == null) return event;

		dispatch(state.dad, funcName, event);
		dispatch(state.boyfriend, funcName, event);
		dispatch(state.gf, funcName, event);
		if (state.vsSongScript != null)
			dispatch(state.vsSongScript, funcName, event);
		dispatchModules(funcName, event);
		dispatchStages(state, funcName, event);
		return event;
		#else
		return null;
		#end
	}

	/** Module script'lerine yayar (active = false olanlar atlanır). */
	public static function dispatchModules(funcName:String, ?event:Dynamic = null):Void
	{
		#if POLYMOD_ALLOWED
		if (event == null) event = make(funcName);
		var mods = VSScriptRegistry.modules;
		if (mods == null) return;
		for (m in mods)
		{
			if (m == null || !m.active) continue;
			dispatch(m, funcName, event);
		}
		#end
	}

	/** Sahne script'lerine yayar (scripted stage'ler de dahil). */
	public static function dispatchStages(state:states.PlayState, funcName:String, ?event:Dynamic = null):Void
	{
		if (state == null) return;
		if (event == null) event = make(funcName);
		try
		{
			for (stage in state.stages)
				if (stage != null && stage.exists && stage.active)
					dispatch(stage, funcName, event);
		}
		catch (e:Dynamic)
		{
			trace('[VSScriptEventDispatcher] stage dispatch hatasi: $e');
		}
	}
}

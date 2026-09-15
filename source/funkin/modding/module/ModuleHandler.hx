package funkin.modding.module;

/**
 * FNF uyumluluk shim'i (ModuleHandler) — v20: gerçek arama.
 *
 * Further'da modüller VSScriptRegistry.modules listesinde tutulur ve yaşam
 * döngüsü VSScriptEventDispatcher üzerinden yürür. Resmî FNF'deki
 * `ModuleHandler.getModule('X')` çağrısı, script modülünü moduleId ile bulur
 * (örn. NoteSwapEvent.hxc → getModule('SwappingNotestyles').scriptCall(...)).
 */
@:noCustomClass
class ModuleHandler
{
	/** Resmî: moduleId'ye göre kayıtlı script modülünü döner (yoksa null). */
	public static function getModule(id:String):Dynamic
	{
		if (id == null) return null;
		try
		{
			for (m in vslice.scripting.VSScriptRegistry.modules)
			{
				if (m == null) continue;
				if (m.moduleId == id) return m;
			}
		}
		catch (e:Dynamic) {}
		return null;
	}

	/** Resmî: modül listesi — Further kayıtlı modüllerini döner. */
	public static function getModules():Array<Dynamic>
	{
		var out:Array<Dynamic> = [];
		try
		{
			for (m in vslice.scripting.VSScriptRegistry.modules)
				if (m != null) out.push(m);
		}
		catch (e:Dynamic) {}
		return out;
	}

	/* Resmî API yüzeyi — Further'da modül yaşam döngüsü registry'de; no-op. */
	public static function activateModule(module:Dynamic):Void {}
	public static function deactivateModule(module:Dynamic):Void {}
	public static function callScriptEvent(event:Dynamic):Void
	{
		// Resmî: olayı tüm modüllere yay. Further köprüsü: dispatcher.
		try
		{
			var funcName:String = 'onScriptEvent';
			vslice.scripting.VSScriptEventDispatcher.dispatchModules(funcName, event);
		}
		catch (e:Dynamic) {}
	}
}

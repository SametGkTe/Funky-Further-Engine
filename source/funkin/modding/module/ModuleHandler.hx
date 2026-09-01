package funkin.modding.module;

/**
 * FNF uyumluluk shim'i (ModuleHandler) - MINIMAL.
 * Further'da module yasam dongusu VSScriptEventDispatcher uzerinden yurur.
 * FNF tarzi ModuleHandler.getModule(id) cagrisi icin null doner (v1).
 */
@:noCustomClass
class ModuleHandler
{
	public static function getModule(id:String):Dynamic
	{
		return null;
	}
}

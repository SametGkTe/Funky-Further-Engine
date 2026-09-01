package funkin.modding.events;

/**
 * FNF uyumluluk shim'i (CountdownScriptEvent).
 * Sayım (countdown) başlarken/bitince tetiklenen olay. Şimdilik taban
 * davranışı taşır; PlayState sayım noktalarına dispatch eklenebilir.
 */
@:noCustomClass
class CountdownScriptEvent extends ScriptEvent
{
	public function new()
	{
		super();
	}
}

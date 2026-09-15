package funkin.play.stage;

import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;

/**
 * V-Slice/FNF uyumluluk shim'i (StageProp) — v17 (Faz 3).
 *
 * Resmî v0.8.7: `class StageProp extends FunkinSprite implements IStateStageProp`.
 * Sahneye eklenen danssız/statik objelerin taban sınıfı. Script'ler
 * `class X extends StageProp` türetebilir veya `new StageProp()` kurabilir.
 */
@:noCustomClass
class StageProp extends funkin.graphics.FunkinSprite
{
	/** Resmî FNF: prop'un dahili adı. */
	public var name:String = '';

	public function new()
	{
		super();
	}

	/** Resmî FNF: prop sahneye eklendiğinde çağrılır. */
	public function onAdd(event:ScriptEvent):Void {}

	/* IStateStageProp / IScriptedClass yaşam döngüsü no-op'ları (super güvenliği). */
	public function onScriptEvent(event:ScriptEvent):Void {}
	public function onCreate(event:ScriptEvent):Void {}
	public function onDestroy(event:ScriptEvent):Void {}
	public function onUpdate(event:UpdateScriptEvent):Void {}
}

package vslice.scripting;

/**
 * Script olay objesi (FNF ScriptEvent benzeri).
 *
 * v15.6: Eskiden anonim yapi {type, cancelled, data} kullaniliyordu;
 * script'ler `event.cancel()` CAGIRIR (FNF kalibi) ama anonim nesnede
 * metot olamazdi. Artik gercek sinif: cancel() calisir, beat/step alanlari
 * onBeatHit/onStepHit icin doldurulur, note alani nota olaylarinda
 * VSNoteProxy tasir (FNF'nin noteData.getMustHitNote() API'si icin).
 */
class VScriptEvent
{
	public var type:String;
	public var cancelled:Bool = false;
	public var data:Dynamic;
	public var note:Dynamic = null;
	public var beat:Null<Int> = null;
	public var step:Null<Int> = null;

	public function new(type:String, ?data:Dynamic)
	{
		this.type = type;
		this.data = data;
	}

	/** FNF: event.cancel() — olayi iptal eder (onPause/onCountdownStart gibi). */
	public function cancel():Void
	{
		cancelled = true;
	}
}

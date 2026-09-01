package funkin.modding.module;

/**
 * V-Slice/FNF uyumluluk shim'i (Module).
 *
 * FNF'de Module, state'ler arası yaşayan, tüm olayları alan scripted
 * sınıftır: `class X extends funkin.modding.module.Module { ... }`.
 * Further'da hafif bir taşıyıcıdır; olaylar PlayState/Dispatcher üzerinden
 * yayılır (bkz. docs/VSLICE_HSCRIPT.md). `active = false` yapılırsa olay
 * almaz (FNF ile aynı).
 *
 * NOT: kurucu imzası FNF ile aynıdır: new(moduleId, priority = 1000).
 * Motor, script'i scriptInit(cls, cls, 1000) ile kurar.
 */
@:noCustomClass
class Module
{
	public var moduleId:String = 'UNKNOWN';
	public var priority:Int = 1000;
	public var active:Bool = true;

	// NOT: FNF script'leri `super('id')` (tek argüman) veya
	// `super('id', 10)` yazabilir; her ikisi de desteklenir.
	public function new(moduleId:String, priority:Int = 1000)
	{
		this.moduleId = moduleId;
		this.priority = priority;
	}

	public function toString():String
	{
		return 'Module($moduleId)';
	}

	// ---- V-Slice script olayları (script'ler override edip super.x() çağırabilir) ----
	public function onCreate(event:Dynamic):Void {}
	public function onCreatePost(event:Dynamic):Void {}
	public function onDestroy(event:Dynamic):Void {}
	public function onUpdate(event:Dynamic):Void {}
	public function onUpdatePost(event:Dynamic):Void {}
	public function onCountdownStart(event:Dynamic):Void {}
	public function onCountdownStep(event:Dynamic):Void {}
	public function onCountdownEnd(event:Dynamic):Void {}
	public function onSongStart(event:Dynamic):Void {}
	public function onSongEnd(event:Dynamic):Void {}
	public function onBeatHit(event:Dynamic):Void {}
	public function onStepHit(event:Dynamic):Void {}
	public function onNoteHit(event:Dynamic):Void {}
	public function onNoteMiss(event:Dynamic):Void {}
	public function onNoteGhostMiss(event:Dynamic):Void {}
	public function onPause(event:Dynamic):Void {}
	public function onResume(event:Dynamic):Void {}
}

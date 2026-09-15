package funkin.play.character;

import flixel.math.FlxPoint;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEvent.CountdownScriptEvent;
import funkin.modding.events.ScriptEvent.GhostMissNoteScriptEvent;
import funkin.modding.events.ScriptEvent.HitNoteScriptEvent;
import funkin.modding.events.ScriptEvent.HoldNoteScriptEvent;
import funkin.modding.events.ScriptEvent.NoteScriptEvent;
import funkin.modding.events.ScriptEvent.PauseScriptEvent;
import funkin.modding.events.ScriptEvent.SongEventScriptEvent;
import funkin.modding.events.ScriptEvent.SongLoadScriptEvent;
import funkin.modding.events.ScriptEvent.SongRetryEvent;
import funkin.modding.events.ScriptEvent.SongTimeScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;
import funkin.play.notes.NoteDirection;

/**
 * V-Slice/FNF uyumluluk shim'i (BaseCharacter) — v16 (derinleştirildi).
 *
 * Gerçek FNF mod script'leri `import funkin.play.character.BaseCharacter;`
 * yazıp `class X extends BaseCharacter { function new() { super('id'); } }`
 * türetir. Bu shim `objects.Character` üzerine resmî funkin v0.8.7
 * BaseCharacter API'sini köprüler:
 *
 *   playAnimation(name, restart, ignoreOther, reversed) -> playAnim
 *   getCurrentAnimation() -> getAnimationName()
 *   characterType (BF/DAD/GF/OTHER)   isSinging()  playSingAnimation(dir)
 *   resetCharacter()  cameraFocusPoint  holdTimer/isDead/tempVocals
 *   danceEvery <-> danceEveryNumBeats
 *
 * Ayrıca tüm IPlayStateScriptedClass yaşam döngüsü metodları NO-OP olarak
 * tanımlıdır — script'ler `super.onBeatHit(event)` çağırdığında patlamaz.
 *
 * Polymod'un script sınıfı yönlendirmesi (scriptClassOverrides)
 * `vslice.scripting.ScriptedBaseCharacter` üzerinden script'leri bağlar.
 */
@:noCustomClass
class BaseCharacter extends objects.Character
{
	/** FNF script'lerinin beklediği alanlar. */
	public var characterId:String;
	public var characterName:String;

	/** Resmî BaseCharacter alanları. */
	public var isDead:Bool = false;
	public var tempVocals:Bool = false;

	var _characterTypeOverride:Null<Int> = null;

	/**
	 * Resmî FNF characterType (BF/DAD/GF/OTHER).
	 * v20: Tip Dynamic — üst sınıfta (objects.Character) V-Slice shim'i
	 * `set_characterType(Dynamic):Dynamic` var; property erişimcisinin
	 * override uyumu için aynı imza şart. Runtime değeri CharacterType (Int).
	 */
	public var characterType(get, set):Dynamic;

	function get_characterType():Dynamic
	{
		if (_characterTypeOverride != null) return _characterTypeOverride;
		if (isPlayer) return CharacterType.BF;
		if (curCharacter != null && curCharacter.toLowerCase().indexOf('gf') == 0) return CharacterType.GF;
		return CharacterType.DAD;
	}

	override public function set_characterType(value:Dynamic):Dynamic
	{
		if (value != null) _characterTypeOverride = cast value;
		return value;
	}

	/** Resmî FNF: danceEvery (Psych karşılığı danceEveryNumBeats). */
	public var danceEvery(get, set):Int;

	function get_danceEvery():Int return danceEveryNumBeats;
	function set_danceEvery(value:Int):Int return danceEveryNumBeats = value;

	/** Resmî FNF: karakterin kamera odak noktası. */
	public var cameraFocusPoint(get, never):FlxPoint;

	function get_cameraFocusPoint():FlxPoint
	{
		var mid:FlxPoint = getMidpoint();
		mid.x -= (frameWidth / 2) * Math.abs(scale.x);
		mid.y -= (frameHeight / 2) * Math.abs(scale.y);
		return mid;
	}

	public function new(id:String)
	{
		super(0, 0, id, false);
		this.characterId = id;
		this.characterName = id;
	}

	/* ============================ RESMÎ API ============================ */

	/**
	 * Resmî imza: playAnimation(name, restart = false, ignoreOther = false, reversed = false)
	 * Psych karşılığı: playAnim(name, Force, Reversed).
	 * ignoreOther=true -> specialAnim kilidini kaldırır.
	 */
	override public function playAnimation(name:String = null, restart:Bool = false, ignoreOther:Bool = false, reversed:Bool = false):Void
	{
		if (name == null || !hasAnimation(name))
		{
			trace('[BaseCharacter] playAnimation: "$name" animasyonu yok (${curCharacter}).');
			return;
		}
		if (ignoreOther) specialAnim = false;
		playAnim(name, restart, reversed);
	}

	/** Resmî FNF: getCurrentAnimation() */
	public function getCurrentAnimation():Null<String>
	{
		return getAnimationName();
	}

	/** Resmî FNF: karakter şu an şarkı söylüyor mu? */
	public function isSinging():Bool
	{
		return holdTimer > 0 || specialAnim;
	}

	/** Resmî FNF: yöne göre sing animasyonu oynatır. */
	public function playSingAnimation(dir:NoteDirection, miss:Bool = false, ?suffix:String = ''):Void
	{
		var dirInt:Int = dir;
		var name:String = switch (dirInt % 4)
		{
			case 0: 'singLEFT';
			case 1: 'singDOWN';
			case 2: 'singUP';
			default: 'singRIGHT';
		};
		if (miss) name += '-miss';
		if (suffix != null && suffix.length > 0) name += suffix;

		if (hasAnimation(name))
		{
			playAnim(name, true);
			specialAnim = true;
			holdTimer = 0;
		}
	}

	/** Resmî FNF: karakteri başlangıç durumuna döndürür. */
	public function resetCharacter(resetCamera:Bool = true):Void
	{
		holdTimer = 0;
		specialAnim = false;
		isDead = false;
		if (hasAnimation('idle'))
			playAnim('idle', true);
		else
			dance();
	}

	/** Resmî FNF: ölüm sistemi stub'ları (Psych GameOver kendi akışını kullanır). */
	public function getDeathCameraOffsets():Array<Float> return [0, 0];
	public function getDeathCameraZoom():Float return 1.0;
	public function getDeathPreTransitionDelay():Float return 0.0;
	public function getDeathQuote():Null<String> return null;
	public function getBaseScale():Float return scale.x;
	public function getHealthIconId():String return healthIcon;

	/* ============ Bopper-uyumluluk üyeleri (v17) ============
	 * Resmî FNF'de BaseCharacter, Bopper'dan türer; karakter script'leri
	 * Bopper alan/metodlarını da kullanabilir. Köprüler:
	 *   setAnimationOffsets -> Psych addOffset
	 *   forceAnimationForDuration -> playAnim + specialAnim kilidi + FlxTimer
	 */

	/** Resmî Bopper alanları (Further'da davranışsız taşınır).
	 *  NOT: idleSuffix zaten objects.Character'da var (miras alınır). */
	public var shouldBop:Bool = false;
	public var globalOffsets:Array<Float> = [0, 0];
	public var originalPosition:FlxPoint = new FlxPoint(0, 0);

	/** Resmî Bopper: animasyon ofseti tanımlar (Psych addOffset köprüsü). */
	public function setAnimationOffsets(name:String, xOffset:Float, yOffset:Float):Void
	{
		addOffset(name, xOffset, yOffset);
	}

	/** Resmî Bopper: animasyonu süre boyunca kilitler (saniye). */
	public function forceAnimationForDuration(name:String, duration:Float):Void
	{
		if (name == null || !hasAnimation(name)) return;
		playAnim(name, true);
		specialAnim = true;
		holdTimer = 0;
		new flixel.util.FlxTimer().start(duration, function(t:flixel.util.FlxTimer) {
			specialAnim = false;
		}, 1);
	}

	/* ============ IPlayStateScriptedClass no-op'ları (super güvenliği) ============ */

	/* v20: Parametreler Dynamic + override — üst sınıf objects.Character'daki
	   V-Slice shim no-op'larıyla imza uyumu için (Haxe override kuralı:
	   parametre daraltılamaz). Runtime'da gelen nesneler zaten ScriptEvent. */
	override public function onScriptEvent(event:Dynamic):Void {}
	override public function onCreate(event:Dynamic):Void {}
	override public function onDestroy(event:Dynamic):Void {}
	override public function onUpdate(event:Dynamic):Void {}
	override public function onStepHit(event:Dynamic):Void {}
	override public function onBeatHit(event:Dynamic):Void {}
	override public function onPause(event:Dynamic):Void {}
	override public function onResume(event:Dynamic):Void {}
	override public function onSongStart(event:Dynamic):Void {}
	override public function onSongEnd(event:Dynamic):Void {}
	override public function onGameOver(event:Dynamic):Void {}
	override public function onNoteIncoming(event:Dynamic):Void {}
	override public function onNoteHit(event:Dynamic):Void {}
	override public function onNoteMiss(event:Dynamic):Void {}
	override public function onNoteHoldDrop(event:Dynamic):Void {}
	public function onNoteGhostMiss(event:GhostMissNoteScriptEvent):Void {}
	override public function onSongEvent(event:Dynamic):Void {}
	override public function onCountdownStart(event:Dynamic):Void {}
	override public function onCountdownStep(event:Dynamic):Void {}
	override public function onCountdownEnd(event:Dynamic):Void {}
	override public function onSongLoaded(event:Dynamic):Void {}
	public function onSongRetry(event:SongRetryEvent):Void {}
}

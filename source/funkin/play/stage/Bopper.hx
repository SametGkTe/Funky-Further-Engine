package funkin.play.stage;

import flixel.math.FlxPoint;
import flixel.util.FlxTimer;
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

/**
 * V-Slice/FNF uyumluluk shim'i (Bopper) — v17 (Faz 3).
 *
 * Resmî v0.8.7: `class Bopper extends StageProp implements IPlayStateScriptedClass`.
 * Beat'e göre dans eden (danceLeft/danceRight/idle) sahne objesi;
 * BaseCharacter'ın resmî üst sınıfı. V-Slice sahne script'leri sıklıkla
 * `new Bopper(danceEvery)` kurar veya `class X extends Bopper` türetir.
 *
 * Dans mantığı resmî davranışı birebir taklit eder:
 *   - shouldAlternate==null ise danceLeft varlığına göre otomatik karar
 *   - danceLeft/danceRight dönüşümlü, yoksa idle (+ idleSuffix)
 *   - onStepHit: danceEvery>0 ve step % (danceEvery*4)==0 ise dance(shouldBop)
 *
 * SINIR: Resmî Bopper animasyon bitişinde canPlayOtherAnims kilidini açar
 * (onFinish sinyali). Shim'de kilit yalnızca ignoreOther=true çağrısı veya
 * forceAnimationForDuration süresi sonunda açılır.
 */
@:noCustomClass
class Bopper extends StageProp
{
	/** Kaç beat'te bir dans eder (0 = etmez). Resmî alan. */
	public var danceEvery:Float = 0.0;

	/** danceLeft/danceRight dönüşümü; null = otomatik (danceLeft varsa true). */
	public var shouldAlternate:Null<Bool> = null;

	var hasDanced:Bool = false;

	/** Animasyon başına ofsetler (ad -> [x, y]). */
	public var animationOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

	/** Dans animasyonlarına eklenen sonek ('-alt' gibi). */
	public var idleSuffix(default, set):String = '';

	/** Pixel render (antialiasing kapatır). */
	public var isPixel(default, set):Bool = false;

	/** Beat'te bop yapmalı mı? Karakterlerde false olmalı. */
	public var shouldBop:Bool = true;

	/** Sahne JSON'undan gelen global ofset. */
	public var globalOffsets(default, set):Array<Float> = [0, 0];

	/** Geçerli animasyonun ofseti (getScreenPosition'da kullanılır). */
	public var animOffsets(default, set):Array<Float> = [0, 0];

	/** Sahne tanımlı başlangıç konumu (resetPosition buraya döner). */
	public var originalPosition:FlxPoint = new FlxPoint(0, 0);

	/** ignoreOther kilidi: false iken yalnızca izinli animasyonlar oynar. */
	public var canPlayOtherAnims:Bool = true;
	public var ignoreExclusionPref:Array<String> = [];

	public function new(danceEvery:Float = 0.0)
	{
		super();
		this.danceEvery = danceEvery;
	}

	function set_idleSuffix(value:String):String
	{
		this.idleSuffix = value;
		this.dance();
		return value;
	}

	function set_isPixel(value:Bool):Bool
	{
		if (isPixel == value) return value;
		this.antialiasing = !value; // Further: pratik karşılığı antialiasing
		return isPixel = value;
	}

	function set_globalOffsets(value:Array<Float>):Array<Float>
	{
		if (value == null) value = [0, 0];
		return globalOffsets = value;
	}

	function set_animOffsets(value:Array<Float>):Array<Float>
	{
		if (value == null) value = [0, 0];
		if (animOffsets != null && animOffsets[0] == value[0] && animOffsets[1] == value[1]) return value;
		return animOffsets = value;
	}

	/** Resmî FNF: prop'u sahne başlangıç konumuna döndürür. */
	public function resetPosition():Void
	{
		this.x = originalPosition.x;
		this.y = originalPosition.y;
	}

	function update_shouldAlternate():Void
	{
		this.shouldAlternate = hasAnimation('danceLeft');
	}

	/* ============================ DANS / ANİMASYON ============================ */

	/** Resmî FNF: her step'te dispatcher tarafından çağrılır. */
	public function onStepHit(event:SongTimeScriptEvent):Void
	{
		if (danceEvery > 0 && (event.step % Math.round(danceEvery * 4)) == 0)
		{
			dance(shouldBop);
		}
	}

	public function onBeatHit(event:SongTimeScriptEvent):Void {}

	/** Resmî FNF: danceLeft/danceRight (veya idle) dönüşümlü dans. */
	public function dance(forceRestart:Bool = false):Void
	{
		if (this.animation == null) return;

		if (shouldAlternate == null) update_shouldAlternate();

		if (shouldAlternate)
		{
			if (hasDanced) playAnimation('danceRight' + idleSuffix, forceRestart);
			else playAnimation('danceLeft' + idleSuffix, forceRestart);
			hasDanced = !hasDanced;
		}
		else
		{
			playAnimation('idle' + idleSuffix, forceRestart);
		}
	}

	/**
	 * Resmî FNF: animasyon adını doğrular; yoksa '-' soneklerini soyar,
	 * sonra fallback'e (varsayılan davranışta null) düşer.
	 */
	function correctAnimationName(name:String, ?fallback:String):String
	{
		if (hasAnimation(name)) return name;

		if (name.lastIndexOf('-') != -1)
		{
			var correctName = name.substring(0, name.lastIndexOf('-'));
			return correctAnimationName(correctName);
		}
		else
		{
			if (fallback != null && fallback != name)
			{
				return correctAnimationName('idle');
			}
			return null;
		}
	}

	/**
	 * Resmî imza: playAnimation(name, restart, ignoreOther, reversed).
	 * Shim tabanı (FunkinSprite) startFrame de alır — override imzası
	 * tabanla birebir aynı olmak zorunda; startFrame aynen geçirilir.
	 */
	override public function playAnimation(id:String, restart:Bool = false, ignoreOther:Bool = false, reversed:Bool = false, startFrame:Int = 0):Void
	{
		if (!canPlayOtherAnims)
		{
			if (getCurrentAnimation() == id && restart) {}
			else if (ignoreExclusionPref != null && ignoreExclusionPref.length > 0)
			{
				var detected:Bool = false;
				for (entry in ignoreExclusionPref)
				{
					if (id != null && id.startsWith(entry))
					{
						detected = true;
						break;
					}
				}
				if (!detected) return;
			}
			else
				return;
		}

		var correctName:String = correctAnimationName(id);
		if (correctName == null) return;

		if (animation != null && animation.exists(correctName))
			animation.play(correctName, restart, reversed, startFrame);

		if (ignoreOther) canPlayOtherAnims = false;

		applyAnimationOffsets(correctName);
	}

	var forceAnimationTimer:FlxTimer = new FlxTimer();

	/** Resmî FNF: animasyonu süre boyunca kilitler (saniye cinsinden). */
	public function forceAnimationForDuration(name:String, duration:Float):Void
	{
		if (this.animation == null) return;

		var correctName:String = correctAnimationName(name);
		if (correctName == null) return;

		if (animation.exists(correctName)) animation.play(correctName, false, false);
		applyAnimationOffsets(correctName);

		canPlayOtherAnims = false;
		forceAnimationTimer.start(duration, function(t:FlxTimer) {
			canPlayOtherAnims = true;
		}, 1);
	}

	function applyAnimationOffsets(name:String):Void
	{
		var offsets:Array<Float> = animationOffsets.get(name);
		this.animOffsets = offsets;
	}

	/** Resmî FNF: setAnimationOffsets(name, x, y) */
	public function setAnimationOffsets(name:String, xOffset:Float, yOffset:Float):Void
	{
		animationOffsets.set(name, [xOffset, yOffset]);
	}

	/** Resmî FNF: çizimde anim/global ofsetleri uygular. */
	override public function getScreenPosition(?result:FlxPoint, ?camera:flixel.FlxCamera):FlxPoint
	{
		var output:FlxPoint = super.getScreenPosition(result, camera);
		if (animOffsets != null && globalOffsets != null)
		{
			output.x -= (animOffsets[0] - globalOffsets[0]) * this.scale.x;
			output.y -= (animOffsets[1] - globalOffsets[1]) * this.scale.y;
		}
		return output;
	}

	/* ============ IPlayStateScriptedClass no-op'ları (super güvenliği) ============
	 * onScriptEvent/onCreate/onDestroy/onUpdate StageProp'tan miras (orada no-op). */

	public function onPause(event:PauseScriptEvent):Void {}
	public function onResume(event:ScriptEvent):Void {}
	public function onSongStart(event:ScriptEvent):Void {}
	public function onSongEnd(event:ScriptEvent):Void {}
	public function onGameOver(event:ScriptEvent):Void {}
	public function onNoteIncoming(event:NoteScriptEvent):Void {}
	public function onNoteHit(event:HitNoteScriptEvent):Void {}
	public function onNoteMiss(event:NoteScriptEvent):Void {}
	public function onNoteHoldDrop(event:HoldNoteScriptEvent):Void {}
	public function onNoteGhostMiss(event:GhostMissNoteScriptEvent):Void {}
	public function onSongEvent(event:SongEventScriptEvent):Void {}
	public function onCountdownStart(event:CountdownScriptEvent):Void {}
	public function onCountdownStep(event:CountdownScriptEvent):Void {}
	public function onCountdownEnd(event:CountdownScriptEvent):Void {}
	public function onSongLoaded(event:SongLoadScriptEvent):Void {}
	public function onSongRetry(event:SongRetryEvent):Void {}
}

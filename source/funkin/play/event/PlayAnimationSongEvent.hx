package funkin.play.event;

import flixel.FlxSprite;
import funkin.data.song.SongData.SongEventData;

/**
 * V-Slice yerleşik chart event'i: PlayAnimation (v15, Psych köprüsü).
 *
 * Resmî funkin v0.8.7 davranışı:
 *   { target: 'boyfriend'|'dad'|'girlfriend'|<stageProp>, anim: String, force: Bool }
 *
 * Psych karşılığı: Character.playAnim / FlxSprite.animation.play.
 * Karakterlerde force=true ise specialAnim de kurulur (Psych'in kendi
 * 'Play Animation' event'iyle aynı davranış — dance animasyonu bozmasın).
 * Sahne prop'ları state.stages üzerinde Reflect ile aranır.
 */
@:noCustomClass
class PlayAnimationSongEvent extends SongEvent
{
	static final DEFAULT_TARGET:String = 'boyfriend';
	static final DEFAULT_ANIM:String = 'idle';
	static final DEFAULT_FORCE:Bool = true;

	public function new()
	{
		super('PlayAnimation');
	}

	override public function handleEvent(data:SongEventData):Void
	{
		var state = states.PlayState.instance;
		if (state == null) return;

		var targetName:Null<String> = data.getString('target');
		if (targetName == null) targetName = DEFAULT_TARGET;

		var anim:Null<String> = data.getString('anim');
		if (anim == null) anim = DEFAULT_ANIM;

		var force:Null<Bool> = data.getBool('force');
		if (force == null) force = DEFAULT_FORCE;

		var target:FlxSprite = null;

		switch (targetName.toLowerCase())
		{
			case 'boyfriend' | 'bf' | 'player':
				target = state.boyfriend;
			case 'dad' | 'opponent':
				target = state.dad;
			case 'girlfriend' | 'gf':
				target = state.gf;
			default:
				target = findStageProp(state, targetName);
				if (target == null) trace('[PlayAnimationSongEvent] Bilinmeyen hedef: $targetName');
		}

		if (target == null) return;

		if (Std.isOfType(target, objects.Character))
		{
			var char:objects.Character = cast target;
			if (!char.hasAnimation(anim))
			{
				trace('[PlayAnimationSongEvent] ${char.curCharacter} üzerinde "$anim" animasyonu yok.');
				return;
			}
			char.playAnim(anim, force);
			if (force) char.specialAnim = true;
			char.holdTimer = 0;
		}
		else
		{
			if (target.animation == null || !target.animation.exists(anim))
			{
				trace('[PlayAnimationSongEvent] $targetName üzerinde "$anim" animasyonu yok.');
				return;
			}
			target.animation.play(anim, force);
		}
	}

	static function findStageProp(state:states.PlayState, name:String):Null<FlxSprite>
	{
		try
		{
			for (stage in state.stages)
			{
				if (stage == null) continue;
				var f:Dynamic = Reflect.field(stage, name);
				if (f != null && Std.isOfType(f, FlxSprite)) return cast f;
			}
		}
		catch (e:Dynamic)
		{
		}
		return null;
	}

	override public function getTitle():String
	{
		return 'Play Animation';
	}
}

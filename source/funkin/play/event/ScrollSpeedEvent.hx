package funkin.play.event;

import flixel.tweens.FlxTween;
import funkin.data.song.SongData.SongEventData;

/**
 * V-Slice yerleşik chart event'i: ScrollSpeed (v15, Psych köprüsü).
 *
 * Resmî funkin v0.8.7 davranışı:
 *   { scroll: Float, duration: Float (step), ease, easeDir, strumline, absolute }
 *   absolute=false -> çarpan; absolute=true -> doğrudan değer.
 *
 * Psych karşılığı: PlayState.songSpeed (setter'ı notaları yeniden ölçekler).
 * Psych'te tek songSpeed olduğundan 'strumline' alanı yok sayılır.
 */
@:noCustomClass
class ScrollSpeedEvent extends SongEvent
{
	static final DEFAULT_SCROLL:Float = 1.0;
	static final DEFAULT_DURATION:Float = 4.0;
	static final DEFAULT_ABSOLUTE:Bool = false;

	public function new()
	{
		super('ScrollSpeed');
	}

	override public function handleEvent(data:SongEventData):Void
	{
		var state = states.PlayState.instance;
		if (state == null) return;

		var scroll:Null<Float> = data.getFloat('scroll');
		if (scroll == null) scroll = DEFAULT_SCROLL;

		var duration:Null<Float> = data.getFloat('duration');
		if (duration == null) duration = DEFAULT_DURATION;

		var ease:String = data.getString('ease');
		if (ease == null) ease = SongEvent.DEFAULT_EASE;
		var easeDir:String = data.getString('easeDir');
		if (easeDir == null) easeDir = SongEvent.DEFAULT_EASE_DIR;

		var absolute:Null<Bool> = data.getBool('absolute');
		if (absolute == null) absolute = DEFAULT_ABSOLUTE;

		var target:Float = absolute ? scroll : state.songSpeed * scroll;

		if (state.songSpeedTween != null)
		{
			state.songSpeedTween.cancel();
			state.songSpeedTween = null;
		}

		var durSec:Float = duration * backend.Conductor.stepCrochet / 1000;
		if (state.playbackRate != 0) durSec /= state.playbackRate;

		if (durSec <= 0)
		{
			state.songSpeed = target;
			return;
		}

		state.songSpeedTween = FlxTween.tween(state, {songSpeed: target}, durSec,
			{
				ease: SongEvent.getEaseFunction(ease, easeDir),
				onComplete: function(twn:FlxTween)
				{
					state.songSpeedTween = null;
				}
			});
	}

	override public function getTitle():String
	{
		return 'Scroll Speed';
	}
}

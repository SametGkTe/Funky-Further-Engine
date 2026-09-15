package funkin.play.event;

import flixel.FlxG;
import flixel.tweens.FlxTween;
import funkin.data.song.SongData.SongEventData;

/**
 * V-Slice yerleşik chart event'i: ZoomCamera (v15, Psych köprüsü).
 *
 * Resmî funkin v0.8.7 davranışı:
 *   { zoom: Float, duration: Float (step), mode: 'direct'|'stage', ease, easeDir }
 *   targetZoom = zoom * (direct ? 1 : stageZoom)
 *
 * Psych karşılığı: FlxG.camera.zoom + state.defaultCamZoom.
 * (Widescreen scale hesabı FFE'de yok; resmî formülün sade hali.)
 */
@:noCustomClass
class ZoomCameraSongEvent extends SongEvent
{
	static final DEFAULT_ZOOM:Float = 1.0;
	static final DEFAULT_DURATION:Float = 4.0;
	static final DEFAULT_MODE:String = 'direct';

	public function new()
	{
		super('ZoomCamera');
	}

	override public function handleEvent(data:SongEventData):Void
	{
		var state = states.PlayState.instance;
		if (state == null) return;

		var zoom:Null<Float> = data.getFloat('zoom');
		if (zoom == null) zoom = DEFAULT_ZOOM;

		var duration:Null<Float> = data.getFloat('duration');
		if (duration == null) duration = DEFAULT_DURATION;

		var mode:String = data.getString('mode');
		if (mode == null) mode = DEFAULT_MODE;
		var isDirectMode:Bool = mode.toLowerCase() == 'direct';

		var ease:String = data.getString('ease');
		if (ease == null) ease = SongEvent.DEFAULT_EASE;
		var easeDir:String = data.getString('easeDir');
		if (easeDir == null) easeDir = SongEvent.DEFAULT_EASE_DIR;

		// Resmî formül: zoom * (direct ? FlxCamera.defaultZoom : stageZoom)
		var targetZoom:Float = zoom * (isDirectMode ? 1.0 : state.defaultCamZoom);

		var durSec:Float = duration * backend.Conductor.stepCrochet / 1000;
		if (state.playbackRate != 0) durSec /= state.playbackRate;

		if (ease.toUpperCase() == 'INSTANT' || durSec <= 0)
		{
			FlxG.camera.zoom = targetZoom;
			return;
		}

		FlxTween.tween(FlxG.camera, {zoom: targetZoom}, durSec, {ease: SongEvent.getEaseFunction(ease, easeDir)});
	}

	override public function getTitle():String
	{
		return 'Zoom Camera';
	}
}

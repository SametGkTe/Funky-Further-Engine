package funkin.play.event;

import funkin.data.song.SongData.SongEventData;

/**
 * V-Slice yerleşik chart event'i: SetCameraBop (v18, Psych köprüsü).
 *
 * Resmî funkin v0.8.7 davranışı:
 *   { rate: Int (beat, varsayılan 4), offset: Int (varsayılan 0), intensity: Float (varsayılan 1) }
 *   cameraBopIntensity = (1.015 - 1.0) * intensity + 1.0
 *
 * Psych karşılığı: sectionHit'teki zoom punch zaten her 4 beat'te bir
 * (section başına) `0.015 * camZoomingMult` / `0.03 * camZoomingMult` uygular
 * — resmî katsayılarla birebir. intensity -> camZoomingMult köprülenir;
 * rate/offset PlayState.sectionHit'teki kapıya bağlanır
 * (cameraZoomRate < 1 ise Psych davranışı değişmez).
 */
@:noCustomClass
class SetCameraBopSongEvent extends SongEvent
{
	static final DEFAULT_ZOOM_RATE:Float = 4;
	static final DEFAULT_ZOOM_OFFSET:Float = 0;
	static final DEFAULT_BOP_INTENSITY:Float = 1.015;

	public function new()
	{
		super('SetCameraBop');
	}

	override public function handleEvent(data:SongEventData):Void
	{
		var state = states.PlayState.instance;
		if (state == null) return;

		var rate:Null<Float> = data.getFloat('rate');
		if (rate == null) rate = DEFAULT_ZOOM_RATE;
		var offset:Null<Float> = data.getFloat('offset');
		if (offset == null) offset = DEFAULT_ZOOM_OFFSET;
		var intensity:Null<Float> = data.getFloat('intensity');
		if (intensity == null) intensity = 1.0;

		state.cameraBopIntensity = (DEFAULT_BOP_INTENSITY - 1.0) * intensity + 1.0;
		state.hudCameraZoomIntensity = (DEFAULT_BOP_INTENSITY - 1.0) * intensity * 2.0;
		state.cameraZoomRate = rate;
		state.cameraZoomRateOffset = offset;

		// Psych'in gerçek görsel kanalı: camZoomingMult (0.015/0.03 katsayıları aynı).
		state.camZoomingMult = state.cameraBopIntensity;
		state.camZooming = true;
	}

	override public function getTitle():String
	{
		return 'Set Camera Bop';
	}
}

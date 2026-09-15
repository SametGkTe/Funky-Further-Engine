package funkin.play.event;

import flixel.tweens.FlxTween;
import funkin.data.song.SongData.SongEventData;

/**
 * V-Slice yerleşik chart event'i: FocusCamera (v15, Psych köprüsü).
 *
 * Resmî funkin v0.8.7 davranışı:
 *   { char: -1|0|1|2, x: Float, y: Float, duration: Float (step), ease, easeDir }
 *   char: -1 = sabit konum, 0 = boyfriend, 1 = dad/opponent, 2 = girlfriend.
 *   x/y seçilen hedefe EKLENİR (offset).
 *
 * Psych karşılığı: camFollow pozisyonu (moveCamera formülleriyle aynı).
 * Tween süresince isCameraOnForcedPos=true; bitince eski haline döner
 * (resmî FNF'de section kamerası çalışmaya devam eder).
 */
@:noCustomClass
class FocusCameraSongEvent extends SongEvent
{
	static final DEFAULT_X_POSITION:Float = 0.0;
	static final DEFAULT_Y_POSITION:Float = 0.0;
	static final DEFAULT_DURATION:Float = 4.0;
	static final DEFAULT_CAMERA_EASE:String = 'CLASSIC';
	static final DEFAULT_TARGET:Int = 0; // Boyfriend

	public function new()
	{
		super('FocusCamera');
	}

	override public function handleEvent(data:SongEventData):Void
	{
		var state = states.PlayState.instance;
		if (state == null || state.camFollow == null) return;

		var posX:Null<Float> = data.getFloat('x');
		if (posX == null) posX = DEFAULT_X_POSITION;
		var posY:Null<Float> = data.getFloat('y');
		if (posY == null) posY = DEFAULT_Y_POSITION;

		var char:Null<Int> = data.getInt('char');
		if (char == null)
		{
			// Eski chartlar: value doğrudan int ya da string olabilir.
			if (Std.isOfType(data.value, Int))
				char = data.value;
			else if (Std.isOfType(data.value, String))
				char = charFromString(data.value);
			else
			{
				var s:Null<String> = data.getString('char');
				if (s != null) char = charFromString(s);
			}
		}
		if (char == null) char = DEFAULT_TARGET;

		var duration:Null<Float> = data.getFloat('duration');
		if (duration == null) duration = DEFAULT_DURATION;
		var ease:Null<String> = data.getString('ease');
		if (ease == null) ease = DEFAULT_CAMERA_EASE;
		var easeDir:String = data.getString('easeDir');
		if (easeDir == null) easeDir = SongEvent.DEFAULT_EASE_DIR;

		var targetX:Float = posX;
		var targetY:Float = posY;

		switch (char)
		{
			case -1: // Sabit konum ("focus" on origin)
			case 0: // Boyfriend
				var bf = state.boyfriend;
				if (bf == null) return;
				targetX += bf.getMidpoint().x - 100;
				targetY += bf.getMidpoint().y - 100;
				targetX -= bf.cameraPosition[0] - state.boyfriendCameraOffset[0];
				targetY += bf.cameraPosition[1] + state.boyfriendCameraOffset[1];
			case 1: // Dad / opponent
				var dad = state.dad;
				if (dad == null) return;
				targetX += dad.getMidpoint().x + 150;
				targetY += dad.getMidpoint().y - 100;
				targetX += dad.cameraPosition[0] + state.opponentCameraOffset[0];
				targetY += dad.cameraPosition[1] + state.opponentCameraOffset[1];
			case 2: // Girlfriend
				var gf = state.gf;
				if (gf == null) return;
				targetX += gf.getMidpoint().x;
				targetY += gf.getMidpoint().y;
				targetX += gf.cameraPosition[0] + state.girlfriendCameraOffset[0];
				targetY += gf.cameraPosition[1] + state.girlfriendCameraOffset[1];
			default:
				trace('[FocusCameraSongEvent] Bilinmeyen char: ' + char);
		}

		var durSec:Float = duration * backend.Conductor.stepCrochet / 1000;
		if (state.playbackRate != 0) durSec /= state.playbackRate;

		if (ease.toUpperCase() == 'INSTANT' || durSec <= 0)
		{
			state.camFollow.setPosition(targetX, targetY);
			return;
		}

		FlxTween.cancelTweensOf(state.camFollow);
		@:privateAccess(states.PlayState) state.isCameraOnForcedPos = true;
		FlxTween.linearMotion(state.camFollow, state.camFollow.x, state.camFollow.y, targetX, targetY, durSec,
			{
				ease: SongEvent.getEaseFunction(ease, easeDir),
				onComplete: function(_)
				{
					if (states.PlayState.instance != null)
					{
						@:privateAccess(states.PlayState)
						states.PlayState.instance.isCameraOnForcedPos = false;
					}
				}
			});
	}

	static function charFromString(s:String):Int
	{
		switch (s.toLowerCase().trim())
		{
			case 'bf' | 'boyfriend' | 'player' | '0':
				return 0;
			case 'dad' | 'opponent' | '1':
				return 1;
			case 'gf' | 'girlfriend' | '2':
				return 2;
			case 'default' | '-1':
				return -1;
			default:
				var v:Null<Int> = Std.parseInt(s);
				return (v != null) ? v : 0;
		}
	}

	override public function getTitle():String
	{
		return 'Focus Camera';
	}
}

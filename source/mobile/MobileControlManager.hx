package mobile;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.util.FlxDestroyUtil;

/**
 * MobileControlManager — Further Engine'in mobil kontrol yöneticisi.
 * Dokunmatik tuş takımı (FurtherPad), hitbox (FurtherHitbox) ve joystick
 * (UltraJoyStick) oluşturma/kaldırma işlemlerini üstlenir.
 */
class MobileControlManager {
	public var currentState:Dynamic;

	public var mobilePad:FurtherPad;
	public var mobilePadCam:FlxCamera;
	public var joyStickCam:FlxCamera;
	public var joyStick:UltraJoyStick;
	public var hitboxCam:FlxCamera;
	public var hitbox:FurtherHitbox;

	public function new(state:Dynamic):Void
	{
		this.currentState = state;
		trace("MobileControlManager initialized.");
	}

	//for lua shit
	public function makeMobilePad(DPad:String, Action:String)
	{
		if (mobilePad != null) removeMobilePad();
		mobilePad = new FurtherPad(DPad, Action, ClientPrefs.data.mobilePadAlpha);
	}

	public function addMobilePad(DPad:String, Action:String)
	{
		makeMobilePad(DPad, Action);
		currentState.add(mobilePad);
	}

	public function removeMobilePad():Void
	{
		if (mobilePad != null)
		{
			currentState.remove(mobilePad);
			mobilePad = FlxDestroyUtil.destroy(mobilePad);
		}

		if(mobilePadCam != null)
		{
			FlxG.cameras.remove(mobilePadCam);
			mobilePadCam = FlxDestroyUtil.destroy(mobilePadCam);
		}
	}

	public function addMobilePadCamera(defaultDrawTarget:Bool = false):Void
	{
		mobilePadCam = new FlxCamera();
		mobilePadCam.bgColor.alpha = 0;
		FlxG.cameras.add(mobilePadCam, defaultDrawTarget);
		mobilePad.cameras = [mobilePadCam];
	}

	public function makeHitbox(?mode:String, ?hints:Bool) {
		if (hitbox != null) removeHitbox();
		hitbox = new FurtherHitbox(mode, hints, ClientPrefs.data.hitboxAlpha);
	}

	public function addHitbox(?mode:String, ?hints:Bool) {
		makeHitbox(mode, hints);
		currentState.add(hitbox);
	}

	public function removeHitbox():Void
	{
		if (hitbox != null)
		{
			currentState.remove(hitbox);
			hitbox = FlxDestroyUtil.destroy(hitbox);
		}

		if(hitboxCam != null)
		{
			FlxG.cameras.remove(hitboxCam);
			hitboxCam = FlxDestroyUtil.destroy(hitboxCam);
		}
	}

	public function addHitboxCamera(defaultDrawTarget:Bool = false):Void
	{
		hitboxCam = new FlxCamera();
		hitboxCam.bgColor.alpha = 0;
		FlxG.cameras.add(hitboxCam, defaultDrawTarget);
		hitbox.cameras = [hitboxCam];
	}

	public function makeJoyStick(x:Float = 0, y:Float = 0, ?graphic:String, ?onMove:Float->Float->Float->String->Void, size:Float = 1):Void
	{
		if (joyStick != null) removeJoyStick();
		joyStick = new UltraJoyStick(x, y, graphic, onMove);
		joyStick.scale.set(size, size);
	}

	public function addJoyStick(x:Float = 0, y:Float = 0, ?graphic:String, ?onMove:Float->Float->Float->String->Void, size:Float = 1):Void
	{
		makeJoyStick(x, y, graphic, onMove, size);
		currentState.add(joyStick);
	}

	public function removeJoyStick():Void
	{
		if (joyStick != null)
		{
			currentState.remove(joyStick);
			joyStick = FlxDestroyUtil.destroy(joyStick);
		}

		if(joyStickCam != null)
		{
			FlxG.cameras.remove(joyStickCam);
			joyStickCam = FlxDestroyUtil.destroy(joyStickCam);
		}
	}

	public function addJoyStickCamera(defaultDrawTarget:Bool = false):Void {
		joyStickCam = new FlxCamera();
		joyStickCam.bgColor.alpha = 0;
		FlxG.cameras.add(joyStickCam, defaultDrawTarget);
		joyStick.cameras = [joyStickCam];
	}

	public function destroy():Void {
		removeMobilePad();
		removeHitbox();
		removeJoyStick();
	}
}

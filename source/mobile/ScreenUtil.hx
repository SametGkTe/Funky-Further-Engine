package mobile;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.input.touch.FlxTouch;
import flixel.FlxCamera;

/**
 * Screen / touch utilities (package `mobile`) — vendored to match the
 * "mobile-controls" library API that FurtherPad / FurtherHitbox /
 * UltraJoyStick / MobileOptionsSubState expect.
 * Implementation delegates to Further Engine's own helpers
 * (`mobile.backend.TouchUtil`, `mobile.backend.PsychJNI`, `MobileScaleMode`).
 */
class ScreenUtil
{
	/**
	 * Touch state helper. Provides `pressed`, `justPressed`, `justReleased`,
	 * `released` and `overlaps(object, ?camera)` (all read-only).
	 */
	public static var touch(default, null):ScreenTouchUtil = new ScreenTouchUtil();

	/**
	 * Wide screen helper. `ScreenUtil.wideScreen.enabled = bool` toggles it.
	 */
	public static var wideScreen(default, null):WideScreenUtil = new WideScreenUtil();

	#if android
	public static inline function getCurrentOrientationAsString():String
		return mobile.backend.PsychJNI.getCurrentOrientationAsString();

	public static inline function setOrientation(width:Int, height:Int, resizeable:Bool, hint:String):Dynamic
		return mobile.backend.PsychJNI.setOrientation(width, height, resizeable, hint);

	public static inline function isScreenKeyboardShown():Dynamic
		return mobile.backend.PsychJNI.isScreenKeyboardShown();

	public static inline function clipboardHasText():Dynamic
		return mobile.backend.PsychJNI.clipboardHasText();

	public static inline function clipboardGetText():Dynamic
		return mobile.backend.PsychJNI.clipboardGetText();

	public static inline function clipboardSetText(text:String):Dynamic
		return mobile.backend.PsychJNI.clipboardSetText(text);

	public static inline function manualBackButton():Dynamic
		return mobile.backend.PsychJNI.manualBackButton();

	public static inline function setActivityTitle(title:String):Dynamic
		return mobile.backend.PsychJNI.setActivityTitle(title);
	#end
}

class ScreenTouchUtil
{
	public function new() {}

	public var pressed(get, never):Bool;
	public var justPressed(get, never):Bool;
	public var justReleased(get, never):Bool;
	public var released(get, never):Bool;

	function get_pressed():Bool return mobile.backend.TouchUtil.pressed;
	function get_justPressed():Bool return mobile.backend.TouchUtil.justPressed;
	function get_justReleased():Bool return mobile.backend.TouchUtil.justReleased;
	function get_released():Bool return mobile.backend.TouchUtil.released;

	public function overlaps(object:FlxObject, ?camera:FlxCamera):Bool
		return mobile.backend.TouchUtil.overlaps(object, camera);

	public function overlapsComplex(object:FlxObject, ?camera:FlxCamera):Bool
		return mobile.backend.TouchUtil.overlapsComplex(object, camera);

	public function getTouch():FlxTouch
		return mobile.backend.TouchUtil.touch;
}

class WideScreenUtil
{
	public function new() {}

	public var enabled(get, set):Bool;

	function get_enabled():Bool
		return ClientPrefs.data.wideScreen;

	function set_enabled(value:Bool):Bool
	{
		ClientPrefs.data.wideScreen = value;
		FlxG.scaleMode = new mobile.backend.MobileScaleMode();
		return value;
	}
}

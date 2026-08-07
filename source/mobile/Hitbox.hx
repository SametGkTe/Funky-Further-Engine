package mobile;

import flixel.FlxCamera;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;
import flixel.util.FlxSignal.FlxTypedSignal;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Matrix;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.FlxG;

/**
 * A zone with 4 hint's (A hitbox).
 *
 * NOTE: This is the ArkoseLabs "mobile-controls" library base (vendored, adapted
 * for Further Engine). Creation is handled by `mobile.objects.FurtherHitbox`, the
 * base constructor intentionally does NOT build any hints.
 *
 * @author KralOyuncu 2010x (ArkoseLabs)
 */
class Hitbox extends MobileInputHandler {
	public var onButtonDown:FlxTypedSignal<(MobileButton, Array<String>, Int) -> Void> = new FlxTypedSignal<(MobileButton, Array<String>, Int) -> Void>();
	public var onButtonUp:FlxTypedSignal<(MobileButton, Array<String>, Int) -> Void> = new FlxTypedSignal<(MobileButton, Array<String>, Int) -> Void>();
	public var instance:MobileInputHandler;
	public var Hints:Array<MobileButton> = [];
	public var buttonIndexFromName:Map<String, Int> = [];
	public var buttonFromName:Map<String, MobileButton> = [];
	public var globalAlpha:Float = 0.7;
	public var buttonCameras(get, set):Array<FlxCamera>;

	public function getButtonIndexFromName(btnName:String)
		return buttonIndexFromName.get(btnName);

	public function getButtonFromName(btnName:String)
		return buttonFromName.get(btnName);

	public function getButton(btnName:String)
		return buttonFromName.get(btnName);

	@:noCompletion
	function get_buttonCameras():Array<FlxCamera>
	{
		return cameras;
	}

	@:noCompletion
	function set_buttonCameras(Value:Array<FlxCamera>):Array<FlxCamera>
	{
		cameras = Value;
		for (button in Hints) {
			button._cameras = Value;
		}
		return Value;
	}

	/**
	 * Create the zone.
	 *
	 * @param   Mode   The Hitbox mode (must exist in `MobileConfig.hitboxModes`).
	 * @param   GlobalAlpha   The alpha of the buttons.
	 * @param   DisableCreation   If true, nothing is created (used by FurtherHitbox).
	 */
	public function new(?Mode:String, ?globalAlpha:Float = 0.7, ?disableCreation:Bool = false):Void
	{
		super();

		this.globalAlpha = globalAlpha;

		if (!disableCreation)
		{
			var Custom:String = Mode != null ? Mode : 'Normal (New)';
			if (MobileConfig.hitboxModes.exists(Custom))
			{
				var currentHint:Array<HitboxData> = MobileConfig.hitboxModes.get(Custom).hints;
				if (currentHint == null && MobileConfig.hitboxModes.get(Custom).none != null)
					currentHint = MobileConfig.hitboxModes.get(Custom).none;

				if (currentHint != null)
				{
					for (buttonData in currentHint)
					{
						var buttonName:String = buttonData.button;
						var buttonIDs:Array<String> = buttonData.buttonIDs;
						var buttonUniqueID:Int = buttonData.buttonUniqueID != null ? buttonData.buttonUniqueID : -1;
						var buttonX:Float = buttonData.x;
						var buttonY:Float = buttonData.y;
						var buttonWidth:Int = buttonData.width;
						var buttonHeight:Int = buttonData.height;
						var buttonColor = buttonData.color;
						var buttonReturn = buttonData.returnKey;
						addHint(buttonName, buttonIDs, buttonUniqueID, buttonX, buttonY, buttonWidth, buttonHeight, Util.colorFromString(buttonColor), buttonReturn);
					}
				}
			}
		}

		scrollFactor.set();
		updateTrackedButtons();

		instance = this;
	}

	public function addHint(Name:String, IDs:Array<String>, UniqueID:Dynamic, X:Float, Y:Float, Width:Int, Height:Int, Color:Int = 0xFFFFFF, ?buttonReturn:String)
	{
		var hint:MobileButton = createHint(IDs, UniqueID, X, Y, Width, Height, Color, buttonReturn);
		hint.name = Name;
		hint.IDs = IDs;
		hint.uniqueID = UniqueID;

		Hints.push(hint);
		add(hint);

		buttonIndexFromName.set(Name, Hints.length - 1);
		buttonFromName.set(Name, hint);
	}

	public function createHint(name:Array<String>, uniqueID:Int, x:Float, y:Float, width:Int, height:Int, color:Int = 0xFFFFFF, ?returned:String):MobileButton
	{
		var hint:MobileButton = new MobileButton(x, y, returned);
		hint.loadGraphic(createHintGraphic(width, height, color));

		hint.solid = false;
		hint.immovable = true;
		hint.scrollFactor.set();
		hint.alpha = 0.00001;
		hint.IDs = name;
		hint.uniqueID = uniqueID;

		#if FLX_DEBUG
		hint.ignoreDrawDebug = true;
		#end
		return hint;
	}

	public function createHintGraphic(Width:Int, Height:Int, Color:Int = 0xFFFFFF, ?isLane:Bool = false):BitmapData
	{
		var shape:Shape = new Shape();
		shape.graphics.beginFill(Color);
		shape.graphics.drawRect(0, 0, Width, Height);
		shape.graphics.endFill();

		var bitmap:BitmapData = new BitmapData(Width, Height, true, 0);
		bitmap.draw(shape);
		return bitmap;
	}

	/**
	 * Clean up memory.
	 */
	override function destroy():Void
	{
		super.destroy();
		onButtonUp.destroy();
		onButtonDown.destroy();

		Hints = [];
		buttonIndexFromName = [];
		buttonFromName = [];
	}
}

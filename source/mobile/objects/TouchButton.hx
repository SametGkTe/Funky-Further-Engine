package mobile.objects;

import mobile.MobileButton;
import mobile.input.MobileInputID;

/**
 * TouchButton — COMPATIBILITY WRAPPER.
 *
 * The old Further Engine "Mobile Porting Team" TouchButton has been replaced by
 * the new ArkoseLabs "mobile-controls" MobileButton (new visuals, 2-frame
 * textures, slide input). To keep every old usage working
 * (`touchPad.buttonZ.pressed`, `TouchButton.NORMAL`, `button.label`, ...) this
 * class extends `mobile.MobileButton` and re-adds the old fields that the rest
 * of the engine still reads (`inputIDs`, `parentAlpha`, `statusBrightness`,
 * `statusIndicatorType`, `indicateStatus()`, ...).
 *
 * `inputIDs` drives the old input system (`mobile.input.MobileInputManager` /
 * `backend.Controls`), while `IDs` (Array<String>) drives the new system
 * (`pressed('A')`, `getButton('buttonA')`, ...).
 */
class TouchButton extends MobileButton
{
	/**
	 * Used with public variable status, means not highlighted or pressed.
	 * (Haxe statics aren't inherited, so these are re-declared here for old
	 * code that reads `TouchButton.NORMAL` etc.)
	 */
	public static inline var NORMAL:Int = 0;

	/**
	 * Used with public variable status, means highlighted (usually from touch over).
	 */
	public static inline var HIGHLIGHT:Int = 1;

	/**
	 * Used with public variable status, means pressed (usually from touch click).
	 */
	public static inline var PRESSED:Int = 2;

	/**
	 * The old-style `MobileInputID`s assigned to this button (used by the
	 * legacy input manager / Controls).
	 */
	public var inputIDs:Array<MobileInputID> = [];

	/**
	 * IF YOU'RE USING SPRITE GROUPS YOU MUST SET THIS TO THE GROUP'S ALPHA LIKE IN TouchPad.
	 */
	public var parentAlpha(default, set):Float = 1;

	/**
	 * Kept for compatibility with old code.
	 */
	public var statusBrightness:Array<Float> = [1.0, 0.95, 0.7];

	/**
	 * Kept for compatibility with old code.
	 */
	public var statusIndicatorType(default, set):StatusIndicators = ALPHA;

	/**
	 * Kept for compatibility with old code.
	 */
	public var labelStatusDiff:Float = 0.05;

	/**
	 * Kept for compatibility with old code.
	 */
	public var brightShader:ButtonBrightnessShader = new ButtonBrightnessShader();

	/**
	 * Creates a new `TouchButton`.
	 *
	 * @param   X         The x position of the button.
	 * @param   Y         The y position of the button.
	 * @param   IDs       The button's old-style IDs (used for input handling).
	 */
	public function new(X:Float = 0, Y:Float = 0, ?IDs:Array<MobileInputID> = null):Void
	{
		super(X, Y);
		this.inputIDs = IDs == null ? [] : IDs;
	}

	/**
	 * Kept for compatibility with old code (the new MobileButton handles status
	 * visuals itself, so this only keeps the status in sync).
	 */
	public function indicateStatus():Void {}

	function set_parentAlpha(Value:Float):Float
	{
		alpha = Value;
		return parentAlpha = Value;
	}

	function set_statusIndicatorType(Value:StatusIndicators)
	{
		statusIndicatorType = Value;
		return Value;
	}

	override public function destroy():Void
	{
		inputIDs = [];
		super.destroy();
	}
}

/**
 * TypedTouchButton — COMPATIBILITY: eski sistemin jenerik butonu. Yeni
 * MobileButton'un jenerik tabanını kullanır; `TouchZone`/`ScrollableObject`
 * gibi eski sınıflar hâlâ bu türe bağlıdır.
 */
class TypedTouchButton<T:FlxSprite> extends TypedMobileButton<T>
{
	/**
	 * Kept for compatibility with old code.
	 */
	public var statusBrightness:Array<Float> = [1.0, 0.95, 0.7];

	/**
	 * Kept for compatibility with old code.
	 */
	public var labelStatusDiff:Float = 0.05;

	/**
	 * Kept for compatibility with old code.
	 */
	public var parentAlpha(default, set):Float = 1;

	/**
	 * Kept for compatibility with old code.
	 */
	public var statusIndicatorType(default, set):StatusIndicators = ALPHA;

	/**
	 * Kept for compatibility with old code.
	 */
	public var brightShader:ButtonBrightnessShader = new ButtonBrightnessShader();

	public function new(X:Float = 0, Y:Float = 0):Void
	{
		super(X, Y);
	}

	public function indicateStatus():Void {}

	function set_parentAlpha(Value:Float):Float
	{
		alpha = Value;
		return parentAlpha = Value;
	}

	function set_statusIndicatorType(Value:StatusIndicators)
	{
		statusIndicatorType = Value;
		return Value;
	}
}

enum StatusIndicators
{
	// isn't very good looking
	ALPHA;
	// best one in my opinion
	BRIGHTNESS;
	// used when u make ur own status indicator like in hitbox
	NONE;
}

class ButtonBrightnessShader extends FlxShader
{
	public var color(default, set):Null<FlxColor> = FlxColor.WHITE;

	@:glFragmentSource('
		#pragma header

		uniform float brightness;

		void main()
		{
			vec4 col = flixel_texture2D(bitmap, openfl_TextureCoordv);
			col.rgb *= brightness;

			gl_FragColor = col;
		}
	')
	public function new()
	{
		super();
	}

	private function set_color(?laColor:FlxColor)
	{
		if (laColor == null)
		{
			colorMultiplier.value = [1, 1, 1, 1];
			hasColorTransform.value = hasTransform.value = [false];
			return color = laColor;
		}
		hasColorTransform.value = hasTransform.value = [true];
		colorMultiplier.value = [laColor.redFloat, laColor.blueFloat, laColor.greenFloat, laColor.alphaFloat];
		return color = laColor;
	}
}

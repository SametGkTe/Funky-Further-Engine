package mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.input.touch.FlxTouch;
import flixel.math.FlxPoint;
import flixel.math.FlxAngle;
import flixel.util.FlxDestroyUtil;
import openfl.utils.Assets;

/**
 * A simple touch Joystick.
 *
 * NOTE: This is the ArkoseLabs "mobile-controls" library Joystick (vendored,
 * reconstructed for Further Engine to match the API used by UltraJoyStick).
 *
 * @author KralOyuncu 2010x (ArkoseLabs) / adapted
 */
class JoyStick extends FlxSpriteGroup
{
	public var base:FlxSprite;
	public var thumb:FlxSprite;

	public var deadZone:Float = 0.35;

	var onMove:Float->Float->Float->String->Void;
	var _activeTouchID:Int = -1;
	var _pressed:Bool = false;
	var _justPressed:Bool = false;
	var _justReleased:Bool = false;
	var _angle:Float = 0;
	var _strength:Float = 0;
	var _direction:String = 'none';

	/**
	 * @param   X   The x position of the joystick.
	 * @param   Y   The y position of the joystick.
	 * @param   Graphic   The sparrow atlas path (without .png/.xml) or null for the default.
	 * @param   OnMove   Callback(angle:Float, strength:Float, directionID:Float, directionName:String).
	 */
	public function new(x:Float = 0, y:Float = 0, ?graphic:String, ?onMove:Float->Float->Float->String->Void)
	{
		super(x, y);

		this.onMove = onMove;

		var gfx:String = graphic != null ? graphic : MobileConfig.mobileFolderPath + 'JoyStick/joystick';

		base = new FlxSprite();
		thumb = new FlxSprite();

		loadObjectGraphic(base, gfx, 'base');
		loadObjectGraphic(thumb, gfx, 'thumb');

		base.scrollFactor.set();
		thumb.scrollFactor.set();

		add(base);
		add(thumb);

		centerThumb();
	}

	private function loadObjectGraphic(object:FlxSprite, graphic:String, img:String)
	{
		object.loadGraphic(FlxGraphic.fromFrame(FlxAtlasFrames.fromSparrow(Assets.getBitmapData('$graphic.png'), Assets.getText('$graphic.xml')).getByName(img)));
	}
	function centerThumb()
	{
		thumb.setPosition(base.x + (base.width - thumb.width) / 2, base.y + (base.height - thumb.height) / 2);
	}

	public function pressed(position:String):Bool
		return getDirectionState(position, false);

	public function justPressed(position:String):Bool
		return getDirectionState(position, true);

	public function justReleased(position:String):Bool
		return getDirectionState(position, true, true);

	function getDirectionState(position:String, just:Bool, released:Bool = false):Bool
	{
		if (position == null) return false;

		if (released)
		{
			if (!_pressed && _justReleased && _direction == position.toLowerCase()) return true;
			return false;
		}

		if (just)
		{
			if (_justPressed && _direction == position.toLowerCase()) return true;
			return false;
		}

		if (_pressed && _direction == position.toLowerCase()) return true;
		return false;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		_justPressed = false;
		_justReleased = false;

		var activeTouch:FlxTouch = null;

		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed && overlapsPoint(touch.getWorldPosition(camera != null ? camera : FlxG.camera, _point), true))
			{
				activeTouch = touch;
				break;
			}

			if (touch.touchPointID == _activeTouchID)
			{
				activeTouch = touch;
				break;
			}
		}

		if (activeTouch == null)
		{
			if (_pressed)
			{
				_pressed = false;
				_justReleased = true;
				_direction = 'none';
				_angle = 0;
				_strength = 0;
				centerThumb();
			}
			return;
		}

		if (activeTouch.justPressed)
		{
			_activeTouchID = activeTouch.touchPointID;
			_pressed = true;
			_justPressed = true;
		}

		if (_pressed)
		{
			var touchPoint:FlxPoint = activeTouch.getWorldPosition(camera != null ? camera : FlxG.camera, FlxPoint.weak());
			var centerX:Float = base.x + base.width / 2;
			var centerY:Float = base.y + base.height / 2;

			var dx:Float = touchPoint.x - centerX;
			var dy:Float = touchPoint.y - centerY;

			var dist:Float = Math.sqrt(dx * dx + dy * dy);
			var maxDist:Float = (base.width / 2) * 0.9;

			if (dist > maxDist)
			{
				dx = dx / dist * maxDist;
				dy = dy / dist * maxDist;
				dist = maxDist;
			}

			thumb.setPosition(centerX + dx - thumb.width / 2, centerY + dy - thumb.height / 2);

			_angle = FlxAngle.wrapAngle(Math.atan2(dy, dx) * 180 / Math.PI);
			_strength = dist / maxDist;
			_direction = getDirectionFromAngle(_angle);

			if (onMove != null)
				onMove(_angle, _strength, getDirectionID(_direction), _direction);
		}
	}

	function getDirectionFromAngle(angle:Float):String
	{
		if (_strength < deadZone) return 'none';

		angle = FlxAngle.wrapAngle(angle);
		if (angle < 0) angle += 360;

		if (angle >= 337.5 || angle < 22.5) return 'right';
		if (angle >= 22.5 && angle < 67.5) return 'downright';
		if (angle >= 67.5 && angle < 112.5) return 'down';
		if (angle >= 112.5 && angle < 157.5) return 'downleft';
		if (angle >= 157.5 && angle < 202.5) return 'left';
		if (angle >= 202.5 && angle < 247.5) return 'upleft';
		if (angle >= 247.5 && angle < 292.5) return 'up';
		return 'upright';
	}

	function getDirectionID(direction:String):Int
	{
		return switch (direction)
		{
			case 'up': 0;
			case 'upright': 45;
			case 'right': 90;
			case 'downright': 135;
			case 'down': 180;
			case 'downleft': 225;
			case 'left': 270;
			case 'upleft': 315;
			default: -1;
		}
	}

	override function destroy():Void
	{
		base = FlxDestroyUtil.destroy(base);
		thumb = FlxDestroyUtil.destroy(thumb);
		onMove = null;
		super.destroy();
	}
}

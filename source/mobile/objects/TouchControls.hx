package mobile.objects;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.input.touch.FlxTouch;
import mobile.MobileConfig;
import mobile.input.MobileInputID;
import openfl.display.BitmapData;
import openfl.utils.Assets;

class TouchControls extends TouchPad
{
	public static inline var TAP_MAX_DIST:Float = 40;
	public static inline var SWIPE_MIN_DIST:Float = 70;
	public static inline var TAP_MAX_TIME:Float = 0.35;
	public static inline var LONGPRESS_TIME:Float = 0.55;
	public static inline var DRAG_START_DIST:Float = 30;
	public static inline var BACK_HIT_PAD:Float = 45;
	public static inline var SCROLL_STEP_BASE:Float = 80;
	public static inline var SCROLL_MAX_STEPS:Int = 6;
	public static inline var SCROLL_REPEAT_DELAY:Float = 0.04;

	public var owner:Dynamic;

	var allowUp:Bool = false;
	var allowDown:Bool = false;
	var allowLeft:Bool = false;
	var allowRight:Bool = false;
	var allowAccept:Bool = false;
	var allowBack:Bool = false;
	var allowReset:Bool = false;

	var backSprite:FlxSprite;

	var trackedTouches:Map<Int, {x:Float, y:Float, lastY:Float, stepAcc:Float, time:Float, moved:Float, onBack:Bool, onButton:Bool, dragging:Bool, fired:Bool}> = [];

	var synth:Map<MobileInputID, {pressed:Bool, justPressed:Bool, justReleased:Bool}> = [];

	var repeatActive:Bool = false;
	var repeatIsUp:Bool = false;
	var repeatLeft:Int = 0;
	var repeatTimer:Float = 0;

	public function new(DPad:String, Action:String, ?ownerRef:Dynamic = null)
	{
		super('NONE', 'NONE');
		owner = ownerRef;
		parseModes(DPad, Action);
		addExtraButtons(Action);
		initSynth();
		createBackButton();
		if (members.length > 0)
		{
			updateTrackedButtons();
			set_alpha(alpha);
		}
	}

	public static function canReplace(DPad:String, Action:String):Bool
	{
		#if mobile
		if (ClientPrefs.data.mobileControlType != 'Touch')
			return false;
		switch (DPad)
		{
			case 'NONE', 'UP_DOWN', 'LEFT_RIGHT', 'LEFT_FULL', 'RIGHT_FULL', 'FULL', 'UP_DOWN_LEFT_RIGHT':
			default:
				return false;
		}
		return switch (Action)
		{
			case 'NONE', 'A', 'B', 'A_B', 'A_B_C', 'A_B_X_Y', 'A_B_C_O_X_Y_Z', 'B_C': true;
			default: false;
		};
		#else
		return false;
		#end
	}

	public static function isEditorOwner(owner:Dynamic):Bool
	{
		if (owner == null)
			return false;
		var cls:Class<Dynamic> = Type.getClass(owner);
		if (cls == null)
			return false;
		var name:String = Type.getClassName(cls);
		return name.indexOf('editors.') == 0 || name.indexOf('.editors.') != -1;
	}

	function parseModes(DPad:String, Action:String):Void
	{
		switch (DPad)
		{
			case 'UP_DOWN':
				allowUp = allowDown = true;
			case 'LEFT_RIGHT':
				allowLeft = allowRight = true;
			case 'LEFT_FULL', 'RIGHT_FULL', 'FULL', 'UP_DOWN_LEFT_RIGHT':
				allowUp = allowDown = allowLeft = allowRight = true;
		}

		allowAccept = Action == 'A' || Action == 'A_B' || Action == 'A_B_C' || Action == 'A_B_X_Y' || Action == 'A_B_C_O_X_Y_Z';
		allowBack = Action == 'B' || Action == 'A_B' || Action == 'A_B_C' || Action == 'A_B_X_Y' || Action == 'A_B_C_O_X_Y_Z' || Action == 'B_C';
		allowReset = Action == 'A_B_C' || Action == 'A_B_C_O_X_Y_Z' || Action == 'B_C';
	}

	function addExtraButtons(Action:String):Void
	{
		#if mobile
		if (Action == 'NONE')
			return;

		if (!MobileConfig.actionModes.exists(Action))
			MobileConfig.ensureBuiltinActionModes();

		if (!MobileConfig.actionModes.exists(Action) && Action == MobileConfig.FREEPLAY_ACTION_MODE
			&& MobileConfig.actionModes.exists('A_B_C_X_Y_Z'))
			Action = 'A_B_C_X_Y_Z';

		if (!MobileConfig.actionModes.exists(Action))
			return;

		for (buttonData in MobileConfig.actionModes.get(Action).buttons)
		{
			var buttonIDs:Array<String> = buttonData.buttonIDs;
			if (buttonIDs == null)
				buttonIDs = [buttonData.button.substr(6).toUpperCase()];

			var skip:Bool = false;
			for (strId in buttonIDs)
			{
				var id:MobileInputID = MobileInputID.fromString(strId);
				if (id == MobileInputID.UP || id == MobileInputID.DOWN || id == MobileInputID.LEFT
					|| id == MobileInputID.RIGHT || id == MobileInputID.A || id == MobileInputID.B)
				{
					skip = true;
					break;
				}
			}
			if (!skip)
				addButtonFromData(buttonData);
		}
		#end
	}

	function hitExtraButton(x:Float, y:Float):Bool
	{
		for (btn in members)
		{
			if (btn == null || !btn.visible || !btn.exists)
				continue;
			var cam = (btn.cameras != null && btn.cameras.length > 0) ? btn.cameras[0] : FlxG.camera;
			var pos = btn.getScreenPosition(cam);
			var w:Float = btn.width * cam.zoom;
			var h:Float = btn.height * cam.zoom;
			var hit:Bool = x >= pos.x && x <= pos.x + w && y >= pos.y && y <= pos.y + h;
			pos.put();
			if (hit)
				return true;
		}
		return false;
	}

	function initSynth():Void
	{
		for (id in [MobileInputID.UP, MobileInputID.DOWN, MobileInputID.LEFT, MobileInputID.RIGHT, MobileInputID.A, MobileInputID.B, MobileInputID.C])
			synth.set(id, {pressed: false, justPressed: false, justReleased: false});
	}

	function createBackButton():Void
	{
		if (!allowBack)
			return;

		var graphic:FlxGraphic = null;
		var paths:Array<String> = [
			MobileConfig.mobileFolderPath + 'MobilePad/Textures/back.png',
			'assets/mobile/MobilePad/Textures/back.png',
			MobileConfig.mobileFolderPath + 'MobilePad/Textures/default.png',
			'assets/mobile/MobilePad/Textures/default.png'
		];
		for (path in paths)
		{
			if (Assets.exists(path))
			{
				graphic = FlxGraphic.fromBitmapData(Assets.getBitmapData(path));
				break;
			}
		}

		backSprite = new FlxSprite();
		if (graphic != null)
			backSprite.loadGraphic(graphic);
		else
			backSprite.makeGraphic(120, 120, 0x88000000);

		var backScale:Float = 125 / backSprite.height;
		backSprite.setGraphicSize(backSprite.width * backScale, 125);
		backSprite.updateHitbox();
		backSprite.x = 20;
		backSprite.y = FlxG.height - backSprite.height - 20;
		backSprite.alpha = alpha;
		backSprite.antialiasing = ClientPrefs.data.antialiasing;
		backSprite.scrollFactor.set();
	}

	function fire(id:MobileInputID):Void
	{
		var s = synth.get(id);
		if (s == null)
			return;
		s.justPressed = true;
		s.pressed = true;
	}

	function hitBack(x:Float, y:Float):Bool
	{
		if (backSprite == null)
			return false;
		var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
		var pos:FlxPoint = backSprite.getScreenPosition(cam);
		var w:Float = backSprite.width * cam.zoom;
		var h:Float = backSprite.height * cam.zoom;
		var hit:Bool = x >= pos.x - BACK_HIT_PAD && x <= pos.x + w + BACK_HIT_PAD
			&& y >= pos.y - BACK_HIT_PAD && y <= pos.y + h + BACK_HIT_PAD;
		pos.put();
		return hit;
	}

	function handleTap(x:Float, y:Float):Void
	{
		if (!allowAccept)
			return;

		var handled:Bool = false;
		if (owner != null)
		{
			try
			{
				if (Reflect.field(owner, 'handleTouchTap') != null)
					handled = owner.handleTouchTap(x, y);
			}
			catch (e:Dynamic) {}
		}
		if (!handled)
			fire(MobileInputID.A);
	}

	function handleHorizontalSwipe(dx:Float):Void
	{
		if (dx > 0)
		{
			if (allowRight) fire(MobileInputID.RIGHT);
		}
		else
		{
			if (allowLeft) fire(MobileInputID.LEFT);
		}
	}

	function queueSteps(isUp:Bool, count:Int):Void
	{
		if (count <= 0)
			return;
		if (!repeatActive || repeatIsUp != isUp)
		{
			repeatActive = true;
			repeatIsUp = isUp;
			repeatLeft = 0;
			repeatTimer = SCROLL_REPEAT_DELAY;
		}
		repeatLeft += count;
		if (repeatLeft > SCROLL_MAX_STEPS)
			repeatLeft = SCROLL_MAX_STEPS;
	}

	function processTouches(elapsed:Float):Void
	{
		if (repeatActive && repeatLeft > 0)
		{
			repeatTimer -= elapsed;
			if (repeatTimer <= 0)
			{
				fire(repeatIsUp ? MobileInputID.UP : MobileInputID.DOWN);
				repeatLeft--;
				repeatTimer = SCROLL_REPEAT_DELAY;
				if (repeatLeft <= 0)
					repeatActive = false;
			}
		}

		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				repeatActive = false;
				var onBack:Bool = allowBack && hitBack(touch.x, touch.y);
				var onButton:Bool = !onBack && hitExtraButton(touch.x, touch.y);
				trackedTouches.set(touch.touchPointID, {
					x: touch.x,
					y: touch.y,
					lastY: touch.y,
					stepAcc: 0,
					time: 0,
					moved: 0,
					onBack: onBack,
					onButton: onButton,
					dragging: false,
					fired: false
				});
				if (onBack)
				{
					if (backSprite != null)
						backSprite.alpha = alpha * 0.5;
					fire(MobileInputID.B);
				}
				continue;
			}

			var info = trackedTouches.get(touch.touchPointID);
			if (info == null)
				continue;

			info.time += elapsed;
			var dx:Float = touch.x - info.x;
			var dy:Float = touch.y - info.y;
			var dist:Float = Math.sqrt(dx * dx + dy * dy);
			if (dist > info.moved)
				info.moved = dist;

			if (!info.dragging && !info.onBack && !info.onButton && !info.fired && (allowUp || allowDown)
				&& Math.abs(dy) >= DRAG_START_DIST && Math.abs(dy) > Math.abs(dx))
			{
				info.dragging = true;
				info.fired = true;
				info.stepAcc = dy;
			}

			if (info.dragging)
			{
				info.stepAcc += touch.y - info.lastY;
				var stepPx:Float = SCROLL_STEP_BASE * 100 / Math.max(25, ClientPrefs.data.touchScrollSens);
				if (info.stepAcc <= -stepPx)
				{
					var n:Int = Math.floor(-info.stepAcc / stepPx);
					info.stepAcc += n * stepPx;
					if (allowDown)
					{
						fire(MobileInputID.DOWN);
						queueSteps(false, n - 1);
					}
				}
				else if (info.stepAcc >= stepPx)
				{
					var n:Int = Math.floor(info.stepAcc / stepPx);
					info.stepAcc -= n * stepPx;
					if (allowUp)
					{
						fire(MobileInputID.UP);
						queueSteps(true, n - 1);
					}
				}
			}
			info.lastY = touch.y;

			if (!info.fired && !info.onBack && !info.onButton && allowReset && info.time >= LONGPRESS_TIME && info.moved < TAP_MAX_DIST)
			{
				info.fired = true;
				fire(MobileInputID.C);
			}

			if (touch.justReleased)
			{
				trackedTouches.remove(touch.touchPointID);
				if (info.onBack)
				{
					if (backSprite != null)
						backSprite.alpha = alpha;
				}
				else if (!info.onButton)
				{
					if (info.dragging)
					{
						repeatActive = false;
					}
					else if (!info.fired)
					{
						if (info.moved < TAP_MAX_DIST && info.time < TAP_MAX_TIME)
							handleTap(touch.x, touch.y);
						else if (info.moved >= SWIPE_MIN_DIST && Math.abs(dx) > Math.abs(dy))
							handleHorizontalSwipe(dx);
					}
				}
			}
		}

		var staleIds:Array<Int> = [];
		for (id in trackedTouches.keys())
		{
			var live:Bool = false;
			for (t in FlxG.touches.list)
			{
				if (t.touchPointID == id)
				{
					live = true;
					break;
				}
			}
			if (!live)
				staleIds.push(id);
		}
		for (id in staleIds)
			trackedTouches.remove(id);
	}

	override public function update(elapsed:Float)
	{
		for (s in synth)
		{
			s.justPressed = false;
			s.justReleased = false;
			if (s.pressed)
			{
				s.pressed = false;
				s.justReleased = true;
			}
		}

		super.update(elapsed);

		if (backSprite != null)
			backSprite.visible = visible;

		for (btn in members)
			if (btn != null)
				btn.visible = visible;

		if (!visible)
			repeatActive = false;

		#if mobile
		if (visible)
			processTouches(elapsed);
		#end
	}

	override public function draw():Void
	{
		super.draw();
		if (backSprite != null && backSprite.visible)
		{
			if (cameras != null)
				backSprite.cameras = cameras;
			backSprite.draw();
		}
	}

	override function set_alpha(Value):Float
	{
		if (backSprite != null)
			backSprite.alpha = Value;
		return super.set_alpha(Value);
	}

	override public function anyJustPressed(buttonsArray:Array<MobileInputID>):Bool
	{
		if (buttonsArray != null)
			for (id in buttonsArray)
			{
				var s = synth.get(id);
				if (s != null && s.justPressed)
					return true;
			}
		return super.anyJustPressed(buttonsArray);
	}

	override public function anyPressed(buttonsArray:Array<MobileInputID>):Bool
	{
		if (buttonsArray != null)
			for (id in buttonsArray)
			{
				var s = synth.get(id);
				if (s != null && s.pressed)
					return true;
			}
		return super.anyPressed(buttonsArray);
	}

	override public function anyJustReleased(buttonsArray:Array<MobileInputID>):Bool
	{
		if (buttonsArray != null)
			for (id in buttonsArray)
			{
				var s = synth.get(id);
				if (s != null && s.justReleased)
					return true;
			}
		return super.anyJustReleased(buttonsArray);
	}

	override public function destroy():Void
	{
		if (backSprite != null)
		{
			backSprite.destroy();
			backSprite = null;
		}
		trackedTouches = null;
		synth = null;
		super.destroy();
	}
}

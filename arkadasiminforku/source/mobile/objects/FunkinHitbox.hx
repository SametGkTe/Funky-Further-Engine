package mobile.objects;

import mobile.Hitbox;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Matrix;
import flixel.util.FlxColor;
import objects.Note;
import flixel.FlxG; // FlxG eklendi
import flixel.input.touch.FlxTouch; // Touch desteği için

class FunkinHitbox extends Hitbox {
	public var currentMode:String;
	public var showHints:Bool;
	
	private var _activeTouches:Map<Int, MobileButton> = new Map();

	public function new(?mode:String, ?showHints:Bool, ?globalAlpha:Float = 0.7):Void
	{
		super(mode, globalAlpha, false);
		currentMode = mode;
		this.showHints = showHints;

		if (mode == 'V Slice') 
		{
			var mania = Note.maniaKeys;
			var spacing:Float = ClientPrefs.data.vSliceSpacing;
    
			// Genişliği ayara göre hesapla: %0 iken 140, %100 iken ekranın tam dilimi
			var baseWidth:Int = (mania == 4) ? 140 : 110;
			var targetWidth:Int = Std.int(FlxG.width / mania);
			var dynamicWidth:Int = Std.int(baseWidth + (targetWidth - baseWidth) * spacing);

			if (mania == 4) {
				addHint('buttonNote1', ["NOTE_LEFT"], 0, PlayState.hitboxPositions[0], 0, dynamicWidth, Std.int(FlxG.height), 0xFFC24B99);
				addHint('buttonNote2', ["NOTE_DOWN"], 1, PlayState.hitboxPositions[1], 0, dynamicWidth, Std.int(FlxG.height), 0xFF00FFFF);
				addHint('buttonNote3', ["NOTE_UP"], 2, PlayState.hitboxPositions[2], 0, dynamicWidth, Std.int(FlxG.height), 0xFF12FA05);
				addHint('buttonNote4', ["NOTE_RIGHT"], 3, PlayState.hitboxPositions[3], 0, dynamicWidth, Std.int(FlxG.height), 0xFFF9393F);
			} else {
				for (i in 0...mania) {
					addHint('buttonNote${i+1}', ['${mania}K_NOTE_${i+1}'], i, PlayState.hitboxPositions[i], 0, dynamicWidth, Std.int(FlxG.height), 0xFFFFFFFF);
				}
			}
		}
		else
		{
			var Custom:String = mode != null ? mode : ClientPrefs.data.hitboxMode;
			var maniaHitbox:String = 'Mania ${Note.maniaKeys}';
			if (MobileConfig.hitboxModes.exists(maniaHitbox) && Note.maniaKeys != 4) {
				Custom = maniaHitbox;
			}

			if (!MobileConfig.hitboxModes.exists(Custom))
				throw 'The ${Custom} Hitbox File doesn\'t exists.';

			var currentHint = MobileConfig.hitboxModes.get(Custom).hints;
			if (MobileConfig.hitboxModes.get(Custom).none != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).none;
			if (ClientPrefs.data.extraKeys == 1 && MobileConfig.hitboxModes.get(Custom).single != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).single;
			if (ClientPrefs.data.extraKeys == 2 && MobileConfig.hitboxModes.get(Custom).double != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).double;
			if (ClientPrefs.data.extraKeys == 3 && MobileConfig.hitboxModes.get(Custom).triple != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).triple;
			if (ClientPrefs.data.extraKeys == 4 && MobileConfig.hitboxModes.get(Custom).quad != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).quad;
			if (ClientPrefs.data.extraKeys != 0 && MobileConfig.hitboxModes.get(Custom).hints != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).hints;

			for (buttonData in currentHint)
			{
				var buttonName:String = buttonData.button;
				var buttonIDs:Array<String> = buttonData.buttonIDs;
				var buttonUniqueID:Int = buttonData.buttonUniqueID;
				var buttonX:Float = buttonData.x;
				var buttonY:Float = buttonData.y;
				var buttonWidth:Int = buttonData.width;
				var buttonHeight:Int = buttonData.height;
				var buttonColor = buttonData.color;
				var buttonReturn = buttonData.returnKey;
				var location = ClientPrefs.data.hitboxLocation;
				var addButton:Bool = false;
				if (buttonData.buttonUniqueID == null) buttonUniqueID = -1;

				switch (location) {
					case 'Top':
						if (buttonData.topX != null) buttonX = buttonData.topX;
						if (buttonData.topY != null) buttonY = buttonData.topY;
						if (buttonData.topWidth != null) buttonWidth = buttonData.topWidth;
						if (buttonData.topHeight != null) buttonHeight = buttonData.topHeight;
						if (buttonData.topColor != null) buttonColor = buttonData.topColor;
						if (buttonData.topReturnKey != null) buttonReturn = buttonData.topReturnKey;
					case 'Middle':
						if (buttonData.middleX != null) buttonX = buttonData.middleX;
						if (buttonData.middleY != null) buttonY = buttonData.middleY;
						if (buttonData.middleWidth != null) buttonWidth = buttonData.middleWidth;
						if (buttonData.middleHeight != null) buttonHeight = buttonData.middleHeight;
						if (buttonData.middleColor != null) buttonColor = buttonData.middleColor;
						if (buttonData.middleReturnKey != null) buttonReturn = buttonData.middleReturnKey;
					case 'Bottom':
						if (buttonData.bottomX != null) buttonX = buttonData.bottomX;
						if (buttonData.bottomY != null) buttonY = buttonData.bottomY;
						if (buttonData.bottomWidth != null) buttonWidth = buttonData.bottomWidth;
						if (buttonData.bottomHeight != null) buttonHeight = buttonData.bottomHeight;
						if (buttonData.bottomColor != null) buttonColor = buttonData.bottomColor;
						if (buttonData.bottomReturnKey != null) buttonReturn = buttonData.bottomReturnKey;
				}

				if (ClientPrefs.data.extraKeys == 0 && buttonData.extraKeyMode == 0 ||
				   ClientPrefs.data.extraKeys == 1 && buttonData.extraKeyMode == 1 ||
				   ClientPrefs.data.extraKeys == 2 && buttonData.extraKeyMode == 2 ||
				   ClientPrefs.data.extraKeys == 3 && buttonData.extraKeyMode == 3 ||
				   ClientPrefs.data.extraKeys == 4 && buttonData.extraKeyMode == 4 ||
				   buttonData.extraKeyMode == null)
				{
					addButton = true;
				}

				for (i in 1...5) {
					var buttonString = 'buttonExtra${i}';
					if (buttonData.button == buttonString && buttonReturn == null)
						buttonReturn = ClientPrefs.data.mobileExtraKeyReturns[i-1];
				}
				if (addButton)
					addHint(buttonName, buttonIDs, buttonUniqueID, buttonX, buttonY, buttonWidth, buttonHeight, Util.colorFromString(buttonColor), buttonReturn);
			}
		}

		scrollFactor.set();
		updateTrackedButtons();
		instance = this;
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		for (touch in FlxG.touches.list)
		{
			var currentOverlappedButton:MobileButton = null;

			// Hangi butonun üzerinde olduğumuzu kontrol et
			for (member in members)
			{
				if (member != null && member is MobileButton)
				{
					var btn:MobileButton = cast member;
					if (touch.overlaps(btn))
					{
						currentOverlappedButton = btn;
						break;
					}
				}
			}

			var lastButtonForTouch = _activeTouches.get(touch.touchPointID);

			if (touch.justPressed)
			{
				if (currentOverlappedButton != null)
				{
					currentOverlappedButton.onDown.callback();
					_activeTouches.set(touch.touchPointID, currentOverlappedButton);
				}
			}
			else if (touch.pressed)
			{
				if (currentOverlappedButton != lastButtonForTouch)
				{
					if (lastButtonForTouch != null)
						lastButtonForTouch.onUp.callback(); // Önceki butonu bırak

					if (currentOverlappedButton != null)
						currentOverlappedButton.onDown.callback(); // Yeni butona bas

					_activeTouches.set(touch.touchPointID, currentOverlappedButton);
				}
			}
			else if (touch.justReleased)
			{
				if (lastButtonForTouch != null)
					lastButtonForTouch.onUp.callback();
				
				_activeTouches.remove(touch.touchPointID);
			}
		}
	}

	override function createHintGraphic(Width:Int, Height:Int, Color:Int = 0xFFFFFF, ?isLane:Bool = false):BitmapData
	{
		var guh:Float = globalAlpha;
		var shape:Shape = new Shape();
		shape.graphics.beginFill(Color);
		switch (ClientPrefs.data.hitboxType) {
			case "No Gradient":
				var matrix:Matrix = new Matrix();
				matrix.createGradientBox(Width, Height, 0, 0, 0);
				if (isLane)
					shape.graphics.beginFill(Color);
				else
					shape.graphics.beginGradientFill(RADIAL, [Color, Color], [0, guh], [60, 255], matrix, PAD, RGB, 0);
				shape.graphics.drawRect(0, 0, Width, Height);
				shape.graphics.endFill();
			case "No Gradient (Old)":
				shape.graphics.lineStyle(10, Color, 1);
				shape.graphics.drawRect(0, 0, Width, Height);
				shape.graphics.endFill();
			case "Gradient":
				shape.graphics.lineStyle(3, Color, 1);
				shape.graphics.drawRect(0, 0, Width, Height);
				shape.graphics.lineStyle(0, 0, 0);
				shape.graphics.drawRect(3, 3, Width - 6, Height - 6);
				shape.graphics.endFill();
				if (isLane)
					shape.graphics.beginFill(Color);
				else
					shape.graphics.beginGradientFill(RADIAL, [Color, FlxColor.TRANSPARENT], [guh, 0], [0, 255], null, null, null, 0.5);
				shape.graphics.drawRect(3, 3, Width - 6, Height - 6);
				shape.graphics.endFill();
		}

		var bitmap:BitmapData = new BitmapData(Width, Height, true, 0);
		bitmap.draw(shape);
		return bitmap;
	}

	override public function createHint(name:Array<String>, uniqueID:Int, x:Float, y:Float, width:Int, height:Int, color:Int = 0xFFFFFF, ?returned:String):MobileButton
	{
		var hint:MobileButton = new MobileButton(x, y, returned);
		hint.loadGraphic(createHintGraphic(width, height, color));
		var VSliceAllowed:Bool = (currentMode == 'V Slice' && Note.maniaKeys < 10);
		if (showHints && !VSliceAllowed) {
			var doHeightFix:Bool = false;
			if (height == 144) doHeightFix = true;

			hint.hintUp = new FlxSprite();
			hint.hintUp.loadGraphic(createHintGraphic(width, Math.floor(height * (doHeightFix ? 0.060 : 0.020)), color, true));
			hint.hintUp.x = x;
			hint.hintUp.y = hint.y;
			hint.hintDown = new FlxSprite();
			hint.hintDown.loadGraphic(createHintGraphic(width, Math.floor(height * (doHeightFix ? 0.060 : 0.020)), color, true));
			hint.hintDown.x = x;
			hint.hintDown.y = hint.y + hint.height / (doHeightFix ? 1.060 : 1.020);
		}

		hint.solid = false;
		hint.immovable = true;
		hint.scrollFactor.set();
		hint.alpha = 0.00001;
		hint.IDs = name;
		hint.uniqueID = uniqueID;
		hint.onDown.callback = function()
		{
			onButtonDown?.dispatch(hint, name, uniqueID);
			if (hint.alpha != globalAlpha && !VSliceAllowed)
				hint.alpha = globalAlpha;
			if ((hint.hintUp?.alpha != 0.00001 || hint.hintDown?.alpha != 0.00001) && hint.hintUp != null && hint.hintDown != null && !VSliceAllowed)
				hint.hintUp.alpha = hint.hintDown.alpha = 0.00001;
		}
		hint.onOut.callback = hint.onUp.callback = function()
		{
			onButtonUp?.dispatch(hint, name, uniqueID);
			if (hint.alpha != 0.00001 && !VSliceAllowed)
				hint.alpha = 0.00001;
			if ((hint.hintUp?.alpha != globalAlpha || hint.hintDown?.alpha != globalAlpha) && hint.hintUp != null && hint.hintDown != null && !VSliceAllowed)
				hint.hintUp.alpha = hint.hintDown.alpha = globalAlpha;
		}

		#if FLX_DEBUG
		hint.ignoreDrawDebug = true;
		#end
		return hint;
	}
}
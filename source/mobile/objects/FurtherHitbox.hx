package mobile.objects;

import mobile.Util;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Matrix;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.input.touch.FlxTouch;

#if sys
import sys.FileSystem;
#end

using StringTools;

/**
 * FurtherHitbox — the new (ArkoseLabs "mobile-controls" based) hitbox used by
 * `mobile.MobileControlManager`.
 *
 * Adapted from Psych Engine Online Mobile for Further Engine:
 *  - no `FunkinFileSystem` dependency (mod files via `Mods`/`Paths`),
 *  - Further Engine is 4K only, so `Note.maniaKeys` is replaced with 4,
 *  - `PlayState.hitboxPositions` is computed locally.
 */
class FurtherHitbox extends mobile.Hitbox {
	public var currentMode:String;
	public var showHints:Bool;
	

	public function new(?mode:String, ?showHints:Bool, ?globalAlpha:Float = 0.7):Void
	{
		super(mode, globalAlpha, true); // disableCreation = true, we build everything ourselves
		currentMode = mode;
		this.showHints = showHints;

		var mania:Int = ClientPrefs.data.mania >= 5 ? ClientPrefs.data.mania : 4;

		var effMode:String = mode != null ? mode : ClientPrefs.data.hitboxMode;
		if (effMode == 'V Slice')
		{
			var spacing:Float = ClientPrefs.data.vSliceCustomX ? 0 : ClientPrefs.data.vSliceSpacing;
			if (spacing < 0) spacing = 0;
			if (spacing > 1) spacing = 1;

			// Pozisyonlar: enableVSliceControls strum MERKEZLERİNİ yazar
			var centers:Array<Float> = PlayState.hitboxPositions;
			var compactW:Float = (mania == 4) ? 140 : 110;
			var noteIds:Array<Array<String>> = [
				["NOTE_LEFT"], ["NOTE_DOWN"], ["NOTE_UP"], ["NOTE_RIGHT"],
				["NOTE_5"], ["NOTE_6"], ["NOTE_7"], ["NOTE_8"], ["NOTE_9"]
			];
			var laneColors:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
			for (i in 0...mania)
			{
				var center:Float = centers[i];
				if (center == 0 && i > 0)
					center = (FlxG.width / mania) * (i + 0.5);

				var compactLeft:Float = center - (compactW * 0.5);
				var compactRight:Float = center + (compactW * 0.5);

				var fullLeft:Float = (i == 0) ? 0 : (centers[i - 1] + center) * 0.5;
				var fullRight:Float = (i == mania - 1) ? FlxG.width : (center + centers[i + 1]) * 0.5;
				if (fullRight <= fullLeft) fullRight = fullLeft + compactW;

				var xPos:Float = compactLeft + (fullLeft - compactLeft) * spacing;
				var right:Float = compactRight + (fullRight - compactRight) * spacing;
				var w:Int = Std.int(Math.max(40, right - xPos));
				var zoneY:Float = 0;
				var zoneH:Int = Std.int(FlxG.height);
				if (ClientPrefs.data.vSliceCustomZones && i < 4 && ClientPrefs.data.vSliceButtonY.length >= 4 && ClientPrefs.data.vSliceButtonHeight.length >= 4)
				{
					zoneY = ClientPrefs.data.vSliceButtonY[i] * FlxG.height;
					zoneH = Std.int(Math.max(40, Math.min(FlxG.height - zoneY, ClientPrefs.data.vSliceButtonHeight[i] * FlxG.height)));
				}
				addHint('buttonNote${i+1}', noteIds[i], i, xPos, zoneY, w, zoneH, laneColors[i % 4]);
			}

			// EKSTRA: ekranın ortasına dokununca ekstra buton sayılır (dodge/ring mekaniği için)
			// otomatik tespit (0) veya manuel >=1 ise ortada geniş bir dokunma alanı olur
			if (PlayState.getExtraKeys() >= 1)
				addHint('buttonExtra', ["EXTRA_1"], 100, FlxG.width / 2 - 75, 0, 150, Std.int(FlxG.height), 0xFFFFFFFF);
		}
		else
		{
			var Custom:String = mode != null ? mode : ClientPrefs.data.hitboxMode;
			var maniaHitbox:String = 'Mania $mania';
			if (MobileConfig.hitboxModes.exists(maniaHitbox) && mania != 4) {
				Custom = maniaHitbox;
			}

			if (!MobileConfig.hitboxModes.exists(Custom))
				throw 'The ${Custom} Hitbox File doesn\'t exists.';

			var currentHint = MobileConfig.hitboxModes.get(Custom).hints;
			if (MobileConfig.hitboxModes.get(Custom).none != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).none;
			if (PlayState.getExtraKeys() == 1 && MobileConfig.hitboxModes.get(Custom).single != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).single;
			if (PlayState.getExtraKeys() == 2 && MobileConfig.hitboxModes.get(Custom).double != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).double;
			if (PlayState.getExtraKeys() == 3 && MobileConfig.hitboxModes.get(Custom).triple != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).triple;
			if (PlayState.getExtraKeys() == 4 && MobileConfig.hitboxModes.get(Custom).quad != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).quad;
			if (PlayState.getExtraKeys() != 0 && MobileConfig.hitboxModes.get(Custom).hints != null)
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

				if (PlayState.getExtraKeys() == 0 && buttonData.extraKeyMode == 0 ||
				   PlayState.getExtraKeys() == 1 && buttonData.extraKeyMode == 1 ||
				   PlayState.getExtraKeys() == 2 && buttonData.extraKeyMode == 2 ||
				   PlayState.getExtraKeys() == 3 && buttonData.extraKeyMode == 3 ||
				   PlayState.getExtraKeys() == 4 && buttonData.extraKeyMode == 4 ||
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

		for (member in members)
		{
			if (member != null && member is MobileButton)
			{
				var btn:MobileButton = cast member;
				if (btn.justPressed)
				{
					onButtonDown.dispatch(btn, btn.IDs, btn.uniqueID);
					updateHintVisuals(btn, true);
				}
				if (btn.justReleased)
				{
					onButtonUp.dispatch(btn, btn.IDs, btn.uniqueID);
					updateHintVisuals(btn, false);
				}
			}
		}
	}

	function updateHintVisuals(btn:MobileButton, pressed:Bool)
	{
		var VSliceAllowed:Bool = (currentMode == 'V Slice');

		if (pressed)
		{
			if (btn.alpha != globalAlpha && !VSliceAllowed)
				btn.alpha = globalAlpha;
			if ((btn.hintUp?.alpha != 0.00001 || btn.hintDown?.alpha != 0.00001) && btn.hintUp != null && btn.hintDown != null && !VSliceAllowed)
				btn.hintUp.alpha = btn.hintDown.alpha = 0.00001;
		}
		else
		{
			if (btn.alpha != 0.00001 && !VSliceAllowed)
				btn.alpha = 0.00001;
			if ((btn.hintUp?.alpha != globalAlpha || btn.hintDown?.alpha != globalAlpha) && btn.hintUp != null && btn.hintDown != null && !VSliceAllowed)
				btn.hintUp.alpha = btn.hintDown.alpha = globalAlpha;
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
		var VSliceAllowed:Bool = (currentMode == 'V Slice');
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
		// NOTE: sinyaller ve görsel geri bildirim, çift tetiklemeyi önlemek için
		// `update()` içindeki `justPressed`/`justReleased` izleyicisinden tetiklenir.

		#if FLX_DEBUG
		hint.ignoreDrawDebug = true;
		#end
		return hint;
	}
}

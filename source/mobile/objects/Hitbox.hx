package mobile.objects;

import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Matrix;
import flixel.FlxG;
import flixel.FlxSprite;

using StringTools;

/**
 * Hitbox — COMPATIBILITY WRAPPER (eski API, yeni motor).
 *
 * Eski kullanım aynen çalışır:
 *   addMobileControls() / mode 3  →  yeni `Hitbox` (yeni görünüm, yeni JSON
 *   hitbox modları, gradient, ipuçları, ekstra tuşlar).
 *
 * Butonlar artık `mobile.MobileConfig.hitboxModes` (yeni format JSON) ve yeni
 * görsel stilleri ile oluşturulur; giriş sistemi eski `MobileInputManager` +
 * `inputIDs` üzerinden aynen çalışır.
 */
class Hitbox extends MobileInputManager implements FMobileControls
{
	public var buttonLeft:TouchButton = new TouchButton(0, 0, [MobileInputID.HITBOX_LEFT, MobileInputID.NOTE_LEFT]);
	public var buttonDown:TouchButton = new TouchButton(0, 0, [MobileInputID.HITBOX_DOWN, MobileInputID.NOTE_DOWN]);
	public var buttonUp:TouchButton = new TouchButton(0, 0, [MobileInputID.HITBOX_UP, MobileInputID.NOTE_UP]);
	public var buttonRight:TouchButton = new TouchButton(0, 0, [MobileInputID.HITBOX_RIGHT, MobileInputID.NOTE_RIGHT]);
	public var buttonExtra:TouchButton = new TouchButton(0, 0, [MobileInputID.EXTRA_1]);
	public var buttonExtra2:TouchButton = new TouchButton(0, 0, [MobileInputID.EXTRA_2]);
	public var buttonExtra3:TouchButton = new TouchButton(0, 0, [MobileInputID.EXTRA_1]);
	public var buttonExtra4:TouchButton = new TouchButton(0, 0, [MobileInputID.EXTRA_2]);

	public var instance:MobileInputManager;
	public var onButtonDown:FlxTypedSignal<TouchButton->Void> = new FlxTypedSignal<TouchButton->Void>();
	public var onButtonUp:FlxTypedSignal<TouchButton->Void> = new FlxTypedSignal<TouchButton->Void>();

	public var buttonFromName:Map<String, TouchButton> = [];

	var globalAlpha:Float = 0.7;

	/**
	 * Create the zone.
	 */
	public function new(?extraMode:ExtraActions = NONE)
	{
		super();

		globalAlpha = ClientPrefs.data.hitboxAlpha;

		var mania:Int = 4;
		var extraKeys:Int = PlayState.getExtraKeys(); // 0 = otomatik (şarkıya göre), 1-4 = manuel
		if (extraMode == SINGLE && extraKeys < 1) extraKeys = 1;
		if (extraMode == DOUBLE && extraKeys < 2) extraKeys = 2;

		var Custom:String = ClientPrefs.data.hitboxMode != null ? ClientPrefs.data.hitboxMode : 'Normal (New)';
		if (!MobileConfig.hitboxModes.exists(Custom))
		{
			trace('Hitbox: "$Custom" modu bulunamadı, "Normal (New)" kullanılıyor.');
			Custom = 'Normal (New)';
		}

		if (!MobileConfig.hitboxModes.exists(Custom))
		{
			// Hiçbir mod yüklenmediyse eski tarz 4 şerit çiz (yeni görünümle)
			buildClassicLanes(mania);
		}
		else
		{
			var currentHint = MobileConfig.hitboxModes.get(Custom).hints;
			if (MobileConfig.hitboxModes.get(Custom).none != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).none;
			if (extraKeys == 1 && MobileConfig.hitboxModes.get(Custom).single != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).single;
			if (extraKeys == 2 && MobileConfig.hitboxModes.get(Custom).double != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).double;
			if (extraKeys == 3 && MobileConfig.hitboxModes.get(Custom).triple != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).triple;
			if (extraKeys == 4 && MobileConfig.hitboxModes.get(Custom).quad != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).quad;
			if (extraKeys != 0 && MobileConfig.hitboxModes.get(Custom).hints != null)
				currentHint = MobileConfig.hitboxModes.get(Custom).hints;

			if (currentHint == null) currentHint = MobileConfig.hitboxModes.get(Custom).hints;

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
				var location = ClientPrefs.data.hitboxLocation;
				var addButton:Bool = false;

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

				if (extraKeys == 0 && buttonData.extraKeyMode == 0 ||
				   extraKeys == 1 && buttonData.extraKeyMode == 1 ||
				   extraKeys == 2 && buttonData.extraKeyMode == 2 ||
				   extraKeys == 3 && buttonData.extraKeyMode == 3 ||
				   extraKeys == 4 && buttonData.extraKeyMode == 4 ||
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
					createHintButton(buttonName, buttonIDs, buttonUniqueID, buttonX, buttonY, buttonWidth, buttonHeight, Util.colorFromString(buttonColor), buttonReturn);
			}
		}

		scrollFactor.set();
		updateTrackedButtons();

		instance = this;
	}

	function buildClassicLanes(mania:Int):Void
	{
		var laneWidth:Int = Std.int(FlxG.width / mania);
		var colors:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
		var ids:Array<Array<String>> = [["NOTE_LEFT"], ["NOTE_DOWN"], ["NOTE_UP"], ["NOTE_RIGHT"]];
		for (i in 0...mania)
			createHintButton('buttonNote${i + 1}', ids[i], i, laneWidth * i, 0, laneWidth, Std.int(FlxG.height), colors[i], null);
	}

	function createHintButton(buttonName:String, buttonIDs:Array<String>, buttonUniqueID:Int, x:Float, y:Float, width:Int, height:Int, color:Int = 0xFFFFFF, ?returned:String):Void
	{
		if (buttonIDs == null) buttonIDs = [buttonName.toUpperCase()];

		var hint:TouchButton = new TouchButton(x, y);
		hint.loadGraphic(createHintGraphic(width, height, color));

		if (ClientPrefs.data.hitboxHint) {
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
		hint.IDs = buttonIDs;
		hint.uniqueID = buttonUniqueID;
		hint.returnedKey = returned;

		// Eski giriş sistemi ID'leri (Controls / MobileInputManager)
		var inputIDs:Array<MobileInputID> = [];
		var fieldName:String = getFieldNameForButton(buttonName, buttonIDs);
		for (strId in buttonIDs)
		{
			var mapped:Array<MobileInputID> = mapHitboxID(strId);
			for (m in mapped) if (inputIDs.indexOf(m) == -1) inputIDs.push(m);
		}
		if (inputIDs.length == 0 && Reflect.hasField(this, fieldName))
			inputIDs = (Reflect.field(this, fieldName):TouchButton).inputIDs.copy();
		hint.inputIDs = inputIDs;

		hint.name = buttonName;
		buttonFromName.set(buttonName, hint);

		// Alanı güncelle (buttonLeft/buttonDown/... veya buttonExtra1..4)
		if (Reflect.hasField(this, fieldName))
			Reflect.setField(this, fieldName, hint);

		add(hint);
	}

	function getFieldNameForButton(buttonName:String, buttonIDs:Array<String>):String
	{
		if (buttonName.startsWith('buttonNote')) {
			return switch (buttonName) {
				case 'buttonNote1': 'buttonLeft';
				case 'buttonNote2': 'buttonDown';
				case 'buttonNote3': 'buttonUp';
				case 'buttonNote4': 'buttonRight';
				default: 'buttonRight';
			};
		}
		if (buttonName.startsWith('buttonExtra')) {
			return switch (buttonName) {
				case 'buttonExtra1': 'buttonExtra';
				case 'buttonExtra2': 'buttonExtra2';
				case 'buttonExtra3': 'buttonExtra3';
				case 'buttonExtra4': 'buttonExtra4';
				default: 'buttonExtra';
			};
		}
		return buttonName;
	}

	function mapHitboxID(strId:String):Array<MobileInputID>
	{
		return switch (strId.toUpperCase()) {
			case 'NOTE_LEFT': [MobileInputID.HITBOX_LEFT, MobileInputID.NOTE_LEFT];
			case 'NOTE_DOWN': [MobileInputID.HITBOX_DOWN, MobileInputID.NOTE_DOWN];
			case 'NOTE_UP': [MobileInputID.HITBOX_UP, MobileInputID.NOTE_UP];
			case 'NOTE_RIGHT': [MobileInputID.HITBOX_RIGHT, MobileInputID.NOTE_RIGHT];
			case 'EXTRA_1': [MobileInputID.EXTRA_1];
			case 'EXTRA_2': [MobileInputID.EXTRA_2];
			default: [MobileInputID.fromString(strId)];
		};
	}

	public function getButton(btnName:String):TouchButton
		return buttonFromName.get(btnName);

	function createHintGraphic(Width:Int, Height:Int, Color:Int = 0xFFFFFF, ?isLane:Bool = false):BitmapData
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

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		for (member in members)
		{
			if (member != null && member is TouchButton)
			{
				var btn:TouchButton = cast member;
				if (btn.justPressed)
				{
					onButtonDown.dispatch(btn);
					if (btn.alpha != globalAlpha) btn.alpha = globalAlpha;
					if ((btn.hintUp?.alpha != 0.00001 || btn.hintDown?.alpha != 0.00001) && btn.hintUp != null && btn.hintDown != null)
						btn.hintUp.alpha = btn.hintDown.alpha = 0.00001;
				}
				if (btn.justReleased)
				{
					onButtonUp.dispatch(btn);
					if (btn.alpha != 0.00001) btn.alpha = 0.00001;
					if ((btn.hintUp?.alpha != globalAlpha || btn.hintDown?.alpha != globalAlpha) && btn.hintUp != null && btn.hintDown != null)
						btn.hintUp.alpha = btn.hintDown.alpha = globalAlpha;
				}
			}
		}
	}

	/**
	 * Clean up memory.
	 */
	override function destroy()
	{
		super.destroy();
		onButtonUp.destroy();
		onButtonDown.destroy();

		for (fieldName in Reflect.fields(this))
		{
			var field = Reflect.field(this, fieldName);
			if (Std.isOfType(field, TouchButton))
				Reflect.setField(this, fieldName, FlxDestroyUtil.destroy(field));
		}
	}
}

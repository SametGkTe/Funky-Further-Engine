package mobile.objects;

import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.graphics.frames.FlxTileFrames;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.utils.Assets;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.FlxG;

#if sys
import sys.FileSystem;
#end

using StringTools;

@:keep
class TouchPad extends MobileInputManager implements FMobileControls
{
	public var buttonLeft:TouchButton = new TouchButton(0, 0, [MobileInputID.LEFT, MobileInputID.NOTE_LEFT]);
	public var buttonUp:TouchButton = new TouchButton(0, 0, [MobileInputID.UP, MobileInputID.NOTE_UP]);
	public var buttonRight:TouchButton = new TouchButton(0, 0, [MobileInputID.RIGHT, MobileInputID.NOTE_RIGHT]);
	public var buttonDown:TouchButton = new TouchButton(0, 0, [MobileInputID.DOWN, MobileInputID.NOTE_DOWN]);
	public var buttonLeft2:TouchButton = new TouchButton(0, 0, [MobileInputID.LEFT2, MobileInputID.NOTE_LEFT]);
	public var buttonUp2:TouchButton = new TouchButton(0, 0, [MobileInputID.UP2, MobileInputID.NOTE_UP]);
	public var buttonRight2:TouchButton = new TouchButton(0, 0, [MobileInputID.RIGHT2, MobileInputID.NOTE_RIGHT]);
	public var buttonDown2:TouchButton = new TouchButton(0, 0, [MobileInputID.DOWN2, MobileInputID.NOTE_DOWN]);
	public var buttonA:TouchButton = new TouchButton(0, 0, [MobileInputID.A]);
	public var buttonB:TouchButton = new TouchButton(0, 0, [MobileInputID.B]);
	public var buttonC:TouchButton = new TouchButton(0, 0, [MobileInputID.C]);
	public var buttonD:TouchButton = new TouchButton(0, 0, [MobileInputID.D]);
	public var buttonE:TouchButton = new TouchButton(0, 0, [MobileInputID.E]);
	public var buttonF:TouchButton = new TouchButton(0, 0, [MobileInputID.F]);
	public var buttonG:TouchButton = new TouchButton(0, 0, [MobileInputID.G]);
	public var buttonH:TouchButton = new TouchButton(0, 0, [MobileInputID.H]);
	public var buttonI:TouchButton = new TouchButton(0, 0, [MobileInputID.I]);
	public var buttonJ:TouchButton = new TouchButton(0, 0, [MobileInputID.J]);
	public var buttonK:TouchButton = new TouchButton(0, 0, [MobileInputID.K]);
	public var buttonL:TouchButton = new TouchButton(0, 0, [MobileInputID.L]);
	public var buttonM:TouchButton = new TouchButton(0, 0, [MobileInputID.M]);
	public var buttonN:TouchButton = new TouchButton(0, 0, [MobileInputID.N]);
	public var buttonO:TouchButton = new TouchButton(0, 0, [MobileInputID.O]);
	public var buttonP:TouchButton = new TouchButton(0, 0, [MobileInputID.P]);
	public var buttonQ:TouchButton = new TouchButton(0, 0, [MobileInputID.Q]);
	public var buttonR:TouchButton = new TouchButton(0, 0, [MobileInputID.R]);
	public var buttonS:TouchButton = new TouchButton(0, 0, [MobileInputID.S]);
	public var buttonT:TouchButton = new TouchButton(0, 0, [MobileInputID.T]);
	public var buttonU:TouchButton = new TouchButton(0, 0, [MobileInputID.U]);
	public var buttonV:TouchButton = new TouchButton(0, 0, [MobileInputID.V]);
	public var buttonW:TouchButton = new TouchButton(0, 0, [MobileInputID.W]);
	public var buttonX:TouchButton = new TouchButton(0, 0, [MobileInputID.X]);
	public var buttonY:TouchButton = new TouchButton(0, 0, [MobileInputID.Y]);
	public var buttonZ:TouchButton = new TouchButton(0, 0, [MobileInputID.Z]);
	public var buttonExtra:TouchButton = new TouchButton(0, 0, [MobileInputID.EXTRA_1]);
	public var buttonExtra2:TouchButton = new TouchButton(0, 0, [MobileInputID.EXTRA_2]);

	public var instance:MobileInputManager;
	public var onButtonDown:FlxTypedSignal<TouchButton->Void> = new FlxTypedSignal<TouchButton->Void>();
	public var onButtonUp:FlxTypedSignal<TouchButton->Void> = new FlxTypedSignal<TouchButton->Void>();

	public var buttonFromName:Map<String, TouchButton> = [];

	public function new(DPad:String, Action:String, ?Extra:ExtraActions = NONE)
	{
		super();

		if (DPad != "NONE")
		{
			if (!MobileConfig.dpadModes.exists(DPad))
				MobileConfig.ensureBuiltinDpadModes();

			if (MobileConfig.dpadModes.exists(DPad))
			{
				for (buttonData in MobileConfig.dpadModes.get(DPad).buttons)
					addButtonFromData(buttonData);
			}
		}

		if (Action != "NONE")
		{
			if (!MobileConfig.actionModes.exists(Action))
				MobileConfig.ensureBuiltinActionModes();

			if (!MobileConfig.actionModes.exists(Action) && Action == MobileConfig.FREEPLAY_ACTION_MODE
				&& MobileConfig.actionModes.exists('A_B_C_X_Y_Z'))
				Action = 'A_B_C_X_Y_Z';

			if (MobileConfig.actionModes.exists(Action))
			{
				for (buttonData in MobileConfig.actionModes.get(Action).buttons)
					addButtonFromData(buttonData);
			}
		}

		switch (Extra)
		{
			case SINGLE:
				add(buttonExtra = createButton(0, FlxG.height - 137, 's', 0xFF0066FF, [MobileInputID.EXTRA_1]));
				setExtrasPos();
			case DOUBLE:
				add(buttonExtra = createButton(0, FlxG.height - 137, 's', 0xFF0066FF, [MobileInputID.EXTRA_1]));
				add(buttonExtra2 = createButton(FlxG.width - 132, FlxG.height - 137, 'g', 0xA6FF00, [MobileInputID.EXTRA_2]));
				setExtrasPos();
			case NONE: 
		}

		alpha = ClientPrefs.data.controlsAlpha;
		scrollFactor.set();
		updateTrackedButtons();

		instance = this;
	}

	function addButtonFromData(buttonData:ButtonsData):Void
	{
		var buttonName:String = buttonData.button;

		var buttonIDs:Array<String> = buttonData.buttonIDs;
		if (buttonIDs == null) buttonIDs = [buttonName.substr(6).toUpperCase()];

		var inputIDs:Array<MobileInputID> = [];
		for (strId in buttonIDs)
		{
			var id:MobileInputID = MobileInputID.fromString(strId);
			if (id != MobileInputID.NONE && inputIDs.indexOf(id) == -1) inputIDs.push(id);
		}
		
		if (inputIDs.length == 0)
		{
			var existing:TouchButton = Reflect.field(this, buttonName);
			if (existing != null) inputIDs = existing.inputIDs.copy();
		}

		var scale:Float = buttonData.scale != null ? buttonData.scale : 1.0;
		var button:TouchButton = createButton(buttonData.x, buttonData.y, buttonData.graphic,
			Util.colorFromString(buttonData.color), inputIDs, scale, buttonData.returnKey);

		button.name = buttonName;
		button.IDs = buttonIDs;
		buttonFromName.set(buttonName, button);

		Reflect.setField(this, buttonName, button);
		add(button);
	}

	public function getButton(btnName:String):TouchButton
		return buttonFromName.get(btnName);

	override public function destroy()
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

	public function setExtrasDefaultPos()
	{
		var int:Int = 0;

		if (MobileData.save.data.extraData == null)
			MobileData.save.data.extraData = new Array();

		for (button in Reflect.fields(this))
		{
			var field = Reflect.field(this, button);
			if (button.toLowerCase().contains('extra') && Std.isOfType(field, TouchButton))
			{
				MobileData.save.data.extraData[int] = FlxPoint.get(field.x, field.y);
				++int;
			}
		}
		MobileData.save.flush();
	}

	public function setExtrasPos()
	{
		var int:Int = 0;
		if (MobileData.save.data.extraData == null)
			setExtrasDefaultPos();

		for (button in Reflect.fields(this))
		{
			var field = Reflect.field(this, button);
			if (button.toLowerCase().contains('extra') && Std.isOfType(field, TouchButton))
			{
				if (MobileData.save.data.extraData.length > int)
					setExtrasDefaultPos();
				var point = MobileData.save.data.extraData[int];
				field.x = point.x;
				field.y = point.y;
				int++;
			}
		}
	}

	private function createButton(X:Float, Y:Float, Graphic:String, ?Color:FlxColor = 0xFFFFFF,
		?IDs:Array<MobileInputID> = null, ?scale:Float = 1.0, ?returned:String = null):TouchButton
	{
		var button = new TouchButton(X, Y, IDs);

		var frames:FlxGraphic = null;
		var graphicName:String = Graphic.toLowerCase();
		var paths:Array<String> = [
			MobileConfig.mobileFolderPath + 'MobilePad/Textures/$graphicName.png',
			'assets/mobile/MobilePad/Textures/$graphicName.png',
			MobileConfig.mobileFolderPath + 'MobilePad/Textures/default.png',
			'assets/mobile/MobilePad/Textures/default.png'
		];

		#if MODS_ALLOWED
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'mobile/MobilePad/Textures/'))
		{
			var candidate:String = haxe.io.Path.join([folder, '$graphicName.png']);
			if (FileSystem.exists(candidate))
			{
				frames = FlxGraphic.fromBitmapData(BitmapData.fromFile(candidate));
				break;
			}
		}
		#end

		if (frames == null)
		{
			for (path in paths)
			{
				if (Assets.exists(path))
				{
					frames = FlxGraphic.fromBitmapData(Assets.getBitmapData(path));
					break;
				}
			}
		}

		if (frames == null)
			frames = FlxGraphic.fromBitmapData(new BitmapData(2, 1, true, 0));

		button.scale.set(scale, scale);
		button.frames = FlxTileFrames.fromGraphic(frames, FlxPoint.get(Std.int(frames.width / 2), frames.height));

		button.updateHitbox();
		button.updateLabelPosition();

		button.bounds.makeGraphic(Std.int(button.width - 50), Std.int(button.height - 50), FlxColor.TRANSPARENT);
		button.centerBounds();

		button.immovable = true;
		button.solid = button.moves = false;
		button.antialiasing = ClientPrefs.data.antialiasing;
		button.tag = Graphic.toUpperCase();
		button.color = Color;
		button.returnedKey = returned;

		return button;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		for (member in members)
		{
			if (member != null && member is TouchButton)
			{
				var btn:TouchButton = cast member;
				if (btn.justPressed) onButtonDown.dispatch(btn);
				if (btn.justReleased) onButtonUp.dispatch(btn);
			}
		}
	}

	override function set_alpha(Value):Float
	{
		forEachAlive((button:TouchButton) -> button.parentAlpha = Value);
		return super.set_alpha(Value);
	}
}
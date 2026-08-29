package mobile.objects;

import mobile.MobilePad;
import flixel.graphics.frames.FlxTileFrames;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.utils.Assets;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.input.touch.FlxTouch;

#if sys
import sys.FileSystem;
#end

using StringTools;

class FurtherPad extends MobilePad {
	
	override public function createVirtualButton(x:Float, y:Float, framePath:String, ?scale:Float = 1.0, ?ColorS:Int = 0xFFFFFF, ?returned:String):MobileButton {
		var frames:FlxGraphic = null;
		var paths:Array<String> = [
			MobileConfig.mobileFolderPath + 'MobilePad/Textures/$framePath.png',
			'assets/mobile/MobilePad/Textures/$framePath.png',
			MobileConfig.mobileFolderPath + 'MobilePad/Textures/default.png',
			'assets/mobile/MobilePad/Textures/default.png'
		];

		#if MODS_ALLOWED
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'mobile/MobilePad/Textures/'))
		{
			var candidate:String = haxe.io.Path.join([folder, '$framePath.png']);
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

		var button = new MobileButton(x, y, returned);
		button.scale.set(scale, scale);
		button.frames = FlxTileFrames.fromGraphic(frames, FlxPoint.get(Std.int(frames.width / 2), frames.height));

		button.updateHitbox();
		button.updateLabelPosition();

		button.bounds.makeGraphic(Std.int(button.width - 50), Std.int(button.height - 50), FlxColor.TRANSPARENT);
		button.centerBounds();

		button.immovable = true;
		button.solid = button.moves = false;
		button.antialiasing = ClientPrefs.data.antialiasing;
		button.tag = framePath.toUpperCase();

		if (ColorS != -1) button.color = ColorS;
		return button;
	}

	public function new(DPad:String, Action:String, globalAlpha:Float = 0.7) {
		super(DPad, Action, globalAlpha);
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
					onButtonDown.dispatch(btn, btn.IDs, btn.uniqueID);
				if (btn.justReleased)
					onButtonUp.dispatch(btn, btn.IDs, btn.uniqueID);
			}
		}
	}
}
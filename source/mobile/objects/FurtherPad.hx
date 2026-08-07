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

/**
 * FurtherPad — Further Engine'in dokunmatik tuş takımı.
 * `mobile.MobileControlManager` tarafından kullanılır; doku ve düzenler
 * `FEMobileConfig`'ten (MobilePad/*.json) okunur, mod dokuları desteklenir.
 *
 * Tasarım temeli: MIT lisanslı mobile-controls (bkz. CREDITS.md).
 */
class FurtherPad extends MobilePad {
	// Her parmak için son basılan butonu hatırlar (çoklu dokunma takibi)

	override public function createVirtualButton(x:Float, y:Float, framePath:String, ?scale:Float = 1.0, ?ColorS:Int = 0xFFFFFF, ?returned:String):MobileButton {
		var frames:FlxGraphic;
		final path:String = MobileConfig.mobileFolderPath + 'MobilePad/Textures/$framePath.png';

		#if MODS_ALLOWED
		var modsPath:String = null;
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'mobile/MobilePad/Textures/')) {
			var candidate:String = haxe.io.Path.join([folder, '$framePath.png']);
			if (FileSystem.exists(candidate)) {
				modsPath = candidate;
				break;
			}
		}
		if (modsPath != null)
			frames = FlxGraphic.fromBitmapData(BitmapData.fromFile(modsPath));
		else #end if(Assets.exists(path))
			frames = FlxGraphic.fromBitmapData(Assets.getBitmapData(path));
		else
			frames = FlxGraphic.fromBitmapData(Assets.getBitmapData(MobileConfig.mobileFolderPath + 'MobilePad/Textures/default.png'));

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

	// --- INPUT GÜNCELLEMESİ: her butonun durumunu izleyip SİNYALLERİ TAM OLARAK
	// BİR KEZ tetikler (çift tetiklemeyi önler; kaydırma/slide desteği temel
	// MobileButton tarafından `allowSwiping` ile sağlanır) ---
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

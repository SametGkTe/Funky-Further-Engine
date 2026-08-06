package mobile.objects;

import mobile.MobilePad;
import flixel.graphics.frames.FlxTileFrames;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.utils.Assets;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.FlxG; // Dokunmatik kontroller için eklendi
import flixel.input.touch.FlxTouch; // Dokunmatik kontroller için eklendi

class FunkinMobilePad extends MobilePad {
	// Aktif dokunuşları ve hangi butonun üzerinde olduklarını takip eden Map
	private var _activeTouches:Map<Int, MobileButton> = new Map();

	override public function createVirtualButton(x:Float, y:Float, framePath:String, ?scale:Float = 1.0, ?ColorS:Int = 0xFFFFFF, ?returned:String):MobileButton {
		var frames:FlxGraphic;
		final path:String = MobileConfig.mobileFolderPath + 'MobilePad/Textures/$framePath.png';
		#if MODS_ALLOWED
		final modsPath:String = Paths.modFolders('mobile/MobilePad/Textures/$framePath.png');
		if(FunkinFileSystem.exists(modsPath))
			frames = FlxGraphic.fromBitmapData(FunkinFileSystem.getBitmapData(modsPath));
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

	// --- INPUT GÜNCELLEMESİ: SLIDE VE TAKILMA SORUNUNU ÇÖZER ---
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		for (touch in FlxG.touches.list)
		{
			var currentOverlappedButton:MobileButton = null;

			// Mevcut butonlardan hangisinin üzerinde olduğumuzu bulalım
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
				// Kaydırma (Slide) Mantığı: Eğer parmak başka bir butona geçtiyse
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
				// Parmak ekrandan çekildiğinde takılı kalmaması için temizlik yap
				if (lastButtonForTouch != null)
					lastButtonForTouch.onUp.callback();
				
				_activeTouches.remove(touch.touchPointID);
			}
		}
	}
}
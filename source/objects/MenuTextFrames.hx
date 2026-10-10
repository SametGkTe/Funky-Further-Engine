package objects;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

/**
 * Custom Menus için atlas'sız metin buton üretir — MainMenuState'in
 * 'idle' / 'selected' animasyon sözleşmesine birebir uyar (Sparrow XML).
 * İstersen mod, mainmenu/menu_custom_<id> atlas'ı sağlayarak bunu ezer.
 */
class MenuTextFrames
{
	static inline var W:Int = 460;
	static inline var H:Int = 110;

	public static function make(prefix:String, label:String):FlxAtlasFrames
	{
		var bmp:BitmapData = new BitmapData(W, H * 2, 0x00000000);
		drawFrame(bmp, 0, label, false);
		drawFrame(bmp, H, label, true);

		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bmp, false, 'menutext_' + prefix);
		graphic.persist = true;

		var xml:String = '<?xml version="1.0" encoding="utf-8"?>\n'
			+ '<TextureAtlas>\n'
			+ '<SubTexture name="$prefix idle" x="0" y="0" width="$W" height="$H" frameX="0" frameY="0" frameWidth="$W" frameHeight="$H"/>\n'
			+ '<SubTexture name="$prefix selected" x="0" y="$H" width="$W" height="$H" frameX="0" frameY="0" frameWidth="$W" frameHeight="$H"/>\n'
			+ '</TextureAtlas>';
		return FlxAtlasFrames.fromSparrow(graphic, xml);
	}

	static function drawFrame(bmp:BitmapData, yOff:Int, label:String, selected:Bool):Void
	{
		var fontName:String = 'assets/fonts/vcr.ttf';
		try
		{
			fontName = Assets.getFont('assets/fonts/title.ttf').fontName;
		}
		catch (e:Dynamic) {}

		var tf:TextField = new TextField();
		var fmt:TextFormat = new TextFormat(fontName, 54, 0xFFFFFFFF, true);
		fmt.align = TextFormatAlign.CENTER;
		tf.defaultTextFormat = fmt;
		tf.selectable = false;
		tf.mouseEnabled = false;
		tf.width = W;
		tf.height = H;
		tf.text = label != null ? label : '';

		// kontur: siyah gölge (8 yön)
		tf.textColor = 0xFF000000;
		for (dx in -2...3)
			for (dy in -2...3)
			{
				if (dx == 0 && dy == 0)
					continue;
				var m:Matrix = new Matrix();
				m.translate(dx, yOff + dy);
				bmp.draw(tf, m);
			}

		// seçili: pembe glow
		if (selected)
		{
			tf.textColor = 0xFFFF2E63;
			for (dx in -4...5)
				for (dy in -4...5)
				{
					if (dx == 0 && dy == 0)
						continue;
					var mg:Matrix = new Matrix();
					mg.translate(dx * 0.7, yOff + dy * 0.7);
					bmp.draw(tf, mg);
				}
		}

		// gövde
		tf.textColor = 0xFFFFFFFF;
		var m2:Matrix = new Matrix();
		m2.translate(0, yOff);
		bmp.draw(tf, m2);
	}
}

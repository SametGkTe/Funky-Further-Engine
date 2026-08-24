package objects;

import backend.SafeMode;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

class SafeModeBadge extends FlxSpriteGroup
{
	public static function addTo(state:flixel.FlxState):SafeModeBadge
	{
		if (!SafeMode.active) return null;
		var badge = new SafeModeBadge();
		state.add(badge);
		return badge;
	}

	public function new()
	{
		super();
		var width:Int = 330;
		var height:Int = 54;
		x = (FlxG.width - width) * 0.5;
		y = 8;
		scrollFactor.set();

		var shadow = new FlxSprite(3, 3).makeGraphic(width, height, 0xAA000000);
		shadow.scrollFactor.set();
		add(shadow);

		var bg = new FlxSprite().makeGraphic(width, height, 0xEE241313);
		bg.scrollFactor.set();
		add(bg);

		var line = new FlxSprite(0, height - 4).makeGraphic(width, 4, 0xFFFFD740);
		line.scrollFactor.set();
		add(line);

		var title = new FlxText(0, 5, width, 'GÜVENLİ MOD', 21);
		title.setFormat(Paths.font('vcr.ttf'), 21, 0xFFFFD740, FlxTextAlign.CENTER);
		title.scrollFactor.set();
		add(title);

		var subtitle = new FlxText(0, 29, width, 'MODLAR DEVRE DIŞI', 14);
		subtitle.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.WHITE, FlxTextAlign.CENTER);
		subtitle.scrollFactor.set();
		add(subtitle);
	}
}

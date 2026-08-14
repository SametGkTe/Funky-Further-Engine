package vslice.menus.freeplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import vslice.menus.StickerSubState;
import vslice.menus.freeplay.FreeplayState.FreeplayStateParams;
import backend.MusicBeatState;

/**
 * Thin host for V-Slice Freeplay.
 * Does NOT build MainMenu (that was causing null crashes and extra load).
 */
class FreeplayHostState extends MusicBeatState
{
	var fpParams:Null<FreeplayStateParams>;
	var fpStickers:Null<StickerSubState>;

	public function new(?params:FreeplayStateParams, ?stickers:StickerSubState)
	{
		super();
		fpParams = params;
		fpStickers = stickers;
	}

	override function create():Void
	{
		super.create();

		persistentUpdate = false;
		persistentDraw = true;

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.scrollFactor.set();
		add(bg);

		openSubState(new FreeplayState(fpParams, fpStickers));
	}
}

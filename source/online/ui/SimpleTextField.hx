package online.ui;

import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.ui.PsychUIInputText;

/**
 * Thin wrapper so lobby code doesn't depend on flixel-ui FlxInputText.
 */
class SimpleTextField extends FlxSpriteGroup {
	public var input:PsychUIInputText;

	public function new(x:Float, y:Float, width:Int, text:String = "", size:Int = 16) {
		super(x, y);
		input = new PsychUIInputText(0, 0, width, text, size);
		input.bg.color = FlxColor.fromRGB(20, 24, 40);
		input.behindText.color = FlxColor.fromRGB(40, 44, 64);
		input.textObj.color = FlxColor.WHITE;
		add(input);
	}

	public var text(get, set):String;
	function get_text():String return input.text;
	function set_text(v:String):String return input.text = v;

	public function focus():Void {
		PsychUIInputText.focusOn = input;
	}
}

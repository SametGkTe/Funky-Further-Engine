package online;

#if FURTHER_ONLINE
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import states.PlayState;
import online.GameClient;
#end

/**
 * Handles in-game quick emotes (1-4 keys) and renders popups over characters.
 */
class EmoteManager {
	#if FURTHER_ONLINE
	public static final EMOTES:Array<String> = [
		"Nice! 🔥",
		"Oops! 💀",
		"Good Luck! 🍀",
		"GG! 👑"
	];

	public static function update():Void {
		if (!PlayStateSync.active()) return;

		// Number keys 1-4
		if (FlxG.keys.justPressed.ONE) sendEmote(0);
		else if (FlxG.keys.justPressed.TWO) sendEmote(1);
		else if (FlxG.keys.justPressed.THREE) sendEmote(2);
		else if (FlxG.keys.justPressed.FOUR) sendEmote(3);
	}

	public static function sendEmote(index:Int):Void {
		if (index < 0 || index >= EMOTES.length) return;
		var text = EMOTES[index];
		GameClient.send("chat", text);

		// Show locally above player character
		showPopup(text, true);
	}

	public static function onEmoteReceived(fromName:String, sid:String, text:String):Void {
		if (GameClient.room != null && sid == GameClient.room.sessionId) return; // already shown locally
		showPopup(text, false);
	}

	public static function showPopup(text:String, isLocal:Bool):Void {
		var ps = PlayState.instance;
		if (ps == null) return;

		var char = isLocal ? ps.boyfriend : ps.dad;
		if (char == null) return;

		var posX = char.getMidpoint().x - 60;
		var posY = char.y - 40;

		var bubble = new FlxText(posX, posY, 150, text, 18);
		bubble.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		bubble.scrollFactor.set(char.scrollFactor.x, char.scrollFactor.y);
		ps.add(bubble);

		// Animate float up and fade out
		FlxTween.tween(bubble, {y: posY - 50, alpha: 0}, 1.5, {
			ease: FlxEase.cubeOut,
			onComplete: function(_) {
				bubble.destroy();
			}
		});
	}
	#else
	public static function update():Void {}
	public static function sendEmote(index:Int):Void {}
	public static function onEmoteReceived(fromName:String, sid:String, text:String):Void {}
	#end
}

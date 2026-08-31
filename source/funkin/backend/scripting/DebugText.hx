package funkin.backend.scripting;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.events.Event;
import openfl.Lib;

typedef DebugMessage = {
	var tf:TextField;
	var timeLeft:Float;
	var baseText:String; // Keeps track of the text without the "(x2)" part
	var count:Int; // Keeps track of how many times it was spammed
}


class DebugText {
	public static var container:Sprite;
	public static var messages:Array<DebugMessage> = [];
	private static var lastTime:Int = 0;

	public static var baseWidth:Float = 1280;
	public static var baseHeight:Float = 720;

	public static var textHeight:Int = 16; 

	public static function addTextToDebug(text:String, color:Int) {
		trace('[HScript] ' + text); // konsola da yaz

		if (container == null) {
			container = new Sprite();
			Lib.current.stage.addChild(container); 
			lastTime = Lib.getTimer();
			Lib.current.stage.addEventListener(Event.RESIZE, onResize);
			onResize(null);
			container.addEventListener(Event.ENTER_FRAME, onUpdate);
		}

		for (msg in messages) {
			if (msg.baseText == text) {
				msg.count++; // Increase the spam counter
				msg.tf.text = msg.baseText + " (x" + msg.count + ")"; // Update the screen text
				msg.timeLeft = 6.0; // Reset the disappearance timer
				msg.tf.alpha = 1.0; // Make it fully visible again if it was fading
				return; // Stop the function here so it doesn't create a new line!
			}
		}

		var newText = new TextField();
		newText.defaultTextFormat = new TextFormat("_sans", textHeight, color, true); 
		newText.text = text;
		newText.selectable = false;
		newText.mouseEnabled = false;
		newText.autoSize = LEFT;

		newText.x = 10;
		newText.y = 10; 

		var unscaledHeight:Float = newText.height; 

		for (msg in messages) {
			msg.tf.y += unscaledHeight + 2; 
		}

		container.addChild(newText);

		messages.push({ tf: newText, timeLeft: 6.0, baseText: text, count: 1 });
	}

	private static function onUpdate(e:Event) {
		var currentTime = Lib.getTimer();
		var elapsed = (currentTime - lastTime) / 1000;
		lastTime = currentTime;

		var i:Int = messages.length - 1;
		while (i >= 0) {
			var msg = messages[i];
			msg.timeLeft -= elapsed;
			if(msg.timeLeft < 0) msg.timeLeft = 0;
			if(msg.timeLeft < 1) msg.tf.alpha = msg.timeLeft;

			if(msg.tf.alpha == 0 || msg.tf.y >= baseHeight) {
				container.removeChild(msg.tf);
				messages.splice(i, 1);
			}
			i--;
		}
	}

	private static function onResize(e:Event) {
		if (container == null) return;
		var stageWidth = Lib.current.stage.stageWidth;
		var stageHeight = Lib.current.stage.stageHeight;

		var ratioX = stageWidth / baseWidth;
		var ratioY = stageHeight / baseHeight;
		var scale = Math.min(ratioX, ratioY);
		container.scaleX = container.scaleY = scale;
		container.x = (stageWidth - (baseWidth * scale)) / 2;
		container.y = (stageHeight - (baseHeight * scale)) / 2;
	}
}

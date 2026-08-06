package mobile;
import mobile.ModMenu;

class OnlineTweaks extends ModMenu {
	public static var simulateBotplay:Bool = false;
	public static var botPlayAccuracy:Float = 99.8;

	public function new(?floatText:String, startX:Float = 50, startY:Float = 50) {
		super(floatText, startX, startY);
	}

	private override function addOptions() {
		addToggleButton('Simulate BotPlay: ${simulateBotplay}', function(tf) {
			simulateBotplay = !simulateBotplay;
			tf.text = 'Simulate BotPlay: ${simulateBotplay}';
		});

		addValueChanger("BotPlay Accuracy", Std.string(botPlayAccuracy), function(val) {
			var ns = Std.parseInt(val);
			if (!Math.isNaN(ns) && ns >= 0.5 && ns <= 2.0) {
				botPlayAccuracy = ns;
			}
		});

		super.addOptions();
	}
}
package online.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.input.keyboard.FlxKey;
import backend.MusicBeatState;
import online.GameClient;
import online.NetThread;

/**
 * Sandbox: 4 local strums + remote flash via strumPlay.
 * Arrow keys / WASD = local; remote presses tint top row.
 * Does NOT require gameStarted — works anytime both are in a room.
 */
class StrumTestState extends MusicBeatState {
	var localStrums:Array<FlxSprite> = [];
	var remoteStrums:Array<FlxSprite> = [];
	var info:FlxText;

	override function create() {
		super.create();
		FlxG.mouse.visible = true;
		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK));

		info = new FlxText(10, 10, FlxG.width - 20,
			"STRUM TEST — arrows/WASD local | ESC/B back to lobby\n" +
			"Connected=" + GameClient.isConnected() + " room=" + GameClient.roomCode(),
			16);
		info.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		add(info);

		for (i in 0...4) {
			var s = new FlxSprite(200 + i * 100, 500).makeGraphic(80, 80, FlxColor.GRAY);
			localStrums.push(s);
			add(s);
			var r = new FlxSprite(200 + i * 100, 200).makeGraphic(80, 80, FlxColor.fromRGB(60, 60, 80));
			remoteStrums.push(r);
			add(r);
		}

		var l1 = new FlxText(200, 170, 400, "REMOTE", 14);
		l1.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.CYAN, LEFT);
		add(l1);
		var l2 = new FlxText(200, 470, 400, "LOCAL", 14);
		l2.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.LIME, LEFT);
		add(l2);

		GameClient.onStrumPlay = function(msg:Dynamic) {
			try {
				var sid:String = Std.string(msg[0]);
				#if FURTHER_ONLINE
				if (GameClient.room != null && sid == GameClient.room.sessionId) return;
				#end
				var payload:Array<Dynamic> = cast msg[1];
				var anim:String = Std.string(payload[0]);
				var key:Int = Std.int(payload[1]);
				if (key < 0 || key > 3) return;
				var spr = remoteStrums[key];
				if (anim == "pressed" || anim == "confirm")
					spr.color = FlxColor.YELLOW;
				else
					spr.color = FlxColor.fromRGB(60, 60, 80);
			} catch (e:Dynamic) {
				trace(e);
			}
		};

		addTouchPad("NONE", "B");
	}

	override function update(elapsed:Float) {
		#if FURTHER_ONLINE
		NetThread.pump();
		#end
		super.update(elapsed);

		if (FlxG.keys.justPressed.ESCAPE || controls.BACK || touchPad.buttonB.justPressed) {
			GameClient.onStrumPlay = null;
			MusicBeatState.switchState(new RoomLobbyState());
			return;
		}

		handleKey(FlxKey.LEFT, FlxKey.A, 0);
		handleKey(FlxKey.DOWN, FlxKey.S, 1);
		handleKey(FlxKey.UP, FlxKey.W, 2);
		handleKey(FlxKey.RIGHT, FlxKey.D, 3);
	}

	function handleKey(k1:FlxKey, k2:FlxKey, idx:Int) {
		var spr = localStrums[idx];
		if (FlxG.keys.anyJustPressed([k1, k2])) {
			spr.color = FlxColor.LIME;
			GameClient.send("strumPlay", ["pressed", idx, 0]);
		}
		if (FlxG.keys.anyJustReleased([k1, k2])) {
			spr.color = FlxColor.GRAY;
			GameClient.send("strumPlay", ["static", idx, 0]);
		}
	}

	override function destroy() {
		GameClient.onStrumPlay = null;
		super.destroy();
	}
}

package online.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.MusicBeatState;
import online.GameClient;
import online.NetThread;

class OnlineResultsState extends MusicBeatState {
	public static var lastPayload:Dynamic = null;

	var body:FlxText;
	var btnLobby:FlxSprite;
	var btnLeave:FlxSprite;
	var btnRematch:FlxSprite;

	override function create() {
		super.create();
		FlxG.mouse.visible = true;
		// Keep net pump; stay in room for rematch
		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(8, 10, 24)));

		var title = new FlxText(0, 36, FlxG.width, "MATCH RESULTS", 32);
		title.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		add(title);

		body = new FlxText(40, 90, FlxG.width - 80, buildText(), 17);
		body.setFormat(Paths.font("vcr.ttf"), 17, FlxColor.WHITE, LEFT);
		add(body);

		btnLobby = mkBtn(40, FlxG.height - 110, 240, 50, "LOBBY", FlxColor.fromRGB(70, 140, 255));
		btnRematch = mkBtn(300, FlxG.height - 110, 240, 50, "REMATCH*", FlxColor.fromRGB(70, 200, 130));
		btnLeave = mkBtn(560, FlxG.height - 110, 240, 50, "LEAVE", FlxColor.fromRGB(180, 70, 70));

		var tip = new FlxText(40, FlxG.height - 50, FlxG.width - 80, "* Rematch: lobbyde tekrar READY. Baglanti koptuysa LEAVE.", 12);
		tip.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.GRAY, LEFT);
		add(tip);

		addTouchPad("NONE", "B");
	}

	function buildText():String {
		var data = lastPayload;
		if (data == null) return "No result data.";
		var lines:Array<String> = [];
		try {
			if (Reflect.field(data, "disconnect") == true) {
				lines.push("CONNECTION LOST");
				lines.push("Sunucu veya rakip koptu.");
				return lines.join("\n");
			}
			lines.push("Song: " + Std.string(Reflect.field(data, "song")));
			lines.push("Health: " + Std.string(Reflect.field(data, "health")));
			lines.push("");

			var players:Dynamic = Reflect.field(data, "players");
			var rows:Array<{name:String, score:Int, misses:Int, side:String, you:Bool, s:Int, g:Int, b:Int, sh:Int}> = [];

			if (players != null) {
				// Try Reflect.fields (object)
				var fieldNames:Array<String> = [];
				try { fieldNames = Reflect.fields(players); } catch (_:Dynamic) {}
				if (fieldNames != null) {
					for (sid in fieldNames) {
						var p:Dynamic = Reflect.field(players, sid);
						if (p == null) continue;
						rows.push(rowFrom(p, sid));
					}
				}
			}

			if (rows.length == 0)
				lines.push("(no player rows — raw: " + Std.string(data).substr(0, 200) + ")");
			else {
				rows.sort(function(a, b) return b.score - a.score);
				var place = 1;
				for (r in rows) {
					var mark = r.you ? "  << YOU" : "";
					lines.push("#" + place + "  " + r.name + " [" + r.side + "]" + mark);
					lines.push("    score " + r.score + "   miss " + r.misses + "   S/G/B/Sh " + r.s + "/" + r.g + "/" + r.b + "/" + r.sh);
					lines.push("");
					place++;
				}
				if (rows.length >= 2) {
					if (rows[0].score == rows[1].score)
						lines.push("Result: DRAW");
					else
						lines.push("Winner: " + rows[0].name + " (" + rows[0].score + ")");
				}
			}
		} catch (e:Dynamic) {
			lines.push("parse error: " + e);
			lines.push(Std.string(data));
		}
		return lines.join("\n");
	}

	function rowFrom(p:Dynamic, sid:String):{name:String, score:Int, misses:Int, side:String, you:Bool, s:Int, g:Int, b:Int, sh:Int} {
		var you = false;
		#if FURTHER_ONLINE
		if (GameClient.room != null && sid == GameClient.room.sessionId) you = true;
		#end
		var bf = Reflect.field(p, "bfSide") == true;
		return {
			name: Std.string(Reflect.field(p, "name")),
			score: Std.int(Reflect.field(p, "score")),
			misses: Std.int(Reflect.field(p, "misses")),
			side: bf ? "BF" : "OPP",
			you: you,
			s: Std.int(Reflect.field(p, "sicks")),
			g: Std.int(Reflect.field(p, "goods")),
			b: Std.int(Reflect.field(p, "bads")),
			sh: Std.int(Reflect.field(p, "shits"))
		};
	}

	function mkBtn(x:Float, y:Float, w:Int, h:Int, label:String, col:FlxColor):FlxSprite {
		var s = new FlxSprite(x, y).makeGraphic(w, h, col);
		add(s);
		var t = new FlxText(x, y + h / 2 - 10, w, label, 16);
		t.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.BLACK, CENTER);
		add(t);
		return s;
	}

	function hit(s:FlxSprite, mx:Float, my:Float):Bool {
		return s != null && mx >= s.x && mx <= s.x + s.width && my >= s.y && my <= s.y + s.height;
	}

	override function update(elapsed:Float) {
		#if FURTHER_ONLINE
		NetThread.pump();
		#end
		super.update(elapsed);

		if (controls.BACK #if android || FlxG.android.justReleased.BACK #end || touchPad.buttonB.justPressed) {
			goLobby();
			return;
		}
		if (FlxG.mouse.justPressed) {
			var mx = FlxG.mouse.x;
			var my = FlxG.mouse.y;
			if (hit(btnLobby, mx, my) || hit(btnRematch, mx, my)) goLobby();
			else if (hit(btnLeave, mx, my)) leaveAll();
		}
	}

	function goLobby() {
		lastPayload = null;
		if (GameClient.isConnected())
			MusicBeatState.switchState(new RoomLobbyState());
		else
			MusicBeatState.switchState(new OnlineMenuState());
	}

	function leaveAll() {
		lastPayload = null;
		GameClient.leaveRoom("results leave");
		MusicBeatState.switchState(new OnlineMenuState());
	}
}

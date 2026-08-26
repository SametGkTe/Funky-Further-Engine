package online.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.MusicBeatState;
import backend.ui.PsychUIInputText;
import online.GameClient;
import online.NetThread;
import online.ui.SimpleTextField;
import online.schema.PlayerState;
import backend.Difficulty;
import backend.Song;
import backend.Highscore;
import backend.Mods;
import states.PlayState;
import states.LoadingState;
import haxe.crypto.Md5;

/**
 * 1v1 lobby. Host sets song; both ready → gameStarted → load PlayState.
 */
class RoomLobbyState extends MusicBeatState {
	var codeTxt:FlxText;
	var playersTxt:FlxText;
	var logTxt:FlxText;
	var statusTxt:FlxText;

	var songField:SimpleTextField;
	var folderField:SimpleTextField;

	var btnSet:FlxSprite;
	var btnHas:FlxSprite;
	var btnReady:FlxSprite;
	var btnLeave:FlxSprite;
	var btnStrum:FlxSprite;

	var logs:Array<String> = [];
	var starting:Bool = false;

	override function create() {
		super.create();
		FlxG.mouse.visible = true;

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(8, 12, 22)));

		var title = new FlxText(0, 20, FlxG.width, "ROOM LOBBY", 28);
		title.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER);
		add(title);

		codeTxt = new FlxText(0, 56, FlxG.width, "CODE: " + GameClient.roomCode(), 24);
		codeTxt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.fromRGB(100, 200, 255), CENTER);
		add(codeTxt);

		playersTxt = new FlxText(40, 100, FlxG.width - 80, "", 15);
		playersTxt.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, LEFT);
		add(playersTxt);

		addLabel(40, 210, "Selected song (or open FREEPLAY)");
		songField = new SimpleTextField(40, 234, 320, "tutorial", 16);
		add(songField);
		addLabel(380, 210, "FOLDER / MOD DIR (optional)");
		folderField = new SimpleTextField(380, 234, 280, "", 16);
		add(folderField);

		btnSet = mkBtn(40, 290, 200, 44, "FREEPLAY", FlxColor.fromRGB(90, 130, 255));
		btnHas = mkBtn(260, 290, 200, 44, "I HAVE SONG", FlxColor.fromRGB(90, 190, 120));
		btnReady = mkBtn(480, 290, 200, 44, "READY", FlxColor.fromRGB(240, 180, 50));
		btnStrum = mkBtn(700, 290, 200, 44, "STRUM TEST", FlxColor.fromRGB(160, 100, 220));
		btnLeave = mkBtn(40, 350, 160, 40, "LEAVE", FlxColor.fromRGB(180, 70, 70));

		logTxt = new FlxText(40, 410, FlxG.width - 80, "", 13);
		logTxt.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.GRAY, LEFT);
		add(logTxt);

		statusTxt = new FlxText(40, FlxG.height - 36, FlxG.width - 80,
			GameClient.isHost() ? "You are HOST — set song, then both ready" : "You are GUEST — wait for song, has song, ready",
			14);
		statusTxt.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.YELLOW, LEFT);
		add(statusTxt);

		GameClient.onLog = function(m:String) pushLog(m);
		GameClient.onWelcome = function(w:Dynamic) {
			pushLog("welcome " + Std.string(w));
			autoConfirmSong(w);
		};
		GameClient.onSongChanged = function(data:Dynamic) {
			pushLog("songChanged " + Std.string(data));
			autoConfirmSong(data);
		};
		GameClient.onLobbyReset = function(data:Dynamic) {
			starting = false;
			pushLog("lobbyReset — rematch: both READY");
			statusTxt.text = "Rematch ready — press READY";
			autoConfirmSong(data);
		};
		// Returning from results: ensure we can ready again
		if (GameClient.isConnected())
			trace("[Lobby] post-match lobby re-entry, connected=" + GameClient.isConnected());

		GameClient.onGameStarted = function(data:Dynamic) {
			if (starting) return;
			starting = true;
			pushLog("GAME STARTED " + Std.string(data));
			statusTxt.text = "Loading PlayState…";
			beginMatch(data);
		};

		addTouchPad("NONE", "B");
	}

	function beginMatch(data:Dynamic) {
		var song:String = StringTools.trim(songField.text);
		var folder:String = StringTools.trim(folderField.text);
		var diff:Int = 1;
		try {
			if (data != null) {
				if (Reflect.hasField(data, "song") && Reflect.field(data, "song") != null)
					song = Std.string(Reflect.field(data, "song"));
				if (Reflect.hasField(data, "folder") && Reflect.field(data, "folder") != null)
					folder = Std.string(Reflect.field(data, "folder"));
				if (Reflect.hasField(data, "diff") && Reflect.field(data, "diff") != null)
					diff = Std.int(Reflect.field(data, "diff"));
			}
			#if FURTHER_ONLINE
			if (GameClient.room != null && GameClient.room.state != null) {
				if (GameClient.room.state.song != null && GameClient.room.state.song != "")
					song = GameClient.room.state.song;
				if (GameClient.room.state.folder != null)
					folder = GameClient.room.state.folder;
				diff = Std.int(GameClient.room.state.diff);
			}
			#end
		} catch (e:Dynamic) {}

		song = song.toLowerCase();

		try {
			if (folder != null && folder != "")
				Mods.currentModDirectory = folder;

			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = diff;

			// Same pattern as FreeplayState
			Difficulty.loadFromSong(song);
			if (diff < 0 || (Difficulty.list != null && diff >= Difficulty.list.length))
				diff = 1;
			PlayState.storyDifficulty = diff;

			var poop:String = Highscore.formatSong(song, diff);
			Song.loadFromJson(poop, song);

			if (PlayState.SONG == null) {
				statusTxt.text = "SONG null — check song id: " + song + " / " + poop;
				starting = false;
				return;
			}

			pushLog("Loading " + song + " (" + poop + ")");
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
		} catch (e:Dynamic) {
			pushLog("beginMatch error " + e);
			statusTxt.text = "Error: " + e;
			starting = false;
		}
	}

	function addLabel(x:Float, y:Float, t:String) {
		var l = new FlxText(x, y, 500, t, 12);
		l.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.fromRGB(140, 180, 255), LEFT);
		add(l);
	}

	function mkBtn(x:Float, y:Float, w:Int, h:Int, label:String, col:FlxColor):FlxSprite {
		var s = new FlxSprite(x, y).makeGraphic(w, h, col);
		add(s);
		var t = new FlxText(x, y + h / 2 - 9, w, label, 15);
		t.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.BLACK, CENTER);
		add(t);
		return s;
	}

	function pushLog(m:String) {
		logs.push(m);
		while (logs.length > 10) logs.shift();
		logTxt.text = logs.join("\n");
	}

	override function update(elapsed:Float) {
		#if FURTHER_ONLINE
		NetThread.pump();
		#end
		super.update(elapsed);
		refreshPlayers();

		if (controls.BACK #if android || FlxG.android.justReleased.BACK #end || touchPad.buttonB.justPressed) {
			leave();
			return;
		}

		if (starting) return;
		if (FlxG.mouse.justPressed) {
			var mx = FlxG.mouse.x;
			var my = FlxG.mouse.y;
			if (hit(btnSet, mx, my)) onSetSong();
			else if (hit(btnHas, mx, my)) onHasSong();
			else if (hit(btnReady, mx, my)) onReady();
			else if (hit(btnStrum, mx, my)) {
				MusicBeatState.switchState(new StrumTestState());
			}
			else if (hit(btnLeave, mx, my)) leave();
		}
	}

	function hit(s:FlxSprite, mx:Float, my:Float):Bool {
		return mx >= s.x && mx <= s.x + s.width && my >= s.y && my <= s.y + s.height;
	}

	function refreshPlayers() {
		#if FURTHER_ONLINE
		codeTxt.text = "CODE: " + GameClient.roomCode();
		var sideHint = GameClient.playsAsBF() ? "YOU PLAY AS: BF (right notes)" : "YOU PLAY AS: OPPONENT (left notes)";
		if (statusTxt != null && (statusTxt.text.indexOf("Host") != -1 || statusTxt.text.indexOf("GUEST") != -1 || statusTxt.text.indexOf("PLAY AS") != -1 || statusTxt.text.indexOf("ready") != -1))
			statusTxt.text = sideHint + (GameClient.isHost() ? "  [HOST]" : "  [GUEST]");
		else if (statusTxt != null)
			statusTxt.text = sideHint;
		if (GameClient.room == null || GameClient.room.state == null) {
			playersTxt.text = "(disconnected)";
			return;
		}
		var st = GameClient.room.state;
		var lines:Array<String> = ["players in room:"];
		try {
			// colyseus-haxe 0.15 MapSchema: items._keys + get(sid)
			var keyList:Array<String> = [];
			try {
				var items:Dynamic = Reflect.field(st.players, "items");
				if (items != null) {
					var ks:Dynamic = Reflect.field(items, "_keys");
					if (ks != null) {
						var arr:Array<Dynamic> = cast ks;
						for (k in arr) keyList.push(Std.string(k));
					}
				}
			} catch (_e:Dynamic) {}
			for (sid in keyList) {
				var p:PlayerState = st.players.get(sid);
				if (p == null) continue;
				var tag = (sid == GameClient.room.sessionId) ? " *YOU*" : "";
				var host = (sid == st.host) ? " [HOST]" : "";
				var side = p.bfSide ? "BF" : "OPP";
				lines.push("  " + p.name + tag + host
					+ "  side=" + side
					+ "  song=" + p.hasSong + " ready=" + p.isReady
					+ "  ping=" + p.ping);
			}
			if (keyList.length == 0)
				lines.push("  (waiting for players…)");
		} catch (e:Dynamic) {
			lines.push("(players err: " + Std.string(e) + ")");
		}
		if (st.song != null && st.song != "")
			songField.text = st.song;
		lines.push("song=" + st.song + " hash=" + st.chartHash + " started=" + st.isStarted + " hp=" + st.health);
		playersTxt.text = lines.join("\n");
		#else
		playersTxt.text = "FURTHER_ONLINE off";
		#end
	}



	function autoConfirmSong(?data:Dynamic):Void {
		#if FURTHER_ONLINE
		var song = "";
		var folder = "";
		if (data != null) {
			if (Reflect.hasField(data, "song") && Reflect.field(data, "song") != null)
				song = Std.string(Reflect.field(data, "song"));
			if (Reflect.hasField(data, "folder") && Reflect.field(data, "folder") != null)
				folder = Std.string(Reflect.field(data, "folder"));
		}
		if ((song == null || song == "") && GameClient.room != null && GameClient.room.state != null)
			song = GameClient.room.state.song;
		if (song == null || song == "") return;
		songField.text = song;
		if (folder != null && folder != "") folderField.text = folder;
		// Assume base-game songs present; custom mods still need manual check later
		GameClient.reportHasSong(true);
		pushLog("auto hasSong=true for " + song);
		#end
	}

	function chartHashFor(song:String, folder:String):String {
		// Real raw-chart MD5 can be added later; identity hash is enough for LAN friends MVP
		try {
			return Md5.encode(song.toLowerCase() + "|" + folder + "|" + Std.string(PlayState.storyDifficulty));
		} catch (e:Dynamic) {
			return "dev";
		}
	}

	function onSetSong() {
		if (!GameClient.isHost()) {
			pushLog("Only host can open Freeplay picker");
			return;
		}
		PsychUIInputText.focusOn = null;
		// Open Freeplay-style song browser
		MusicBeatState.switchState(new OnlineFreeplayPickerState());
	}

	function onHasSong() {
		PsychUIInputText.focusOn = null;
		// Guest verifies they can resolve the song name
		var song = songField.text;
		#if FURTHER_ONLINE
		if (GameClient.room != null && GameClient.room.state != null && GameClient.room.state.song != "")
			song = GameClient.room.state.song;
		#end
		songField.text = song;
		GameClient.reportHasSong(true);
		pushLog("hasSong=true (" + song + ")");
	}

	function onReady() {
		PsychUIInputText.focusOn = null;
		GameClient.toggleReady();
	}

	function leave() {
		PsychUIInputText.focusOn = null;
		GameClient.clearListeners();
		GameClient.leaveRoom("lobby leave");
		MusicBeatState.switchState(new OnlineMenuState());
	}

	override function destroy() {
		GameClient.onLog = null;
		GameClient.onGameStarted = null;
		GameClient.onWelcome = null;
		GameClient.onSongChanged = null;
		GameClient.onLobbyReset = null;
		super.destroy();
	}
}

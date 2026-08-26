package online.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import backend.MusicBeatState;
import backend.Difficulty;
import backend.Highscore;
import backend.Song;
import backend.Mods;

import backend.freeplay.FreeplayCatalog;
import backend.freeplay.FreeplayEntry;
import online.GameClient;
import online.NetThread;
import states.PlayState;
import haxe.crypto.Md5;

/**
 * Host-only freeplay song picker for Online lobby.
 */
class OnlineFreeplayPickerState extends MusicBeatState {
	var filtered:Array<FreeplayEntry> = [];
	var curSelected:Int = 0;
	var curDiff:Int = 1;

	var listText:FlxText;
	var infoText:FlxText;
	var title:FlxText;
	var hint:FlxText;

	static inline var VISIBLE:Int = 12;

	override function create() {
		super.create();
		FlxG.mouse.visible = true;

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(12, 14, 30)));

		title = new FlxText(0, 16, FlxG.width, "ONLINE FREEPLAY — HOST PICKS", 26);
		title.setFormat(Paths.font("vcr.ttf"), 26, FlxColor.WHITE, CENTER);
		add(title);

		listText = new FlxText(40, 70, FlxG.width * 0.55, "", 18);
		listText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		add(listText);

		infoText = new FlxText(FlxG.width * 0.55, 70, FlxG.width * 0.42, "", 16);
		infoText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.YELLOW, LEFT);
		add(infoText);

		hint = new FlxText(20, FlxG.height - 60, FlxG.width - 40,
			"W/S or UP/DOWN: song   A/D or LEFT/RIGHT: difficulty\nENTER: confirm to lobby   ESC/B: back",
			14);
		hint.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.GRAY, LEFT);
		add(hint);

		loadSongs();
		refresh();
		addTouchPad("UP_DOWN_LEFT_RIGHT", "A_B");
	}

	function loadSongs() {
		filtered = [];
		try {
			var entries = FreeplayCatalog.ensureLoaded();
			if (entries != null) {
				for (e in entries) {
					if (e == null || e.songName == null || e.songName.length < 1) continue;
					filtered.push(e);
				}
			}
		} catch (e:Dynamic) {
			trace("[OnlineFreeplay] " + e);
		}
		if (filtered.length == 0) {
			for (s in ["tutorial", "bopeebo", "fresh", "dadbattle", "spookeez", "south", "monster", "pico", "philly", "blammed"]) {
				var fe = new FreeplayEntry();
				fe.songName = s;
				fe.folder = "";
				fe.difficulties = ["Easy", "Normal", "Hard"];
				filtered.push(fe);
			}
		}
		if (curSelected >= filtered.length) curSelected = 0;
	}

	function changeSel(d:Int) {
		if (filtered.length < 1) return;
		curSelected = FlxMath.wrap(curSelected + d, 0, filtered.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.35);
		loadDiffsForCurrent();
		refresh();
	}

	function changeDiff(d:Int) {
		if (Difficulty.list == null || Difficulty.list.length < 1) return;
		curDiff = FlxMath.wrap(curDiff + d, 0, Difficulty.list.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.25);
		refresh();
	}

	function loadDiffsForCurrent() {
		if (filtered.length < 1) return;
		var e = filtered[curSelected];
		var folder = e.folder != null ? e.folder : "";
		try {
			Mods.currentModDirectory = folder;
			Difficulty.loadFromSong(e.songName);
		} catch (_:Dynamic) {
			Difficulty.list = ["Easy", "Normal", "Hard"];
		}
		if (Difficulty.list == null || Difficulty.list.length < 1)
			Difficulty.list = ["Easy", "Normal", "Hard"];
		if (e.difficulties != null && e.difficulties.length > 0) {
			// prefer entry diffs if present
			try Difficulty.list = e.difficulties.copy() catch (_:Dynamic) {}
		}
		if (curDiff >= Difficulty.list.length) curDiff = Difficulty.list.length - 1;
		if (curDiff < 0) curDiff = 0;
	}

	function refresh() {
		if (filtered.length < 1) {
			listText.text = "(no songs)";
			infoText.text = "";
			return;
		}
		var start = Std.int(Math.max(0, curSelected - Std.int(VISIBLE / 2)));
		var end = Std.int(Math.min(filtered.length, start + VISIBLE));
		if (end - start < VISIBLE) start = Std.int(Math.max(0, end - VISIBLE));

		var lines:Array<String> = [];
		for (i in start...end) {
			var mark = (i == curSelected) ? "> " : "  ";
			var e = filtered[i];
			var mod = (e.folder != null && e.folder != "") ? " [" + e.folder + "]" : "";
			lines.push(mark + e.songName + mod);
		}
		listText.text = lines.join("\n");

		var e = filtered[curSelected];
		var diffName = (Difficulty.list != null && curDiff < Difficulty.list.length) ? Difficulty.list[curDiff] : "?";
		var score = 0;
		try score = Highscore.getScore(e.songName, curDiff) catch (_:Dynamic) {}
		infoText.text = "SELECTED\n" + e.songName
			+ "\n\nDifficulty:\n< " + diffName.toUpperCase() + " >"
			+ "\n\nBest score: " + score
			+ "\nFolder: " + (e.folder != null && e.folder != "" ? e.folder : "(base)")
			+ "\n\nENTER = set for lobby";
	}

	function confirm() {
		if (filtered.length < 1) return;
		if (!GameClient.isHost()) {
			hint.text = "Only HOST can confirm.";
			hint.color = FlxColor.RED;
			return;
		}
		var e = filtered[curSelected];
		var song = Paths.formatToSongPath(e.songName);
		var folder = e.folder != null ? e.folder : "";
		var diffs = (Difficulty.list != null && Difficulty.list.length > 0) ? Difficulty.list.copy() : ["Easy", "Normal", "Hard"];
		var hash = Md5.encode(song + "|" + folder + "|" + curDiff);

		try {
			Mods.currentModDirectory = folder;
			var poop = Highscore.formatSong(song, curDiff);
			Song.loadFromJson(poop, song);
			if (PlayState.SONG == null) throw "null SONG";
		} catch (err:Dynamic) {
			hint.text = "Chart error: " + err;
			hint.color = FlxColor.RED;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		GameClient.setSong(song, folder, curDiff, diffs, hash);
		GameClient.reportHasSong(true);
		FlxG.sound.play(Paths.sound('confirmMenu'));
		MusicBeatState.switchState(new RoomLobbyState());
	}

	override function update(elapsed:Float) {
		#if FURTHER_ONLINE
		NetThread.pump();
		#end
		super.update(elapsed);

		if (controls.BACK #if android || FlxG.android.justReleased.BACK #end || touchPad.buttonB.justPressed) {
			MusicBeatState.switchState(new RoomLobbyState());
			return;
		}

		if (controls.UI_UP_P || touchPad.buttonUp.justPressed) changeSel(-1);
		if (controls.UI_DOWN_P || touchPad.buttonDown.justPressed) changeSel(1);
		if (controls.UI_LEFT_P || touchPad.buttonLeft.justPressed) changeDiff(-1);
		if (controls.UI_RIGHT_P || touchPad.buttonRight.justPressed) changeDiff(1);
		if (controls.ACCEPT || touchPad.buttonA.justPressed) confirm();
		if (FlxG.mouse.wheel != 0) changeSel(-FlxG.mouse.wheel);
	}
}

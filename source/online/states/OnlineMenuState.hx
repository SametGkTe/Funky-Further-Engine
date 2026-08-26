package online.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import backend.MusicBeatState;
import backend.ui.PsychUIInputText;
import online.GameClient;
import online.NetConfig;
import online.NetThread;
import online.FurtherOnline;
import online.ui.SimpleTextField;

/**
 * Create / Join entry — FE native UI (PsychUIInputText).
 */
class OnlineMenuState extends MusicBeatState {
	var addressField:SimpleTextField;
	var nameField:SimpleTextField;
	var codeField:SimpleTextField;
	var statusTxt:FlxText;

	var btnCreate:FlxSprite;
	var btnJoin:FlxSprite;
	var btnBack:FlxSprite;
	var busy:Bool = false;

	override function create() {
		super.create();
		FlxG.mouse.visible = true;

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(10, 12, 28)));

		var title = new FlxText(0, 36, FlxG.width, "FURTHER ONLINE", 32);
		title.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		add(title);

		var sub = new FlxText(0, 78, FlxG.width, "1v1 LAN  ·  protocol " + FurtherOnline.PROTOCOL, 16);
		sub.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, CENTER);
		add(sub);

		var help = new FlxText(60, 120, FlxG.width - 120,
			"1) PC'de: cd further-server && npm start (port 2567)\n" +
			"2) ADRES:\n" +
			"   PC build: ws://127.0.0.1:2567\n" +
			"   Android EMULATOR: ws://10.0.2.2:2567\n" +
			"   GERCEK TELEFON: ws://PC_LAN_IP:2567  (127.0.0.1 CALISMAZ)\n" +
			"3) CREATE → kodu paylas → JOIN",
			13);
		help.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.fromRGB(160, 160, 180), LEFT);
		add(help);

		var y = 220;
		addLabel(60, y, "SERVER ADDRESS");
		addressField = new SimpleTextField(60, y + 26, FlxG.width - 120, NetConfig.getAddress(), 16);
		add(addressField);

		addLabel(60, y + 90, "NAME");
		var nm = "Player";
		#if FURTHER_ONLINE
		try {
			if (backend.AuthManager.isLoggedIn)
				nm = backend.AuthManager.currentUsername;
		} catch (e:Dynamic) {}
		#end
		nameField = new SimpleTextField(60, y + 116, 360, nm, 16);
		add(nameField);

		addLabel(450, y + 90, "ROOM CODE");
		codeField = new SimpleTextField(450, y + 116, 240, "", 16);
		// UPPER_CASE = 1 (CaseMode lives inside PsychUIInputText.hx module — use int)
		codeField.input.forceCase = 1;
		codeField.input.maxLength = 8;
		add(codeField);

		btnCreate = makeBtn(60, y + 200, 280, 52, "CREATE ROOM", FlxColor.fromRGB(70, 140, 255));
		btnJoin = makeBtn(360, y + 200, 280, 52, "JOIN ROOM", FlxColor.fromRGB(70, 200, 130));
		btnBack = makeBtn(60, y + 270, 180, 44, "BACK", FlxColor.fromRGB(80, 80, 90));

		statusTxt = new FlxText(60, y + 340, FlxG.width - 120,
			FurtherOnline.enabled() ? "Ready." : "Build with -DFURTHER_ONLINE", 16);
		statusTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.YELLOW, LEFT);
		add(statusTxt);

		addTouchPad("NONE", "B");
	}

	function addLabel(x:Float, y:Float, t:String) {
		var l = new FlxText(x, y, 400, t, 12);
		l.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.fromRGB(140, 180, 255), LEFT);
		add(l);
	}

	function makeBtn(x:Float, y:Float, w:Int, h:Int, label:String, col:FlxColor):FlxSprite {
		var s = new FlxSprite(x, y).makeGraphic(w, h, col);
		add(s);
		var t = new FlxText(x, y + h / 2 - 10, w, label, 18);
		t.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.BLACK, CENTER);
		add(t);
		return s;
	}

	override function update(elapsed:Float) {
		#if FURTHER_ONLINE
		NetThread.pump();
		#end
		super.update(elapsed);

		if (controls.BACK #if android || FlxG.android.justReleased.BACK #end || touchPad.buttonB.justPressed) {
			goBack();
			return;
		}

		if (busy) return;

		if (FlxG.mouse.justPressed || (FlxG.mouse.justPressed && true)) {
			var mx = FlxG.mouse.x;
			var my = FlxG.mouse.y;
			if (hit(btnCreate, mx, my)) doCreate();
			else if (hit(btnJoin, mx, my)) doJoin();
			else if (hit(btnBack, mx, my)) goBack();
		}
	}

	function hit(s:FlxSprite, mx:Float, my:Float):Bool {
		return mx >= s.x && mx <= s.x + s.width && my >= s.y && my <= s.y + s.height;
	}

	function setStatus(s:String) {
		statusTxt.text = s;
		trace("[OnlineMenu] " + s);
	}

	function doCreate() {
		if (!FurtherOnline.enabled()) {
			setStatus("Enable FURTHER_ONLINE in Project.xml");
			return;
		}
		PsychUIInputText.focusOn = null;
		NetConfig.setAddress(addressField.text);
		busy = true;
		setStatus("Creating room…");
		GameClient.createRoom(nameField.text, function(ok, msg) {
			busy = false;
			if (!ok) {
				setStatus("FAILED: " + msg);
				return;
			}
			MusicBeatState.switchState(new RoomLobbyState());
		});
	}

	function doJoin() {
		if (!FurtherOnline.enabled()) {
			setStatus("Enable FURTHER_ONLINE in Project.xml");
			return;
		}
		PsychUIInputText.focusOn = null;
		NetConfig.setAddress(addressField.text);
		busy = true;
		setStatus("Joining " + codeField.text + "…");
		GameClient.joinRoom(codeField.text, nameField.text, function(ok, msg) {
			busy = false;
			if (!ok) {
				setStatus("FAILED: " + msg);
				return;
			}
			MusicBeatState.switchState(new RoomLobbyState());
		});
	}

	function goBack() {
		PsychUIInputText.focusOn = null;
		GameClient.leaveRoom("menu back");
		MusicBeatState.switchState(new states.MainMenuState());
	}
}

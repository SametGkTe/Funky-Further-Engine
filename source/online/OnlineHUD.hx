package online;

#if FURTHER_ONLINE
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;
import online.schema.RoomState;
import online.schema.PlayerState;
#end

/**
 * Online multiplayer HUD overlay showing both players' status:
 * - Name, side (BF/OPP), score, maxCombo, ping
 * - Color-coded ping quality
 * - Local player indicator
 */
class OnlineHUD {
	#if FURTHER_ONLINE
	private var group:FlxGroup;
	private var bg:FlxSprite;
	private var titleText:FlxText;
	private var player1Text:FlxText;
	private var player2Text:FlxText;
	private var pingIndicator1:FlxSprite;
	private var pingIndicator2:FlxSprite;
	private var localSideText:FlxText;
	private var roomCodeText:FlxText;
	private var visible:Bool = true;
	private var lastUpdate:Float = 0;
	private static inline var UPDATE_INTERVAL:Float = 0.1; // 10 updates per second
	#end

	public function new() {
		#if FURTHER_ONLINE
		init();
		#end
	}

	#if FURTHER_ONLINE
	private function init():Void {
		group = new FlxGroup();

		// Semi-transparent background
		bg = new FlxSprite(0, 0);
		bg.makeGraphic(FlxG.width, 140, FlxColor.TRANSPARENT);
		bg.scrollFactor.set(0, 0);
		bg.alpha = 0.85;
		group.add(bg);

		// Styling for a more 'Psych Engine' look
		var bar = new FlxSprite(0, 0);
		bar.makeGraphic(FlxG.width, 140, FlxColor.BLACK);
		bar.scrollFactor.set(0, 0);
		bar.alpha = 0.6;
		group.add(bar);

		// Accent line
		var line = new FlxSprite(0, 138).makeGraphic(FlxG.width, 2, FlxColor.CYAN);
		line.scrollFactor.set(0, 0);
		group.add(line);

		// Title with shadow
		titleText = new FlxText(10, 5, FlxG.width - 20, "FURTHER ONLINE — 1v1 MATCH", 18);
		titleText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set(0, 0);
		group.add(titleText);

		// Room code
		roomCodeText = new FlxText(10, 30, 300, "Room: " + GameClient.roomCode(), 14);
		roomCodeText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, "left");
		roomCodeText.scrollFactor.set(0, 0);
		group.add(roomCodeText);

		// Local side indicator
		localSideText = new FlxText(FlxG.width - 240, 30, 230, "", 14);
		localSideText.setFormat(Paths.font("vcr.ttf"), 14, 0xFF00FF00, "right");
		localSideText.scrollFactor.set(0, 0);
		group.add(localSideText);

		// Player 1 (left side in HUD)
		player1Text = new FlxText(35, 60, FlxG.width / 2 - 45, "", 15);
		player1Text.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, "left");
		player1Text.scrollFactor.set(0, 0);
		group.add(player1Text);

		// Player 2 (right side in HUD)
		player2Text = new FlxText(FlxG.width / 2 + 35, 60, FlxG.width / 2 - 45, "", 15);
		player2Text.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, "right");
		player2Text.scrollFactor.set(0, 0);
		group.add(player2Text);

		// Ping indicators (small colored circles)
		pingIndicator1 = new FlxSprite(15, 62);
		pingIndicator1.makeGraphic(14, 14, 0xFF00FF00);
		pingIndicator1.scrollFactor.set(0, 0);
		group.add(pingIndicator1);

		pingIndicator2 = new FlxSprite(FlxG.width / 2 + 15, 62);
		pingIndicator2.makeGraphic(14, 14, 0xFF00FF00);
		pingIndicator2.scrollFactor.set(0, 0);
		group.add(pingIndicator2);

		FlxG.state.add(group);
	}

	public function update():Void {
		#if FURTHER_ONLINE
		if (!visible || !GameClient.isConnected() || GameClient.room == null || GameClient.room.state == null) return;

		var now = FlxG.elapsed;
		if (now - lastUpdate < UPDATE_INTERVAL) return;
		lastUpdate = now;

		var state:RoomState = GameClient.room.state;
		var self = GameClient.getSelf();
		var isBF = GameClient.playsAsBF();
		var localName = self != null ? self.name : "You";

		// Update local side indicator
		localSideText.text = "YOU: " + (isBF ? "BF (RIGHT)" : "OPPONENT (LEFT)");
		localSideText.color = isBF ? 0xFF00FF00 : 0xFFFFFF00;

		// Update room code
		roomCodeText.text = "Room: " + GameClient.roomCode();

		// Get both players from schema
		var players = state.players;
		if (players == null) return;

		// Find both players
		var localPlayer:PlayerState = null;
		var remotePlayer:PlayerState = null;

		// Use Reflect to iterate MapSchema (colyseus-haxe 0.15 pattern)
		var items = Reflect.field(players, "items");
		if (items == null) return;

		for (key in Reflect.fields(items)) {
			var p:PlayerState = Reflect.field(items, key);
			if (p == null) continue;

			if (key == GameClient.room.sessionId) {
				localPlayer = p;
			} else {
				remotePlayer = p;
			}
		}

		// Render Player 1 (BF side)
		renderPlayer(player1Text, pingIndicator1, localPlayer, remotePlayer, true, localName, isBF);
		// Render Player 2 (Opponent side)
		renderPlayer(player2Text, pingIndicator2, remotePlayer, localPlayer, false, localName, isBF);
	}

	private function renderPlayer(
		textField:FlxText,
		pingIndicator:FlxSprite,
		primary:PlayerState,
		fallback:PlayerState,
		isLeftSide:Bool,
		localName:String,
		localIsBF:Bool
	):Void {
		var p = primary;
		if (p == null) p = fallback;
		if (p == null) {
			textField.text = isLeftSide ? "WAITING FOR PLAYER..." : "WAITING FOR PLAYER...";
			pingIndicator.color = 0xFF888888;
			return;
		}

		var isLocal = (p.name == localName);
		var sideLabel = p.bfSide ? "BF" : "OPP";
		var sideColor = p.bfSide ? 0xFF00FFFF : 0xFFFFFF00;
		var score = Std.int(p.score);
		var maxCombo = Std.int(p.maxCombo);
		var ping = Std.int(p.ping);
		var pingColor = getPingColor(ping);

		// Build display string
		var prefix = isLocal ? "[YOU] " : "";
		var s = prefix + "$p.name\n";
		s += "Side: $sideLabel  |  Score: $score  |  Max Combo: $maxCombo";

		textField.text = s;
		textField.color = isLocal ? 0xFF00FF00 : FlxColor.WHITE;

		// Ping indicator color
		pingIndicator.color = pingColor;
		pingIndicator.x = isLeftSide ? 10 : FlxG.width / 2;
	}

	private function getPingColor(ping:Int):Int {
		if (ping < 50) return 0xFF00FF00;      // Green - excellent
		if (ping < 100) return 0xFF88FF00;     // Light green - good
		if (ping < 200) return 0xFFFFFF00;     // Yellow - fair
		if (ping < 400) return 0xFFFF8800;     // Orange - poor
		return 0xFFFF0000;                     // Red - bad
	}
	#end

	public function setVisible(v:Bool):Void {
		#if FURTHER_ONLINE
		visible = v;
		if (group != null) group.visible = v;
		#end
	}

	public function destroy():Void {
		#if FURTHER_ONLINE
		if (group != null) {
			group.destroy();
			group = null;
		}
		bg = null;
		titleText = null;
		player1Text = null;
		player2Text = null;
		pingIndicator1 = null;
		pingIndicator2 = null;
		localSideText = null;
		roomCodeText = null;
		#end
	}
	#else
	public function update():Void {}
	public function setVisible(v:Bool):Void {}
	public function destroy():Void {}
	#end
}
package online;

#if FURTHER_ONLINE
import io.colyseus.Client;
import io.colyseus.Room;
import online.schema.RoomState;
import online.schema.PlayerState;
#end

/**
 * Thin Colyseus wrapper for Further Online 1v1.
 * All room event handlers are dispatched via NetThread → main thread.
 */
class GameClient {
	#if FURTHER_ONLINE
	public static var client:Client;
	public static var room:Room<RoomState>;
	public static var address:String = "";
	public static var lastError:String = "";
	public static var reconnecting:Bool = false;

	static var _pending:Array<Array<Dynamic>> = [];
	#end

	public static function isConnected():Bool {
		#if FURTHER_ONLINE
		return room != null || reconnecting;
		#else
		return false;
		#end
	}

	public static function isHost():Bool {
		#if FURTHER_ONLINE
		if (room == null || room.state == null) return false;
		return room.state.host == room.sessionId;
		#else
		return false;
		#end
	}

	public static function getSelf():#if FURTHER_ONLINE PlayerState #else Dynamic #end {
		#if FURTHER_ONLINE
		if (room == null || room.state == null) return null;
		return room.state.players.get(room.sessionId);
		#else
		return null;
		#end
	}

	public static function playsAsBF():Bool {
		#if FURTHER_ONLINE
		var self = getSelf();
		return self == null ? true : self.bfSide;
		#else
		return true;
		#end
	}

	public static function roomCode():String {
		#if FURTHER_ONLINE
		return room != null ? room.roomId : "";
		#else
		return "";
		#end
	}

	/** options shared on create/join */
	static function buildOptions(name:String):#if FURTHER_ONLINE Map<String, Dynamic> #else Dynamic #end {
		#if FURTHER_ONLINE
		return [
			"name" => (name != null && name != "" ? name : "Player"),
			"protocol" => FurtherOnline.PROTOCOL
		];
		#else
		return null;
		#end
	}

	public static function createRoom(?name:String, ?onDone:Bool->String->Void):Void {
		#if FURTHER_ONLINE
		_connect(true, null, name, onDone);
		#else
		if (onDone != null) onDone(false, "FURTHER_ONLINE not defined");
		#end
	}

	public static function joinRoom(code:String, ?name:String, ?onDone:Bool->String->Void):Void {
		#if FURTHER_ONLINE
		if (code == null || StringTools.trim(code) == "") {
			if (onDone != null) onDone(false, "Room code empty");
			return;
		}
		_connect(false, StringTools.trim(code).toUpperCase(), name, onDone);
		#else
		if (onDone != null) onDone(false, "FURTHER_ONLINE not defined");
		#end
	}

	#if FURTHER_ONLINE
	static function _connect(asHost:Bool, roomId:Null<String>, name:String, onDone:Bool->String->Void):Void {
		leaveRoom(null, false);
		lastError = "";
		address = NetConfig.getAddress();
		_pending = [];

		// Haxe Colyseus Client accepts ws:// or http:// endpoints (matchmake over HTTP).
		var endpoint = address;
		if (StringTools.startsWith(endpoint, "ws://") || StringTools.startsWith(endpoint, "wss://")) {
			// keep as-is — SDK derives HTTP matchmake URL
		} else if (!StringTools.startsWith(endpoint, "http")) {
			endpoint = "ws://" + endpoint;
		}
		trace('[GameClient] connect host=$asHost endpoint=$endpoint');

		#if sys
		sys.thread.Thread.create(function() {
			try {
				client = new Client(endpoint);
				var opts = buildOptions(name);

				if (asHost) {
					client.create(FurtherOnline.ROOM_NAME, opts, RoomState, function(err, r) {
						_onJoin(err, r, onDone);
					});
				} else {
					client.joinById(roomId, opts, RoomState, function(err, r) {
						_onJoin(err, r, onDone);
					});
				}
			} catch (e:Dynamic) {
				lastError = formatError(e) + " | catch | endpoint=" + endpoint;
				NetThread.enqueue(function() {
					if (onDone != null) onDone(false, lastError);
				});
			}
		});
		#else
		if (onDone != null) onDone(false, "Online requires sys target");
		#end
	}


	static function formatError(err:Dynamic):String {
		if (err == null) return "unknown error";
		try {
			var code = Reflect.field(err, "code");
			var msg = Reflect.field(err, "message");
			if (code != null || msg != null)
				return "MatchMakeError code=" + Std.string(code) + " msg=" + Std.string(msg);
		} catch (e:Dynamic) {}
		var s = Std.string(err);
		if (s == null || s == "" || s == "MatchMakeError")
			return "MatchMakeError (no details) — is further-server running? Android: use ws://PC_LAN_IP:2567 not 127.0.0.1";
		return s;
	}

	static function _onJoin(err:Dynamic, r:Room<RoomState>, onDone:Bool->String->Void):Void {
		NetThread.enqueue(function() {
			if (err != null) {
				lastError = formatError(err);
				trace("[GameClient] join error " + lastError + " | endpoint was " + address);
				room = null;
				client = null;
				if (onDone != null) onDone(false, lastError);
				return;
			}

			room = r;
			reconnecting = false;
			_bindRoomHandlers();
			sendPending();
			trace("[GameClient] joined room=" + room.roomId + " sid=" + room.sessionId);
			if (onDone != null) onDone(true, room.roomId);
		});
	}

	static function _bindRoomHandlers():Void {
		if (room == null) return;

		room.onError += function(code:Int, msg:String) {
			NetThread.enqueue(function() {
				trace("[GameClient] room error " + code + " " + msg);
				lastError = code + " " + msg;
			});
		};

		// colyseus-haxe 0.15: onLeave is Void->Void (no code arg)
		room.onLeave += function() {
			NetThread.enqueue(function() {
				trace("[GameClient] onLeave");
				if (!reconnecting) {
					room = null;
				}
			});
		};

		room.onMessage("ping", function(ts:Dynamic) {
			send("pong", null);
		});

		room.onMessage("alert", function(message:Dynamic) {
			NetThread.enqueue(function() {
				trace("[GameClient] alert " + Std.string(message));
				// Hook: show FE AlertMgr / FlxG.log if desired
			});
		});

		room.onMessage("log", function(message:Dynamic) {
			NetThread.enqueue(function() {
				trace("[GameClient:log] " + Std.string(message));
				if (onLog != null) onLog(Std.string(message));
			});
		});

		room.onMessage("welcome", function(message:Dynamic) {
			NetThread.enqueue(function() {
				trace("[GameClient] welcome " + Std.string(message));
				if (onWelcome != null) onWelcome(message);
			});
		});

		room.onMessage("gameStarted", function(message:Dynamic) {
			NetThread.enqueue(function() {
				trace("[GameClient] gameStarted " + Std.string(message));
				if (onGameStarted != null) onGameStarted(message);
			});
		});

		room.onMessage("startSong", function(message:Dynamic) {
			NetThread.enqueue(function() {
				trace("[GameClient] startSong");
				if (onStartSong != null) onStartSong();
			});
		});

		room.onMessage("matchEnded", function(message:Dynamic) {
			NetThread.enqueue(function() {
				trace("[GameClient] matchEnded");
				if (onMatchEnded != null) onMatchEnded(message);
			});
		});

		// Gameplay relays — PlayState will replace/extend these
		room.onMessage("strumPlay", function(message:Dynamic) {
			NetThread.enqueue(function() {
				if (onStrumPlay != null) onStrumPlay(message);
			});
		});

		room.onMessage("noteHit", function(message:Dynamic) {
			NetThread.enqueue(function() {
				if (onNoteHit != null) onNoteHit(message);
			});
		});

		room.onMessage("noteMiss", function(message:Dynamic) {
			NetThread.enqueue(function() {
				if (onNoteMiss != null) onNoteMiss(message);
			});
		});

		room.onMessage("charPlay", function(message:Dynamic) {
			NetThread.enqueue(function() {
				if (onCharPlay != null) onCharPlay(message);
			});
		});

		room.onMessage("chat", function(message:Dynamic) {
			NetThread.enqueue(function() {
				if (onChat != null) onChat(message);
			});
		});

		room.onMessage("songChanged", function(message:Dynamic) {
			NetThread.enqueue(function() {
				if (onSongChanged != null) onSongChanged(message);
			});
		});

		room.onMessage("lobbyReset", function(message:Dynamic) {
			NetThread.enqueue(function() {
				if (onLobbyReset != null) onLobbyReset(message);
			});
		});
	}
	#end

	// Optional listeners set by states / PlayState
	public static var onLog:String->Void;
	public static var onWelcome:Dynamic->Void;
	public static var onGameStarted:Dynamic->Void;
	public static var onStartSong:Void->Void;
	public static var onMatchEnded:Dynamic->Void;
	public static var onStrumPlay:Dynamic->Void;
	public static var onNoteHit:Dynamic->Void;
	public static var onNoteMiss:Dynamic->Void;
	public static var onCharPlay:Dynamic->Void;
	public static var onChat:Dynamic->Void;
	public static var onSongChanged:Dynamic->Void;
	public static var onLobbyReset:Dynamic->Void;

	public static function clearListeners():Void {
		onLog = null;
		onWelcome = null;
		onGameStarted = null;
		onStartSong = null;
		onMatchEnded = null;
		onStrumPlay = null;
		onNoteHit = null;
		onNoteMiss = null;
		onCharPlay = null;
		onChat = null;
		onSongChanged = null;
		onLobbyReset = null;
	}

	public static function send(type:String, ?message:Dynamic):Void {
		#if FURTHER_ONLINE
		if (type == null) return;
		if (room == null) {
			_pending.push([type, message]);
			return;
		}
		try {
			room.send(type, message);
		} catch (e:Dynamic) {
			trace("[GameClient] send fail " + type + " " + e);
			_pending.push([type, message]);
		}
		#end
	}

	#if FURTHER_ONLINE
	static function sendPending():Void {
		while (_pending.length > 0) {
			var m = _pending.shift();
			send(m[0], m[1]);
		}
	}
	#end

	public static function setSong(song:String, folder:String, diff:Int, diffList:Array<String>, chartHash:String):Void {
		send("setSong", {
			song: song,
			folder: folder,
			diff: diff,
			diffList: diffList,
			chartHash: chartHash
		});
	}

	public static function reportHasSong(ok:Bool):Void {
		send("hasSong", ok);
	}

	public static function toggleReady():Void {
		send("toggleReady", null);
	}

	public static function playerReady():Void {
		send("playerReady", null);
	}

	public static function leaveRoom(?reason:String, ?notify:Bool = true):Void {
		#if FURTHER_ONLINE
		clearListeners();
		_pending = [];
		reconnecting = false;
		try {
			if (room != null) {
				room.leave(true);
			}
		} catch (e:Dynamic) {}
		room = null;
		client = null;
		if (notify && reason != null)
			trace("[GameClient] leave: " + reason);
		#end
	}
}

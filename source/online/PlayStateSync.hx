package online;

#if FURTHER_ONLINE
import flixel.FlxG;
import flixel.math.FlxMath;
import objects.Note;
import objects.StrumNote;
import states.PlayState;
import backend.Conductor;
import backend.MusicBeatState;
import online.EmoteManager;
#if DISCORD_ALLOWED
import backend.Discord;
#end
#end

/**
 * Bridges PlayState <-> GameClient for 1v1 (stabilized).
 */
class PlayStateSync {
	#if FURTHER_ONLINE
	static var bound:Bool = false;
	static var endedSent:Bool = false;
	static var lastScoreSent:Int = -1;
	static var lastComboSent:Int = -1;
	static var countdownStarted:Bool = false;
	static var waitingStartSong:Bool = false;
	static var matchOver:Bool = false;
	static var boundPlayState:PlayState = null;

	public static function bind(ps:PlayState):Void {
		if (!GameClient.isConnected()) return;
		unbind();
		bound = true;
		boundPlayState = ps;
		endedSent = false;
		matchOver = false;
		lastScoreSent = -1;
		lastComboSent = -1;
		countdownStarted = false;
		waitingStartSong = true;

		GameClient.onStrumPlay = onStrumPlay;
		GameClient.onNoteHit = onNoteHit;
		GameClient.onNoteMiss = onNoteMiss;
		GameClient.onCharPlay = onCharPlay;
		GameClient.onChat = function(message:Dynamic) {
			try {
				var msg = Std.string(Reflect.field(message, "text"));
				var sid = Std.string(Reflect.field(message, "sid"));
				var fromName = Std.string(Reflect.field(message, "from"));
				EmoteManager.onEmoteReceived(fromName, sid, msg);
			} catch (e:Dynamic) {}
		};

		GameClient.onGameStarted = function(data:Dynamic) {
			#if DISCORD_ALLOWED
			if (GameClient.room != null && GameClient.room.state != null) {
				var roomState = GameClient.room.state;
				var songName = roomState.song;
				var folder = roomState.folder;
				var diff = Std.int(roomState.diff);
				DiscordClient.changePresenceOnlineMatch(songName, folder, diff);
			}
			#end
		};

		GameClient.onStartSong = function() {
			if (matchOver) return;
			waitingStartSong = false;
			if (ps != null && !countdownStarted && !ps.endingSong) {
				countdownStarted = true;
				try {
					// Resume if we paused while waiting
					if (FlxG.sound.music != null) {
						try { FlxG.sound.music.resume(); } catch (_:Dynamic) {}
					}
					ps.startCountdown();
				} catch (e:Dynamic) {
					trace("[PlayStateSync] startCountdown: " + e);
				}
			}
		};

		GameClient.onMatchEnded = function(data:Dynamic) {
			if (matchOver) return;
			matchOver = true;
			waitingStartSong = false;
			trace("[PlayStateSync] matchEnded " + Std.string(data));
			try {
				online.states.OnlineResultsState.lastPayload = data;
				// Small delay so last frames flush
				haxe.Timer.delay(function() {
					try {
						MusicBeatState.switchState(new online.states.OnlineResultsState());
					} catch (e:Dynamic) {
						trace("[PlayStateSync] results switch fail " + e);
						try {
							MusicBeatState.switchState(new online.states.RoomLobbyState());
						} catch (_:Dynamic) {}
					}
				}, 200);
			} catch (e:Dynamic) {
				trace("[PlayStateSync] matchEnded handler " + e);
			}
		};

		// If opponent already left and room dropped
		// (handled by GameClient onLeave → room null; update watches this)

		GameClient.playerReady();
		trace("[PlayStateSync] bound, playerReady sent, waiting startSong, sideBF=" + GameClient.playsAsBF());
	}

	public static function unbind():Void {
		if (!bound) return;
		bound = false;
		boundPlayState = null;
		GameClient.onStrumPlay = null;
		GameClient.onNoteHit = null;
		GameClient.onNoteMiss = null;
		GameClient.onCharPlay = null;
		GameClient.onStartSong = null;
		GameClient.onMatchEnded = null;
		GameClient.onGameStarted = null;
		waitingStartSong = false;

		// Reset Discord presence when leaving match
		#if DISCORD_ALLOWED
		DiscordClient.resetOnlinePresence();
		#end
	}

	public static inline function active():Bool {
		return bound && GameClient.isConnected() && !matchOver;
	}

	public static inline function isWaitingStart():Bool {
		return bound && waitingStartSong && !matchOver;
	}

	public static inline function isMatchOver():Bool {
		return matchOver;
	}

	public static function update(ps:PlayState, ?elapsed:Float = 0.016):Void {
		if (!bound || ps == null) return;

		// Connection lost mid-match
		if (!GameClient.isConnected() && !matchOver) {
			matchOver = true;
			trace("[PlayStateSync] connection lost mid-match");
			try {
				online.states.OnlineResultsState.lastPayload = {
					song: "?",
					health: ps.health,
					disconnect: true,
					players: {}
				};
				MusicBeatState.switchState(new online.states.OnlineResultsState());
			} catch (e:Dynamic) {
				trace(e);
			}
			return;
		}

		if (matchOver) return;
		if (!GameClient.isConnected()) return;

		// Freeze until both clients loaded
		if (waitingStartSong) {
			try {
				if (FlxG.sound.music != null && FlxG.sound.music.playing)
					FlxG.sound.music.pause();
			} catch (_:Dynamic) {}
			return;
		}

		// Server health (with smooth interpolation)
		try {
			if (GameClient.room != null && GameClient.room.state != null) {
				var h:Float = Std.parseFloat(Std.string(GameClient.room.state.health));
				if (!Math.isNaN(h)) {
					ps.health = FlxMath.lerp(ps.health, h, Math.min(1, elapsed * 15));
				}
			}
		} catch (e:Dynamic) {}

		// Score sync (throttled by value change)
		if (ps.songScore != lastScoreSent) {
			lastScoreSent = ps.songScore;
			GameClient.send("setScore", ps.songScore);
		}

		// Combo sync (throttled by value change, live during match)
		if (ps.combo != lastComboSent) {
			lastComboSent = ps.combo;
			GameClient.send("updateMaxCombo", ps.combo);
		}

		// Discord RPC: Live match presence with scores
		#if DISCORD_ALLOWED
		if (GameClient.room != null && GameClient.room.state != null) {
			var roomState = GameClient.room.state;
			var myScore = 0;
			var opponentScore = 0;
			var myMaxCombo = 0;
			try {
				var items = Reflect.field(roomState.players, "items");
				if (items != null) {
					for (sid in Reflect.fields(items)) {
						var p = Reflect.field(items, sid);
						if (p == null) continue;
						var isMe = sid == GameClient.room.sessionId;
						if (isMe) {
							myScore = Std.int(p.score);
							myMaxCombo = Std.int(p.maxCombo);
						} else {
							opponentScore = Std.int(p.score);
						}
					}
				}
			} catch (e:Dynamic) {}
			DiscordClient.changePresenceOnlineMatch(
				roomState.song,
				roomState.folder,
				Std.int(roomState.diff),
				myScore,
				opponentScore,
				myMaxCombo
			);
		}
		#end
	}

	public static function sendStrumPressed(key:Int):Void {
		if (!active() || waitingStartSong) return;
		GameClient.send("strumPlay", ["pressed", key, 0]);
	}

	public static function sendStrumStatic(key:Int):Void {
		if (!active() || waitingStartSong) return;
		GameClient.send("strumPlay", ["static", key, 0]);
	}

	public static function sendNoteHit(note:Note, ?ratingName:String):Void {
		if (!active() || waitingStartSong || note == null) return;
		var rating = ratingName;
		if (rating == null) rating = note.rating != null ? note.rating : "";
		GameClient.send("noteHit", [
			note.strumTime,
			note.noteData,
			note.isSustainNote,
			rating,
			note.noteType != null ? note.noteType : "",
			0,
			note.mustPress
		]);
		if (!note.isSustainNote && rating != null && rating != "")
			GameClient.send("addHitJudge", rating);
		GameClient.send("strumPlay", ["confirm", note.noteData, 0]);

		// Immediately send combo update on hit (if combo increased)
		var ps = boundPlayState;
		if (ps != null && ps.combo != lastComboSent) {
			lastComboSent = ps.combo;
			GameClient.send("updateMaxCombo", ps.combo);
		}
	}

	public static function sendNoteMiss(note:Note, direction:Int):Void {
		if (!active() || waitingStartSong) return;
		if (note != null)
			GameClient.send("noteMiss", [note.strumTime, note.noteData, note.isSustainNote]);
		else
			GameClient.send("noteMiss", [Conductor.songPosition, direction, false]);
		GameClient.send("addMiss", null);
	}

	public static function onLocalSongEnd(ps:PlayState):Bool {
		if (!bound || !GameClient.isConnected()) return false;
		if (endedSent) return true;
		endedSent = true;
		GameClient.send("setScore", ps.songScore);
		GameClient.send("updateMaxCombo", ps.combo);
		GameClient.send("playerEnded", null);
		trace("[PlayStateSync] playerEnded sent, waiting for opponent/matchEnded");
		return true;
	}

	static function onStrumPlay(message:Dynamic):Void {
		if (matchOver || waitingStartSong) return;
		var ps = PlayState.instance;
		if (ps == null || message == null) return;
		try {
			var sid:String = Std.string(message[0]);
			if (GameClient.room != null && sid == GameClient.room.sessionId) return;
			var payload:Array<Dynamic> = cast message[1];
			if (payload == null || payload.length < 2) return;
			var anim:String = Std.string(payload[0]);
			var key:Int = Std.int(payload[1]);
			var reset:Float = payload.length > 2 ? Std.parseFloat(Std.string(payload[2])) : 0;
			if (Math.isNaN(reset)) reset = 0;

			// Remote player's strums = the lane they play.
			// If local is BF (playsAsBF() == true), remote is opponent -> ps.opponentStrums.
			// If local is Opponent (playsAsBF() == false), remote is BF -> ps.playerStrums.
			var isBF:Bool = GameClient.playsAsBF();
			var strums = isBF ? ps.opponentStrums : ps.playerStrums;
			if (strums == null || key < 0 || key >= strums.length) return;
			var spr:StrumNote = strums.members[key];
			if (spr == null) return;
			spr.playAnim(anim, true);
			spr.resetAnim = reset;
		} catch (e:Dynamic) {
			trace("[PlayStateSync] onStrumPlay " + e);
		}
	}

	static function onNoteHit(message:Dynamic):Void {
		if (matchOver || waitingStartSong) return;
		var ps = PlayState.instance;
		if (ps == null || message == null) return;
		try {
			var sid:String = Std.string(message[0]);
			if (GameClient.room != null && sid == GameClient.room.sessionId) return;
			var payload:Array<Dynamic> = cast message[1];
			if (payload == null || payload.length < 3) return;

			var strumTime:Float = Std.parseFloat(Std.string(payload[0]));
			var noteData:Int = Std.int(payload[1]);
			var isSus:Bool = payload[2] == true;

			// Remote notes: if local is BF, remote is opponent (mustPress == false).
			// If local is Opponent, remote is BF (mustPress == true).
			var isBF:Bool = GameClient.playsAsBF();
			var targetMustPress:Bool = isBF ? false : true;
			var found:Note = null;
			if (ps.notes != null) {
				ps.notes.forEachAlive(function(note:Note) {
					if (found != null) return;
					if (note.mustPress != targetMustPress) return;
					if (note.noteData != noteData) return;
					if (note.isSustainNote != isSus) return;
					// Latency compensation: account for one-way network delay (approximate)
				var latencyOffset = 0.0;
				try {
					if (GameClient.room != null && GameClient.room.state != null) {
						var items = Reflect.field(GameClient.room.state.players, "items");
						if (items != null) {
							for (sid in Reflect.fields(items)) {
								if (sid == GameClient.room.sessionId) continue;
								var p = Reflect.field(items, sid);
								if (p != null) {
									latencyOffset = Std.int(p.ping) / 2000.0; // ms -> seconds, half RTT
									break;
								}
							}
						}
					}
				} catch (e:Dynamic) {}
				if (Math.abs(note.strumTime - (strumTime + latencyOffset)) > 60.0) return; // more forgiving with compensation
					found = note;
				});
			}

			if (found != null) {
				found.wasGoodHit = true;
				if (!found.hitByOpponent)
					ps.opponentNoteHit(found);
			}
		} catch (e:Dynamic) {
			trace("[PlayStateSync] onNoteHit " + e);
		}
	}

	static function onNoteMiss(message:Dynamic):Void {
		// visual only
	}

	static function onCharPlay(message:Dynamic):Void {}

	public static inline function allowOpponentAutoHit():Bool {
		return !active();
	}

	public static inline function suppressLocalHealth():Bool {
		return active();
	}

	/** Online: no game over / death — play to the end */
	public static inline function suppressDeath():Bool {
		return active() || matchOver;
	}
	#else
	public static function bind(ps:Dynamic):Void {}
	public static function unbind():Void {}
	public static function active():Bool return false;
	public static function isWaitingStart():Bool return false;
	public static function isMatchOver():Bool return false;
	public static function update(ps:Dynamic):Void {}
	public static function sendStrumPressed(key:Int):Void {}
	public static function sendStrumStatic(key:Int):Void {}
	public static function sendNoteHit(note:Dynamic, ?ratingName:String):Void {}
	public static function sendNoteMiss(note:Dynamic, direction:Int):Void {}
	public static function onLocalSongEnd(ps:Dynamic):Bool return false;
	public static function allowOpponentAutoHit():Bool return true;
	public static function suppressLocalHealth():Bool return false;
	public static function suppressDeath():Bool return false;
	#end
}

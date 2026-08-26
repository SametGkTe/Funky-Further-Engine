package online;

import flixel.FlxG;

/**
 * Server address prefs. LAN-first defaults.
 */
class NetConfig {
	public static inline var DEFAULT_ADDRESS:String = "ws://127.0.0.1:2567";

	/** Android emulator loopback to host machine */
	public static inline var ANDROID_EMU_ADDRESS:String = "ws://10.0.2.2:2567";

	public static function getAddress():String {
		#if FURTHER_ONLINE
		var saved:String = null;
		try {
			if (FlxG.save.data.furtherOnlineAddress != null)
				saved = Std.string(FlxG.save.data.furtherOnlineAddress);
		} catch (e:Dynamic) {}
		if (saved != null && StringTools.trim(saved) != "") {
			saved = StringTools.trim(saved);
			#if android
			// 127.0.0.1 on a phone is the phone itself — never the PC server
			if (saved.indexOf("127.0.0.1") != -1 || saved.indexOf("localhost") != -1) {
				trace("[NetConfig] ignoring saved 127.0.0.1 on Android → " + ANDROID_EMU_ADDRESS);
				return ANDROID_EMU_ADDRESS;
			}
			#end
			return saved;
		}
		#end

		#if android
		// Emulator → host PC. Real device: set your PC LAN IP in the Online menu.
		return ANDROID_EMU_ADDRESS;
		#else
		return DEFAULT_ADDRESS;
		#end
	}

	public static function setAddress(v:String):Void {
		#if FURTHER_ONLINE
		if (v == null) v = "";
		v = StringTools.trim(v);
		if (v == "") v = DEFAULT_ADDRESS;
		try {
			FlxG.save.data.furtherOnlineAddress = v;
			FlxG.save.flush();
		} catch (e:Dynamic) {
			trace("[NetConfig] save failed: " + e);
		}
		#end
	}

	/** ws://host:port → http://host:port (Colyseus HTTP matchmake) */
	public static function toHttpBase(wsUrl:String):String {
		if (wsUrl == null) return "http://127.0.0.1:2567";
		var u = StringTools.trim(wsUrl);
		if (StringTools.startsWith(u, "wss://"))
			return "https://" + u.substr(6);
		if (StringTools.startsWith(u, "ws://"))
			return "http://" + u.substr(5);
		if (StringTools.startsWith(u, "http"))
			return u;
		return "http://" + u;
	}
}

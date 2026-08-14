package vslice.menus.components.crash;

class CrashServer
{
	public inline static function init()
	{
		#if FIREBASE_CRASH_HANDLER
		Crashlytics.initialize();
		Crashlytics.setCustomKey("ASTC support", backend.Native.isASTCSupported());
		Crashlytics.setCustomKey("Startup time", DateUtil.generateTimestamp());
		#end
	}

	public inline static function setupInstanceId()
	{
		#if FIREBASE_CRASH_HANDLER
		trace("Setting instance id: ");
		if (FlxG.save.data.buildId == null)
		{
			FlxG.save.data.buildId = new flixel.math.FlxRandom().int();
			FlxG.save.flush();
		}
		trace(FlxG.save.data.buildId);
		Crashlytics.setUserId(FlxG.save.data.buildId);
		#end
	}

	public static inline function updateModDir(mod:String)
	{
		#if FIREBASE_CRASH_HANDLER
		Crashlytics.setCustomKey("Loaded mod", mod);
		#end
	}

	public static inline function onCrash()
	{
		var hook = PlayState.instance;
		#if FIREBASE_CRASH_HANDLER
		Crashlytics.setCustomKey("Is PlayState active", hook != null);

		if (hook == null)
			return;
		#if LUA_ALLOWED
		Crashlytics.setCustomKey("Lua scripts", hook.luaArray.map(s -> s.scriptName));
		Crashlytics.setCustomKey("Song name", hook.songName);
		#end
		#end
	}

	public static inline function updateGlobalMods(globalMods:Array<String>)
	{
		#if FIREBASE_CRASH_HANDLER
		Crashlytics.setCustomKey("All loaded mods", globalMods);
		#end
	}
}

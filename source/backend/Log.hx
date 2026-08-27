package backend;

import Date;

/**
 *   Log.info('chart', 'BPM map built');
 *   Log.infoLazy('memory', function() return 'Assets: ' + Paths.currentTrackedAssets.length);
 */
 
@:enum
abstract LogLevel(Int)
{
	public var TRACE = 0;
	public var DEBUG = 1;
	public var INFO  = 2;
	public var WARN  = 3;
	public var ERROR = 4;
	public var FATAL = 5;
}

typedef LogEntry = {
	var level:Int;
	var category:String;
	var message:String;
	var time:Float;
}

class Log
{
	public static var level:Int = #if debug 1 #else 2 #end; // DEBUG=1, INFO=2
	public static var consoleOutput:Bool = true;

	public static inline var TRACE:Int = 0;
	public static inline var DEBUG:Int = 1;
	public static inline var INFO:Int  = 2;
	public static inline var WARN:Int  = 3;
	public static inline var ERROR:Int = 4;
	public static inline var FATAL:Int = 5;

	static inline var RING_BUFFER_SIZE:Int = 512;
	static var ringBuffer:Array<LogEntry> = [];
	static var enabledCategories:Map<String, Bool> = [];

	static var _levelNames:Array<String> = ['TRACE', 'DEBUG', 'INFO ', 'WARN ', 'ERROR', 'FATAL'];

	public static inline function setLevel(lvl:Int):Void
		level = lvl;

	public static inline function enableCategory(cat:String, ?enabled:Bool = true):Void
		enabledCategories.set(cat, enabled);

	public static function wouldLog(lvl:Int, ?category:String = null):Bool
	{
		if (lvl < level) return false;
		if (category != null)
		{
			var explicit = enabledCategories.get(category);
			if (explicit != null && explicit == false) return false;
		}
		return true;
	}

	public static function write(lvl:Int, category:String, msg:String):Void
	{
		if (!wouldLog(lvl, category)) return;
		var nowTime:Float;
		#if sys
		nowTime = Sys.time();
		#else
		nowTime = Date.now().getTime() / 1000;
		#end
		var cat:String = (category != null) ? category : 'core';
		var entry:LogEntry = {
			level: lvl,
			category: cat,
			message: msg,
			time: nowTime
		};
		if (consoleOutput)
		{
			#if debug
			trace(_levelNames[lvl] + ' [' + cat + '] ' + msg);
			#else
			if (lvl >= INFO) trace(_levelNames[lvl] + ' [' + cat + '] ' + msg);
			#end
		}
		pushRing(entry);
	}

	public static inline function writeLazy(lvl:Int, category:String, msg:Void->String):Void
	{
		if (!wouldLog(lvl, category)) return;
		write(lvl, category, msg());
	}

	public static inline function trace(cat:String, msg:String):Void write(TRACE, cat, msg);
	public static inline function debug(cat:String, msg:String):Void write(DEBUG, cat, msg);
	public static inline function info (cat:String, msg:String):Void write(INFO,  cat, msg);
	public static inline function warn (cat:String, msg:String):Void write(WARN,  cat, msg);
	public static inline function error(cat:String, msg:String):Void write(ERROR, cat, msg);
	public static inline function fatal(cat:String, msg:String):Void write(FATAL, cat, msg);

	public static inline function traceLazy(cat:String, msg:Void->String):Void writeLazy(TRACE, cat, msg);
	public static inline function debugLazy(cat:String, msg:Void->String):Void writeLazy(DEBUG, cat, msg);
	public static inline function infoLazy (cat:String, msg:Void->String):Void writeLazy(INFO,  cat, msg);
	public static inline function warnLazy (cat:String, msg:Void->String):Void writeLazy(WARN,  cat, msg);
	public static inline function errorLazy(cat:String, msg:Void->String):Void writeLazy(ERROR, cat, msg);
	public static inline function fatalLazy(cat:String, msg:Void->String):Void writeLazy(FATAL, cat, msg);

	static function pushRing(entry:LogEntry):Void
	{
		ringBuffer.push(entry);
		if (ringBuffer.length > RING_BUFFER_SIZE)
			ringBuffer.shift();
	}

	public static function recentLogs(?max:Int):Array<LogEntry>
	{
		var m = (max == null) ? RING_BUFFER_SIZE : max;
		if (m >= ringBuffer.length) return ringBuffer.copy();
		return ringBuffer.slice(ringBuffer.length - m);
	}

	public static function formatRecent(?max:Int):String
	{
		var m = (max == null) ? 80 : max;
		var buf = new StringBuf();
		var logs = recentLogs(m);
		for (e in logs)
		{
			buf.add(_levelNames[e.level] + ' [' + e.category + '] ' + e.message + '\n');
		}
		return buf.toString();
	}
}

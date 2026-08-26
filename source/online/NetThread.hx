package online;

#if (target.threaded)
import sys.thread.Mutex;
#end

/**
 * Queue network callbacks onto the main Flixel thread.
 * NEVER touch FlxSprite / OpenFL display from a socket thread.
 */
class NetThread {
	static var _queue:Array<Void->Void> = [];

	#if (target.threaded)
	static var _mutex:Mutex = new Mutex();
	#end

	public static function enqueue(fn:Void->Void):Void {
		if (fn == null) return;
		#if (target.threaded)
		_mutex.acquire();
		_queue.push(fn);
		_mutex.release();
		#else
		_queue.push(fn);
		#end
	}

	/** Call once per frame from Main / MusicBeatState */
	public static function pump():Void {
		var batch:Array<Void->Void> = null;
		#if (target.threaded)
		_mutex.acquire();
		if (_queue.length > 0) {
			batch = _queue;
			_queue = [];
		}
		_mutex.release();
		#else
		if (_queue.length > 0) {
			batch = _queue;
			_queue = [];
		}
		#end

		if (batch == null) return;
		for (fn in batch) {
			try {
				fn();
			} catch (e:Dynamic) {
				trace("[NetThread] callback error: " + e);
			}
		}
	}
}

package backend;

import flixel.FlxBasic;

/**
 * Update/animation callback'i sırasında nesne yok etmekten doğan grup iterasyonu
 * ve animation callback null hatalarını önler. Fikir FPS Plus'taki gecikmeli
 * destroy yaklaşımından alınmış, Further Engine için bağımsız yazılmıştır.
 */
class SafeDestroy
{
	static var pending:Array<FlxBasic> = [];
	static var scheduled:Bool = false;

	public static function afterUpdate(object:FlxBasic):Void
	{
		if (object == null || pending.contains(object)) return;
		pending.push(object);
		if (scheduled) return;
		scheduled = true;
		FlxG.signals.postUpdate.addOnce(flush);
	}

	static function flush():Void
	{
		scheduled = false;
		var queue = pending;
		pending = [];
		for (object in queue)
			if (object != null) object.destroy();
	}

	public static function clearWithoutDestroying():Void
	{
		pending = [];
		scheduled = false;
	}
}

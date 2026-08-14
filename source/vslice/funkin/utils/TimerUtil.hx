package vslice.funkin.utils;

import flixel.util.FlxTimer;

class TimerUtil
{
	public static function wait(time:Float, callback:Void->Void):FlxTimer
	{
		return new FlxTimer().start(time, function(_:FlxTimer)
		{
			callback();
		});
	}
}

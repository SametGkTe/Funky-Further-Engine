package vslice.funkin.utils;

import flixel.util.FlxSort;

class SortUtil
{
	public static function byZIndex(order:Int, a:Dynamic, b:Dynamic):Int
	{
		var aZ:Float = (a.zIndex != null) ? a.zIndex : 0;
		var bZ:Float = (b.zIndex != null) ? b.zIndex : 0;
		return FlxSort.byValues(order, aZ, bZ);
	}
	
	public static function alphabetically(a:String, b:String):Int
	{
		if (a < b) return -1;
		if (a > b) return 1;
		return 0;
	}
}

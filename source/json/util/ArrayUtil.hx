package json.util;

/**
 * Compatibility override for jsonpath 1.1.0 + modern thx.core.
 * jsonpath calls the removed thx.Arrays.containsExact API; keeping the helper
 * local makes builds deterministic on macOS/Linux/Windows without mutating the
 * runner's global haxelib directory.
 */
class ArrayUtil
{
	static function containsExact<T>(items:Array<T>, expected:T):Bool
	{
		if (items == null) return false;
		for (item in items)
			if (thx.Dynamics.equals(item, expected)) return true;
		return false;
	}

	public static function subtract<T>(list:Array<T>, subtract:Array<T>):Array<T>
	{
		if (list == null) return [];
		return list.filter(item -> !containsExact(subtract, item));
	}

	public static function equalsUnordered<T>(a:Array<T>, b:Array<T>):Bool
	{
		if (a == null || b == null || a.length != b.length) return false;
		for (element in a) if (!containsExact(b, element)) return false;
		for (element in b) if (!containsExact(a, element)) return false;
		return true;
	}

	public static function intersect<T>(list:Array<T>, intersect:Array<T>):Array<T>
	{
		if (list == null) return [];
		return list.filter(item -> containsExact(intersect, item));
	}
}

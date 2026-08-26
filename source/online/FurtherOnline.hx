package online;

/**
 * Feature flag helpers + protocol constant for Further Online MVP.
 * Enable with -DFURTHER_ONLINE in Project.xml
 */
class FurtherOnline {
	/** Must match further-server PROTOCOL */
	public static inline var PROTOCOL:Int = 1;

	public static inline var ROOM_NAME:String = "further";

	public static inline function enabled():Bool {
		#if FURTHER_ONLINE
		return true;
		#else
		return false;
		#end
	}
}

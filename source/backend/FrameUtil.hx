package backend;

/** Frame hızından bağımsız ve hitch sonrası taşma yapmayan hareket yardımcıları. */
class FrameUtil
{
	/** rate: saniyedeki yakınsama hızı (örn. 10 hızlı, 5 yumuşak). */
	public static inline function damp(current:Float, target:Float, rate:Float, elapsed:Float):Float
	{
		if (elapsed <= 0) return current;
		var factor = 1 - Math.exp(-Math.max(0, rate) * elapsed);
		return current + (target - current) * factor;
	}

	public static inline function approach(current:Float, target:Float, unitsPerSecond:Float, elapsed:Float):Float
	{
		var step = Math.abs(unitsPerSecond) * Math.max(0, elapsed);
		if (current < target) return Math.min(target, current + step);
		if (current > target) return Math.max(target, current - step);
		return target;
	}
}

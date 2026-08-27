package backend;

/**
 * Tek tıkla tüm grafik/performans ayarlarını ayarlayan presetler.
 *   - PERFORMANCE: Düşük uç mobil / eski PC — 30FPS, shader kapalı, düşük kalite
 *   - BALANCED:    Çoğu cihazda çalışır — 60FPS, shader'lar açık, orta kalite
 *   - HIGH:        Güçlü masaüstü / yeni telefon — 60-144FPS, tüm efektler
 */
@:enum
abstract PerformanceProfile(String) from String to String
{
	public var PERFORMANCE = 'performance';
	public var BALANCED    = 'balanced';
	public var HIGH        = 'high';
}

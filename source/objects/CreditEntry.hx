package objects;

/**
 * Credits listesindeki tek bir satır.
 *
 * Ham credits.txt alanları:
 *   0 = isim, 1 = icon, 2 = açıklama, 3 = link, 4 = renk,
 *   5 = görünüm bayrakları, 6 = mod klasörü (varsa)
 *
 * 1 alanlı satırlar başlık ya da ayırıcıdır (ikisi de seçilemez).
 */
class CreditEntry
{
	public var name:String = '';
	public var iconName:String = '';
	public var desc:String = '';
	public var link:String = '';
	public var color:String = '';
	public var rawFlags:String = '';
	public var modFolder:String = '';

	public var style:CreditStyle;

	/** Başlık satırı (ör. "Psych Engine Team"). */
	public var isHeader:Bool = false;
	/** Boş ayırıcı satır. */
	public var isSeparator:Bool = false;
	/** [ayarlar] / [global] satırı: listelenmez, tüm liste için varsayılan olur. */
	public var isGlobal:Bool = false;

	/** Çözümlenmiş icon yolu (ör. "credits/gkte" ya da "credits/gkte-pixel"). */
	public var iconPath:String = 'credits/missing_icon';
	/** Çözümlenmiş özel arkaplan key'i, null ise bulunamadı/istenmedi. */
	public var bgKey:String = null;

	public function new() {}

	public function isSectionLine():Bool
	{
		return isHeader || isSeparator;
	}

	public function hasLink():Bool
	{
		return link != null && link.length > 4;
	}

	public function toString():String
	{
		return 'CreditEntry($name, header=$isHeader, separator=$isSeparator, icon=$iconPath)';
	}
}

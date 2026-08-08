package backend.modpack;

/**
 * Further Engine — Modpack Tier Sistemi
 *
 * Her modpack bir tier'a aittir:
 *   - lite    → En düşük boyut (~100 MB). Depolama alanı kısıtlı cihazlar için.
 *   - medium  → Orta boyut (~300-500 MB).
 *   - further → Tüm modların olduğu eksiksiz paket.
 *
 * Tier'lar aynı zamanda packId olarak kullanılır (install(zipPath, "lite", ...)).
 * Eski sistemin id'leri (minimal, high, full) otomatik olarak yeni tier'lara
 * eşlenir — böylece eski kurulumlar kaybolmaz.
 */
typedef ModpackTierInfo = {
	var id:String;
	var label:String;
	var description:String;
	var color:Int;
	var order:Int;

	/** Önerilen hedef boyut (bayt). further için 0 = sınırsız. */
	var sizeHintBytes:Float;

	/** İnsan okunur boyut etiketi, ör: "~100 MB" */
	var sizeLabel:String;
}

enum abstract ModpackTier(String) from String to String {
	var LITE = "lite";
	var MEDIUM = "medium";
	var FURTHER = "further";

	// ─────────────────────────────────────────────
	//  Çözümleme
	// ─────────────────────────────────────────────

	/**
	 * String'i tier'a çevirir. Bilinmeyen id'ler ve null için null döner.
	 * Eski sistem id'leri eşlenir:
	 *   minimal → lite,  medium → medium,  high/full/max → further
	 */
	public static function fromString(value:String):Null<ModpackTier> {
		if (value == null) return null;

		var v = StringTools.trim(value).toLowerCase();

		return switch (v) {
			case "lite", "light", "minimal", "min":
				LITE;
			case "medium", "med", "orta":
				MEDIUM;
			case "further", "full", "high", "max", "ultimate", "complete":
				FURTHER;
			default:
				null;
		}
	}

	/** packId'den tier çözümle (packId = tier id olarak kullanılır). */
	public static inline function fromPackId(packId:String):Null<ModpackTier> {
		return fromString(packId);
	}

	/** Eski sistemde bu tier'a karşılık gelen packId'ler (geçiş desteği). */
	public static function legacyIdsFor(packId:String):Array<String> {
		return switch (packId) {
			case "lite": ["minimal", "min"];
			case "medium": ["medium"];
			case "further": ["high", "full", "max"];
			default: [];
		}
	}

	/** Bilinen tüm tier'lar, sıralı (önce en küçük). */
	public static function allTiers():Array<ModpackTier> {
		return [LITE, MEDIUM, FURTHER];
	}

	// ─────────────────────────────────────────────
	//  Karşılaştırma
	// ─────────────────────────────────────────────

	public function getOrder():Int {
		return switch (this) {
			case LITE: 0;
			case MEDIUM: 1;
			case FURTHER: 2;
			default: 0;
		}
	}

	public inline function isHigherThan(other:ModpackTier):Bool {
		return getOrder() > other.getOrder();
	}

	public inline function isLowerThan(other:ModpackTier):Bool {
		return getOrder() < other.getOrder();
	}

	// ─────────────────────────────────────────────
	//  Meta veri
	// ─────────────────────────────────────────────

	public function getLabel():String {
		return switch (this) {
			case LITE: "Lite Modpack";
			case MEDIUM: "Medium Modpack";
			case FURTHER: "Further Modpack";
			default: this;
		}
	}

	public function getDescription():String {
		return switch (this) {
			case LITE: "Depolama alanı kısıtlı cihazlar için. Yaklaşık 100 MB, temel modlar.";
			case MEDIUM: "Orta boyutlu paket. Daha fazla mod, karakter ve şarkı.";
			case FURTHER: "Tüm modların olduğu eksiksiz paket. En geniş deneyim.";
			default: "";
		}
	}

	/** UI'da tier rozeti/kartı için renk (ARGB). */
	public function getColor():Int {
		return switch (this) {
			case LITE: 0xFF22C55E; // yeşil
			case MEDIUM: 0xFFF59E0B; // amber
			case FURTHER: 0xFFA855F7; // mor
			default: 0xFF888888;
		}
	}

	public function getSizeHintBytes():Float {
		return switch (this) {
			case LITE: 100 * 1024 * 1024; // ~100 MB
			case MEDIUM: 500 * 1024 * 1024; // ~500 MB
			case FURTHER: 0; // sınırsız
			default: 0;
		}
	}

	public function getSizeLabel():String {
		return switch (this) {
			case LITE: "~100 MB";
			case MEDIUM: "~500 MB";
			case FURTHER: "1 GB+";
			default: "";
		}
	}

	public function getTierInfo():ModpackTierInfo {
		return {
			id: this,
			label: getLabel(),
			description: getDescription(),
			color: getColor(),
			order: getOrder(),
			sizeHintBytes: getSizeHintBytes(),
			sizeLabel: getSizeLabel()
		};
	}

	// ─────────────────────────────────────────────
	//  Statik yardımcılar (null güvenli)
	// ─────────────────────────────────────────────

	public static function tierInfoFor(id:String):Null<ModpackTierInfo> {
		var tier = fromString(id);
		return tier == null ? null : tier.getTierInfo();
	}

	public static function labelFor(id:String):String {
		var tier = fromString(id);
		return tier == null ? (id != null && id.length > 0 ? id : "Bilinmeyen") : tier.getLabel();
	}

	public static function colorFor(id:String):Int {
		var tier = fromString(id);
		return tier == null ? 0xFF888888 : tier.getColor();
	}
}

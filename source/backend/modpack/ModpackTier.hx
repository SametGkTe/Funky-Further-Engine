package backend.modpack;

typedef ModpackTierInfo = {
	var id:String;
	var label:String;
	var description:String;
	var color:Int;
	var order:Int;

	var sizeHintBytes:Float;

	var sizeLabel:String;
}

enum abstract ModpackTier(String) from String to String {
	var LITE = "lite";
	var MEDIUM = "medium";
	var FURTHER = "further";

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

	public static inline function fromPackId(packId:String):Null<ModpackTier> {
		return fromString(packId);
	}

	public static function legacyIdsFor(packId:String):Array<String> {
		return switch (packId) {
			case "lite": ["minimal", "min"];
			case "medium": ["medium"];
			case "further": ["high", "full", "max"];
			default: [];
		}
	}

	public static function allTiers():Array<ModpackTier> {
		return [LITE, MEDIUM, FURTHER];
	}

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

	public function getColor():Int {
		return switch (this) {
			case LITE: 0xFF22C55E;
			case MEDIUM: 0xFFF59E0B;
			case FURTHER: 0xFFA855F7;
			default: 0xFF888888;
		}
	}

	public function getSizeHintBytes():Float {
		return switch (this) {
			case LITE: 100 * 1024 * 1024;
			case MEDIUM: 500 * 1024 * 1024;
			case FURTHER: 0;
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

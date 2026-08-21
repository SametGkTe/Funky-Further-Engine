package backend.modpack;

import haxe.Json;

/**
 * İçerik kataloğu (modpack.json) tipleri.
 * Bu katalog, mod-bazlı (delta) güncelleme sisteminin kaynağıdır ve
 * içerik reposunda (ör: Further-Modpack-Content) kök dizinde durur.
 * build_modpack.py tarafından otomatik üretilir.
 */
typedef ContentCatalogMod = {
	var folder:String;        // mods/ altındaki hedef klasör adı
	var version:String;       // mod sürümü

	@:optional var zipName:String;
	@:optional var url:String;        // GitHub Release asset adresi
	@:optional var sizeBytes:Float;
	@:optional var sha256:String;     // zip hash'i (varsa doğrulanır)
	@:optional var hash:String;       // yayıncı tarafı değişim takibi (motor kullanmaz)
	@:optional var removed:Bool;      // true → kuruluysa cihazdan silinir
	@:optional var addedIn:String;
}

typedef ContentCatalog = {
	var packId:String;

	@:optional var displayName:String;
	@:optional var packVersion:String;
	@:optional var engineVersion:String;
	@:optional var updatedAt:String;
	@:optional var releaseTag:String;
	@:optional var modCount:Int;
	@:optional var totalSizeBytes:Float;
	@:optional var mods:Array<ContentCatalogMod>;
}

class ModpackCatalog {
	/**
	 * Katalog JSON'unu güvenle parse eder. Hatalıysa null döner.
	 */
	public static function parse(raw:String):Null<ContentCatalog> {
		if (raw == null || raw.length == 0) return null;
		try {
			var cat:ContentCatalog = cast Json.parse(raw);
			if (cat.packId == null || cat.packId.length == 0) return null;
			return cat;
		} catch (e:Dynamic) {
			trace('[ModpackCatalog] Parse hatası: ${Std.string(e)}');
			return null;
		}
	}

	/**
	 * raw.githubusercontent URL'ine jsDelivr yedek URL'ini üretir.
	 * Motor her ikisini de sırayla dener (TR'de raw bazen düşer).
	 */
	public static function catalogUrls(rawUrl:String):Array<String> {
		var urls:Array<String> = [rawUrl];
		var js:String = StringTools.replace(rawUrl, "https://raw.githubusercontent.com/", "https://cdn.jsdelivr.net/gh/");
		if (js != rawUrl) {
			// raw.githubusercontent.com/owner/repo/branch/path
			// cdn.jsdelivr.net/gh/owner/repo@branch/path
			var rest:String = js.substr("https://cdn.jsdelivr.net/gh/".length);
			var parts:Array<String> = rest.split("/");
			if (parts.length >= 4) {
				var owner:String = parts[0];
				var repo:String = parts[1];
				var branch:String = parts[2];
                var path:String = parts.slice(3).join("/");
                urls.push('https://cdn.jsdelivr.net/gh/$owner/$repo@$branch/$path');
			}
		}
		return urls;
	}

	public static function getDisplayVersion(cat:ContentCatalog):String {
		return cat.packVersion != null && cat.packVersion.length > 0 ? cat.packVersion : "1.0.0";
	}
}

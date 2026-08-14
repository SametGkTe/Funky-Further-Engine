package backend.modpack;

#if sys
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import backend.modpack.DownloadManager;
#end

class MediafireStats {
	#if sys

	static final CACHE_TTL:Float = 6 * 60 * 60;

	public static final SRC_API = "api";
	public static final SRC_HTML = "html";
	public static final SRC_CATALOG = "katalog";

	public static function extractQuickKey(mediafireUrl:String):Null<String> {
		if (mediafireUrl == null) return null;

		var idx:Int = mediafireUrl.indexOf("/file/");
		if (idx == -1) return null;

		var rest:String = mediafireUrl.substr(idx + "/file/".length);
		var keyEnd:Int = rest.indexOf("/");
		if (keyEnd == -1) keyEnd = rest.length;

		var key:String = StringTools.trim(rest.substr(0, keyEnd));
		if (key.length < 3 || key.length > 40) return null;

		if (!~/^[A-Za-z0-9_-]+$/.match(key)) return null;

		return key;
	}

	public static function parseApiCount(jsonText:String):Float {
		if (jsonText == null || jsonText.length == 0) return -1;

		try {
			var parsed:Dynamic = Json.parse(jsonText);
			var fi:Dynamic = parsed.response != null ? parsed.response.file_info : null;
			if (fi == null) return -1;

			for (field in ["downloads", "download_count", "dl_count", "view"]) {
				if (Reflect.hasField(fi, field)) {
					var v:Dynamic = Reflect.field(fi, field);
					if (v != null) {
						var n:Float = Std.parseFloat(Std.string(v));
						if (!Math.isNaN(n) && n >= 0) return n;
					}
				}
			}
		} catch (e:Dynamic) {}

		return -1;
	}

	public static function parseHtmlCount(html:String):Float {
		if (html == null || html.length == 0) return -1;

		var patterns:Array<EReg> = [

			~/["']downloads["'][ \t]*:[ \t]*([0-9]+)/i,

			~/(?:id|class)="[^"]*(?:download|dl)[^"]*(?:count|cnt)[^"]*"[^>]*>[ \t]*([0-9.,]+)[ \t]*</i,

			~/data-(?:downloads|dl-count|cnt)="([0-9]+)"/i,

			~/Downloads?[ \t]*[:][ \t]*([0-9.,]+)/i,

			~/([0-9.,]+)[ \t]+Downloads/i
		];

		for (pattern in patterns) {
			try {
				if (pattern.match(html)) {
					var raw:String = pattern.matched(1);
					if (raw == null) continue;

					var cleaned:String = StringTools.replace(raw, ",", "");
					var n:Float = Std.parseFloat(cleaned);
					if (!Math.isNaN(n) && n > 0) return n;
				}
			} catch (e:Dynamic) {}
		}

		return -1;
	}

	public static function getDownloadCount(
		packId:String,
		mediafireUrl:String,
		catalogCount:Int,
		onResult:Int->String->Void
	):Void {
		if (onResult == null) return;

		var cached:Null<{count:Int, source:String}> = readCache(packId);
		if (cached != null) {
			onResult(cached.count, cached.source);
			return;
		}

		var quickKey:Null<String> = extractQuickKey(mediafireUrl);

		var finish = function(count:Int, source:String):Void {
			writeCache(packId, count, source);
			onResult(count, source);
		};

		var tryCatalog = function():Void {
			if (catalogCount > 0)
				finish(catalogCount, SRC_CATALOG);
			else
				finish(0, SRC_CATALOG);
		};

		if (quickKey == null) {

			if (mediafireUrl != null && mediafireUrl.length > 0) {
				scrapePage(mediafireUrl, finish, tryCatalog);
			} else {
				tryCatalog();
			}
			return;
		}

		var apiUrl:String = 'https://www.mediafire.com/api/1.5/file/get_info.php?quick_key=$quickKey&response_format=json';

		var dm = new DownloadManager();
		dm.fetchUrlText(apiUrl, function(json:String) {
			var count:Float = parseApiCount(json);
			if (count > 0) {
				finish(Std.int(count), SRC_API);
			} else if (mediafireUrl != null && mediafireUrl.length > 0) {
				scrapePage(mediafireUrl, finish, tryCatalog);
			} else {
				tryCatalog();
			}
		}, function(_err:String) {
			if (mediafireUrl != null && mediafireUrl.length > 0) {
				scrapePage(mediafireUrl, finish, tryCatalog);
			} else {
				tryCatalog();
			}
		});
	}

	static function scrapePage(pageUrl:String, finish:Int->String->Void, onFail:Void->Void):Void {
		var dm = new DownloadManager();
		dm.fetchUrlText(pageUrl, function(html:String) {
			var count:Float = parseHtmlCount(html);
			if (count > 0)
				finish(Std.int(count), SRC_HTML);
			else
				onFail();
		}, function(_err:String) {
			onFail();
		});
	}

	static function getCachePath(packId:String):String {
		return ModpackPaths.getDownloadDirectory() + "download-count-" + packId + ".json";
	}

	static function readCache(packId:String):Null<{count:Int, source:String}> {
		try {
			var path = getCachePath(packId);
			if (!FileSystem.exists(path)) return null;

			var parsed:Dynamic = Json.parse(File.getContent(path));
			if (parsed == null || parsed.count == null) return null;

			var fetchedAt:Float = Std.parseFloat(Std.string(parsed.fetchedAt));
			if (Math.isNaN(fetchedAt)) return null;

			if (Sys.time() - fetchedAt > CACHE_TTL) return null;

			return {
				count: Std.parseInt(Std.string(parsed.count)),
				source: parsed.source != null ? Std.string(parsed.source) : SRC_CATALOG
			};
		} catch (e:Dynamic) {
			return null;
		}
	}

	static function writeCache(packId:String, count:Int, source:String):Void {
		try {
			var path = getCachePath(packId);
			var dir = Path.directory(path);
			if (dir != null && dir.length > 0 && !FileSystem.exists(dir))
				FileSystem.createDirectory(dir);

			File.saveContent(path, Json.stringify({
				count: count,
				source: source,
				fetchedAt: Sys.time()
			}));
		} catch (e:Dynamic) {
			trace('[MediafireStats] Cache yazılamadı: ${Std.string(e)}');
		}
	}
	#else

	public static final SRC_API = "api";
	public static final SRC_HTML = "html";
	public static final SRC_CATALOG = "katalog";

	public static function extractQuickKey(mediafireUrl:String):Null<String> return null;

	public static function parseApiCount(jsonText:String):Float return -1;
	public static function parseHtmlCount(html:String):Float return -1;

	public static function getDownloadCount(
		packId:String,
		mediafireUrl:String,
		catalogCount:Int,
		onResult:Int->String->Void
	):Void {
		if (onResult != null) onResult(catalogCount, SRC_CATALOG);
	}
	#end
}

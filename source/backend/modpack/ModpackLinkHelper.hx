package backend.modpack;

class ModpackLinkHelper {

	public static function getMediafireUrl(mp:Dynamic):Null<String> {
		if (mp == null) return null;
		var url:String = mp.mediafireUrl != null ? Std.string(mp.mediafireUrl) : "";
		if (url.length == 0 && mp.externalPageUrl != null)
			url = Std.string(mp.externalPageUrl);
		return url.length > 0 ? url : null;
	}

	public static function getGithubUrl(mp:Dynamic):Null<String> {
		if (mp == null) return null;
		var url:String = mp.githubUrl != null ? Std.string(mp.githubUrl) : "";
		if (url.length == 0 && mp.directDownloadUrl != null)
			url = Std.string(mp.directDownloadUrl);
		return url.length > 0 ? url : null;
	}

	public static function getIncludes(mp:Dynamic):Array<String> {
		if (mp == null || mp.includes == null) return [];
		var out:Array<String> = [];
		var list:Array<Dynamic> = cast mp.includes;
		for (item in list) {
			if (item != null && Std.string(item).length > 0)
				out.push(Std.string(item));
		}
		return out;
	}

	public static function getCatalogDownloads(mp:Dynamic):Int {
		if (mp == null || mp.downloads == null) return 0;
		var n:Null<Int> = Std.parseInt(Std.string(mp.downloads));
		return n != null && n > 0 ? n : 0;
	}

	public static function shortUrl(url:String):String {
		if (url == null || url.length == 0) return "";
		var cleaned = StringTools.replace(url, "https://", "");
		cleaned = StringTools.replace(cleaned, "http://", "");
		if (cleaned.length > 48)
			cleaned = cleaned.substr(0, 45) + "...";
		return cleaned;
	}
}

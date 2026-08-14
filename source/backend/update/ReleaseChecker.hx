package backend.update;

import haxe.Json;

class ReleaseChecker {
	public static var checked:Bool = false;
	public static var isChecking:Bool = false;
	public static var hasUpdate:Bool = false;
	public static var latestVersion:String = "";
	public static var releaseUrl:String = "";
	public static var releaseNotes:String = "";
	public static var lastError:String = "";

	public static function check(?onDone:Void->Void):Void {
		if (isChecking) return;
		isChecking = true;

		var headers = [
			"User-Agent" => "Further-Engine/" + UpdateConfig.CURRENT_ENGINE_VERSION,
			"Accept" => "application/vnd.github+json"
		];

		SafeHttp.getFirst(UpdateConfig.latestReleaseUrls(), headers, function(data:String) {
			isChecking = false;
			checked = true;

			try {
				var parsed:Dynamic = Json.parse(data);
				var tag:String = parsed.tag_name != null ? Std.string(parsed.tag_name) : "";

				if (StringTools.startsWith(tag, "v") || StringTools.startsWith(tag, "V"))
					tag = tag.substr(1);

				latestVersion = tag;
				releaseUrl = parsed.html_url != null ? Std.string(parsed.html_url) : '';
				releaseNotes = parsed.body != null ? Std.string(parsed.body) : '';

				hasUpdate = tag.length > 0
					&& UpdateChecker.isRemoteNewer(UpdateConfig.CURRENT_ENGINE_VERSION, tag);

				trace('[ReleaseChecker] En son sürüm: $tag | yerel: ${UpdateConfig.CURRENT_ENGINE_VERSION} | güncelleme: $hasUpdate');

				if (onDone != null) onDone();
			} catch (e:Dynamic) {
				lastError = Std.string(e);
				trace('[ReleaseChecker] JSON parse hatası: $lastError');
				if (onDone != null) onDone();
			}
		}, function(error:String) {
			isChecking = false;
			checked = true;
			lastError = error;
			var msg:String = error != null ? error : "";
			if (msg.indexOf("resolve host") != -1 || msg.indexOf("Couldn't resolve") != -1)
				trace('[ReleaseChecker] Çevrimdışı, sürüm kontrolü atlandı.');
			else
				trace('[ReleaseChecker] Kontrol başarısız: $error');
			if (onDone != null) onDone();
		});
	}
}

package backend.update;

import haxe.Json;

class BetaChecker {
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
		lastError = "";
		latestVersion = "";
		releaseUrl = "";
		releaseNotes = "";
		hasUpdate = false;

		var headers = [
			"User-Agent" => "Further-Engine/" + UpdateConfig.CURRENT_ENGINE_VERSION,
			"Accept" => "application/vnd.github+json"
		];

		SafeHttp.getFirst(UpdateConfig.betaReleaseUrls(), headers, function(data:String) {
			isChecking = false;
			checked = true;

			try {
				var list:Array<Dynamic> = cast Json.parse(data);
				var found:Dynamic = null;

				if (list != null) {
					for (rel in list) {
						if (rel != null && rel.prerelease == true && rel.draft != true) {
							found = rel;
							break;
						}
					}
				}

				if (found == null) {
					trace('[BetaChecker] Yayinda beta surumu yok.');
					if (onDone != null) onDone();
					return;
				}

				var tag:String = found.tag_name != null ? Std.string(found.tag_name) : "";

				if (StringTools.startsWith(tag, "v") || StringTools.startsWith(tag, "V"))
					tag = tag.substr(1);

				latestVersion = tag;
				releaseUrl = found.html_url != null ? Std.string(found.html_url) : '';
				releaseNotes = found.body != null ? Std.string(found.body) : '';

				hasUpdate = tag.length > 0
					&& UpdateChecker.isRemoteNewer(UpdateConfig.CURRENT_ENGINE_VERSION, tag);

				trace('[BetaChecker] En son beta: $tag | yerel: ${UpdateConfig.CURRENT_ENGINE_VERSION} | guncelleme: $hasUpdate');

				if (onDone != null) onDone();
			} catch (e:Dynamic) {
				lastError = Std.string(e);
				trace('[BetaChecker] JSON parse hatasi: $lastError');
				if (onDone != null) onDone();
			}
		}, function(error:String) {
			isChecking = false;
			checked = true;
			lastError = error != null ? error : "";
			trace('[BetaChecker] Kontrol basarisiz: $lastError');
			if (onDone != null) onDone();
		});
	}
}

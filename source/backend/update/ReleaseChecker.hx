package backend.update;

import haxe.Http;
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

		var apiUrl:String = 'https://api.github.com/repos/${UpdateConfig.GITHUB_REPO_OWNER}/${UpdateConfig.GITHUB_REPO_NAME}/releases/latest';

		var http = new Http(apiUrl);
		http.addHeader("User-Agent", "Further-Engine/" + UpdateConfig.CURRENT_ENGINE_VERSION);
		http.addHeader("Accept", "application/vnd.github+json");

		http.onData = function(data:String) {
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
		};

		http.onError = function(error:String) {
			isChecking = false;
			checked = true;
			lastError = error;
			trace('[ReleaseChecker] Kontrol başarısız: $error');
			if (onDone != null) onDone();
		};

		http.request(false);
	}
}
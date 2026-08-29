package backend.update;

class UpdateConfig {
	public static inline var ENGINE_NAME:String = "Further Engine";
	public static inline var CHECK_ON_STARTUP:Bool = true;
	public static inline var DEBUG_FORCE_UPDATES:Bool = false;
	public static inline var CURRENT_ENGINE_VERSION:String = "1.7.0";

	public static inline var GITHUB_REPO_OWNER:String = "SametGkTe";
	public static inline var GITHUB_REPO_NAME:String = "Funky-Further-Engine";
	public static inline var GITHUB_BRANCH:String = "main";

	public static inline var CATALOG_RELATIVE_PATH:String = "updates/modpacks.json";

	public static var MODPACK_JSON_URL(get, never):String;

	static function get_MODPACK_JSON_URL():String {
		return modpackJsonUrls()[0];
	}

	public static var STORE_JSON_URL(get, never):String;

	static function get_STORE_JSON_URL():String {
		return MODPACK_JSON_URL;
	}

	public static function modpackJsonUrls():Array<String>
	{
		var owner = GITHUB_REPO_OWNER;
		var repo = GITHUB_REPO_NAME;
		var branch = GITHUB_BRANCH;
		var path = CATALOG_RELATIVE_PATH;
		return [
			'https://raw.githubusercontent.com/$owner/$repo/$branch/$path',
			'https://cdn.jsdelivr.net/gh/$owner/$repo@$branch/$path'
		];
	}

	public static function latestReleaseUrls():Array<String>
	{
		var owner = GITHUB_REPO_OWNER;
		var repo = GITHUB_REPO_NAME;
		return [
			'https://api.github.com/repos/$owner/$repo/releases/latest'
		];
	}
}

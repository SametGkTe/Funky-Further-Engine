package backend.update;

class UpdateConfig {
	public static inline var ENGINE_NAME:String = "Further Engine";
	public static inline var CHECK_ON_STARTUP:Bool = true;
	public static inline var DEBUG_FORCE_UPDATES:Bool = false;
	public static inline var CURRENT_ENGINE_VERSION:String = "1.5.3";

	public static inline var GITHUB_REPO_OWNER:String = "SametGkTe";
	public static inline var GITHUB_REPO_NAME:String = "Further-Engine";
	public static inline var GITHUB_BRANCH:String = "main";

	public static inline var CATALOG_RELATIVE_PATH:String = "updates/modpacks.json";

	public static var MODPACK_JSON_URL(get, never):String;

	static function get_MODPACK_JSON_URL():String {
		return 'https://raw.githubusercontent.com/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME/$GITHUB_BRANCH/$CATALOG_RELATIVE_PATH';
	}

	public static var STORE_JSON_URL(get, never):String;

	static function get_STORE_JSON_URL():String {
		return MODPACK_JSON_URL;
	}
}

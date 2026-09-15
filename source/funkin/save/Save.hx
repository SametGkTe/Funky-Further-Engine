package funkin.save;

/**
 * FNF uyumluluk shim'i (Save) — v20 (Faz 4.5), minimal.
 *
 * Resmî v0.8.7'de Save, polymod tabanlı gelişmiş bir kayıt sistemidir.
 * Further'da kayıtlar backend.PlayerSettings/FlxSave ile yönetilir; bu shim
 * yalnızca mod script'lerinin `Save.instance.modOptions["x"]` erişimini
 * ÇALIŞIR hale getirir (bellek içi Map — oyun kapanınca sıfırlanır).
 *
 * Kalıcılık istenirse ileri sürümde FlxSave'a bağlanabilir (v20: hayır).
 */
@:noCustomClass
class Save
{
	static var _instance:Save;

	/** Resmî singleton erişimi: Save.instance */
	public static var instance(get, never):Save;
	static function get_instance():Save
	{
		if (_instance == null) _instance = new Save();
		return _instance;
	}

	public function new() {}

	/**
	 * Resmî: mod-scope seçenek deposu (`Save.instance.modOptions["noteCamera"]`).
	 * Script'ler Map erişimi (get/set/exists) yapabilir.
	 */
	public var modOptions:Map<String, Dynamic> = new Map<String, Dynamic>();

	/** Resmî: diske yaz — shim'de no-op (bellek içi). */
	public function flush():Void {}

	/** Resmî yüzey: data — shim'de modOptions'ı sarmalar. */
	public var data(get, never):Dynamic;
	function get_data():Dynamic return {modOptions: modOptions};

	public function save():Void {}
	public function wipeSave():Void {}
}

package funkin.play.character;

/**
 * FNF uyumluluk shim'i (CharacterDataParser) — v20 (Faz 4.5).
 *
 * Resmî v0.8.7: `CharacterDataParser.fetchCharacter(id)` bir BaseCharacter
 * döner; `characterCache` ham veriyi önbellekler. Further'da karakterler
 * Psych JSON'larından kurulur; fetchCharacter köprüsü önce scripted
 * karakteri (VSScriptRegistry.resolveCharacter), yoksa düz
 * `new objects.Character(0, 0, id)` dener — SwapCharacterEvent/
 * ChangeCharacterEvent tarzı mod script'leri bu API'yi kullanır.
 */
@:noCustomClass
class CharacterDataParser
{
	/** Resmî: karakter verisi önbelleği (id -> data). */
	public static var characterCache:Map<String, Dynamic> = new Map<String, Dynamic>();

	/**
	 * Resmî imza: parseCharacterData(entryId:String):CharacterData.
	 * Eski imza (parseCharacterData(json)) da desteklenir: String olmayan
	 * giriş doğrudan geri döner.
	 */
	public static function parseCharacterData(?entryId:Dynamic, ?fallback:Dynamic):Dynamic
	{
		if (entryId == null) return (fallback != null) ? fallback : {};
		if (!Std.isOfType(entryId, String)) return entryId; // eski kullanım: ham json
		var id:String = Std.string(entryId);
		if (characterCache.exists(id)) return characterCache.get(id);
		var data:Dynamic = {id: id, name: id};
		characterCache.set(id, data);
		return data;
	}

	/** Resmî: fetchCharacter(entryId) — Further karakter köprüsü. */
	public static function fetchCharacter(entryId:String, ?forceMosaic:Dynamic):Dynamic
	{
		if (entryId == null || entryId == '') return null;
		var inst:Dynamic = null;
		try { inst = vslice.scripting.VSScriptRegistry.resolveCharacter(0, 0, entryId, false); }
		catch (e:Dynamic) {}
		if (inst == null)
		{
			try { inst = new objects.Character(0, 0, entryId); }
			catch (e:Dynamic) { return null; }
		}
		return inst;
	}
}

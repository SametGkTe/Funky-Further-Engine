package backend;

#if sys
import sys.io.File;
#end

/**
 * Metadata köprüsü: V-Slice (Polymod) mod metadata'sını (_polymod_meta.json)
 * Psych Engine'in beklediği "pack" nesnesine çevirir.
 *
 * Psych `Mods.getPack()` normalde sadece `pack.json` okur. V-Slice modlarında ise
 * metadata dosyası `_polymod_meta.json`'dır. Bu helper, Psych'in `ModItem` vb.
 * tüketicileri değişmeden çalışsın diye alan eşleştirmesi yapar:
 *
 *   _polymod_meta.json  ->  Psych pack
 *   title               ->  name
 *   description         ->  description
 *   mod_version         ->  version
 *   api_version         ->  (dokunulmaz, PolymodHandler doğrular)
 *   license             ->  license
 *   contributors[]      ->  (dokunulmaz)
 */
class VSliceMeta
{
	/**
	 * Belirtilen mod klasöründe `_polymod_meta.json` var mı?
	 */
	public static function exists(folder:String):Bool
	{
		return Paths.mods(folder + '/_polymod_meta.json') != null
			&& FileSystem.exists(Paths.mods(folder + '/_polymod_meta.json'));
	}

	/**
	 * `_polymod_meta.json` dosyasını okuyup Psych `pack` biçimine çevirir.
	 * Dosya yoksa ya da JSON bozuksa `null` döner.
	 */
	public static function read(folder:String):Dynamic
	{
		#if MODS_ALLOWED
		var path:String = Paths.mods(folder + '/_polymod_meta.json');
		if (path == null || !FileSystem.exists(path)) return null;

		try
		{
			#if sys
			var rawJson:String = File.getContent(path);
			#else
			var rawJson:String = openfl.utils.Assets.getText(path);
			#end
			if (rawJson == null || rawJson.length < 1) return null;

			var raw:Dynamic = haxe.Json.parse(rawJson);
			if (raw == null) return null;

			// Psych `pack` alan adlarına eşleştir.
			var pack:Dynamic = {};
			pack.name = raw.title != null ? raw.title : folder;
			pack.description = raw.description != null ? raw.description : 'No description provided.';
			if (raw.mod_version != null) pack.version = raw.mod_version;
			if (raw.api_version != null) pack.apiVersion = raw.api_version;
			if (raw.license != null) pack.license = raw.license;
			if (raw.contributors != null) pack.contributors = raw.contributors;
			// V-Slice modları için Psych `runsGlobally` mantığı:
			// V-Slice modları da "global" (her menüde etkin) sayılsın.
			pack.runsGlobally = true;

			return pack;
		}
		catch (e:Dynamic)
		{
			trace('VSliceMeta: _polymod_meta.json okunamadı ($folder): $e');
			return null;
		}
		#end
		return null;
	}
}

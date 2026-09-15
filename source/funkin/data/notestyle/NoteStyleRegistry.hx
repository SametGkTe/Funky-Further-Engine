package funkin.data.notestyle;

import funkin.play.notes.notestyle.NoteStyle;

/**
 * FNF uyumluluk shim'i (NoteStyleRegistry) — v20 (Faz 4.5).
 *
 * Resmî v0.8.7: `NoteStyleRegistry.instance.fetchEntry(id)` /
 * `listEntryIds()` / `fetchDefault()`. Further'da yerleşik stiller
 * NoteStyle.fetchNoteStyle önbelleğinden, SCRIPT'li stiller
 * (class X extends ScriptedSongEvent... değil: extends NoteStyle)
 * ScriptedNoteStyle.scriptInit ile üretilir ve burada önbelleklenir.
 */
@:noCustomClass
class NoteStyleRegistry
{
	/* ---- Resmî singleton ---- */

	public static var instance(get, never):NoteStyleRegistry;
	static var _instance:NoteStyleRegistry;
	static function get_instance():NoteStyleRegistry
	{
		if (_instance == null) _instance = new NoteStyleRegistry();
		return _instance;
	}

	public function new() {}

	/** Script'li notestyle örnekleri (sınıf adı küçük harf -> örnek). */
	static var _scripted:Map<String, NoteStyle> = new Map<String, NoteStyle>();

	/* ---- Resmî örnek (instance) API'si ---- */

	/** Resmî: fetchEntry(id) — script'li stilleri de çözer; null dönmez (fallback: funkin). */
	public function fetchEntry(entryId:String, force:Bool = false):Null<NoteStyle>
	{
		if (entryId == null || entryId == '') entryId = 'funkin';
		var sc:Null<NoteStyle> = fetchScripted(entryId);
		if (sc != null) return sc;
		return NoteStyle.fetchNoteStyle(entryId);
	}

	/** Resmî: varsayılan stil. */
	public function fetchDefault():NoteStyle
	{
		return NoteStyle.fetchNoteStyle('funkin');
	}

	/** Resmî: kayıtlı tüm stil id'leri (yerleşik + scripted). */
	public function listEntryIds():Array<String>
	{
		var ids:Array<String> = ['funkin'];
		for (n in listScriptedNames())
			if (!ids.contains(n)) ids.push(n);
		return ids;
	}

	public function listEntryNames():Array<String> return listEntryIds();

	/** Resmî: scripted sınıf adları. */
	public function fetchEntryClassNames():Array<String> return listScriptedNames();

	/* ---- Yardımcılar ---- */

	static function listScriptedNames():Array<String>
	{
		try
		{
			var names:Array<String> = vslice.scripting.ScriptedNoteStyle.listScriptClasses();
			if (names != null) return names;
		}
		catch (e:Dynamic) {}
		return [];
	}

	static function fetchScripted(entryId:String):Null<NoteStyle>
	{
		var lower:String = entryId.toLowerCase();
		if (_scripted.exists(lower)) return _scripted.get(lower);
		for (cls in listScriptedNames())
		{
			if (cls.toLowerCase() != lower) continue;
			try
			{
				var inst:NoteStyle = vslice.scripting.ScriptedNoteStyle.scriptInit(cls, cls);
				if (inst != null)
				{
					_scripted.set(lower, inst);
					return inst;
				}
			}
			catch (e:Dynamic)
			{
				trace('[NoteStyleRegistry] Scripted notestyle kurulamadi: $cls — $e');
			}
			return null;
		}
		return null;
	}

	/* ---- Eski statik imzalar (geriye uyum) ---- */

	public static function getNoteStyle(?id:String):NoteStyle
	{
		return instance.fetchEntry((id != null && id != '') ? id : 'funkin');
	}

	public static function fetchNoteStyle(id:String):NoteStyle
	{
		return instance.fetchEntry(id);
	}
}

package funkin.play.notes.notekind;

/**
 * FNF uyumluluk shim'i (NoteKindManager) - MINIMAL.
 * Further nota tipi sistemini kendi yonetir; bu shim yalnizca import
 * cozumu icin var. Cagrilar null/false doner (v1).
 */
@:noCustomClass
class NoteKindManager
{
	public static function getNoteKind(?id:String):Dynamic
	{
		return null;
	}

	public static function registerNoteKind(?kind:Dynamic):Bool
	{
		return false;
	}
}

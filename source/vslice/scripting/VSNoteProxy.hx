package vslice.scripting;

/**
 * Script'lere giden nota sarmalayicisi (FNF Note API esdegeri).
 *
 * Psych'in objects.Note sinifinda `noteData` bir Int'tir (yön 0-3);
 * FNF script'leri ise `note.noteData.getMustHitNote()` seklinde METOT
 * cagirir (FNF ChartNote API). Int uzerinde metot olmayacagi icin
 * nota olaylarinda event.note gercek Note yerine bu sarmalayiciyi tasir;
 * script'lerin okudugu ortak alanlar (strumTime, mustPress, isSustainNote,
 * noteType, sustainLength) ve noteData sarmalayicisi saglanir.
 */
class VSNoteProxy
{
	var _note:objects.Note;

	public var noteData(get, never):VSNoteData;
	function get_noteData():VSNoteData return new VSNoteData(_note);

	public var strumTime(get, never):Float;
	function get_strumTime():Float return _note.strumTime;

	public var mustPress(get, never):Bool;
	function get_mustPress():Bool return _note.mustPress;

	public var isSustainNote(get, never):Bool;
	function get_isSustainNote():Bool return _note.isSustainNote;

	public var noteType(get, never):String;
	function get_noteType():String return _note.noteType;

	public var sustainLength(get, never):Float;
	function get_sustainLength():Float return _note.sustainLength;

	public function new(note:objects.Note)
	{
		this._note = note;
	}
}

/**
 * FNF ChartNote esdegeri (asgari): script'lerin cagirdigi metotlar.
 */
class VSNoteData
{
	var _note:objects.Note;

	public function new(note:objects.Note)
	{
		this._note = note;
	}

	/** FNF: notayi oyuncu mu basiyor? (Psych: !mustPress) */
	public function getMustHitNote():Bool
	{
		return !_note.mustPress;
	}

	/** FNF: yön (0-3). Psych Note.noteData zaten bu degeri tasir. */
	public function getDirection():Int
	{
		return _note.noteData;
	}
}

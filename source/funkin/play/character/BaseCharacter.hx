package funkin.play.character;

/**
 * V-Slice/FNF uyumluluk shim'i (BaseCharacter).
 *
 * Gerçek FNF mod script'leri `import funkin.play.character.BaseCharacter;`
 * yazıp `class X extends BaseCharacter { function new() { super('id'); } }`
 * türetir. Further'da bu shim, `objects.Character`'a id-tabanlı kurucu ile
 * köprü kurar; Polymod'un script sınıfı yönlendirmesi (scriptClassOverrides)
 * `vslice.scripting.ScriptedBaseCharacter` üzerinden script'leri bağlar.
 */
@:noCustomClass
class BaseCharacter extends objects.Character
{
	/** FNF script'lerinin beklediği alanlar (uyumluluk için). */
	public var characterId:String;
	public var characterName:String;

	public function new(id:String)
	{
		super(0, 0, id, false);
		this.characterId = id;
		this.characterName = id;
	}
}

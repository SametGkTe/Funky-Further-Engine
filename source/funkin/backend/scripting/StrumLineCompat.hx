package funkin.backend.scripting;

/**
 * CNE scriptlerindeki `strumLines` kısayolu için uyumluluk sarmalayıcısı.
 * Further 4k Psych düzeninde çalıştığı için:
 *  members[0] = rakip (dad), members[1] = oyuncu (boyfriend), members[2] = gf
 * CNE scriptleri `strumLines.members[0].characters[0]` şeklinde erişir.
 */
class StrumLineCompat
{
	public var members:Array<StrumLineCompatMember> = [];

	public function new() {}
}

class StrumLineCompatMember
{
	public var characters:Array<Dynamic> = [];
	public var type:Int = 0;
	public var position:String = '';

	public function new(type:Int = 0, position:String = '', ?characters:Array<Dynamic>)
	{
		this.type = type;
		this.position = position;
		if (characters != null) this.characters = characters;
	}
}

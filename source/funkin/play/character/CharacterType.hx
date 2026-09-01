package funkin.play.character;

/**
 * FNF uyumluluk shim'i (CharacterType) - MINIMAL.
 * FNF'deki enum abstract; script'ler `CharacterType.DAD` gibi degerleri
 * kullanir. Polymod enum abstract'lari otomatik destekler.
 */
enum abstract CharacterType(Int) from Int to Int
{
	var BF = 0;
	var DAD = 1;
	var GF = 2;
	var OTHER = 3;

	public function toString():String
	{
		return switch (this)
		{
			case BF: 'bf';
			case DAD: 'dad';
			case GF: 'gf';
			default: 'other';
		}
	}
}

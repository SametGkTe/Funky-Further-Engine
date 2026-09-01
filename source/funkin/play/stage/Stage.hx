package funkin.play.stage;

/**
 * FNF uyumluluk shim'i (Stage).
 * FNF mod script'leri `class garage extends funkin.play.stage.Stage { ... }`
 * türetir; bu shim onları Psych'in BaseStage API'sine bağlar.
 * Script'ler `new Stage()` benzeri direkt kurulum yapmaz — Polymod köprüsü
 * script'i yükleyince bu sınıf taban olur; sahne düzeni StageData'dan gelir.
 */
@:noCustomClass
class Stage extends backend.BaseStage
{
	public function new()
	{
		super();
	}
}

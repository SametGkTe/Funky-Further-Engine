package funkin.play.notes.notestyle;

/**
 * V-Slice/FNF uyumluluk shim'i (NoteStyle) — v17 (Faz 3, derinleştirildi).
 *
 * Resmî v0.8.7'de NoteStyle nota/strum/countdown/judgement varlıklarının
 * görünümünü tanımlar ve registry'den çekilir. Further nota görünümünü
 * kendi noteSkin sistemiyle yönetir; bu shim resmî API YÜZEYİNİ güvenli
 * varsayılanlarla sunar (script'ler `extends NoteStyle` türetebilir,
 * getter'ları çağırabilir; buildNoteSprite vb. no-op'tur).
 */
@:noCustomClass
class NoteStyle
{
	/** Basit yerleşik stiller için statik önbellek. */
	static var _cache:Map<String, NoteStyle> = new Map<String, NoteStyle>();

	/** Resmî yardımcı: id'ye göre NoteStyle (yoksa yeni varsayılan üretir). */
	public static function fetchNoteStyle(id:String):NoteStyle
	{
		if (id == null || id == '') id = 'funkin';
		if (!_cache.exists(id)) _cache.set(id, new NoteStyle(id));
		return _cache.get(id);
	}

	public var id:String = 'funkin';
	public var name:String = 'funkin';
	var _params:Dynamic;

	public function new(id:String, ?params:Dynamic)
	{
		this.id = (id != null) ? id : 'funkin';
		this.name = this.id;
		this._params = params;
	}

	/* ---- Resmî getter'lar (güvenli varsayılanlar) ---- */

	public function getName():String return name;
	public function getAuthor():String return 'FunkinCrew';
	public function getFallbackID():Null<String> return null;

	public function getNoteAssetPath(raw:Bool = false):Null<String> return null;
	public function isNoteAnimated():Bool return false;
	public function getNoteScale():Float return 1.0;
	public function getNoteOffsets():Array<Float> return [0, 0];

	public function getHoldNoteAssetPath(raw:Bool = false):Null<String> return null;
	public function isHoldNotePixel():Bool return false;
	public function fetchHoldNoteScale():Float return 1.0;
	public function getHoldNoteOffsets():Array<Float> return [0, 0];

	public function getStrumlineAssetPath(raw:Bool = false):Null<String> return null;
	public function getStrumlineOffsets():Array<Float> return [0, 0];
	public function getStrumlineScale():Float return 1.0;

	public function isNoteSplashEnabled():Bool return true;
	public function isHoldNoteCoverEnabled():Bool return false;

	public function buildCountdownSprite(step:funkin.play.Countdown.CountdownStep):Null<funkin.graphics.FunkinSprite> return null;
	public function buildCountdownSpritePath(step:funkin.play.Countdown.CountdownStep):Null<String> return null;
	public function isCountdownSpritePixel(step:funkin.play.Countdown.CountdownStep):Bool return false;
	public function getCountdownSpriteOffsets(step:funkin.play.Countdown.CountdownStep):Array<Float> return [0, 0];
	public function getCountdownSoundPath(step:funkin.play.Countdown.CountdownStep, raw:Bool = false):Null<String> return null;

	public function buildJudgementSprite(rating:String):Null<funkin.graphics.FunkinSprite> return null;
	public function buildJudgementSpritePath(rating:String):Null<String> return null;
	public function isJudgementSpritePixel(rating:String):Bool return false;

	/* ---- Resmî no-op'lar (Further render'ı kendi yapar) ---- */

	public function buildNoteSprite(target:objects.Note):Void {}
	public function applyStrumlineFrames(target:objects.StrumNote):Void {}
	public function applyStrumlineAnimations(target:objects.StrumNote, dir:funkin.play.notes.NoteDirection):Void {}
	public function applyStrumlineOffsets(target:objects.StrumNote):Void {}

	/* ---- v20: Resmî frame-builder API'si (script'ler ön-bellekleme için
	   buildNoteFrames(true) vb. çağırır; Further noteSkin kullandığından
	   bunlar güvenle null/no-op döner) ---- */

	public function buildNoteFrames(force:Bool = false):Dynamic return null;
	public function buildSplashFrames(force:Bool = false):Dynamic return null;
	public function buildHoldCoverFrames(force:Bool = false):Dynamic return null;
	public function buildCountdownFrames(force:Bool = false):Dynamic return null;
	public function buildJudgementFrames(force:Bool = false):Dynamic return null;
	public function buildComboNumFrames(force:Bool = false):Dynamic return null;
	public function buildComboNumSprite(digit:Int):Null<funkin.graphics.FunkinSprite> return null;
	public function buildComboNumSpritePath(digit:Int):Null<String> return null;
	public function buildSplashSprite(target:Dynamic):Void {}
	public function buildHoldCoverSprite(target:Dynamic):Void {}

	public function toString():String return 'NoteStyle($id)';
}

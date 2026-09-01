package funkin.graphics;

/**
 * V-Slice/FNF uyumluluk shim'i (FunkinSprite).
 *
 * FNF script'leri `class X extends funkin.graphics.FunkinSprite { ... }`
 * türetir. FNF'nin orijinali atlas/filtre sistemine derinden bağlıdır;
 * Further'da bu shim temel FlxSprite davranışı + birkaç yardımcı sunar.
 * FNF sözdizimi korunur (extends + kurucu), gelişmiş atlas özellikleri yok.
 */
@:noCustomClass
class FunkinSprite extends flixel.FlxSprite
{
	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
	}

	/** Psych tarzı basit resim yükleme yardımcısı. */
	public function loadGraphicSimple(key:String):Void
	{
		this.loadGraphic(backend.Paths.image(key));
	}

	/** Düz renkli kare üretir (FNF'nin makeSolidColor kısaltması). */
	public function makeSolidColor(width:Int, height:Int, color:flixel.util.FlxColor = flixel.util.FlxColor.WHITE):funkin.graphics.FunkinSprite
	{
		this.makeGraphic(width, height, color);
		return this;
	}

	/** Sparrow atlası yükler (vslice yardımcısı üzerinden). */
	public function loadSparrow(key:String):Void
	{
		this.frames = backend.Paths.getSparrowAtlas(key);
	}

	/** Kısa animasyon yardımcısı (FNF script'lerinin alışkanlığı). */
	public function playAnim(name:String, restart:Bool = false):Void
	{
		this.animation.play(name, restart);
	}

	public function getAnimName():String
	{
		return (this.animation != null && this.animation.curAnim != null) ? this.animation.curAnim.name : '';
	}
}

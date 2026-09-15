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
	/** Resmî FNF: sprite çizim sıralaması (Further'da yalnızca taşınır). */
	public var zIndex:Float = 0;

	/**
	 * Resmî v0.8.7 imzası: new(?x, ?y, ?path, ?atlasSettings)
	 * Shim: path verilirse sparrow atlas → olmazsa düz resim yüklenir;
	 * atlasSettings yok sayılır.
	 */
	public function new(?x:Float = 0, ?y:Float = 0, ?path:String, ?atlasSettings:Dynamic)
	{
		super(x, y);
		if (path != null && path != '')
		{
			try
			{
				this.frames = backend.Paths.getSparrowAtlas(path);
			}
			catch (e:Dynamic)
			{
				try
				{
					this.loadGraphic(backend.Paths.image(path));
				}
				catch (e2:Dynamic)
				{
					trace('[FunkinSprite] path yüklenemedi: $path');
				}
			}
		}
	}

	/* ---- v16: resmî FlxAtlasSprite/FunkinSprite API köprüleri ---- */

	/**
	 * Resmî imza: playAnimation(id, restart = false, ignoreOther = false, reversed = false, startFrame = 0)
	 * Flixel karşılığı: animation.play(id, restart, reversed, startFrame).
	 * ignoreOther bu shim'de anlamsız (specialAnim kilidi yok) — yok sayılır.
	 */
	public function playAnimation(id:String, restart:Bool = false, ignoreOther:Bool = false, reversed:Bool = false, startFrame:Int = 0):Void
	{
		if (id == null || animation == null || !animation.exists(id))
		{
			trace('[FunkinSprite] playAnimation: "$id" animasyonu yok.');
			return;
		}
		animation.play(id, restart, reversed, startFrame);
	}

	/** Resmî FNF: hasAnimation(id) */
	public function hasAnimation(id:String):Bool
	{
		return animation != null && animation.exists(id);
	}

	/** Resmî FNF: getCurrentAnimation() */
	public function getCurrentAnimation():Null<String>
	{
		return (animation != null && animation.curAnim != null) ? animation.curAnim.name : null;
	}

	/** Resmî FNF: isAnimationFinished() — geçerli animasyon bitti mi? */
	public function isAnimationFinished():Bool
	{
		return animation != null && animation.curAnim != null && animation.curAnim.finished;
	}

	/** Resmî FNF: listAnimations() — tanımlı tüm animasyon adları. */
	public function listAnimations():Array<String>
	{
		if (animation == null) return [];
		return [for (a in animation.getAnimationList()) a.name];
	}

	/** Resmî FNF: loadTexture(key) — tek kare resim yükler, zincirlenebilir. */
	public function loadTexture(key:String):funkin.graphics.FunkinSprite
	{
		try
		{
			this.loadGraphic(backend.Paths.image(key));
		}
		catch (e:Dynamic)
		{
			trace('[FunkinSprite] loadTexture basarisiz ($key): $e');
		}
		return this;
	}

	/**
	 * Resmî FNF: loadSpriteAtlas(assetPath, prefix, ...)
	 * Shim: sparrow atlasını `prefix` adıyla yükler (assetPath yok sayılır;
	 * Psych Paths.getSparrowAtlas mod/asset çözümlemesini zaten yapar).
	 * FlxAnimate (animate atlas) gerekirse vslice.funkin.FlxAtlasSprite kullanın.
	 */
	public function loadSpriteAtlas(assetPath:String, prefix:String, ?skipAtlasPrefix:Bool = false, ?settings:Dynamic):Void
	{
		try
		{
			this.frames = backend.Paths.getSparrowAtlas(prefix);
		}
		catch (e:Dynamic)
		{
			trace('[FunkinSprite] loadSpriteAtlas basarisiz ($assetPath/$prefix): $e');
		}
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

	/** Sparrow atlası yükler (resmî: zincirlenebilir, FunkinSprite döner). */
	public function loadSparrow(key:String):funkin.graphics.FunkinSprite
	{
		this.frames = backend.Paths.getSparrowAtlas(key);
		return this;
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

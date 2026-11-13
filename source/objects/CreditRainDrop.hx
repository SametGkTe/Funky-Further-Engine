package objects;

import flixel.graphics.FlxGraphic;

/**
 * Credits ekranındaki "icondrop" efektinin tek bir damlası.
 *
 * Davranış: ekranın üstünden rastgele bir X noktasında, rastgele bir açıyla
 * (ve rastgele bir dönüş hızıyla) doğar; HER ZAMAN aşağı doğru süzülür ve
 * ekranın altına inince yukarıdan tekrar doğar. Bu yüzden dönme hareketi
 * dikey düşüşü asla tersine çevirmez — sadece görsel dönüş yapar.
 */
class CreditRainDrop extends FlxSprite
{
	/** Aşağı düşme hızı (px/sn). */
	public var fallSpeed:Float = 120;
	/** Yatay sürüklenme (px/sn), düşüşü bozmamak için küçük tutulur. */
	public var drift:Float = 0;
	/** Dönüş hızı (derece/sn). */
	public var spin:Float = 0;
	/** Spawn anında verilen saydamlık. */
	public var baseAlpha:Float = 1;

	/** Ekranın altına inince çağrılır: state burada damlayı yeniden doğurur. */
	public var onRecycle:Void->Void = null;

	public function new()
	{
		super();
		visible = false;
		active = true;
		scrollFactor.set();
	}

	/**
	 * Verilen graphic ile damlayı ekranın üstüne yerleştirir.
	 * @param graphic  Kullanılacak görsel (seçili credit'in iconu)
	 * @param pixel    Pixel-art icon mu? (antialiasing kapatılır)
	 * @param speedMult Damla hızı çarpanı
	 */
	public function prepare(graphic:FlxGraphic, pixel:Bool = false, speedMult:Float = 1):Void
	{
		if (graphic == null)
		{
			visible = false;
			return;
		}

		if (this.graphic != graphic)
			loadGraphic(graphic);

		antialiasing = !pixel;

		// Rastgele boyut + rastgele açı: "rastgele açılardan rastgele dönerek"
		var size:Float = FlxG.random.float(0.40, 1.0);
		updateHitbox();
		scale.set(size, size);

		baseAlpha = FlxG.random.float(0.25, 0.85);
		alpha = baseAlpha;

		angle = FlxG.random.float(0, 360);
		spin = FlxG.random.float(-150, 150);
		drift = FlxG.random.float(-30, 30);
		fallSpeed = FlxG.random.float(70, 190) * speedMult;

		x = FlxG.random.float(-60, FlxG.width + 60);
		y = FlxG.random.float(-FlxG.height, -height - 20);

		visible = true;
	}

	/** Görseli değiştirir (seçim değiştiğinde mevcut damlalar için). */
	public function setDropGraphic(graphic:FlxGraphic, pixel:Bool = false):Void
	{
		if (graphic == null) return;
		if (this.graphic == graphic) return;

		var lastAngle:Float = angle;
		var lastScaleX:Float = scale.x;
		var lastScaleY:Float = scale.y;

		loadGraphic(graphic);
		updateHitbox();
		scale.set(lastScaleX, lastScaleY);
		angle = lastAngle;
		antialiasing = !pixel;
	}

	override function update(elapsed:Float):Void
	{
		if (visible)
		{
			// Sadece aşağı: dönme açısı ne olursa olsun y artar.
			y += fallSpeed * elapsed;
			x += drift * elapsed;
			angle += spin * elapsed;

			// height/width zaten scale'i içeriyor; dönme payı için max olanı kullan
			if (y > FlxG.height + Math.max(width, height) + 40 || x < -400 || x > FlxG.width + 400)
			{
				if (onRecycle != null) onRecycle();
				else visible = false;
			}
		}
		super.update(elapsed);
	}
}

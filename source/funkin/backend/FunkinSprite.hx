package funkin.backend;

import flixel.addons.effects.FlxSkewedSprite;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;
import backend.Paths;

/**
 * CNE uyumluluğu için FlxSprite benzeri sprite.
 * PEXO'daki FunkinSprite'ın sadeleştirilmiş hali:
 * atlas (FlxAnimate) desteği yok, sadece temel animasyon + offset sistemi var.
 * CNE scriptlerinin `FunkinSprite` kullanımı (playAnim / animOffsets) karşılanır.
 */
class FunkinSprite extends FlxSkewedSprite
{
	public var extra:Map<String, Dynamic> = [];

	public var animOffsets:Map<String, FlxPoint> = new Map<String, FlxPoint>();

	public function new(?X:Float = 0, ?Y:Float = 0, ?SimpleGraphic:FlxGraphicAsset)
	{
		super(X, Y);

		if (SimpleGraphic != null)
		{
			if (SimpleGraphic is String)
				loadGraphic(Paths.image(cast SimpleGraphic));
			else
				loadGraphic(SimpleGraphic);
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (AnimName == null) return;
		if (!animation.exists(AnimName)) return;
		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset:FlxPoint = getAnimOffset(AnimName);
		offset.set(daOffset.x, daOffset.y);
		daOffset.putWeak();
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = FlxPoint.get(x, y);
	}

	public inline function getAnimOffset(name:String):FlxPoint
	{
		if (animOffsets.exists(name))
			return animOffsets[name];
		return FlxPoint.weak(0, 0);
	}

	public inline function hasAnimation(AnimName:String):Bool
	{
		return animation.exists(AnimName);
	}

	public inline function getAnimName():String
	{
		return animation.curAnim != null ? animation.curAnim.name : null;
	}

	public inline function removeAnimation(name:String)
	{
		animation.remove(name);
	}

	public inline function getNameList():Array<String>
	{
		return animation.getNameList();
	}

	public inline function stopAnimation()
	{
		animation.stop();
	}

	public inline function isAnimFinished():Bool
	{
		return animation.curAnim != null ? animation.curAnim.finished : true;
	}

	override public function destroy():Void
	{
		if (animOffsets != null)
		{
			for (key in animOffsets.keys())
			{
				final point:FlxPoint = animOffsets[key];
				animOffsets.remove(key);
				if (point != null)
					point.put();
			}
			animOffsets = null;
		}
		super.destroy();
	}
}

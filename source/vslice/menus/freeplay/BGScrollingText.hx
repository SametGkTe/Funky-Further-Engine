package vslice.menus.freeplay;

import flixel.text.FlxText;
import flixel.util.FlxSort;
import flixel.math.FlxPoint;

@:nullSafety
class BGScrollingText extends FlxText
{
	var _textPositions:Array<FlxPoint> = [];
	var _positionCache:FlxPoint = FlxPoint.get();
	var _needsSort:Bool = false;

	public var widthShit:Float = FlxG.width;
	public var placementOffset:Float = 20;
	public var speed:Float = 1;

	public function new(x:Float, y:Float, text:String, widthShit:Float = 100, ?bold:Bool = false, ?size:Int = 48)
	{
		super(x, y, 0, text, size);
		_positionCache = FlxPoint.get(x, y);
		font = "5by7";
		this.bold = bold ?? false;

		this.widthShit = widthShit;

		@:privateAccess
		regenGraphic();

		var needed:Int = Math.ceil(widthShit / frameWidth) + 1;

		for (i in 0...needed)
		{
			_textPositions.push(FlxPoint.get((i * frameWidth) + (i * 20), 0));
		}
	}

	override public function update(elapsed:Float):Void
	{
		if (!visible || alpha <= 0)
			return;

		super.update(elapsed);

		var delta:Float = speed * (elapsed / (1 / 60));
		_needsSort = false;

		for (txtPosition in _textPositions)
		{
			if (txtPosition == null)
				continue;

			txtPosition.x -= delta;

			if (speed > 0)
			{
				if (txtPosition.x < -frameWidth)
				{
					txtPosition.x = getLastX() + frameWidth + placementOffset;
					_needsSort = true;
				}
			}
			else
			{
				if (txtPosition.x > frameWidth * 2)
				{
					txtPosition.x = getFirstX() - frameWidth - placementOffset;
					_needsSort = true;
				}
			}
		}

		// Sadece gerektiğinde sort yap
		if (_needsSort)
			sortTextShit();
	}

	override public function draw():Void
	{
		if (!visible || alpha <= 0)
			return;

		_positionCache.set(x, y);
		var screenLeft:Float = -frameWidth;
		var screenRight:Float = FlxG.width + frameWidth;

		for (position in _textPositions)
		{
			if (position == null)
				continue;

			var drawX:Float = _positionCache.x + position.x;

			if (drawX > screenRight || drawX + frameWidth < screenLeft)
				continue;

			setPosition(drawX, _positionCache.y + position.y);
			super.draw();
		}
		setPosition(_positionCache.x, _positionCache.y);
	}

	// Cached first/last X getters — sort'tan kaçınmak için
	inline function getLastX():Float
	{
		var maxX:Float = -999999;
		for (p in _textPositions)
		{
			if (p != null && p.x > maxX)
				maxX = p.x;
		}
		return maxX;
	}

	inline function getFirstX():Float
	{
		var minX:Float = 999999;
		for (p in _textPositions)
		{
			if (p != null && p.x < minX)
				minX = p.x;
		}
		return minX;
	}

	function sortTextShit():Void
	{
		_textPositions.sort(function(Obj1:FlxPoint, Obj2:FlxPoint)
		{
			return FlxSort.byValues(FlxSort.ASCENDING, Obj1.x, Obj2.x);
		});
	}
}

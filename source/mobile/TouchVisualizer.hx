package mobile;

#if mobile
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.TouchEvent;

/**
 * Tüm mobil ekranlarda dokunulan noktayı kısa süreli beyaz bir daireyle gösterir.
 *
 * Performans notları:
 * - Her dokunuşta yeni Bitmap/Sprite/Tween oluşturmaz.
 * - Bütün göstergeler tek bir BitmapData'yı paylaşır.
 * - Ayar kapalıyken frame listener çalışmaz.
 * - Fade tamamlandığında ENTER_FRAME listener tamamen kaldırılır.
 */
class TouchVisualizer extends Sprite
{
	static inline final POOL_SIZE:Int = 10;
	static inline final DIAMETER:Int = 28;
	static inline final RADIUS:Float = DIAMETER * 0.5;
	static inline final START_ALPHA:Float = 0.6;
	static inline final FADE_TIME_MS:Int = 220;

	var markers:Array<TouchMarker> = [];
	var nextMarker:Int = 0;
	var updating:Bool = false;

	public function new()
	{
		super();
		mouseEnabled = false;
		mouseChildren = false;

		// Daire yalnızca bir kez çizilir ve tüm Bitmap nesneleri bunu paylaşır.
		var circleData:BitmapData = new BitmapData(DIAMETER, DIAMETER, true, 0x00000000);
		var shape:Shape = new Shape();
		shape.graphics.beginFill(0xFFFFFF, 1);
		shape.graphics.drawCircle(RADIUS, RADIUS, RADIUS);
		shape.graphics.endFill();
		circleData.draw(shape);

		for (i in 0...POOL_SIZE)
		{
			var bitmap:Bitmap = new Bitmap(circleData);
			// Bitmap bir InteractiveObject değildir; girişleri zaten yakalamaz.
			bitmap.visible = false;
			addChild(bitmap);
			markers.push(new TouchMarker(bitmap));
		}

		if (stage != null)
			attachToStage();
		else
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage, false, 0, true);
	}

	function onAddedToStage(_:Event):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		attachToStage();
	}

	inline function attachToStage():Void
	{
		// Flixel'den bağımsız stage koordinatı kullanıldığı için state/substate
		// ve kamera değişimlerinde ek işlem gerekmez.
		stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin, false, 0, true);
	}

	function onTouchBegin(event:TouchEvent):Void
	{
		if (!ClientPrefs.data.showTouches)
			return;

		var marker:TouchMarker = markers[nextMarker];
		nextMarker = (nextMarker + 1) % POOL_SIZE;

		marker.bitmap.x = event.stageX - RADIUS;
		marker.bitmap.y = event.stageY - RADIUS;
		marker.bitmap.alpha = START_ALPHA;
		marker.bitmap.visible = true;
		marker.startedAt = Lib.getTimer();
		marker.active = true;

		if (!updating)
		{
			updating = true;
			addEventListener(Event.ENTER_FRAME, updateFade, false, 0, true);
		}
	}

	function updateFade(_:Event):Void
	{
		var now:Int = Lib.getTimer();
		var hasActiveMarker:Bool = false;

		for (marker in markers)
		{
			if (!marker.active)
				continue;

			var progress:Float = (now - marker.startedAt) / FADE_TIME_MS;
			if (progress >= 1)
			{
				marker.active = false;
				marker.bitmap.visible = false;
				continue;
			}

			marker.bitmap.alpha = START_ALPHA * (1 - progress);
			hasActiveMarker = true;
		}

		if (!hasActiveMarker)
		{
			updating = false;
			removeEventListener(Event.ENTER_FRAME, updateFade);
		}
	}
}

private class TouchMarker
{
	public var bitmap:Bitmap;
	public var startedAt:Int = 0;
	public var active:Bool = false;

	public inline function new(bitmap:Bitmap)
	{
		this.bitmap = bitmap;
	}
}
#end

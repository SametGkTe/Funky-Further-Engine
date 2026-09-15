package funkin.data.song;

/**
 * V-Slice/FNF uyumluluk shim'i (SongData modülü) — v15.
 *
 * Resmî funkin v0.8.7 `funkin/data/song/SongData.hx` modülünün
 * script'lerin dokunduğu kısmı: `SongEventData` (+ Raw), `SongNoteData`.
 *
 * Script kullanımı:
 *   import funkin.data.song.SongData.SongEventData;
 *   ...
 *   override function handleEvent(data:SongEventData) {
 *     var zoom:Float = data.getFloat('zoom') ?? 1.0;
 *   }
 *
 * Polymod çözümlemesi: "funkin.data.song.SongData.SongEventData" tam yolu
 * önce denenir; modül-eksik yol ("funkin.data.song.SongEventData") da
 * resolveImportedClass'ta yedek olarak denenir ve runtime'da
 * Type.resolveClass ile bulunur (DCE kapalı). Ayrıca abstract yapısı
 * abstractClassImpls makrosuna takılır — resmî FNF ile aynı mekanizma.
 */

/**
 * Taşıyıcı sınıf (modül adı ile aynı). Resmî FNF'de bu modül yalnızca
 * typedef/sınıf kümesidir.
 */
@:noCustomClass
class SongData
{
}

/**
 * V-Slice chart nota verisi ({t, d, l, k}).
 */
@:noCustomClass
class SongNoteData
{
	/** Nota zamanı (ms). JSON: "t" */
	public var time:Float = 0;

	/** Yön: 0-3 oyuncu, 4-7 rakip. JSON: "d" */
	public var direction:Int = 0;

	/** Uzunluk (ms) — sustain için. JSON: "l" */
	public var length:Float = 0;

	/** Nota türü (notekind). JSON: "k" */
	public var kind:String = '';

	public function new(time:Float = 0, direction:Int = 0, length:Float = 0, kind:String = '')
	{
		this.time = time;
		this.direction = direction;
		this.length = length;
		this.kind = kind;
	}

	public function clone():SongNoteData
	{
		return new SongNoteData(time, direction, length, kind);
	}

	public function toString():String
	{
		return 'SongNoteData(t=$time, d=$direction, l=$length, k=$kind)';
	}
}

/**
 * Resmî FNF'deki SongEventDataRaw karşılığı (serileştirilebilir ham sınıf).
 */
@:noCustomClass
class SongEventDataRaw
{
	/**
	 * The timestamp of the event (ms).
	 */
	public var time(default, set):Float;

	function set_time(value:Float):Float
	{
		_stepTime = null;
		return time = value;
	}

	/**
	 * The kind of the event.
	 * Examples include "FocusCamera" and "PlayAnimation".
	 */
	public var eventKind:String;

	/**
	 * The data for the event. JSON-serializable herhangi bir değer.
	 */
	public var value:Dynamic = null;

	/**
	 * Whether this event has been activated (engine içi kullanım).
	 */
	public var activated:Bool = false;

	public function new(time:Float, eventKind:String, value:Dynamic = null)
	{
		this.time = time;
		this.eventKind = eventKind;
		this.value = value;
	}

	var _stepTime:Null<Float> = null;

	/**
	 * Get the position of the event in the song, in steps.
	 */
	public function getStepTime(force:Bool = false):Float
	{
		if (_stepTime != null && !force) return _stepTime;
		return _stepTime = backend.Conductor.getStep(this.time);
	}

	public function clone():SongEventDataRaw
	{
		return new SongEventDataRaw(this.time, this.eventKind, this.value);
	}

	public function valueAsStruct(?defaultKey:String = "key"):Dynamic
	{
		if (this.value == null) return {};
		if (Std.isOfType(this.value, Array))
		{
			var result:haxe.DynamicAccess<Dynamic> = {};
			result.set(defaultKey, this.value);
			return cast result;
		}
		else if (Reflect.isObject(this.value))
		{
			return cast this.value;
		}
		else
		{
			var result:haxe.DynamicAccess<Dynamic> = {};
			result.set(defaultKey, this.value);
			return cast result;
		}
	}

	/**
	 * Retrieve the SongEvent handler class for this event.
	 */
	public function getHandler():Null<funkin.play.event.SongEvent>
	{
		return funkin.data.event.SongEventRegistry.getEvent(this.eventKind);
	}

	/**
	 * Retrieve the schema for this event.
	 */
	public function getSchema():Null<funkin.data.event.SongEventSchema>
	{
		return funkin.data.event.SongEventRegistry.getEventSchema(this.eventKind);
	}

	public function getDynamic(key:String):Dynamic
	{
		var data:haxe.DynamicAccess<Dynamic> = valueAsStruct();
		return data.get(key);
	}

	public function getBool(key:String):Null<Bool>
	{
		var value:Dynamic = getDynamic(key);
		if (value == null) return null;
		if (Std.isOfType(value, Bool)) return value;
		if (Std.isOfType(value, String))
		{
			var s:String = (value : String).toLowerCase();
			if (s == 'true') return true;
			if (s == 'false') return false;
		}
		return null;
	}

	public function getInt(key:String):Null<Int>
	{
		var value:Dynamic = getDynamic(key);
		if (value == null) return null;
		if (Std.isOfType(value, Int)) return value;
		if (Std.isOfType(value, Float)) return Std.int(value);
		if (Std.isOfType(value, String))
		{
			var parsed:Null<Int> = Std.parseInt(value);
			return parsed;
		}
		return null;
	}

	public function getFloat(key:String):Null<Float>
	{
		var value:Dynamic = getDynamic(key);
		if (value == null) return null;
		if (Std.isOfType(value, Float)) return value;
		if (Std.isOfType(value, Int)) return value;
		if (Std.isOfType(value, String))
		{
			var parsed:Float = Std.parseFloat(value);
			if (Math.isNaN(parsed)) return null;
			return parsed;
		}
		return null;
	}

	public function getString(key:String):String
	{
		var value:Dynamic = getDynamic(key);
		if (value == null) return null;
		return Std.string(value);
	}

	public function getArray(key:String):Array<Dynamic>
	{
		var value:Dynamic = getDynamic(key);
		if (value == null) return null;
		if (Std.isOfType(value, Array)) return cast value;
		return null;
	}

	public function getBoolArray(key:String):Array<Bool>
	{
		var value:Dynamic = getDynamic(key);
		if (value == null) return null;
		if (Std.isOfType(value, Array)) return cast value;
		return null;
	}

	public function getFloatArray(key:String):Array<Float>
	{
		var value:Dynamic = getDynamic(key);
		if (value == null) return null;
		if (Std.isOfType(value, Array)) return cast value;
		return null;
	}

	public function getStringArray(key:String):Array<String>
	{
		var value:Dynamic = getDynamic(key);
		if (value == null) return null;
		if (Std.isOfType(value, Array)) return cast value;
		return null;
	}

	public function toString():String
	{
		return 'SongEventData(${eventKind}, ${value})';
	}
}

/**
 * Resmî FNF ile aynı: SongEventDataRaw üzerine @:forward abstract.
 */
@:forward(time, eventKind, value, activated, getStepTime, clone, getHandler, getSchema, getDynamic, getBool, getInt, getFloat, getString, getArray,
	getBoolArray, getFloatArray, getStringArray, valueAsStruct, toString)
abstract SongEventData(SongEventDataRaw) from SongEventDataRaw to SongEventDataRaw
{
	public function new(time:Float, eventKind:String, value:Dynamic = null)
	{
		this = new SongEventDataRaw(time, eventKind, value);
	}

	/**
	 * Create an independent copy of this event with the same underlying data.
	 */
	public function clone():SongEventData
	{
		return new SongEventData(this.time, this.eventKind, this.value);
	}
}

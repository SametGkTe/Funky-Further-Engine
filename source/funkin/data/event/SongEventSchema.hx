package funkin.data.event;

/**
 * V-Slice/FNF uyumluluk shim'i (SongEventSchema) — v15.
 *
 * Resmî funkin v0.8.7'de bu şema, chart editöründeki event formunu
 * üretmek için kullanılır. Further'da chart editörü Psych tabanlı
 * olduğundan şema yalnızca "script'ler getEventSchema() override
 * edebilsin ve import çözülsün" diye MINIMAL olarak taşınır.
 */

/**
 * Şema alan tipi. Resmî FNF'de enum abstract'tır; runtime çözümlemesi
 * risksiz olsun diye düz statik sabitler kullanıldı (değerler aynı).
 */
@:noCustomClass
class SongEventFieldType
{
	public static inline var STRING:String = 'string';
	public static inline var INTEGER:String = 'integer';
	public static inline var FLOAT:String = 'float';
	public static inline var BOOL:String = 'bool';
	public static inline var ENUM:String = 'enum';
	public static inline var FRAME:String = 'frame';
}

/**
 * Tek bir şema alanı tanımı.
 */
@:noCustomClass
class SongEventSchemaField
{
	public var key:String;
	public var name:String;
	public var type:String;
	public var defaultValue:Dynamic = null;
	public var step:Null<Float> = null;
	public var min:Null<Float> = null;
	public var max:Null<Float> = null;

	/** ENUM tipi için seçenek anahtarları. */
	public var keys:Null<Array<String>> = null;

	/** ENUM tipi için seçenek görünen adları. */
	public var values:Null<Array<String>> = null;

	/** Sayı alanları için çarpan (örn. derece -> radyan). */
	public var multiplier:Null<Float> = null;

	public function new(key:String, name:String, type:String, ?defaultValue:Dynamic)
	{
		this.key = key;
		this.name = name;
		this.type = type;
		this.defaultValue = defaultValue;
	}

	public function toString():String
	{
		return 'SongEventSchemaField($key, $type)';
	}
}

/**
 * Ham şema sınıfı (resmî SongEventSchemaRaw karşılığı).
 */
@:noCustomClass
class SongEventSchemaRaw
{
	public var fields:Array<SongEventSchemaField>;

	public function new(?fields:Array<SongEventSchemaField>)
	{
		this.fields = (fields != null) ? fields : [];
	}

	public function getByName(key:String):Null<SongEventSchemaField>
	{
		for (field in fields)
		{
			if (field != null && field.key == key) return field;
		}
		return null;
	}

	public function getKeys():Array<String>
	{
		var result:Array<String> = [];
		for (field in fields)
		{
			if (field != null) result.push(field.key);
		}
		return result;
	}
}

/**
 * Resmî FNF ile aynı: abstract sarmalayıcı.
 */
@:forward(fields, getByName, getKeys)
abstract SongEventSchema(SongEventSchemaRaw) from SongEventSchemaRaw to SongEventSchemaRaw
{
	public function new(?fields:Array<SongEventSchemaField>)
	{
		this = new SongEventSchemaRaw(fields);
	}
}

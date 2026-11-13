package objects;

/**
 * CREDITS KİŞİSELLEŞTİRME — tek bir credit satırının görünüm ayarları.
 *
 * credits.txt satırının 6. alanı (renkten sonra gelen kısım) bayrakları tutar.
 * Virgül (,) ya da çift iki nokta (::) ayırıcı olarak kullanılabilir.
 *
 * Örnek satır:
 *   Perez Sen::SAO::Cuenta De youtube::https://www.youtube.com/channel/UCEY::FFA500::icondrop, ::custom::shared/images/özel.png::
 *
 * Desteklenen bayraklar:
 * ARKAPLAN MODU (tek seçim — birbirini dışlar):
 *   icondrop            → arkaplan = FlxBackdrop grid  +  icon yağmuru
 *   grid                → arkaplan = FlxBackdrop grid (yağmur yok)
 *   custom::yol.png     → arkaplan = özel resim (grid ve yağmur yok)
 *   mode::icondrop|custom|default → modu açıkça seçer
 *   Son yazılan mod kazanır; "icondrop" + "custom" aynı satırda kullanılmaz.
 *
 * EFEKT / İNCE AYAR bayrakları:
 *   rain / rain::20     → icon yağmurunu açar (sayı opsiyonel)
 *   norain              → yağmuru kapatır
 *   raincount::24       → damla sayısı (0 - 40)
 *   rainspeed::1.5      → damla hızı çarpanı
 *   gridspeed::80       → grid kayma hızı (varsayılan 40)
 *   gridalpha::0.5      → grid saydamlığı (0 - 1, varsayılan 1.0 = tam opak)
 *   nocustom            → özel arkaplanı kapatır
 *   dim::0.4            → arkaplanı karartma oranı (0 - 1)
 *   color::FF0055       → sadece bu satır için renk geçersiz kılma
 *   plain / none        → grid + yağmur + özel arkaplan hepsini kapatır
 *
 * Global ayar: ismi [global] / [settings] / [ayarlar] / [genel] olan satır
 * listelenmez, sadece o dosyadaki tüm credit'lerin varsayılanı olur.
 */
class CreditStyle
{
	public static inline var MIN_RAIN_COUNT:Int = 0;
	public static inline var MAX_RAIN_COUNT:Int = 40;
	public static inline var DEFAULT_RAIN_COUNT:Int = 14;

	// --- Arkaplan modları (aynı anda SADECE biri aktif olabilir) ---
	/** Klasik renkli menuDesat arkaplanı. */
	public static inline var BG_DEFAULT:Int = 0;
	/** FlxBackdrop + FlxGridOverlay grid arkaplanı. */
	public static inline var BG_ICONDROP:Int = 1;
	/** Özel arkaplan resmi. */
	public static inline var BG_CUSTOM:Int = 2;

	/** Aktif arkaplan modu: BG_DEFAULT / BG_ICONDROP / BG_CUSTOM. */
	public var bgMode:Int = BG_DEFAULT;
	/** Icon yağmuru aktif mi? (icondrop modunda varsayılan true) */
	public var rain:Bool = false;
	/** Kaç damla düşecek. */
	public var rainCount:Int = DEFAULT_RAIN_COUNT;
	/** Damla hızı çarpanı. */
	public var rainSpeed:Float = 1.0;
	/** Grid'in kayma hızı. */
	public var gridSpeed:Float = 40.0;
	/** Grid'in hedef saydamlığı. Varsayılan 1.0 = tam opak (arkada bg yok). */
	public var gridAlpha:Float = 1.0;
	/** `gridalpha::` ile AÇIKÇA yazıldı mı? Yazılmadıysa 1.0 zorunlu. */
	public var gridAlphaSet:Bool = false;
	/** Özel arkaplan resmi (ham yol, çözümleme CreditsState'te yapılır). */
	public var customBg:String = null;
	/** Arkaplan karartma oranı, -1 = otomatik (özel resimde 0.35, diğerlerinde 0). */
	public var dim:Float = -1.0;
	/** Renk geçersiz kılma (hex string). */
	public var color:String = null;

	public function new() {}

	public function copy():CreditStyle
	{
		var s:CreditStyle = new CreditStyle();
		s.bgMode = bgMode;
		s.rain = rain;
		s.rainCount = rainCount;
		s.rainSpeed = rainSpeed;
		s.gridSpeed = gridSpeed;
		s.gridAlpha = gridAlpha;
		s.gridAlphaSet = gridAlphaSet;
		s.customBg = customBg;
		s.dim = dim;
		s.color = color;
		return s;
	}

	/** Bu satırda özel bir görünüm ayarı var mı? */
	public function hasCustomLook():Bool
	{
		return bgMode != BG_DEFAULT || rain || customBg != null || dim >= 0 || color != null;
	}

	// ---------------------------------------------------------------- PARSER

	static var KNOWN_FLAGS:Array<String> = [
		'icondrop', 'icondrops', 'drop',
		'grid', 'flxgrid', 'nogrid', 'nographic',
		'mode', 'bgmode',
		'rain', 'iconrain', 'drops', 'norain', 'nograin',
		'raincount', 'rainamount', 'dropcount', 'rainspeed',
		'gridspeed', 'gridalpha',
		'custom', 'bg', 'image', 'background', 'nocustom',
		'dim', 'color',
		'plain', 'none', 'clear'
	];

	public static function isFlag(word:String):Bool
	{
		if (word == null) return false;
		return KNOWN_FLAGS.indexOf(word.toLowerCase().trim()) > -1;
	}

	/**
	 * Bayrak metnini çözümler. `base` verilirse onun üzerine yazar
	 * (global ayarların üstüne satır ayarı bindirmek için kullanılır).
	 */
	public static function parse(flags:String, ?base:CreditStyle):CreditStyle
	{
		var style:CreditStyle = (base != null) ? base : new CreditStyle();
		if (flags == null) return style;

		var tokens:Array<String> = tokenize(flags);

		var i:Int = 0;
		while (i < tokens.length)
		{
			var key:String = tokens[i].toLowerCase();
			var value:String = null;

			if (i + 1 < tokens.length && !isFlag(tokens[i + 1]))
			{
				value = tokens[i + 1];
				i++;
			}

			switch (key)
			{
				case 'icondrop' | 'icondrops' | 'drop':
					style.bgMode = BG_ICONDROP;
					style.rain = true;

				case 'grid' | 'flxgrid':
					style.bgMode = BG_ICONDROP;
					style.rain = false;

				case 'nogrid' | 'nographic':
					if (style.bgMode == BG_ICONDROP) style.bgMode = BG_DEFAULT;

				case 'mode' | 'bgmode':
					switch ((value != null) ? value.toLowerCase() : '')
					{
						case 'icondrop' | 'grid':
							style.bgMode = BG_ICONDROP;
							style.rain = true;
						case 'custom' | 'image' | 'bg':
							style.bgMode = BG_CUSTOM;
						case 'default' | 'none' | 'plain' | 'funkin':
							style.bgMode = BG_DEFAULT;
							style.rain = false;
						default:
							// geçersiz değer: yoksay
					}

				case 'rain' | 'iconrain' | 'drops':
					style.rain = true;
					var n:Null<Int> = parseInt(value);
					if (n != null) style.rainCount = clampRain(n);

				case 'norain' | 'nograin':
					style.rain = false;

				case 'raincount' | 'rainamount' | 'dropcount':
					var n2:Null<Int> = parseInt(value);
					if (n2 != null) style.rainCount = clampRain(n2);

				case 'rainspeed':
					var f:Null<Float> = parseFloat(value);
					if (f != null) style.rainSpeed = Math.max(0.1, Math.min(4, f));

				case 'gridspeed':
					var f2:Null<Float> = parseFloat(value);
					if (f2 != null) style.gridSpeed = f2;

				case 'gridalpha':
					style.gridAlphaSet = true;
					var f3:Null<Float> = parseFloat(value);
					if (f3 != null) style.gridAlpha = Math.max(0, Math.min(1, f3));

				case 'custom' | 'bg' | 'image' | 'background':
					if (value != null && value.length > 0)
					{
						style.customBg = value;
						style.bgMode = BG_CUSTOM;
					}

				case 'nocustom':
					style.customBg = null;
					if (style.bgMode == BG_CUSTOM) style.bgMode = BG_DEFAULT;

				case 'dim':
					var f4:Null<Float> = parseFloat(value);
					if (f4 != null) style.dim = Math.max(0, Math.min(1, f4));

				case 'color':
					if (value != null && value.length > 0) style.color = value;

				case 'plain' | 'none' | 'clear':
					style.bgMode = BG_DEFAULT;
					style.rain = false;
					style.customBg = null;
					style.dim = -1;
					style.color = null;

				default:
					// bilinmeyen bayrak: yoksay (ileri sürüm bayrakları eski sürümü bozmasın)
			}

			i++;
		}
		return style;
	}

	/**
	 * Bayrak metnini virgül / iki nokta / noktalı virgül üzerinden parçalar.
	 * (EReg.split tek başına Haxe'de tüm ayırıcıları bölmediği için elle yazıldı.)
	 */
	static function tokenize(flags:String):Array<String>
	{
		var tokens:Array<String> = [];
		var buffer:StringBuf = new StringBuf();

		for (i in 0...flags.length)
		{
			var c:String = flags.charAt(i);
			if (c == ',' || c == ':' || c == ';')
			{
				var token:String = buffer.toString().trim();
				if (token.length > 0) tokens.push(token);
				buffer = new StringBuf();
			}
			else buffer.add(c);
		}

		var last:String = buffer.toString().trim();
		if (last.length > 0) tokens.push(last);

		return tokens;
	}

	static function clampRain(value:Int):Int
	{
		return Std.int(Math.max(MIN_RAIN_COUNT, Math.min(MAX_RAIN_COUNT, value)));
	}

	static function parseInt(value:String):Null<Int>
	{
		if (value == null) return null;
		return Std.parseInt(value.trim());
	}

	static function parseFloat(value:String):Null<Float>
	{
		if (value == null) return null;
		return Std.parseFloat(value.trim());
	}

	/** Modun okunabilir adı (debug/UI için). */
	public function modeName():String
	{
		return switch (bgMode)
		{
			case BG_ICONDROP: 'icondrop';
			case BG_CUSTOM: 'custom';
			default: 'default';
		}
	}

	public function toString():String
	{
		return 'CreditStyle(mode=$bgMode, rain=$rain, rainCount=$rainCount, rainSpeed=$rainSpeed, '
			+ 'gridSpeed=$gridSpeed, gridAlpha=$gridAlpha, customBg=$customBg, dim=$dim, color=$color)';
	}
}

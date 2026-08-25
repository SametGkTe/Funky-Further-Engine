package cne.compatibility;


#if sys
import sys.io.File;
#end

/**
 * CNECharacterConverter — Codename Engine karakter XML'ini (`data/characters/*.xml`)
 * runtime'da Psych (Further-Engine) karakter JSON formatına çevirir.
 *
 * FORMAT EŞLEŞMESİ:
 *   CNE XML                              Psych JSON
 *   ----------------------------------   --------------------------------
 *   <character sprite="bf">              image: "characters/bf"
 *   x / y                                position: [x, y]
 *   camx / camy                          camera_position: [camx, camy]
 *   icon                                 healthicon
 *   color (#RRGGBB)                      healthbar_colors: [r, g, b]
 *   flipX                                flip_x
 *   holdTime                             sing_duration
 *   scale                                scale
 *   antialiasing="false"                 no_antialiasing: true
 *   isPlayer                             _editor_isPlayer
 *   <anim name="idle" anim="BF idle.."   animations: [{anim, name, fps,
 *         fps loop indices x y/>            loop, indices, offsets}]
 *
 * KISITLAR: FlxAnimate karakterler çalışır (images/characters/<sprite>/Animation.json
 * otomatik algılanır). Karakter scriptleri (.hx) desteklenmez.
 */
class CNECharacterConverter
{
	/**
	 * Aktif mod sırasına göre tüm modlarda karakteri arar ve ilk bulunanı
	 * Psych JSON'una çevirir. Bulunamazsa null.
	 */
	public static function convertFromMods(character:String):Dynamic
	{
		#if MODS_ALLOWED
		for (mod in CNECompat.modSearchOrder())
		{
			var json:Dynamic = convertFromMod(mod, character);
			if (json != null) return json;
		}
		#end
		return null;
	}

	/** Belirli bir moddaki CNE karakter XML'ini Psych JSON'una çevirir. */
	public static function convertFromMod(mod:String, character:String):Dynamic
	{
		#if (MODS_ALLOWED && sys)
		var path:String = CNECompat.findCharacterXml(mod, character);
		if (path == null) return null;
		try
		{
			var node:Xml = Xml.parse(File.getContent(path)).firstElement();
			if (node == null) return null;
			return convertNode(node, character);
		}
		catch (e:Dynamic)
		{
			trace('[CNECharacter] "$character" karakteri çevrilemedi (mod: $mod): $e');
			return null;
		}
		#else
		return null;
		#end
	}

	static var _iconCache:Map<String, String> = new Map();

	/**
	 * Bir karakterin CNE XML'indeki `icon` attribute'unu çözer (önbellekli).
	 * Psych ikon dosyaları karakter adıyla aranır; CNE'de ikon adı karakter
	 * adından farklı olabildiği için HealthIcon bunu kullanır. Karakterin
	 * CNE XML'i yoksa null döner.
	 */
	public static function resolveIconName(character:String):String
	{
		if (character == null || character.length < 1) return null;
		#if (MODS_ALLOWED && sys)
		var key:String = character + '::' + backend.Mods.currentModDirectory;
		if (_iconCache.exists(key))
		{
			var cached:String = _iconCache.get(key);
			return cached.length > 0 ? cached : null;
		}
		var icon:String = null;
		for (mod in CNECompat.modSearchOrder())
		{
			var path:String = CNECompat.findCharacterXml(mod, character);
			if (path == null) continue;
			try
			{
				var node:Xml = Xml.parse(File.getContent(path)).firstElement();
				if (node != null && node.exists('icon') && node.get('icon').length > 0)
				{
					icon = node.get('icon');
					break;
				}
			}
			catch (e:Dynamic) {}
		}
		_iconCache.set(key, icon != null ? icon : '');
		return icon;
		#else
		return null;
		#end
	}

	static function convertNode(node:Xml, character:String):Dynamic
	{
		var sprite:String = node.exists('sprite') ? node.get('sprite') : character;

		var animations:Array<Dynamic> = [];
		for (el in node.elements())
		{
			if (el.nodeName != 'anim') continue;
			var animName:String = el.exists('name') ? el.get('name') : null;
			var animPrefix:String = el.exists('anim') ? el.get('anim') : null;
			if (animName == null || animPrefix == null) continue;

			animations.push({
				anim: animName,
				name: animPrefix,
				fps: Std.int(CNECompat.parseFloatAttr(el, 'fps', 24)),
				loop: el.exists('loop') && el.get('loop') == 'true',
				indices: CNECompat.parseIntList(el.exists('indices') ? el.get('indices') : null),
				offsets: [
					Std.int(CNECompat.parseFloatAttr(el, 'x', 0)),
					Std.int(CNECompat.parseFloatAttr(el, 'y', 0))
				]
			});
		}

		var colors:Array<Int> = CNECompat.parseColor(node.exists('color') ? node.get('color') : null);
		if (colors == null) colors = [161, 161, 161];

		return {
			animations: animations,
			image: 'characters/$sprite',
			scale: CNECompat.parseFloatAttr(node, 'scale', 1),
			sing_duration: CNECompat.parseFloatAttr(node, 'holdTime', 4),
			is_player: node.exists('isPlayer') && node.get('isPlayer') == 'true',
			position: [
				CNECompat.parseFloatAttr(node, 'x', 0),
				CNECompat.parseFloatAttr(node, 'y', 0)
			],
			camera_position: [
				CNECompat.parseFloatAttr(node, 'camx', 0),
				CNECompat.parseFloatAttr(node, 'camy', 0)
			],
			flip_x: node.exists('flipX') && node.get('flipX') == 'true',
			no_antialiasing: node.exists('antialiasing') && node.get('antialiasing') == 'false',
			healthicon: node.exists('icon') ? node.get('icon') : character,
			healthbar_colors: colors,
			vocals_file: null,
			_editor_isPlayer: node.exists('isPlayer') && node.get('isPlayer') == 'true',
			_cne_converted: true
		};
	}
}

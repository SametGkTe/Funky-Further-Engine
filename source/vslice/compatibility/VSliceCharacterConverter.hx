package vslice.compatibility;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
import haxe.Json;

/**
 * VSliceCharacterConverter — V-Slice (FunkinCrew/Funkin 0.8) karakter JSON'unu
 * Psych (Further-Engine) karakter formatına runtime'da çevirir.
 *
 * FORMAT FARKLARI (V-Slice -> Psych):
 *   V-Slice CharacterData:                 Psych Character JSON:
 *   ------------------------------         ------------------------------
 *   assetPath ("shared:characters/x")      image ("characters/x")
 *   scale                                  scale
 *   singTime                               sing_duration
 *   healthIcon (dict/string)               healthicon
 *   cameraOffsets [x,y]                    camera_position [x,y]
 *   flipX                                  flip_x
 *   isPixel                                no_antialiasing
 *   animations[].name                      animations[].anim
 *   animations[].prefix                    animations[].name
 *   animations[].offsets                   animations[].offsets
 *   animations[].looped                    animations[].loop
 *   animations[].frameRate                 animations[].fps
 *   animations[].frameIndices              animations[].indices
 *
 * Bu converter, V-Slice modundaki `data/characters/<id>.json` dosyasını okuyup
 * Psych `Character.loadCharacterFile()`'ın beklediği JSON'a çevirir. Görsel
 * asset'i (sprite) Psych'in `images/characters/` yoluna `shared/images/characters/`
 * V-Slice düzeninden çözülür.
 */
class VSliceCharacterConverter
{
	/**
	 * V-Slice karakter JSON nesnesini Psych karakter JSON'a çevirir.
	 * @param vslice  V-Slice CharacterData (parse edilmiş)
	 * @param charId  Karakter id'si (dosya adı)
	 */
	public static function convert(vslice:Dynamic, charId:String):Dynamic
	{
		// assetPath'ten image değerini üret.
		// "shared:characters/foolhardy2023" -> "characters/foolhardy2023"
		// "characters/foolhardy2023"        -> "characters/foolhardy2023"
		var image:String = charId;
		var asset:Dynamic = Reflect.field(vslice, 'assetPath');
		if (asset != null && Std.string(asset).length > 0)
		{
			var s:String = Std.string(asset);
			// library:path -> path
			var colon:Int = s.indexOf(':');
			if (colon >= 0) s = s.substring(colon + 1);
			if (s.length > 0) image = s;
		}
		// 'characters/' ile başlamıyorsa ve bir dizin içermiyorsa 'characters/' önek ekle
		if (image.indexOf('characters/') != 0 && image.indexOf('/') < 0)
			image = 'characters/' + image;

		var out:Dynamic = {};
		out.image = image;

		out.scale = (Reflect.field(vslice, 'scale') != null) ? Reflect.field(vslice, 'scale') : 1.0;
		out.sing_duration = (Reflect.field(vslice, 'singTime') != null) ? Reflect.field(vslice, 'singTime') : 4.0;

		// healthIcon
		var hicon:Dynamic = Reflect.field(vslice, 'healthIcon');
		var hiconStr:String = 'bf';
		if (hicon != null)
		{
			if (Std.isOfType(hicon, String)) hiconStr = Std.string(hicon);
			else
			{
				var hp:Dynamic = Reflect.field(hicon, 'assetPath');
				if (hp != null && Std.string(hp).length > 0) hiconStr = Std.string(hp);
			}
		}
		out.healthicon = hiconStr;

		// camera_position <- cameraOffsets
		var cam:Array<Dynamic> = cast Reflect.field(vslice, 'cameraOffsets');
		out.camera_position = (cam != null && cam.length >= 2)
			? [Std.parseFloat(Std.string(cam[0])), Std.parseFloat(Std.string(cam[1]))]
			: [0, 0];

		out.flip_x = (Reflect.field(vslice, 'flipX') == true);
		out.healthbar_colors = [161, 161, 161];
		out.no_antialiasing = (Reflect.field(vslice, 'isPixel') == true);

		// animasyonlar
		var anims:Array<Dynamic> = cast Reflect.field(vslice, 'animations');
		var outAnims:Array<Dynamic> = [];
		if (anims != null)
		{
			for (a in anims)
			{
				var pa:Dynamic = {};
				pa.anim = Reflect.field(a, 'name') != null ? Std.string(Reflect.field(a, 'name')) : 'idle';
				pa.name = Reflect.field(a, 'prefix') != null ? Std.string(Reflect.field(a, 'prefix')) : pa.anim;
				var offs:Array<Dynamic> = cast Reflect.field(a, 'offsets');
				pa.offsets = (offs != null && offs.length >= 2)
					? [Std.parseFloat(Std.string(offs[0])), Std.parseFloat(Std.string(offs[1]))]
					: [0, 0];
				pa.loop = (Reflect.field(a, 'looped') == true);
				pa.fps = (Reflect.field(a, 'frameRate') != null) ? Std.int(Reflect.field(a, 'frameRate')) : 24;
				pa.indices = (Reflect.field(a, 'frameIndices') != null) ? Reflect.field(a, 'frameIndices') : [];
				outAnims.push(pa);
			}
		}
		out.animations = outAnims;

		return out;
	}

	/**
	 * V-Slice modundaki `data/characters/<charId>.json` dosyasını okuyup Psych
	 * karakter JSON nesnesi döndürür. Bulunamazsa null.
	 */
	public static function convertFromMod(modDir:String, charId:String):Dynamic
	{
		#if (MODS_ALLOWED && sys)
		var candidates:Array<String> = [
			'mods/$modDir/data/characters/$charId.json',
			'mods/$modDir/characters/$charId.json'
		];
		for (path in candidates)
		{
			if (FileSystem.exists(path))
			{
				var raw:String = File.getContent(path);
				var json:Dynamic = try Json.parse(raw) catch(e:Dynamic) null;
				if (json != null) return convert(json, charId);
			}
		}
		#end
		return null;
	}

	/**
	 * V-Slice modundaki karakter sprite'ının gerçek dosya yolunu bulur.
	 * V-Slice: mods/<mod>/shared/images/characters/<id>.png (+ .xml)
	 * Psych:   mods/<mod>/images/characters/<id>.png (+ .xml)
	 * Sadece hangi klasörde olduğunu tespit edip görselin map edilmesini sağlar.
	 */
	public static function findCharAsset(modDir:String, imageId:String):{png:String, xml:String}
	{
		var png:String = null;
		var xml:String = null;
		#if sys
		var tryPaths:Array<String> = [
			'mods/$modDir/shared/images/characters/',
			'mods/$modDir/images/characters/'
		];
		for (base in tryPaths)
		{
			if (png == null && FileSystem.exists(base + imageId + '.png')) png = base + imageId + '.png';
			if (xml == null && FileSystem.exists(base + imageId + '.xml')) xml = base + imageId + '.xml';
			if (png != null && xml != null) break;
		}
		#end
		return {png: png, xml: xml};
	}
}

package vslice.compatibility;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
import haxe.Json;

/**
 * VSliceStageConverter — V-Slice (FunkinCrew/Funkin 0.8) stage JSON'unu
 * Psych (Further-Engine) `StageFile` formatına runtime'da çevirir.
 *
 * FORMAT FARKLARI:
 *   V-Slice stage:                          Psych StageFile:
 *   -----------------------------------      ---------------------------------
 *   props[].name                            objects[].name
 *   props[].assetPath ("stageback")         objects[].image ("stageback")
 *   props[].position [x,y]                  objects[].x / objects[].y
 *   props[].scale [x,y]                     objects[].scale
 *   props[].scroll [x,y]                    objects[].scrollFactor
 *   props[].animations[...]                 objects[].animations[...]
 *   props[].zIndex                          (kısmi: layer sırası)
 *   characters.bf.position                  boyfriend [x,y]
 *   characters.dad.position                 opponent [x,y]
 *   characters.gf.position                  girlfriend [x,y]
 *   characters.*.cameraOffsets              camera_boyfriend / camera_opponent / camera_girlfriend
 *   cameraZoom                              defaultZoom
 *   directory                               directory
 *
 * Bu converter, V-Slice modundaki `data/stages/<stage>.json` dosyasını okuyup
 * Psych'in `StageData.getStageFile()`'in beklediği `StageFile`'a çevirir.
 * Böylece Psych asset sistemi (dosya sistemi) üzerinden V-Slice sahneleri de
 * çözülür; Polymod/FLIXEL yükü yoktur, performans düşmez.
 */
class VSliceStageConverter
{
	/**
	 * Bir V-Slice stage JSON nesnesini Psych StageFile'a çevirir.
	 * @param vslice  V-Slice stage JSON (parse edilmiş)
	 * @param stageId Sahne id'si (dosya adı, yedek)
	 */
	public static function convert(vslice:Dynamic, stageId:String):Dynamic
	{
		var objects:Array<Dynamic> = [];

		var props:Array<Dynamic> = cast Reflect.field(vslice, 'props');
		if (props == null) props = [];

		for (p in props)
		{
			var o:Dynamic = {};
			o.name = Reflect.field(p, 'name') != null ? Std.string(Reflect.field(p, 'name')) : 'prop';
			// Psych stage nesneleri filters alanı olmadan çizilmez (LOW|HIGH = 3).
			o.filters = 3;
			var asset:Dynamic = Reflect.field(p, 'assetPath');
			if (asset != null && Std.string(asset).length > 0)
				o.image = Std.string(asset);

			var pos:Array<Dynamic> = cast Reflect.field(p, 'position');
			if (pos != null && pos.length >= 2)
			{
				o.x = Std.parseFloat(Std.string(pos[0]));
				o.y = Std.parseFloat(Std.string(pos[1]));
			}

			var scale:Array<Dynamic> = cast Reflect.field(p, 'scale');
			if (scale != null && scale.length >= 2)
				o.scale = [Std.parseFloat(Std.string(scale[0])), Std.parseFloat(Std.string(scale[1]))];

			var scroll:Array<Dynamic> = cast Reflect.field(p, 'scroll');
			if (scroll != null && scroll.length >= 2)
				o.scroll = [Std.parseFloat(Std.string(scroll[0])), Std.parseFloat(Std.string(scroll[1]))];

			var isPixel:Dynamic = Reflect.field(p, 'isPixel');
			if (isPixel != null) o.antialiasing = (isPixel == true) ? false : true;

			// animasyonları çevir
			var anims:Array<Dynamic> = cast Reflect.field(p, 'animations');
			if (anims != null && anims.length > 0)
			{
				var outAnims:Array<Dynamic> = [];
				for (a in anims)
				{
					var pa:Dynamic = {};
					pa.anim = Reflect.field(a, 'name') != null ? Std.string(Reflect.field(a, 'name')) : 'idle';
					pa.name = Reflect.field(a, 'prefix') != null ? Std.string(Reflect.field(a, 'prefix')) : pa.anim;
					var offs:Array<Dynamic> = cast Reflect.field(a, 'offsets');
					pa.offsets = (offs != null) ? [Std.parseFloat(Std.string(offs[0])), Std.parseFloat(Std.string(offs[1]))] : [0, 0];
					pa.loop = Reflect.field(a, 'looped') == true;
					pa.fps = (Reflect.field(a, 'frameRate') != null) ? Std.int(Reflect.field(a, 'frameRate')) : 24;
					pa.indices = (Reflect.field(a, 'frameIndices') != null) ? Reflect.field(a, 'frameIndices') : [];
					outAnims.push(pa);
				}
				o.animations = outAnims;
				o.type = 'animatedSprite';
				o.firstAnimation = outAnims.length > 0 ? outAnims[0].anim : null;
			}
			else
				o.type = 'sprite';
			objects.push(o);
		}

		// Karakterler
		var chars:Dynamic = Reflect.field(vslice, 'characters');
		var bf:Array<Float> = [770, 100];
		var dad:Array<Float> = [100, 100];
		var gf:Array<Float> = [400, 130];
		var camBf:Array<Float> = [0, 0];
		var camDad:Array<Float> = [0, 0];
		var camGf:Array<Float> = [0, 0];

		if (chars != null)
		{
			var b:Dynamic = Reflect.field(chars, 'bf');
			if (b != null)
			{
				var p:Array<Dynamic> = cast Reflect.field(b, 'position');
				if (p != null && p.length >= 2) bf = [Std.parseFloat(Std.string(p[0])), Std.parseFloat(Std.string(p[1]))];
				var c:Array<Dynamic> = cast Reflect.field(b, 'cameraOffsets');
				if (c != null && c.length >= 2) camBf = [Std.parseFloat(Std.string(c[0])), Std.parseFloat(Std.string(c[1]))];
			}
			var d:Dynamic = Reflect.field(chars, 'dad');
			if (d != null)
			{
				var p:Array<Dynamic> = cast Reflect.field(d, 'position');
				if (p != null && p.length >= 2) dad = [Std.parseFloat(Std.string(p[0])), Std.parseFloat(Std.string(p[1]))];
				var c:Array<Dynamic> = cast Reflect.field(d, 'cameraOffsets');
				if (c != null && c.length >= 2) camDad = [Std.parseFloat(Std.string(c[0])), Std.parseFloat(Std.string(c[1]))];
			}
			var g:Dynamic = Reflect.field(chars, 'gf');
			if (g != null)
			{
				var p:Array<Dynamic> = cast Reflect.field(g, 'position');
				if (p != null && p.length >= 2) gf = [Std.parseFloat(Std.string(p[0])), Std.parseFloat(Std.string(p[1]))];
				var c:Array<Dynamic> = cast Reflect.field(g, 'cameraOffsets');
				if (c != null && c.length >= 2) camGf = [Std.parseFloat(Std.string(c[0])), Std.parseFloat(Std.string(c[1]))];
			}
		}

		var zoom:Float = 0.9;
		var z:Dynamic = Reflect.field(vslice, 'cameraZoom');
		if (z != null) zoom = Std.parseFloat(Std.string(z));

		var directory:String = '';
		var dir:Dynamic = Reflect.field(vslice, 'directory');
		if (dir != null) directory = Std.string(dir);

		// Karakterler sahne nesne listesine eklenmezse PlayState onları
		// 'objects' modunda sahneye hiç eklemez (gruplar add edilmez).
		objects.push({type: 'gf'});
		objects.push({type: 'dad'});
		objects.push({type: 'boyfriend'});

		return {
			directory: directory,
			defaultZoom: zoom,
			stageUI: 'normal',
			boyfriend: bf,
			girlfriend: gf,
			opponent: dad,
			hide_girlfriend: false,
			camera_boyfriend: camBf,
			camera_opponent: camDad,
			camera_girlfriend: camGf,
			camera_speed: 1,
			objects: objects
		};
	}

	/**
	 * V-Slice modundaki `data/stages/<stage>.json` dosyasını okuyup Psych StageFile
	 * JSON string olarak döndürür. Bulunamazsa null.
	 */
	public static function convertFromMod(modDir:String, stageId:String):Dynamic
	{
		#if (MODS_ALLOWED && sys)
		var candidates:Array<String> = [
			'mods/$modDir/data/stages/$stageId.json',
			'mods/$modDir/stages/$stageId.json'
		];
		for (path in candidates)
		{
			if (FileSystem.exists(path))
			{
				trace('[VSliceStage] "$stageId" bulundu: $path');
				var raw:String = File.getContent(path);
				var json:Dynamic = try Json.parse(raw) catch(e:Dynamic) null;
				if (json != null) return convert(json, stageId);
			}
		}
		trace('[VSliceStage] "$stageId" mod "$modDir" içinde bulunamadı');
		#end
		return null;
	}
}

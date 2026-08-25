package cne.compatibility;

#if sys
import sys.io.File;
#end

/**
 * CNEStageConverter — Codename Engine sahne XML'ini (`data/stages/*.xml`)
 * runtime'da Psych (Further-Engine) `StageFile` formatına çevirir.
 *
 * FORMAT EŞLEŞMESİ:
 *   CNE XML                                Psych StageFile
 *   ------------------------------------   --------------------------------
 *   <stage zoom="0.9">                     defaultZoom
 *   <stage folder="stages/default/">       object image ön eki
 *   <sprite name="bg" x y sprite scroll>   objects: [{type:'sprite', ...}]
 *   <sprite animated="true"><anim .../>    objects: [{type:'animatedSprite', animations}]
 *   <girlfriend x y camxoffset camyoffset> girlfriend + camera_girlfriend + {type:'gf'}
 *   <dad .../>                             opponent + camera_opponent + {type:'dad'}
 *   <boyfriend .../>                       boyfriend + camera_boyfriend + {type:'boyfriend'}
 *   <girlfriend/> yoksa                    hide_girlfriend: true
 *
 * KISITLAR: <box>/<solid>, ratings/combo konumu ve sahne scriptleri (.hx)
 * desteklenmez; bu düğümler güvenle yok sayılır.
 */
class CNEStageConverter
{
	/** Psych visibility filtresi: LOW_QUALITY | HIGH_QUALITY (her zaman görünür). */
	static inline var ALWAYS_VISIBLE:Int = 3;

	/**
	 * `backend.StageData.dummy()` ile aynı varsayılan StageFile.
	 * backend.StageData import edilmez; döngüsel modül bağımlılığı önlenir.
	 */
	static function defaultStageFile():Dynamic
	{
		return {
			directory: "",
			defaultZoom: 0.9,
			stageUI: "normal",

			boyfriend: [770, 100],
			girlfriend: [400, 130],
			opponent: [100, 100],
			hide_girlfriend: false,

			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1
		};
	}

	/** Aktif mod sırasına göre sahneyi arar; ilk bulunanı çevirir. */
	public static function convertFromMods(stage:String):Dynamic
	{
		#if MODS_ALLOWED
		for (mod in CNECompat.modSearchOrder())
		{
			var file:Dynamic = convertFromMod(mod, stage);
			if (file != null) return file;
		}
		#end
		return null;
	}

	/** Belirli bir moddaki CNE sahne XML'ini Psych StageFile'a çevirir. */
	public static function convertFromMod(mod:String, stage:String):Dynamic
	{
		#if (MODS_ALLOWED && sys)
		var path:String = CNECompat.findStageXml(mod, stage);
		if (path == null) return null;
		try
		{
			var node:Xml = Xml.parse(File.getContent(path)).firstElement();
			if (node == null) return null;
			return convertNode(node);
		}
		catch (e:Dynamic)
		{
			trace('[CNEStage] "$stage" sahnesi çevrilemedi (mod: $mod): $e');
			return null;
		}
		#else
		return null;
		#end
	}

	static function convertNode(node:Xml):Dynamic
	{
		var stageFile:Dynamic = defaultStageFile();
		stageFile.directory = '';

		var folder:String = node.exists('folder') ? node.get('folder') : '';
		if (folder.length > 0 && !StringTools.endsWith(folder, '/'))
			folder += '/';

		if (node.exists('zoom'))
			stageFile.defaultZoom = CNECompat.parseFloatAttr(node, 'zoom', 0.9);

		var objects:Array<Dynamic> = [];
		var hasGfNode:Bool = false;
		var seenDad:Bool = false;
		var seenBf:Bool = false;

		for (el in node.elements())
		{
			switch (el.nodeName)
			{
				case 'sprite', 'spr', 'sparrow':
					var obj:Dynamic = buildSpriteObject(el, folder);
					if (obj != null) objects.push(obj);

				case 'girlfriend', 'gf':
					hasGfNode = true;
					applyCharNode(stageFile, 'girlfriend', el);
					objects.push({type: 'gf'});

				case 'dad', 'opponent':
					seenDad = true;
					applyCharNode(stageFile, 'dad', el);
					objects.push({type: 'dad'});

				case 'boyfriend', 'bf', 'player':
					seenBf = true;
					applyCharNode(stageFile, 'boyfriend', el);
					objects.push({type: 'boyfriend'});

				default:
					// box / solid / ratings / combo / extension: desteklenmiyor.
			}
		}

		// XML'de hiç geçmeyen karakterleri Psych'in varsayılan katman sırasıyla ekle.
		if (!hasGfNode) objects.push({type: 'gf'});
		if (!seenDad) objects.push({type: 'dad'});
		if (!seenBf) objects.push({type: 'boyfriend'});

		stageFile.hide_girlfriend = !hasGfNode;
		stageFile.objects = objects;
		return stageFile;
	}

	/** Karakter düğümündeki x/y/camxoffset/camyoffset değerlerini uygular. */
	static function applyCharNode(stageFile:Dynamic, which:String, el:Xml)
	{
		var pos:Array<Dynamic>;
		var cam:Array<Float>;
		switch (which)
		{
			case 'boyfriend':
				pos = stageFile.boyfriend;
				cam = stageFile.camera_boyfriend;
			case 'dad':
				pos = stageFile.opponent;
				cam = stageFile.camera_opponent;
			default:
				pos = stageFile.girlfriend;
				cam = stageFile.camera_girlfriend;
		}
		if (el.exists('x')) pos[0] = CNECompat.parseFloatAttr(el, 'x', pos[0]);
		if (el.exists('y')) pos[1] = CNECompat.parseFloatAttr(el, 'y', pos[1]);
		if (el.exists('camxoffset')) cam[0] = CNECompat.parseFloatAttr(el, 'camxoffset', 0);
		if (el.exists('camyoffset')) cam[1] = CNECompat.parseFloatAttr(el, 'camyoffset', 0);
	}

	/** <sprite> düğümünü Psych stage object tanımına çevirir. */
	static function buildSpriteObject(el:Xml, folder:String):Dynamic
	{
		if (!el.exists('sprite') || !el.exists('name')) return null;

		var image:String = folder + el.get('sprite');

		var animations:Array<Dynamic> = [];
		var firstAnim:String = null;
		for (child in el.elements())
		{
			if (child.nodeName != 'anim') continue;
			var animName:String = child.exists('name') ? child.get('name') : '';
			var animPrefix:String = child.exists('anim') ? child.get('anim') : '';
			if (animName.length < 1 || animPrefix.length < 1) continue;
			animations.push({
				anim: animName,
				name: animPrefix,
				fps: Std.int(CNECompat.parseFloatAttr(child, 'fps', 24)),
				loop: child.exists('loop') && child.get('loop') == 'true',
				indices: CNECompat.parseIntList(child.exists('indices') ? child.get('indices') : null),
				offsets: [
					Std.int(CNECompat.parseFloatAttr(child, 'x', 0)),
					Std.int(CNECompat.parseFloatAttr(child, 'y', 0))
				]
			});
			if (firstAnim == null) firstAnim = animName;
		}

		var animated:Bool = (el.exists('animated') && el.get('animated') == 'true') || animations.length > 0;

		var scroll:Float = CNECompat.parseFloatAttr(el, 'scroll', 1);
		var obj:Dynamic = {
			type: animated ? 'animatedSprite' : 'sprite',
			name: el.get('name'),
			x: CNECompat.parseFloatAttr(el, 'x', 0),
			y: CNECompat.parseFloatAttr(el, 'y', 0),
			image: image,
			scroll: [scroll, scroll],
			antialiasing: !(el.exists('antialiasing') && el.get('antialiasing') == 'false'),
			flipX: el.exists('flipX') && el.get('flipX') == 'true',
			filters: ALWAYS_VISIBLE
		};

		if (el.exists('scale'))
		{
			var s:Float = CNECompat.parseFloatAttr(el, 'scale', 1);
			obj.scale = [s, s];
		}
		if (el.exists('color')) obj.color = el.get('color');
		if (el.exists('alpha')) obj.alpha = CNECompat.parseFloatAttr(el, 'alpha', 1);
		if (el.exists('angle')) obj.angle = CNECompat.parseFloatAttr(el, 'angle', 0);

		if (animated)
		{
			obj.animations = animations;
			if (el.exists('startingAnim') && el.get('startingAnim').length > 0)
				obj.firstAnimation = el.get('startingAnim');
			else if (firstAnim != null)
				obj.firstAnimation = firstAnim;
		}
		return obj;
	}
}

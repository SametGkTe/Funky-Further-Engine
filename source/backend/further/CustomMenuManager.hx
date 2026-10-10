package backend.further;

import backend.Mods;
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;

/**
 * Custom Menus (Faz 3) — oyuncular kaynak koda dokunmadan HX ile kendi
 * menülerini ekler. Ana menüde butonlar mevcut butonların ALTINA dizilir.
 *
 * Sözleşme (bkz. docs/CUSTOM_MENUS_TR.md):
 *
 *   mods/<mod>/
 *   ├── scripts/
 *   │   └── CoolMenu.hxc     ← class CoolMenu extends funkin.modding.base.ScriptedMusicBeatState
 *   └── menus/
 *       └── coolmenu/
 *           └── menu.json    ← { "id", "label", "class": "CoolMenu", "order"? }
 *
 * Sınıf, Polymod'un .hxc script-class yükleyicisiyle kaydedilir;
 * CustomMenuManager.open() onu ScriptedMusicBeatState.scriptInit ile kurar.
 * (Aynı yol: funkin.data.notestyle.NoteStyleRegistry → ScriptedNoteStyle.scriptInit)
 */
typedef CustomMenuDef =
{
	var id:String;
	var label:String;
	var className:String;
	var order:Float;
	var folder:String;
	var icon:String;
	var source:String;
}

class CustomMenuManager
{
	public static var menus:Array<CustomMenuDef> = [];

	/** Etkin modlar + extension pack'lerdeki menus/ klasörlerini tarar. */
	public static function rescan():Void
	{
		menus = [];
		#if MODS_ALLOWED
		try
		{
			var list = Mods.parseList();
			for (mod in list.enabled)
				scanMenusIn(Paths.mods(mod), mod);
		}
		catch (e:Dynamic)
		{
			trace('[CustomMenu] Mod taraması hatası: ' + Std.string(e));
		}

		// Extension Packs (Faz 4) — menus/ şimdiden desteklenir
		try
		{
			var extRoot:String = Path.addTrailingSlash(mobile.backend.StorageUtil.getStorageRootDirectory()) + 'further/extensionpacks/';
			if (FileSystem.exists(extRoot))
			{
				for (pack in FileSystem.readDirectory(extRoot))
				{
					var dir:String = Path.join([extRoot, pack]);
					if (FileSystem.isDirectory(dir))
						scanMenusIn(dir, 'ext:' + pack);
				}
			}
		}
		catch (e:Dynamic)
		{
			trace('[CustomMenu] Extension taraması hatası: ' + Std.string(e));
		}
		#end

		menus.sort(function(a:CustomMenuDef, b:CustomMenuDef):Int
		{
			if (a.order < b.order)
				return -1;
			if (a.order > b.order)
				return 1;
			return (a.id < b.id) ? -1 : 1;
		});

		if (menus.length > 0)
			trace('[CustomMenu] ${menus.length} özel menü bulundu.');
	}

	static function scanMenusIn(root:String, source:String):Void
	{
		var menusDir:String = Path.join([root, 'menus']);
		if (!FileSystem.exists(menusDir) || !FileSystem.isDirectory(menusDir))
			return;

		for (folder in FileSystem.readDirectory(menusDir))
		{
			var dir:String = Path.join([menusDir, folder]);
			if (!FileSystem.isDirectory(dir))
				continue;
			var jsonPath:String = Path.join([dir, 'menu.json']);
			if (!FileSystem.exists(jsonPath))
				continue;
			try
			{
				var raw:String = Paths.readTextFileBom(jsonPath);
				var m:Dynamic = Json.parse(raw);
				var id:String = (m != null && m.id != null) ? Std.string(m.id) : folder;
				var label:String = (m != null && m.label != null) ? Std.string(m.label) : id;
				var cls:String = (m != null && m.className != null) ? Std.string(m.className) : null;
				if (cls == null && m != null && Reflect.hasField(m, 'class'))
					cls = Std.string(Reflect.field(m, 'class'));
				if (cls == null || cls.length == 0)
				{
					trace('[CustomMenu] "class" alanı yok: $jsonPath');
					continue;
				}
				var order:Float = (m != null && m.order != null) ? Std.parseFloat(Std.string(m.order)) : 50;
				if (Math.isNaN(order))
					order = 50;

				var def:CustomMenuDef = {
					id: id,
					label: label,
					className: cls,
					order: order,
					folder: Path.addTrailingSlash(dir),
					icon: (m != null && m.icon != null) ? Std.string(m.icon) : '',
					source: source
				};

				var dup:Bool = false;
				for (e in menus)
					if (e.id == id)
					{
						dup = true;
						break;
					}
				if (!dup)
					menus.push(def);
			}
			catch (e:Dynamic)
			{
				trace('[CustomMenu] menu.json bozuk: $jsonPath — ' + Std.string(e));
			}
		}
	}

	public static function find(id:String):Null<CustomMenuDef>
	{
		for (m in menus)
			if (m.id == id)
				return m;
		return null;
	}

	public static function labelFor(id:String):String
	{
		var m:CustomMenuDef = find(id);
		return (m != null) ? m.label : id;
	}

	/**
	 * Özel menüyü açar. true = geçiş başladı; false = başarısız (rehberli hata).
	 */
	public static function open(id:String):Bool
	{
		// Pack menusu siniflari henuz kayitli olmayabilir
		backend.further.ExtensionPackManager.loadPackScripts();
		var def:CustomMenuDef = find(id);
		if (def == null)
		{
			fail('Özel menü bulunamadı: $id');
			return false;
		}

		#if (HSC_ALLOWED || POLYMOD_ALLOWED)
		try
		{
			var state:Dynamic = funkin.modding.base.ScriptedMusicBeatState.scriptInit(def.className);
			if (state != null)
			{
				MusicBeatState.switchState(cast state);
				return true;
			}
		}
		catch (e:Dynamic)
		{
			trace('[CustomMenu] scriptInit hatası (${def.className}): ' + Std.string(e));
			fail('Menü açılamadı: ${def.label}\n\nSınıf: ${def.className}\nHata: ' + Std.string(e));
			return false;
		}

		fail('Menü açılamadı: ${def.label}\n\n"${def.className}" script sınıfı bulunamadı.\n\nKontrol listesi:\n'
			+ '- mods/${def.source}/scripts/ altinda ${def.className}.hxc var mi?\n'
			+ '- Dosya icinde "class ${def.className} extends\n  funkin.modding.base.ScriptedMusicBeatState" yaziyor mu?\n'
			+ '- Sinif adi buyuk/kucuk harf dogru mu?\n'
			+ '- menu.json icindeki "class" alani eslesiyor mu?');
		return false;
		#else
		fail('Script desteği bu derlemede kapalı (HSC_ALLOWED / POLYMOD_ALLOWED).');
		return false;
		#end
	}

	static function fail(msg:String):Void
	{
		trace('[CustomMenu] ' + msg);
		CoolUtil.showPopUp(msg, 'Custom Menu');
	}
}

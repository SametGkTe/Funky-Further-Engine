package backend.further;

import haxe.Json;
import haxe.io.Path;
import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.AssetType;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Bir kurulu Extension Pack'i temsil eder (further/extensionpacks/<folder>). */
typedef EPack =
{
	var id:String;
	var name:String;
	var description:String;
	var author:String;
	var type:String; // character | menu | misc
	var version:String;
	var folder:String; // alt klasör adı
	var dir:String; // tam yol
}

/** extensions.json katalog girdisi (kurucu URL dahil). */
typedef ECatalogEntry =
{
	var id:String;
	var name:String;
	var type:String;
	var author:String;
	var description:String;
	var url:String;
	var version:String;
}

/**
 * FURTHER: Extension Pack yonetimi.
 * Paket sozlesmesi:
 *   further/extensionpacks/<pack>/
 *   ├── extensionpack.json   {id,name,description,author,type,version}
 *   ├── data/players/        (character pack: V-Slice oynanabilir girisleri)
 *   ├── characters/          (character pack: Psych karakter JSON + atlas)
 *   ├── menus/               (menu pack: CustomMenuManager tarar)
 *   ├── scripts/             (menu siniflari: loadPackScripts kaydeder)
 *   └── images/              (opsiyonel grafikler)
 * Karakterler motorun mevcut mod koku mekanizmasiyla "modDir()" isaret
 * dizgisi uzerinden cozulur (Paths.mods('../further/extensionpacks/<id>/...')).
 */
class ExtensionPackManager
{
	/** Saglamali (curated) katalog dosyasi; internet yoksa gomulu kopya kullanilir. */
	public static var CATALOG_URL:String = 'https://raw.githubusercontent.com/FNF-Further/Funky-Further-Engine/main/extensions.json';
	public static inline var CATALOG_FALLBACK:String = 'data/further/extensions.json';

	static var packs:Array<EPack> = [];
	static var registeredScripts:Map<String, Bool> = new Map();
	static var catalogCache:Array<ECatalogEntry> = null;
	static var _root:String;
	static var inited:Bool = false;

	public static function init():Void
	{
		ensure();
	}

	public static function ensure():Void
	{
		if (!inited)
		{
			inited = true;
			rescan();
		}
	}

	/** <base>/further/extensionpacks — TexturePack'lerle ayni koku ailesi. */
	public static function getRoot():String
	{
		if (_root != null)
			return _root;
		_root = Path.join([mobile.backend.StorageUtil.getStorageRootDirectory(), 'further', 'extensionpacks']);
		return _root;
	}

	public static function rescan():Void
	{
		packs = [];
		#if sys
		var root = getRoot();
		if (FileSystem.exists(root) && FileSystem.isDirectory(root))
		{
			for (entry in FileSystem.readDirectory(root))
			{
				var dir = Path.join([root, entry]);
				if (!FileSystem.isDirectory(dir))
					continue;
				var meta = Path.join([dir, 'extensionpack.json']);
				if (!FileSystem.exists(meta))
					continue;
				try
				{
					var raw:Dynamic = Json.parse(File.getContent(meta));
					if (raw == null)
						continue;
					var pack:EPack = {
						id: (raw.id != null && Std.isOfType(raw.id, String)) ? raw.id : entry,
						name: (raw.name != null && Std.isOfType(raw.name, String)) ? raw.name : entry,
						description: (raw.description != null && Std.isOfType(raw.description, String)) ? raw.description : '',
						author: (raw.author != null && Std.isOfType(raw.author, String)) ? raw.author : '',
						type: (raw.type != null && Std.isOfType(raw.type, String)) ? raw.type : 'misc',
						version: (raw.version != null && Std.isOfType(raw.version, String)) ? raw.version : '1.0.0',
						folder: entry,
						dir: dir
					};
					packs.push(pack);
				}
				catch (e:Dynamic)
					trace('[ExtensionPack] extensionpack.json okunamadi: $meta ($e)');
			}
		}
		packs.sort(function(a, b)
		{
			return Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase());
		});
		trace('[ExtensionPack] ' + packs.length + ' paket: ' + [for (p in packs) p.id].join(', '));
		#end
	}

	public static function list():Array<EPack>
	{
		ensure();
		return packs;
	}

	public static function find(id:String):Null<EPack>
	{
		ensure();
		for (p in packs)
			if (p.id == id || p.folder == id)
				return p;
		return null;
	}

	/**
	 * Mod koku isaret dizgisi: Paths.mods(modDir(id)) = <base>/mods/../further/extensionpacks/<id>
	 * motorun tum mod-relative cozumleyicileri (PsliceRegistry, modFolders, Character)
	 * bu degerle paket klasorunu bir "mod" gibi gezer.
	 */
	public static function modDir(packFolder:String):String
	{
		return '../further/extensionpacks/' + packFolder;
	}

	/** Oynanabilir karakter iceren paketlerin isaret dizgileri (CharSelect bunlari mod gibi tarar). */
	public static function packMarkersWithPlayers():Array<String>
	{
		var result:Array<String> = [];
		ensure();
		#if sys
		for (p in packs)
		{
			var playersDir = Path.join([p.dir, 'data', 'players']);
			var charsDir = Path.join([p.dir, 'characters']);
			var hasPlayers = FileSystem.exists(playersDir) && FileSystem.isDirectory(playersDir);
			var hasChars = FileSystem.exists(charsDir) && FileSystem.isDirectory(charsDir);
			if (hasPlayers || hasChars)
				result.push(modDir(p.folder));
		}
		#end
		return result;
	}

	/**
	 * Paket scripts/*.hxc dosyalarini Polymod script-class kaydina gecer
	 * (menu pack'lerin CustomMenuManager'dan acilabilmesi icin gerekli).
	 * Idempotent: her dosya bir kez kaydedilir.
	 */
	public static function loadPackScripts():Void
	{
		ensure();
		#if sys
		for (p in packs)
		{
			var scriptsDir = Path.join([p.dir, 'scripts']);
			if (!(FileSystem.exists(scriptsDir) && FileSystem.isDirectory(scriptsDir)))
				continue;
			for (file in FileSystem.readDirectory(scriptsDir))
			{
				if (!StringTools.endsWith(file, '.hxc'))
					continue;
				var path = Path.join([scriptsDir, file]);
				if (registeredScripts.exists(path))
					continue;
				registeredScripts.set(path, true);
				try
				{
					polymod.hscript._internal.PolymodScriptClass.registerScriptClassByString(File.getContent(path), path);
					trace('[ExtensionPack] script sinifi kaydedildi: $path');
				}
				catch (e:Dynamic)
					trace('[ExtensionPack] script kaydedilemedi: $path ($e)');
			}
		}
		#end
	}

	/** Paketi siler (kutuphaneden kaldir). */
	public static function remove(packId:String):Bool
	{
		var p = find(packId);
		if (p == null)
			return false;
		#if sys
		try
		{
			deleteRecursive(p.dir);
			rescan();
			return true;
		}
		catch (e:Dynamic)
		{
			trace('[ExtensionPack] silinemedi: ${p.dir} ($e)');
			return false;
		}
		#else
		return false;
		#end
	}

	static function deleteRecursive(path:String):Void
	{
		#if sys
		if (!FileSystem.exists(path))
			return;
		if (FileSystem.isDirectory(path))
		{
			for (entry in FileSystem.readDirectory(path))
				deleteRecursive(Path.join([path, entry]));
			FileSystem.deleteDirectory(path);
		}
		else
			FileSystem.deleteFile(path);
		#end
	}

	// ─── Katalog (extensions.json) ────────────────────────────────────────

	public static function loadCatalog(onDone:Array<ECatalogEntry>->Void):Void
	{
		if (catalogCache != null)
		{
			onDone(catalogCache);
			return;
		}
		var finish = function(list:Array<ECatalogEntry>):Void
		{
			catalogCache = list;
			DownloadQueue.pushMain(function()
			{
				onDone(list);
			});
		};
		try
		{
			var http = new backend.modpack.DownloadManager();
			http.fetchUrlText(CATALOG_URL, function(data:String)
			{
				var parsed = parseCatalog(data);
				finish(parsed != null ? parsed : loadBundledCatalog());
			}, function(err:String)
			{
				trace('[ExtensionPack] katalog alinamadi ($err) - gomulu kullaniliyor');
				finish(loadBundledCatalog());
			});
		}
		catch (e:Dynamic)
		{
			finish(loadBundledCatalog());
		}
	}

	static function parseCatalog(data:String):Null<Array<ECatalogEntry>>
	{
		try
		{
			var raw:Dynamic = Json.parse(data);
			var arr:Array<Dynamic> = null;
			if (Std.isOfType(raw, Array))
				arr = cast raw;
			else if (raw != null && raw.packs != null)
				arr = cast raw.packs;
			if (arr == null)
				return null;
			var list:Array<ECatalogEntry> = [];
			for (item in arr)
			{
				if (item == null)
					continue;
				list.push({
					id: (item.id != null) ? Std.string(item.id) : '',
					name: (item.name != null) ? Std.string(item.name) : '',
					type: (item.type != null) ? Std.string(item.type) : 'misc',
					author: (item.author != null) ? Std.string(item.author) : '',
					description: (item.description != null) ? Std.string(item.description) : '',
					url: (item.url != null) ? Std.string(item.url) : '',
					version: (item.version != null) ? Std.string(item.version) : '1.0.0'
				});
			}
			return list;
		}
		catch (e:Dynamic)
			return null;
	}

	static function loadBundledCatalog():Array<ECatalogEntry>
	{
		try
		{
			var shared = backend.Paths.getSharedPath(CATALOG_FALLBACK);
			if (OpenFlAssets.exists(shared, AssetType.TEXT))
			{
				var parsed = parseCatalog(OpenFlAssets.getText(shared));
				if (parsed != null)
					return parsed;
			}
		}
		catch (e:Dynamic) {}
		return [];
	}
}

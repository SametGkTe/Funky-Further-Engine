package mikolka.funkin.custom;

import haxe.Json;
import haxe.io.Path;
import StringTools;
import mikolka.compatibility.funkin.FunkinPath;
import mikolka.compatibility.ModsHelper;
import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.AssetType;
import backend.Paths;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class PsliceRegistry
{
	final regPath:String;

	public function new(registryName:String)
	{
		regPath = 'registry/$registryName';
	}

	static function fsExists(path:String):Bool
	{
		#if sys
		return FileSystem.exists(path);
		#else
		return NativeFileSystem.exists(path);
		#end
	}

	static function fsIsDirectory(path:String):Bool
	{
		#if sys
		return FileSystem.exists(path) && FileSystem.isDirectory(path);
		#else
		return NativeFileSystem.exists(path);
		#end
	}

	static function fsReadDirectory(path:String):Array<String>
	{
		#if sys
		return FileSystem.readDirectory(path);
		#else
		return NativeFileSystem.readDirectory(path);
		#end
	}

	static function fsGetContent(path:String):String
	{
		#if sys
		return File.getContent(path);
		#else
		return NativeFileSystem.getContent(path);
		#end
	}

	function registryToDataPath(path:String):String
	{
		if (StringTools.startsWith(path, "registry/"))
			return "data/" + path.substr("registry/".length);
		return path;
	}

	public static function resolveModsRoot():Null<String>
	{
		var candidates:Array<String> = [];
		var seen:Map<String, Bool> = new Map();

		inline function addCandidate(path:String):Void
		{
			if (path == null || path.length < 1)
				return;

			var normalized = StringTools.replace(path, "\\", "/");
			while (StringTools.endsWith(normalized, "/"))
				normalized = normalized.substr(0, normalized.length - 1);

			if (seen.exists(normalized))
				return;

			seen.set(normalized, true);
			candidates.push(normalized);
		}

		addCandidate("mods");
		addCandidate("./mods");

		try
		{
			var cwd = Sys.getCwd();
			if (cwd != null && cwd.length > 0)
				addCandidate(Path.join([cwd, "mods"]));
		}
		catch (e:Dynamic) {}

		try
		{
			var exeDir = Path.directory(Sys.programPath());
			if (exeDir != null && exeDir.length > 0)
				addCandidate(Path.join([exeDir, "mods"]));
		}
		catch (e:Dynamic) {}

		for (candidate in candidates)
		{
			var exists = fsExists(candidate) && fsIsDirectory(candidate);
			trace('[PsliceRegistry] resolveModsRoot candidate=' + candidate + ' exists=' + exists);
			if (exists)
				return candidate;
		}

		return null;
	}

	function readJson(id:String):Dynamic
	{
		var relativePath = '$regPath/$id.json';
		var nativePath = FunkinPath.getPath(relativePath);
		var sharedPath = Paths.getSharedPath(relativePath);

		trace('[PsliceRegistry] Requested: ' + relativePath);
		trace('[PsliceRegistry] Resolved to: ' + nativePath);
		trace('[PsliceRegistry] Native exists: ' + fsExists(nativePath));
		trace('[PsliceRegistry] Shared exists: ' + OpenFlAssets.exists(sharedPath, AssetType.TEXT));

		var text:String = null;

		// 1) Önce çözülmüş normal path
		if (fsExists(nativePath))
		{
			text = fsGetContent(nativePath);
		}

		// 2) Sonra aktif mod içinde data path dene
		if (text == null || text.length < 1)
		{
			var activeMod = ModsHelper.getActiveMod();
			var modsRoot = resolveModsRoot();

			if (modsRoot != null && activeMod != null && activeMod.length > 0)
			{
				var dataRelative = registryToDataPath(relativePath);
				var modDataPath = Path.join([modsRoot, activeMod, dataRelative]);

				trace('[PsliceRegistry] Trying mod data path: ' + modDataPath);
				trace('[PsliceRegistry] Mod data exists: ' + fsExists(modDataPath));

				if (fsExists(modDataPath))
				{
					text = fsGetContent(modDataPath);
				}
			}
		}

		// 3) Son olarak shared/embed asset
		if ((text == null || text.length < 1) && OpenFlAssets.exists(sharedPath, AssetType.TEXT))
		{
			text = OpenFlAssets.getText(sharedPath);
		}

		if (text == null || text.length < 1)
			return null;

		return Json.parse(text);
	}

	function listJsons():Array<String>
	{
		var result:Array<String> = [];
		var seen:Map<String, Bool> = new Map();

		inline function addId(id:String):Void
		{
			if (id == null || id.length < 1)
				return;
			if (seen.exists(id))
				return;

			seen.set(id, true);
			result.push(id);
		}

		var activeMod = ModsHelper.getActiveMod();
		var modsRoot = resolveModsRoot();

		// 1) Aktif mod registry/data tara
		if (modsRoot != null && activeMod != null && activeMod.length > 0)
		{
			var modRegistryDir = Path.join([modsRoot, activeMod, regPath]);
			trace('[PsliceRegistry] listJsons mod registry dir: ' + modRegistryDir);

			if (fsIsDirectory(modRegistryDir))
			{
				for (file in fsReadDirectory(modRegistryDir))
				{
					if (file.endsWith(".json"))
						addId(file.substr(0, file.length - 5));
				}
			}

			var modDataDir = Path.join([modsRoot, activeMod, registryToDataPath(regPath)]);
			trace('[PsliceRegistry] listJsons mod data dir: ' + modDataDir);

			if (fsIsDirectory(modDataDir))
			{
				for (file in fsReadDirectory(modDataDir))
				{
					if (file.endsWith(".json"))
						addId(file.substr(0, file.length - 5));
				}
			}
		}

		// 2) Shared/embed tara
		var sharedDir = Paths.getSharedPath(regPath);
		trace('[PsliceRegistry] listJsons native/shared dir: ' + sharedDir);

		for (asset in OpenFlAssets.list(AssetType.TEXT))
		{
			if (!asset.endsWith(".json"))
				continue;

			if (!StringTools.startsWith(asset, sharedDir + "/"))
				continue;

			var relative = asset.substr((sharedDir + "/").length);

			if (relative.indexOf("/") != -1 || relative.indexOf("\\") != -1)
				continue;

			addId(relative.substr(0, relative.length - 5));
		}

		trace('[PsliceRegistry] listJsons result: ' + result.join(", "));
		return result;
	}
}
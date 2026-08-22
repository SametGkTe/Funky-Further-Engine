package states;

import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import openfl.display.BitmapData;
import backend.MusicBeatState;
import backend.MenuStyleRouter;
import backend.WeekData;
import backend.modpack.ModImportQueue;
import vslice.compatibility.freeplay.FreeplaySongData;
import vslice.menus.freeplay.pslice.BPMCache;
import backend.modpack.zip.IZipExtractor;
import backend.modpack.zip.ZipExtractorFactory;
import backend.modpack.zip.ZipTypes;

class ModImportState extends MusicBeatState
{
	var zipPath:String;
	var extractor:IZipExtractor;
	var started:Bool = false;
	var finished:Bool = false;
	var failed:Bool = false;
	var leaving:Bool = false;
	var alreadyInstalled:Bool = false;
	var status:String = "KURULUYOR";
	var targetProgress:Float = 0;
	var currentProgress:Float = 0;
	var installedName:String = "";
	var tempRoot:String = "";
	var previewLoaded:Bool = false;
	var previewTimer:Float = 0;

	var bg:FlxSprite;
	var icon:FlxSprite;
	var packNameText:FlxText;
	var statusText:FlxText;
	var barBorder:FlxSprite;
	var barBg:FlxSprite;
	var barFill:FlxSprite;
	var percentText:FlxText;
	var detailText:FlxText;

	static inline final ICON_SIZE:Int = 240;
	static inline final BAR_HEIGHT:Int = 28;
	static inline final BAR_MARGIN:Int = 80;
	static inline final ACCENT:Int = 0xFFFFFFFF;

	public function new(zipPath:String)
	{
		super();
		this.zipPath = zipPath;
	}

	override function create()
	{
		super.create();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF0A0A0A);
		add(bg);

		icon = new FlxSprite();
		loadFallbackIcon();
		icon.setGraphicSize(ICON_SIZE, ICON_SIZE);
		icon.updateHitbox();
		icon.screenCenter(X);
		icon.y = FlxG.height * 0.12;
		icon.antialiasing = ClientPrefs.data.antialiasing;
		add(icon);

		var displayName:String = Path.withoutExtension(Path.withoutDirectory(zipPath));
		if (displayName == null || displayName == "")
			displayName = "MOD";

		packNameText = new FlxText(40, icon.y + ICON_SIZE + 28, FlxG.width - 80, displayName, 40);
		packNameText.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.WHITE, CENTER);
		packNameText.screenCenter(X);
		add(packNameText);

		statusText = new FlxText(40, packNameText.y + packNameText.height + 8, FlxG.width - 80, "KURULUYOR", 22);
		statusText.setFormat(Paths.font("vcr.ttf"), 22, 0xFFBBBBBB, CENTER);
		add(statusText);

		var barWidth:Int = FlxG.width - (BAR_MARGIN * 2);
		var barY:Int = FlxG.height - 92;

		barBorder = new FlxSprite(BAR_MARGIN - 3, barY - 3).makeGraphic(barWidth + 6, BAR_HEIGHT + 6, 0xFF333333);
		add(barBorder);
		barBg = new FlxSprite(BAR_MARGIN, barY).makeGraphic(barWidth, BAR_HEIGHT, 0xFF1A1A1A);
		add(barBg);
		barFill = new FlxSprite(BAR_MARGIN, barY).makeGraphic(1, BAR_HEIGHT, ACCENT);
		add(barFill);

		percentText = new FlxText(0, barY - 42, FlxG.width, "0%", 28);
		percentText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER);
		add(percentText);

		detailText = new FlxText(60, barY + BAR_HEIGHT + 10, FlxG.width - 120, "", 16);
		detailText.setFormat(Paths.font("vcr.ttf"), 16, 0xFF888888, CENTER);
		detailText.visible = false;
		add(detailText);

		extractor = ZipExtractorFactory.createSafe();
		new flixel.util.FlxTimer().start(0.3, function(_) startInstall());
	}

	function loadFallbackIcon():Void
	{
		var fallback = Paths.image("unknownMod");
		if (fallback != null)
			icon.loadGraphic(fallback);
		else
			icon.makeGraphic(ICON_SIZE, ICON_SIZE, 0xFF222222);
	}

	function applyPreview(pngPath:String, displayName:String):Void
	{
		if (displayName != null && StringTools.trim(displayName) != "")
		{
			packNameText.text = displayName;
			packNameText.screenCenter(X);
		}

		#if sys
		if (pngPath != null && FileSystem.exists(pngPath))
		{
			try
			{
				var bmp:BitmapData = BitmapData.fromFile(pngPath);
				if (bmp != null)
				{
					icon.loadGraphic(bmp);
					icon.setGraphicSize(ICON_SIZE, ICON_SIZE);
					icon.updateHitbox();
					icon.screenCenter(X);
					icon.y = FlxG.height * 0.12;
					previewLoaded = true;
				}
			}
			catch (e:Dynamic) {}
		}
		#end
	}

	#if sys
	function scanPreview(root:String):Void
	{
		if (previewLoaded || root == null || !FileSystem.exists(root))
			return;

		var foundPng:String = findFile(root, "pack.png");
		if (foundPng == null)
			foundPng = findFile(root, "pack-pixel.png");

		var foundName:String = null;
		var jsonPath:String = findFile(root, "pack.json");
		if (jsonPath != null)
		{
			try
			{
				var raw = File.getContent(jsonPath);
				var pack:Dynamic = haxe.Json.parse(raw);
				if (pack != null && pack.name != null)
					foundName = Std.string(pack.name);
			}
			catch (e:Dynamic) {}
		}

		if (foundPng != null || foundName != null)
			applyPreview(foundPng, foundName);
	}

	function findFile(root:String, fileName:String):String
	{
		var direct = Path.join([root, fileName]);
		if (FileSystem.exists(direct))
			return direct;

		if (!FileSystem.isDirectory(root))
			return null;

		for (entry in FileSystem.readDirectory(root))
		{
			var full = Path.join([root, entry]);
			if (FileSystem.isDirectory(full))
			{
				var nested = Path.join([full, fileName]);
				if (FileSystem.exists(nested))
					return nested;
				if (entry == "mods")
				{
					var deeper = findFile(full, fileName);
					if (deeper != null)
						return deeper;
				}
			}
		}
		return null;
	}
	#end

	function startInstall():Void
	{
		#if !sys
		fail("Bu platformda kurulum desteklenmiyor.");
		#else
		if (started)
			return;
		started = true;

		if (zipPath == null || !FileSystem.exists(zipPath))
		{
			fail("Paylaşılan zip bulunamadı.");
			return;
		}

		if (!extractor.isSupported())
		{
			fail("ZIP çıkarma bu cihazda desteklenmiyor.");
			return;
		}

		tempRoot = Path.addTrailingSlash(ModImportQueue.modsDirectory()) + "_import_tmp/";
		try
		{
			if (FileSystem.exists(tempRoot))
				deleteRecursive(tempRoot);
			FileSystem.createDirectory(tempRoot);
		}
		catch (e:Dynamic)
		{
			fail("Geçici klasör oluşturulamadı.");
			return;
		}

		status = "KURULUYOR";
		extractor.extract(zipPath, tempRoot, {
			onProgress: function(info:ExtractProgressInfo)
			{
				if (info.totalEntries > 0)
					targetProgress = info.currentEntries / info.totalEntries * 0.85;
			},
			onComplete: function(info:ExtractCompleteInfo)
			{
				try
				{
					#if sys
					scanPreview(tempRoot);
					#end
					var copied = finalizeExtract(tempRoot);
					installedName = copied;
					if (copied != null && copied != "")
						packNameText.text = copied;
					packNameText.screenCenter(X);
					targetProgress = 1;
					if (alreadyInstalled)
						status = "BU MOD ZATEN KURULU";
					else
						status = "TAMAMLANDI";
					finished = true;
				}
				catch (e:Dynamic)
				{
					fail(Std.string(e));
				}
			},
			onError: function(err:ExtractError)
			{
				fail(Std.string(err));
			},
			onCancelled: function()
			{
				fail("İptal edildi.");
			}
		});
		#end
	}

	#if sys
	function finalizeExtract(tempRoot:String):String
	{
		var modsDir:String = ModImportQueue.modsDirectory();
		if (!FileSystem.exists(modsDir))
			FileSystem.createDirectory(modsDir);

		var source:String = unwrapModRoot(tempRoot);
		var folderName:String = Path.withoutDirectory(source);
		if (folderName == null || folderName == "" || folderName == "_import_tmp")
			folderName = Path.withoutExtension(Path.withoutDirectory(zipPath));
		folderName = sanitize(folderName);

		var dest:String = Path.addTrailingSlash(modsDir) + folderName;
		if (FileSystem.exists(dest))
			deleteRecursive(dest);

		copyRecursive(source, dest);
		deleteRecursive(tempRoot);

		var installedPng = Path.join([dest, "pack.png"]);
		if (!FileSystem.exists(installedPng))
			installedPng = Path.join([dest, "pack-pixel.png"]);
		var jsonName:String = folderName;
		var jsonPath = Path.join([dest, "pack.json"]);
		if (FileSystem.exists(jsonPath))
		{
			try
			{
				var pack:Dynamic = haxe.Json.parse(File.getContent(jsonPath));
				if (pack != null && pack.name != null)
					jsonName = Std.string(pack.name);
			}
			catch (e:Dynamic) {}
		}
		applyPreview(FileSystem.exists(installedPng) ? installedPng : null, jsonName);

		try FileSystem.deleteFile(zipPath) catch (e:Dynamic) {}
		return jsonName;
	}

	function unwrapModRoot(tempRoot:String):String
	{
		var entries = FileSystem.readDirectory(tempRoot);
		if (entries == null)
			return tempRoot;

		var real:Array<String> = [];
		for (e in entries)
		{
			if (e == null || StringTools.startsWith(e, "."))
				continue;
			real.push(e);
		}

		if (real.length == 1 && FileSystem.isDirectory(Path.join([tempRoot, real[0]])))
		{
			var inner = Path.join([tempRoot, real[0]]);
			if (real[0] == "mods")
				return unwrapModRoot(inner);
			return inner;
		}

		if (real.indexOf("mods") != -1 && FileSystem.isDirectory(Path.join([tempRoot, "mods"])))
			return unwrapModRoot(Path.join([tempRoot, "mods"]));

		return tempRoot;
	}

	function copyRecursive(from:String, to:String):Void
	{
		if (FileSystem.isDirectory(from))
		{
			if (!FileSystem.exists(to))
				FileSystem.createDirectory(to);
			for (entry in FileSystem.readDirectory(from))
				copyRecursive(Path.join([from, entry]), Path.join([to, entry]));
		}
		else
		{
			var dir = Path.directory(to);
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);
			File.copy(from, to);
		}
	}

	function deleteRecursive(path:String):Void
	{
		if (!FileSystem.exists(path))
			return;
		if (FileSystem.isDirectory(path))
		{
			for (entry in FileSystem.readDirectory(path))
				deleteRecursive(Path.join([path, entry]));
			try FileSystem.deleteDirectory(path) catch (e:Dynamic) {}
		}
		else
		{
			try FileSystem.deleteFile(path) catch (e:Dynamic) {}
		}
	}

	function sanitize(name:String):String
	{
		var out = name;
		out = StringTools.replace(out, "/", "_");
		out = StringTools.replace(out, "\\", "_");
		out = StringTools.replace(out, "..", "_");
		return out;
	}
	#end

	function refreshInstalledMods():Void
	{
		#if MODS_ALLOWED
		try Mods.updatedOnState = false catch (e:Dynamic) {}
		try Mods.parseList() catch (e:Dynamic) {}
		try Mods.pushGlobalMods() catch (e:Dynamic) {}
		try Mods.loadTopMod() catch (e:Dynamic) {}
		try WeekData.reloadWeekFiles(false) catch (e:Dynamic) {}
		try FreeplaySongData.clearPathCache() catch (e:Dynamic) {}
		try BPMCache.instance.clearCache() catch (e:Dynamic) {}
		#end
	}

	function fail(message:String):Void
	{
		failed = true;
		finished = true;
		status = "HATA";
		detailText.visible = true;
		detailText.text = message;
		statusText.color = 0xFFFF5555;
		percentText.color = 0xFFFF5555;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		#if sys
		previewTimer += elapsed;
		if (!previewLoaded && tempRoot != "" && previewTimer > 0.35)
		{
			previewTimer = 0;
			scanPreview(tempRoot);
		}
		#end

		currentProgress = backend.FrameUtil.damp(currentProgress, targetProgress, 12, elapsed);
		var barWidth:Int = FlxG.width - (BAR_MARGIN * 2);
		var w:Int = Std.int(Math.max(2, barWidth * currentProgress));
		if (barFill != null)
			barFill.makeGraphic(w, BAR_HEIGHT, failed ? 0xFFFF5555 : ACCENT);
		if (percentText != null)
			percentText.text = Std.int(currentProgress * 100) + "%";
		if (statusText != null)
			statusText.text = status;

		if (finished && currentProgress > 0.97 && !leaving)
		{
			if (failed || alreadyInstalled)
			{
				if (alreadyInstalled)
					status = "BU MOD ZATEN KURULU";
				if (controls.ACCEPT || controls.BACK)
				{
					leaving = true;
					MenuStyleRouter.goToFreeplay();
				}
			}
			else
			{
				leaving = true;
				#if MODS_ALLOWED
				refreshInstalledMods();
				#end
				MenuStyleRouter.goToFreeplay();
			}
		}
	}
}

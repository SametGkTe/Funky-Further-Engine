package backend;

import openfl.utils.AssetCache;
import flixel.FlxG;
import flixel.util.FlxStringUtil;
import flixel.system.FlxAssets;
import openfl.media.Sound;
import openfl.Assets;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.system.System;
import flixel.graphics.FlxGraphic;

typedef ImageLine =
{
	size:Int,
	text:String
};

@:access(openfl.display.BitmapData)
class CacheSystem
{
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static var localTrackedAssets:Array<String> = [];
	public static var dumpExclusions:Array<String> = ['music/freakyMenu.${Paths.SOUND_EXT}'];

	public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static function clearUnusedMemory()
	{
		for (key in currentTrackedAssets.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				var graphic = currentTrackedAssets.get(key);
				if (graphic != null && graphic.useCount <= 0)
				{
					destroyGraphic(graphic);
					currentTrackedAssets.remove(key);
				}
			}
		}

		for (key => asset in currentTrackedSounds)
		{
			// KORUMA: şu an çalan müziğin sesini temizleme (şarkı çalarken inst ölmesin)
			var playingSound:openfl.media.Sound = null;
			if (FlxG.sound.music != null)
				playingSound = @:privateAccess FlxG.sound.music._sound;
			if (asset != null && asset == playingSound) continue;
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}

		// Partial preview dosyalarini temizle
		var cacheObj = cast(openfl.Assets.cache, AssetCache);
		@:privateAccess
		for (sndKey in cacheObj.sound.keys())
		{
			if (sndKey != null && sndKey.contains(".partial") && !localTrackedAssets.contains(sndKey))
			{
				cacheObj.sound.remove(sndKey);
			}
		}

		#if cpp
		cpp.vm.Gc.compact();
		#end
	}

	#if debug
	public static function cacheStatus():String
	{
		var str = new StringBuf();
		str.add('-- Cache dump start --');
		str.add("\n");
		str.add('( openfl caches are ${openfl.utils.Assets.cache.enabled})');
		str.add("\n");
		var totalMemory = 0;

		str.add("-- Managed bitmaps --");
		str.add("\n");
		var entries:Array<ImageLine> = [];
		@:privateAccess
		for (key => texture in FlxG.bitmap._cache)
		{
			var inStored = currentTrackedAssets.exists(key) ? "S" : "-";
			var inLocal = localTrackedAssets.contains(key) ? "L" : "-";
			var memory = texture?.bitmap?.image?.data?.byteLength ?? 0;
			entries.push({
				size: memory,
				text: '[ $inStored $inLocal ](${FlxStringUtil.formatBytes(memory)}) $key'
			});
			totalMemory += memory;
		}
		entries.sort((x, y) -> cast y.size - x.size);
		for (entry in entries)
		{
			str.add(entry.text);
			str.add("\n");
		}
		str.add('Total: ${FlxStringUtil.formatBytes(totalMemory)}');
		str.add("\n");

		str.add("-- Managed sounds --");
		str.add("\n");
		totalMemory = 0;
		@:privateAccess
		for (key => snd in currentTrackedSounds)
		{
			var inLocal = localTrackedAssets.contains(key) ? "L" : "-";
			var memory = snd.bytesLoaded;
			str.add('[ $inLocal ](${FlxStringUtil.formatBytes(memory)}}/${FlxStringUtil.formatBytes(snd.bytesTotal)}) $key');
			str.add("\n");
			totalMemory += memory;
		}
		str.add('Total: ${FlxStringUtil.formatBytes(totalMemory)}');
		str.add("\n");

		str.add("-- OPENFL sounds --");
		str.add("\n");
		totalMemory = 0;
		@:privateAccess
		for (key => snd in currentTrackedSounds)
		{
			var memory = snd.__buffer.data.length;
			str.add(' (${FlxStringUtil.formatBytes(memory)}) $key');
			str.add("\n");
			totalMemory += memory;
		}
		str.add('Total: ${FlxStringUtil.formatBytes(totalMemory)}');
		str.add("\n");

		str.add("-- END --");
		return str.toString();
	}
	#end

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		localTrackedAssets = [];

		#if !html5
		openfl.Assets.cache.clear("songs");
		#end

		#if mobile
		// Mobile'da sadece ses cache'ini temizle, grafiklere dokunma
		// KORUMA: şu an çalan müziğin sesini temizleme
		var playingSound:openfl.media.Sound = null;
		if (FlxG.sound.music != null)
			playingSound = @:privateAccess FlxG.sound.music._sound;
		for (key => asset in currentTrackedSounds)
		{
			if (asset != null && asset == playingSound) continue;
			if (!dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		return;
		#end

		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key) && !dumpExclusions.contains(key))
			{
				var graphic = FlxG.bitmap.get(key);
				if (graphic != null && graphic.useCount <= 0)
				{
					destroyGraphic(graphic);
				}
			}
		}
	}

	public static function loadBitmap(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		if (currentTrackedAssets.exists(key))
		{
			localTrackedAssets.push(key);
			return currentTrackedAssets.get(key);
		}
		var bitmap = __loadBitmap(key, parentFolder);
		return cacheBitmap(key, bitmap, allowGPU);
	}

	public static function cacheBitmap(key:String, bitmap:BitmapData, ?allowGPU:Bool = true):FlxGraphic
	{
		if (bitmap == null)
			return null;

		var useGpuCache:Bool = allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null;

		#if mobile
		useGpuCache = false;
		#end

		if (useGpuCache)
		{
			if (FlxG.stage != null && FlxG.stage.context3D != null)
			{
				bitmap.lock();
				if (bitmap.__texture == null)
				{
					bitmap.image.premultiplied = true;
					bitmap.getTexture(FlxG.stage.context3D);
				}
			}
		}

		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(key, graph);
		localTrackedAssets.push(key);
		return graph;
	}

	public static function loadSound(file:String, ?beepOnNull:Bool = true, requestName:String = ""):Sound
	{
		if (!currentTrackedSounds.exists(file))
		{
			var isTrackingSound = false;
			var sound = NativeFileSystem.getSound(file);
			if (sound != null)
			{
				currentTrackedSounds.set(file, sound);
				isTrackingSound = true;
			}
			else if (beepOnNull && !isTrackingSound)
			{
				trace('SOUND NOT FOUND: $requestName');
				return FlxAssets.getSound('flixel/sounds/beep');
			}
		}
		localTrackedAssets.push(file);
		return currentTrackedSounds.get(file);
	}

	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = [];
		function checkForGraphics(spr:Dynamic)
		{
			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
				if (grp != null)
				{
					for (member in grp)
					{
						checkForGraphics(member);
					}
					return;
				}
			}

			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
				if (gfx != null)
				{
					protectedGfx.push(gfx);
				}
			}
		}

		for (member in FlxG.state.members)
			checkForGraphics(member);

		if (FlxG.state.subState != null)
			for (member in FlxG.state.subState.members)
				checkForGraphics(member);

		for (key in currentTrackedAssets.keys())
		{
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);
				if (!protectedGfx.contains(graphic))
				{
					destroyGraphic(graphic);
					currentTrackedAssets.remove(key);
				}
			}
		}
	}

	private inline static function destroyGraphic(graphic:FlxGraphic)
	{
		if (graphic == null)
			return;
		if (graphic.useCount > 0)
			return;

		FlxG.bitmap.remove(graphic);
	}

	private inline static function __loadBitmap(key:String, ?parentFolder:String = null):BitmapData
	{
		var intarnalFile = Path.withoutExtension(key);
		var file:String = getTexturePath(intarnalFile, parentFolder);
		var bitmap = NativeFileSystem.getBitmap(file);
		if (bitmap == null)
		{
			trace('Bitmap not found: $file | key: $key');
		}

		return bitmap;
	}

	private static function getTexturePath(file:String, ?parentfolder:String):String
	{
		function astcGetSharedPath(path:String)
		{
			#if ATSC_SUPPORT
			if (Native.isASTCSupported())
			{
				var assetPath = Paths.getSharedPath('$path.astc');
				if (NativeFileSystem.exists(assetPath))
					return assetPath;
			}
			#end
			return Paths.getSharedPath('$path.png');
		}

		function astcGetFolderPath(file:String, folder:String)
		{
			#if ATSC_SUPPORT
			if (Native.isASTCSupported())
			{
				var assetPath = Paths.getFolderPath('$file.astc', folder);
				if (NativeFileSystem.exists(assetPath))
					return assetPath;
			}
			#end
			return Paths.getFolderPath('$file.png', folder);
		}
		#if MODS_ALLOWED
		function astcModFolders(path:String)
		{
			#if ATSC_SUPPORT
			if (Native.isASTCSupported())
			{
				var assetPath = Paths.modFolders('$path.astc');
				if (NativeFileSystem.exists(assetPath))
					return assetPath;
			}
			#end
			return Paths.modFolders('$path.png');
		}

		var customFile:String = file;
		if (parentfolder != null)
			customFile = '$parentfolder/$file';

		if (Paths.currentLevel != null && Paths.currentLevel != 'shared')
		{
			var levelPath = astcModFolders('${Paths.currentLevel}/$customFile');
			if (NativeFileSystem.exists(levelPath))
				return levelPath;
		}

		var modded:String = astcModFolders(customFile);
		if (NativeFileSystem.exists(modded))
			return modded;
		#end
		if (parentfolder == "mobile")
			return astcGetSharedPath('mobile/$file');

		if (parentfolder != null)
			return astcGetFolderPath(file, parentfolder);

		if (Paths.currentLevel != null && Paths.currentLevel != 'shared')
		{
			var levelPath = astcGetFolderPath(file, Paths.currentLevel);
			if (NativeFileSystem.exists(levelPath))
				return levelPath;
		}
		return astcGetSharedPath(file);
	}
}
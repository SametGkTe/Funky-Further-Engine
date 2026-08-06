package backend;

import lime.utils.Assets;
import haxe.io.Path;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

import haxe.Exception;

import openfl.media.Sound;
import lime.media.AudioBuffer;

import openfl.display.BitmapData;
import lime.graphics.Image;

@:access(lime.utils.Assets)
@:access(lime.utils.AssetLibrary)
class FunkinFileSystem
{
	/**
	 * A `Map` for linking paths to libraries.
	 * Used internally for checking if a file is from `lime` or not.
	 *
	 *
	 * `Path` => `Library`
	 * @see `FunkinFileSystem.populateLimeCache`
	 */
	static var limePathToLibrary:Null<Map<String, String>> = null;

	/**
	 * Populates the `limePathToLibrary` variable.
	 * @see `FunkinFileSystem.limePathToLibrary`
	 */
	public static function populateLimeCache():Void
	{
		limePathToLibrary = new Map<String, String>();

		for (library => assetLibrary in Assets.libraries)
		{
			for (asset in assetLibrary.types.keys())
			{
				var directory:String = Path.addTrailingSlash(Path.directory(asset));

				if (!limePathToLibrary.exists(asset))
					limePathToLibrary.set(asset, library);

				if (!limePathToLibrary.exists(directory))
					limePathToLibrary.set(directory, library);
			}
		}
	}

	public static function invalidateLimeCache():Void
	{
		limePathToLibrary = null;
	}

	public static function validateLimeCache():Void
	{
		if (limePathToLibrary == null)
		{
			populateLimeCache();
		}
	}

	/**
	 * Gets text from a path.
	 * @param path The path to find the text for.
	 * @return The text content of the path. If `null`, the path does not exist.
	 */
	public static function getText(path:String):Null<String>
	{
		var content:Null<String> = null;

		try
		{
			if (fromLime(path, false))
			{
				var fullPath:String = formatLimePath(path);
				content = Assets.getText(fullPath);

				if (content == null)
				{
					throw new Exception("Lime returned `null` when getting the text. This should not happen!");
				}
			}
			#if sys
			else if(FileSystem.exists(path))
			{
				// For protection, maybe there could be a way to disallow access to paths outside of the game?
				// I'll look into this later.
				content = File.getContent(path);
			}
			#end
		}
		catch(e:Exception)
		{
			trace('Failed to get the contents of "${path}". More info:\n${e.details()}');
			content = null;
		}

		return content;
	}

	/**
	 * Gets text from a path.
	 * @param path The path to find the text for.
	 * @return The text content of the path. If `null`, the path does not exist.
	 * NOTE: This call is a redirection to `getText`.
	 * @see `FunkinFileSystem.getText`
	 */
	public static function getContent(path:String):Null<String>
	{
		return getText(path);
	}

	/**
	 * Gets an OpenFL sound from a path.
	 * @param path The path to find the sound for.
	 * @return The OpenFL sound of the path. If `null`, the path does not exist.
	 */
	public static function getSound(path:String):Null<Sound>
	{
		var sound:Null<Sound> = null;

		try
		{
			var buffer:Null<AudioBuffer> = null;

			if (fromLime(path, false))
			{
				var fullPath:String = formatLimePath(path);
				buffer = Assets.getAudioBuffer(fullPath, false);

				if (buffer == null)
				{
					throw new Exception("Lime returned `null` when getting the audio buffer. This should not happen!");
				}
			}
			#if sys
			else if(FileSystem.exists(path))
			{
				buffer = AudioBuffer.fromFile(path);
			}
			#end

			if (buffer != null)
			{
				sound = Sound.fromAudioBuffer(buffer);
			}
		}
		catch(e:Exception)
		{
			trace('Failed to get the sound from "${path}". More info:\n${e.details()}');
			sound = null;
		}

		return sound;
	}

	/**
	 * Gets a Bitmap from a path.
	 * @param path The path to find the bitmap for.
	 * @return The Bitmap of the path. If `null`, the path does not exist.
	 */
	public static function getBitmapData(path:String):Null<BitmapData>
	{
		var bitmap:Null<BitmapData> = null;

		try
		{
			var image:Null<Image> = null;

			if (fromLime(path, false))
			{
				var fullPath:String = formatLimePath(path);
				image = Assets.getImage(fullPath, false);

				if (image == null)
				{
					throw new Exception("Lime returned `null` when getting the image. This should not happen!");
				}
			}
			#if sys
			else if(FileSystem.exists(path))
			{
				image = Image.fromFile(path);
			}
			#end

			if (image != null)
			{
				bitmap = BitmapData.fromImage(image);
			}
		}
		catch(e:Exception)
		{
			trace('Failed to get the bitmap from "${path}". More info:\n${e.details()}');
			bitmap = null;
		}

		return bitmap;
	}

	public static function readDirectory(path:String, ?recursive:Bool = false):Array<String>
	{
		validateLimeCache();

		if (limePathToLibrary == null)
			throw new Exception("Lime Cache is null while validated! This should not happen!");

		if (fromLime(path, true))
		{
			var parent:String = Path.addTrailingSlash(path);
			var parentLibrary:Null<String> = limePathToLibrary.get(parent);

			return [for (path => library in limePathToLibrary)
			{
				if (library != parentLibrary || !path.startsWith(parent))
					continue;

				var file:String = path.substring(parent.length);

				if(file.length == 0)
					continue;

				if(!recursive && Path.directory(file).length > 0)
					continue;

				formatLimePath(file, parentLibrary);
			}];
		}
		else
		{
			var parent:String = Path.removeTrailingSlashes(path);

			var searchDirectory:(?directory:Null<String>)->Array<String> = (?d:Null<String>) -> [];

			searchDirectory = (?directory:Null<String>) -> {
				var toReturn:Array<String> = [];

				var joinedDirectory:String = Path.join([parent, directory]);
				for (file in FileSystem.readDirectory(joinedDirectory))
				{
					var fullPath:String = Path.join([joinedDirectory, file]);
					var path:String = Path.join([directory, file]);

					if (FileSystem.isDirectory(fullPath))
					{
						if (!recursive)
							continue;

						for(file in searchDirectory(path))
							toReturn.push(file);
					}
					else if (!toReturn.contains(path))
					{
						toReturn.push(path);
					}
				}

				trace(toReturn);
				return toReturn;
			};

			return searchDirectory();
		}
	}

	public static function fromLime(path:String, ?directory:Null<Bool> = null):Bool
	{
		validateLimeCache();

		if (limePathToLibrary == null)
			throw new Exception("Lime Cache is null while validated! This should not happen!");

		var symbolName:String = path.substring(path.indexOf(':') + 1);

		if (directory != null)
		{
			var asset:String = (directory == true ? Path.addTrailingSlash : Path.removeTrailingSlashes)(symbolName);
			return limePathToLibrary.exists(asset);
		}
		else
		{
			if (limePathToLibrary.exists(Path.addTrailingSlash(symbolName)))
				return true;

			if (limePathToLibrary.exists(Path.removeTrailingSlashes(symbolName)))
				return true;

			return false;
		}
	}

	public static function formatLimePath(path:String, ?library:Null<String> = null):String
	{
		if(library != null)
		{
			validateLimeCache();

			if (limePathToLibrary == null)
				throw new Exception("Lime Cache is null while validated! This should not happen!");
		}

		var symbolName:String = path.substring(path.indexOf(':') + 1);
		if (library == null) library = limePathToLibrary.get(symbolName);

		if(library == null || library == 'default')
			return symbolName;

		return library + ':' + symbolName;
	}

	public static function exists(path:String):Bool
	{
		if (fromLime(path))
			return true;

		return FileSystem.exists(path);
	}
}
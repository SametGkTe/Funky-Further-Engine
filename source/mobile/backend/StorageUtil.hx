package mobile.backend;

import haxe.io.Path;
import haxe.io.Bytes;
import StringTools;
import lime.system.System as LimeSystem;
import lime.app.Application;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

#if android
import sys.io.Process;
#end

/**
 * Merged StorageUtil
 * - Keeps modpack functions from old StorageUtil
 * - Adds custom storage features from new StorageUtil
 * - Avoids direct crash if ClientPrefs.data.storageType does not exist
 */
class StorageUtil
{
	#if sys
	public static var rootDir:String = Path.addTrailingSlash(LimeSystem.applicationStorageDirectory);

	#if android
	public static var currentExternalStorageDirectory:String = null;
	public static var lastGettedPermission:Int = 0;
	#end

	public static inline function getStorageDirectory():String
	{
		return #if android
			Path.addTrailingSlash(AndroidContext.getExternalFilesDir())
		#elseif ios
			Path.addTrailingSlash(LimeSystem.documentsDirectory)
		#else
			Path.addTrailingSlash(Sys.getCwd())
		#end;
	}

	public static function saveContent(fileName:String, fileData:String, ?alert:Bool = true):Void
	{
		final folder:String = getStorageRootDirectory() + 'saves/';
		try
		{
			ensureDirectory(folder);
			File.saveContent(folder + fileName, fileData);

			if (alert)
			{
				CoolUtil.showPopUp(
					Language.getPhrase('file_save_success', '{1} has been saved.', [fileName]),
					Language.getPhrase('mobile_success', "Success!")
				);
			}
		}
		catch (e:Dynamic)
		{
			var err:String = errorToString(e);

			if (alert)
			{
				CoolUtil.showPopUp(
					Language.getPhrase('file_save_fail', '{1} couldn\'t be saved.\n({2})', [fileName, err]),
					Language.getPhrase('mobile_error', "Error!")
				);
			}
			else
			{
				trace('$fileName couldn\'t be saved. ($err)');
			}
		}
	}

	public static function getStorageRootDirectory():String
	{
		return #if android
			Path.addTrailingSlash(getExternalStorageDirectory())
		#elseif ios
			Path.addTrailingSlash(LimeSystem.documentsDirectory)
		#else
			Path.addTrailingSlash(Sys.getCwd())
		#end;
	}

	public static function getModsDirectory():String
		return getStorageRootDirectory() + 'mods/';

	public static function getModpackCacheDirectory():String
		return getStorageRootDirectory() + 'modpack-cache/';

	public static function getModpackDownloadDirectory():String
		return getModpackCacheDirectory() + 'downloads/';

	public static function getModpackTempDirectory():String
		return getModpackCacheDirectory() + 'temp/';

	public static function getModpackInstalledDirectory():String
		return getModpackCacheDirectory() + 'installed/';

	public static function ensureDirectory(path:String):Void
	{
		if (path == null || StringTools.trim(path) == '')
			return;

		if (!FileSystem.exists(path))
			FileSystem.createDirectory(path);
	}

	public static function ensureModpackDirectories():Void
	{
		final dirs:Array<String> = [
			getStorageRootDirectory(),
			getModsDirectory(),
			getModpackCacheDirectory(),
			getModpackDownloadDirectory(),
			getModpackTempDirectory(),
			getModpackInstalledDirectory()
		];

		for (dir in dirs)
		{
			try
			{
				ensureDirectory(dir);
			}
			catch (e:Dynamic)
			{
				trace('Dizin oluşturma hatası: $dir (${errorToString(e)})');
			}
		}
	}

	#if android
	public static inline function getCustomStoragePath():String
		return Path.addTrailingSlash(AndroidContext.getExternalFilesDir()) + 'storageModes.txt';

	public static function getCustomStorageDirectories(?doNotSeperate:Bool):Array<String>
	{
		var result:Array<String> = [];
		var curTextFile:String = getCustomStoragePath();

		if (!FileSystem.exists(curTextFile))
			return result;

		for (mode in CoolUtil.coolTextFile(curTextFile))
		{
			if (mode == null)
				continue;

			mode = StringTools.trim(mode);
			if (mode.length < 1)
				continue;

			mode = StringTools.replace(mode, 'Name: ', '');
			mode = StringTools.replace(mode, ' Folder: ', '|');

			var dat = mode.split("|");

			if (doNotSeperate == true)
				result.push(mode);
			else if (dat.length > 0)
				result.push(dat[0]);
		}

		return result;
	}

	private static function getMetaValue(key:String, defaultValue:String):String
	{
		try
		{
			var value:Dynamic = Application.current.meta.get(key);
			if (value != null)
			{
				var text:String = Std.string(value);
				if (StringTools.trim(text) != '')
					return text;
			}
		}
		catch (e:Dynamic) {}

		return defaultValue;
	}

	private static function getDefaultStorageType():String
	{
		var storageType:String = 'EXTERNAL_DATA';

		try
		{
			var prefData:Dynamic = ClientPrefs.data;
			if (prefData != null && Reflect.hasField(prefData, "storageType"))
			{
				var found:Dynamic = Reflect.field(prefData, "storageType");
				if (found != null)
				{
					var text:String = StringTools.trim(Std.string(found));
					if (text != '')
						storageType = text;
				}
			}
		}
		catch (e:Dynamic) {}

		return storageType;
	}

	private static function getSavedStorageType():String
	{
		var filePath:String = rootDir + 'storagetype.txt';
		var storageType:String = getDefaultStorageType();

		try
		{
			ensureDirectory(rootDir);

			if (!FileSystem.exists(filePath))
			{
				File.saveContent(filePath, storageType);
			}
			else
			{
				var content:String = StringTools.trim(File.getContent(filePath));
				if (content != '')
					storageType = content;
			}
		}
		catch (e:Dynamic)
		{
			trace('Failed to read storagetype.txt: ' + errorToString(e));
		}

		return storageType;
	}

	private static function resolveExternalStorageDirectory():String
	{
		var daPath:String = '';
		var curStorageType:String = getSavedStorageType();

		for (line in getCustomStorageDirectories(true))
		{
			if (line == null || StringTools.trim(line) == '')
				continue;

			if (StringTools.startsWith(line, curStorageType))
			{
				var dat = line.split("|");
				if (dat.length > 1)
					daPath = dat[1];
			}
		}

		switch (curStorageType)
		{
			case 'EXTERNAL':
				daPath = AndroidEnvironment.getExternalStorageDirectory() + '/.' + getMetaValue('file', 'PsychEngine');

			case 'EXTERNAL_OBB':
				daPath = AndroidContext.getObbDir();

			case 'EXTERNAL_MEDIA':
				daPath = AndroidEnvironment.getExternalStorageDirectory() + '/Android/media/' + getMetaValue('packageName', 'com.psychengine.game');

			case 'EXTERNAL_DATA':
				daPath = AndroidContext.getExternalFilesDir();

			default:
				if (daPath == null || StringTools.trim(daPath) == '')
				{
					var ext:String = getExternalDirectory(curStorageType);
					if (ext != null && StringTools.trim(ext) != '')
						daPath = ext + '.' + getMetaValue('file', 'PsychEngine');
				}
		}

		if (daPath == null || StringTools.trim(daPath) == '')
			daPath = '/sdcard/.PsychEngine/';

		return Path.addTrailingSlash(daPath);
	}

	public static function initExternalStorageDirectory():String
	{
		currentExternalStorageDirectory = resolveExternalStorageDirectory();

		try
		{
			ensureDirectory(getStorageDirectory());
		}
		catch (e:Dynamic)
		{
			CoolUtil.showPopUp(
				Language.getPhrase('create_directory_error', 'Please create directory to\n{1}\nPress OK to close the game', [getStorageDirectory()]),
				Language.getPhrase('mobile_error', "Error!")
			);
			lime.system.System.exit(1);
		}

		ensureModpackDirectories();

		try
		{
			ensureDirectory(getModsDirectory());
		}
		catch (e:Dynamic)
		{
			CoolUtil.showPopUp(
				Language.getPhrase('create_directory_error', 'Please create directory to\n{1}\nPress OK to close the game', [getExternalStorageDirectory()]),
				Language.getPhrase('mobile_error', "Error!")
			);
			lime.system.System.exit(1);
		}

		return currentExternalStorageDirectory;
	}

	public static function getExternalStorageDirectory():String
	{
		if (currentExternalStorageDirectory == null || StringTools.trim(currentExternalStorageDirectory) == '')
			return initExternalStorageDirectory();

		return Path.addTrailingSlash(currentExternalStorageDirectory);
	}

	public static function requestPermissions():Void
	{
		if (AndroidVersion.SDK_INT >= AndroidVersionCode.TIRAMISU)
		{
			AndroidPermissions.requestPermissions([
				'READ_MEDIA_IMAGES',
				'READ_MEDIA_VIDEO',
				'READ_MEDIA_AUDIO',
				'READ_MEDIA_VISUAL_USER_SELECTED'
			]);
		}
		else
		{
			AndroidPermissions.requestPermissions([
				'READ_EXTERNAL_STORAGE',
				'WRITE_EXTERNAL_STORAGE'
			]);
		}

		if (!AndroidEnvironment.isExternalStorageManager())
			AndroidSettings.requestSetting('MANAGE_APP_ALL_FILES_ACCESS_PERMISSION');

		if ((AndroidVersion.SDK_INT >= AndroidVersionCode.TIRAMISU
			&& !AndroidPermissions.getGrantedPermissions().contains('android.permission.READ_MEDIA_IMAGES'))
			|| (AndroidVersion.SDK_INT < AndroidVersionCode.TIRAMISU
				&& !AndroidPermissions.getGrantedPermissions().contains('android.permission.READ_EXTERNAL_STORAGE')))
		{
			CoolUtil.showPopUp(
				Language.getPhrase('permissions_message', 'İzinleri kabul ettiyseniz oyununuz sorunsuz açılacaktır, etmediyseniz izinler bölümünden tüm dosyalara erişime izin verin'),
				Language.getPhrase('mobile_notice', "Uyarı!")
			);
		}

		initExternalStorageDirectory();
	}

	public static function chmodPermission(fullPath:String):Int
	{
		var process = new Process("sh", ["-c", 'stat -c %a "$fullPath"']);
		var stringOutput:String = process.stdout.readAll().toString();
		process.close();

		lastGettedPermission = Std.parseInt(StringTools.trim(stringOutput));
		return lastGettedPermission;
	}

	public static function chmod(permissions:Int, fullPath:String):Void
	{
		var process = new Process("sh", ["-c", 'chmod -R $permissions "$fullPath"']);
		var exitCode:Int = process.exitCode();

		if (exitCode == 0)
		{
			trace('Başarılı: $fullPath dosyasının izinleri ($permissions) olarak ayarlandı');
		}
		else
		{
			var errorOutput:String = process.stderr.readAll().toString();
			trace('HATA: ($fullPath) dosyası için istenen izin değiştirme isteği başarısız. Çıkış Kodu: $exitCode, Hata: $errorOutput');
		}

		process.close();
	}

	public static function checkExternalPaths(?splitStorage:Bool = false):Array<String>
	{
		var process = new Process("sh", ["-c", 'grep -o "/storage/....-...." /proc/mounts | paste -sd ","']);
		var paths:String = StringTools.trim(process.stdout.readAll().toString());
		process.close();

		if (paths == null || paths == '')
			return [];

		if (splitStorage)
			paths = StringTools.replace(paths, '/storage/', '');

		return paths.split(',');
	}

	public static function getExternalDirectory(externalDir:String):String
	{
		var daPath:String = '';

		for (path in checkExternalPaths())
		{
			if (path != null && path.indexOf(externalDir) != -1)
				daPath = StringTools.trim(path);
		}

		if (daPath == null || daPath == '')
			return '';

		return Path.addTrailingSlash(daPath);
	}
	#else
	public static function getExternalStorageDirectory():String
	{
		return #if ios
			Path.addTrailingSlash(LimeSystem.documentsDirectory)
		#else
			Path.addTrailingSlash(Sys.getCwd())
		#end;
	}

	public static function requestPermissions():Void {}
	#end

	public static function copySpesificFileFromAssets(filePathInAssets:String, copyTo:String, ?changeable:Bool):Void
	{
		#if sys
		try
		{
			if (!Assets.exists(filePathInAssets))
				return;

			var dir:String = Path.directory(copyTo);
			if (dir != null && StringTools.trim(dir) != '')
				ensureDirectory(dir);

			var fileData:Bytes = null;
			try
			{
				fileData = Assets.getBytes(filePathInAssets);
			}
			catch (e:Dynamic) {}

			if (fileData != null)
			{
				if (FileSystem.exists(copyTo))
				{
					if (changeable == true)
					{
						var existingFileData:Bytes = File.getBytes(copyTo);
						if (existingFileData == null || !bytesEqual(existingFileData, fileData))
							File.saveBytes(copyTo, fileData);
					}
				}
				else
				{
					File.saveBytes(copyTo, fileData);
				}

				trace('Copied: $filePathInAssets -> $copyTo');
				return;
			}

			var textData:String = null;
			try
			{
				textData = Assets.getText(filePathInAssets);
			}
			catch (e:Dynamic) {}

			if (textData != null)
			{
				if (FileSystem.exists(copyTo))
				{
					if (changeable == true)
					{
						var existingTxtData:String = File.getContent(copyTo);
						if (existingTxtData != textData)
							File.saveContent(copyTo, textData);
					}
				}
				else
				{
					File.saveContent(copyTo, textData);
				}

				trace('Copied (text): $filePathInAssets -> $copyTo');
			}
		}
		catch (e:Dynamic)
		{
			trace('Error copying file $filePathInAssets: ' + errorToString(e));
		}
		#end
	}

	private static function bytesEqual(a:Bytes, b:Bytes):Bool
	{
		if (a == null || b == null)
			return a == b;

		if (a.length != b.length)
			return false;

		for (i in 0...a.length)
		{
			if (a.get(i) != b.get(i))
				return false;
		}

		return true;
	}

	private static function errorToString(e:Dynamic):String
	{
		if (e == null)
			return "Unknown error";

		try
		{
			var msg:Dynamic = Reflect.field(e, "message");
			if (msg != null)
				return Std.string(msg);
		}
		catch (_:Dynamic) {}

		return Std.string(e);
	}
	#end
}
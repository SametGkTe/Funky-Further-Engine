package backend.further;

import backend.modpack.zip.IZipExtractor;
import backend.modpack.zip.ZipExtractorFactory;
import backend.modpack.zip.ZipTypes;
import haxe.crypto.Md5;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * Hızlı, etkileşimsiz zip → mod/texturepack kurucu.
 * Mantık ModImportState.finalizeExtract/unwrapModRoot'tan alınmıştır (aynı motor
 * davranışı; kullanıcı onayı olmadan, indirme kuyruğu için).
 * kind: 'mod' → mods/<ad>/ | 'texturepack' → further/texturepacks/<ad>/ | 'extensionpack' → further/extensionpacks/<ad>/
 */
class QuickModInstaller
{
	static inline var MD5_MAX_BYTES:Float = 200 * 1024 * 1024; // 200MB üstü dosyalarda md5 atlanır

	public static function installZip(zipPath:String, kind:String, ?expectedMd5:String, onMsg:String->Void, onDone:Bool->String->Void):Void
	{
		#if target.threaded
		sys.thread.Thread.create(() -> run(zipPath, kind, expectedMd5, onMsg, onDone));
		#else
		run(zipPath, kind, expectedMd5, onMsg, onDone);
		#end
	}

	static function run(zipPath:String, kind:String, expectedMd5:String, onMsg:String->Void, onDone:Bool->String->Void):Void
	{
		try
		{
			if (zipPath == null || !FileSystem.exists(zipPath))
			{
				onDone(false, 'Zip bulunamadı: $zipPath');
				return;
			}

			// MD5 doğrulama (GameBanana checksum verirse)
			if (expectedMd5 != null && expectedMd5.length > 0)
			{
				var size:Float = FileSystem.stat(zipPath).size;
				if (size <= MD5_MAX_BYTES)
				{
					onMsg('MD5 doğrulanıyor...');
					var actual:String = Md5.make(File.getBytes(zipPath)).toHex().toLowerCase();
					var expect:String = expectedMd5.toLowerCase();
					if (actual != expect)
					{
						onDone(false, 'MD5 uyuşmuyor! Dosya bozuk veya değiştirilmiş olabilir.');
						return;
					}
				}
			}

			var extractor:IZipExtractor = ZipExtractorFactory.createSafe();
			if (!extractor.isSupported())
			{
				onDone(false, 'ZIP çıkarma bu cihazda desteklenmiyor.');
				return;
			}

			var targetRoot:String = (kind == 'texturepack') ? TexturePackPaths.getPacksDirectory()
				: (kind == 'extensionpack') ? ExtensionPackManager.getRoot()
				: backend.modpack.ModImportQueue.modsDirectory();
			targetRoot = Path.addTrailingSlash(targetRoot);

			var tempRoot:String = Path.addTrailingSlash(backend.modpack.ModpackPaths.getTempDirectory()) + '_dlq_tmp/';
			if (FileSystem.exists(tempRoot))
				deleteRecursive(tempRoot);
			FileSystem.createDirectory(tempRoot);

			onMsg('Arşiv açılıyor...');
			extractor.extract(zipPath, tempRoot, {
				onProgress: function(info:ExtractProgressInfo)
				{
					if (info.totalEntries > 0)
						onMsg('Açılıyor %' + Std.int(info.currentEntries / info.totalEntries * 100));
				},
				onComplete: function(info:ExtractCompleteInfo)
				{
					try
					{
						var source:String = unwrapModRoot(tempRoot);
						var folderName:String = Path.withoutDirectory(source);
						if (folderName == null || folderName == '' || folderName == '_dlq_tmp')
							folderName = Path.withoutExtension(Path.withoutDirectory(zipPath));
						folderName = sanitize(folderName);

						var dest:String = targetRoot + folderName;
						onMsg('Kopyalanıyor: $folderName');
						if (FileSystem.exists(dest))
							deleteRecursive(dest);
						copyRecursive(source, dest);
						deleteRecursive(tempRoot);

						// zip'i temizle (kuruldu)
						try FileSystem.deleteFile(zipPath) catch (e:Dynamic) {}

						onDone(true, folderName);
					}
					catch (e:Dynamic)
					{
						onDone(false, 'Kurulum hatası: ' + Std.string(e));
					}
				},
				onError: function(err:ExtractError)
				{
					onDone(false, 'Arşiv açılamadı: ' + Std.string(err));
				},
				onCancelled: function()
				{
					onDone(false, 'Kurulum iptal edildi.');
				}
			});
		}
		catch (e:Dynamic)
		{
			onDone(false, 'Kurulum istisnası: ' + Std.string(e));
		}
	}

	/** Zip kökü tek klasörse (veya mods/ sarmalıysa) gerçek mod kökünü bul. */
	static function unwrapModRoot(tempRoot:String):String
	{
		var entries = FileSystem.readDirectory(tempRoot);
		if (entries == null)
			return tempRoot;

		var real:Array<String> = [];
		for (e in entries)
		{
			if (e == null || StringTools.startsWith(e, '.'))
				continue;
			real.push(e);
		}

		if (real.length == 1 && FileSystem.isDirectory(Path.join([tempRoot, real[0]])))
		{
			var inner = Path.join([tempRoot, real[0]]);
			if (real[0] == 'mods')
				return unwrapModRoot(inner);
			return inner;
		}

		if (real.indexOf('mods') != -1 && FileSystem.isDirectory(Path.join([tempRoot, 'mods'])))
			return unwrapModRoot(Path.join([tempRoot, 'mods']));

		return tempRoot;
	}

	static function copyRecursive(from:String, to:String):Void
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

	static function deleteRecursive(path:String):Void
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

	static function sanitize(name:String):String
	{
		var out = name;
		out = StringTools.replace(out, '/', '_');
		out = StringTools.replace(out, '\\', '_');
		out = StringTools.replace(out, '..', '_');
		out = StringTools.replace(out, ':', '_');
		if (out.length == 0)
			out = 'kurulum';
		return out;
	}
}

package backend.modpack.zip;

#if sys
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Reader;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import backend.modpack.zip.ZipTypes;
import backend.modpack.zip.ZipSecurity;
#end

class SystemZipExtractor implements IZipExtractor {
	#if sys
	var _extracting:Bool = false;
	var _cancelled:Bool = false;

	static final PROGRESS_EVERY:Int = 10;

	public function new() {}

	public function getBackendName():String {
		return "haxe-zip-streaming";
	}

	public function isSupported():Bool {
		return true;
	}

	public function isExtracting():Bool {
		return _extracting;
	}

	public function cancel():Void {
		if (_extracting) {
			_cancelled = true;
			trace("[SystemZipExtractor] İptal isteği alındı.");
		}
	}

	public function listEntries(zipPath:String):ExtractResult<Array<ZipEntryInfo>> {
		if (!FileSystem.exists(zipPath))
			return Failure(FileNotFound(zipPath));

		var input:FileInput = null;

		try {
			input = File.read(zipPath, true);
			var reader = new Reader(input);
			var entries = reader.read();

			var result:Array<ZipEntryInfo> = [];

			for (entry in entries) {
				result.push(entryToInfo(entry));
			}

			input.close();
			return Success(result);
		} catch (e:Dynamic) {
			if (input != null) {
				try {
					input.close();
				} catch (_) {}
			}
			return Failure(CorruptArchive(Std.string(e)));
		}
	}

	public function extract(zipPath:String, destinationPath:String, callbacks:ExtractCallbacks):Void {
		var skippedEntries:Int = 0;
		if (_extracting) {
			safeError(callbacks, Unknown("Zaten bir extraction devam ediyor."));
			return;
		}

		_extracting = true;
		_cancelled = false;

		if (!FileSystem.exists(zipPath)) {
			finishWithError(callbacks, FileNotFound(zipPath));
			return;
		}

		try {
			ensureDirectory(destinationPath);
		} catch (e:Dynamic) {
			finishWithError(callbacks, PermissionDenied(destinationPath));
			return;
		}

		var normalizedDest = normalizeDirPath(destinationPath);

		var input:FileInput = null;
		var entries:List<Entry>;

		try {
			input = File.read(zipPath, true);
			var reader = new Reader(input);
			entries = reader.read();
		} catch (e:Dynamic) {
			if (input != null) {
				try {
					input.close();
				} catch (_) {}
			}
			finishWithError(callbacks, CorruptArchive(Std.string(e)));
			return;
		}

		var entryInfos:Array<ZipEntryInfo> = [];
		for (entry in entries) {
			entryInfos.push(entryToInfo(entry));
		}

		var scanResult = ZipSecurity.scanEntries(entryInfos, normalizedDest);
		switch (scanResult) {
			case Dangerous(reasons):
				try {
					input.close();
				} catch (_) {}
				finishWithError(callbacks, PathTraversal(reasons.join(" | ")));
				return;
			case Clean:
		}

		var stripPrefix = detectWrapperFolder(entryInfos);
		if (stripPrefix.length > 0) {
			trace('[SystemZipExtractor] Fazladan üst klasör algılandı: "$stripPrefix" — otomatik kaldırılacak.');
		}

		var totalEntries = entryInfos.length;
		var totalBytes:Float = 0;
		for (info in entryInfos)
			totalBytes += info.uncompressedSize;

		var extractedEntries = 0;
		var extractedBytes:Float = 0;
		var loopIndex = 0;
		var errorOccured:Null<ExtractError> = null;

		for (entry in entries) {

			if (_cancelled) {
				try {
					input.close();
				} catch (_) {}
				finishCancelled(callbacks);
				return;
			}

			var rawName = entry.fileName;

			var adjustedName = applyStripPrefix(rawName, stripPrefix);

			if (adjustedName.length == 0) {
				loopIndex++;
				continue;
			}

			var safePath:String;
			switch (ZipSecurity.checkEntryPath(adjustedName, normalizedDest)) {
				case Safe(normalized):
					safePath = normalized;
				case Unsafe(reason):
					trace('[SystemZipExtractor] Atlandı (güvensiz): $rawName — $reason');
					loopIndex++;
					continue;
			}

			var fullDestPath = Path.join([normalizedDest, safePath]);
			fullDestPath = StringTools.replace(fullDestPath, "\\", "/");

			if (isDirectoryEntry(entry)) {
				try {
					ensureDirectory(fullDestPath);
				} catch (e:Dynamic) {
					trace('[SystemZipExtractor] Klasör oluşturulamadı: $fullDestPath');
				}
				loopIndex++;
				extractedEntries++;
				continue;
			}

			var parentDir = Path.directory(fullDestPath);
			if (parentDir != null && parentDir.length > 0) {
				try {
					ensureDirectory(parentDir);
				} catch (e:Dynamic) {
					trace('[SystemZipExtractor] Üst klasör oluşturulamadı: $parentDir');
				}
			}

			try {
				var data:Null<Bytes> = safeUnzip(entry);
				if (data == null) {
					trace('[SystemZipExtractor] Dosya atlandı (açılamadı): ${entry.fileName}');
					skippedEntries++;
					loopIndex++;
					continue;
				}
				File.saveBytes(fullDestPath, data);
				extractedBytes += data.length;
			} catch (e:Dynamic) {
				trace('[SystemZipExtractor] Dosya yazılamadı: $fullDestPath — ${Std.string(e)}');
				errorOccured = Unknown('Dosya yazılamadı: $fullDestPath');
				break;
			}

			extractedEntries++;
			loopIndex++;

			if (callbacks != null && callbacks.onProgress != null) {
				if (loopIndex % PROGRESS_EVERY == 0 || loopIndex == totalEntries) {
					callbacks.onProgress({
						currentEntries: extractedEntries,
						totalEntries: totalEntries,
						currentFile: safePath,
						processedBytes: extractedBytes,
						totalBytes: totalBytes
					});
				}
			}
		}

		try {
			input.close();
		} catch (_) {}

		if (errorOccured != null) {
			finishWithError(callbacks, errorOccured);
			return;
		}

		_extracting = false;

		if (callbacks != null && callbacks.onComplete != null) {
			callbacks.onComplete({
				destination: normalizedDest,
				extractedEntries: extractedEntries,
				extractedBytes: extractedBytes
			});
		}
	}

	function detectWrapperFolder(entries:Array<ZipEntryInfo>):String {
		if (entries.length == 0)
			return "";

		var firstPrefix:String = null;

		for (entry in entries) {
			var name = sanitizeName(entry.fileName);
			if (name.length == 0)
				continue;

			var slashIdx = name.indexOf("/");

			if (slashIdx == -1) {

				return "";
			}

			var topFolder = name.substr(0, slashIdx + 1);

			if (firstPrefix == null) {
				firstPrefix = topFolder;
			} else if (firstPrefix != topFolder) {

				return "";
			}
		}

		if (firstPrefix == null)
			return "";

		var hasManifestInWrapper = false;
		var hasManifestAtRoot = false;

		for (entry in entries) {
			var name = sanitizeName(entry.fileName);
			if (name == "_modpack.json")
				hasManifestAtRoot = true;
			if (name == firstPrefix + "_modpack.json")
				hasManifestInWrapper = true;
		}

		if (hasManifestInWrapper && !hasManifestAtRoot)
			return firstPrefix;

		if (!hasManifestAtRoot && !hasManifestInWrapper)
			return firstPrefix;

		return "";
	}

	function applyStripPrefix(entryName:String, prefix:String):String {
		if (prefix.length == 0)
			return entryName;

		var name = sanitizeName(entryName);

		if (StringTools.startsWith(name, prefix)) {
			return name.substr(prefix.length);
		}

		return name;
	}

	function sanitizeName(name:String):String {
		var result = StringTools.replace(name, "\\", "/");

		while (StringTools.startsWith(result, "./"))
			result = result.substr(2);

		return result;
	}

	function safeUnzip(entry:Entry):Null<Bytes> {
		if (entry.data == null)
			return null;

		if (entry.compressed) {
			try {
				Reader.unzip(entry);
			} catch (e:Dynamic) {
				trace('[SystemZipExtractor] Reader.unzip başarısız, raw inflate deneniyor...');
				try {
					var inflated = rawInflate(entry.data, entry.fileSize);
					entry.data = inflated;
					entry.compressed = false;
				} catch (e2:Dynamic) {
					trace('[SystemZipExtractor] ✗ Dosya açılamadı: ${entry.fileName} — ${Std.string(e2)}');
					return null;
				}
			}
		}

		return entry.data;
	}

	function rawInflate(data:Bytes, expectedSize:Int):Bytes {

		var u = new haxe.zip.Uncompress(-15);
		var buf = Bytes.alloc(expectedSize);
		var result = u.execute(data, 0, buf, 0);
		u.close();

		if (result.done) {
			return buf;
		}

		return buf.sub(0, result.write);
	}

	function entryToInfo(entry:Entry):ZipEntryInfo {
		return {
			fileName: entry.fileName,
			compressedSize: entry.data != null ? entry.data.length : 0,
			uncompressedSize: entry.fileSize,
			isDirectory: isDirectoryEntry(entry),
			crc32: Std.string(entry.crc32),
			isSymlink: false
		};
	}

	function isDirectoryEntry(entry:Entry):Bool {
		if (entry.fileSize == 0) {
			var name = entry.fileName;
			return StringTools.endsWith(name, "/") || StringTools.endsWith(name, "\\");
		}
		return false;
	}

	function ensureDirectory(path:String):Void {
		if (path == null || path.length == 0)
			return;

		var normalized = StringTools.replace(path, "\\", "/");
		if (StringTools.endsWith(normalized, "/"))
			normalized = normalized.substr(0, normalized.length - 1);

		if (FileSystem.exists(normalized))
			return;

		var parent = Path.directory(normalized);
		if (parent != null && parent.length > 0 && parent != normalized) {
			ensureDirectory(parent);
		}

		try {
			FileSystem.createDirectory(normalized);
		} catch (e:Dynamic) {
			trace('[SystemZipExtractor] mkdir başarısız: $normalized — ${Std.string(e)}');
		}
	}

	function normalizeDirPath(path:String):String {
		var normalized = Path.normalize(path);
		normalized = StringTools.replace(normalized, "\\", "/");
		if (!StringTools.endsWith(normalized, "/"))
			normalized += "/";
		return normalized;
	}

	function safeError(callbacks:ExtractCallbacks, error:ExtractError):Void {
		if (callbacks != null && callbacks.onError != null)
			callbacks.onError(error);
	}

	function finishWithError(callbacks:ExtractCallbacks, error:ExtractError):Void {
		_extracting = false;
		_cancelled = false;
		safeError(callbacks, error);
	}

	function finishCancelled(callbacks:ExtractCallbacks):Void {
		_extracting = false;
		_cancelled = false;
		if (callbacks != null && callbacks.onCancelled != null)
			callbacks.onCancelled();
	}

	#else
	public function new() {}

	public function getBackendName():String
		return "unsupported-no-sys";

	public function isSupported():Bool
		return false;

	public function isExtracting():Bool
		return false;

	public function cancel():Void {}

	public function listEntries(zipPath:String):ExtractResult<Array<ZipEntryInfo>>
		return Failure(NotSupported("sys target gerekli."));

	public function extract(zipPath:String, destinationPath:String, callbacks:ExtractCallbacks):Void {
		if (callbacks != null && callbacks.onError != null)
			callbacks.onError(NotSupported("sys target gerekli."));
	}
	#end
}

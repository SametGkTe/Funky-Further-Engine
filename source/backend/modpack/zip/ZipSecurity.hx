package backend.modpack.zip;

import haxe.io.Path;
import backend.modpack.zip.ZipTypes.ZipEntryInfo;

enum PathCheckResult {
	Safe(normalizedEntry:String);
	Unsafe(reason:String);
}

enum ArchiveScanResult {
	Clean;
	Dangerous(reasons:Array<String>);
}

class ZipSecurity {
	public static function checkEntryPath(entryName:String, destinationRoot:String):PathCheckResult {
		if (entryName == null)
			return Unsafe("Entry adı null.");

		var entry = sanitizeEntryName(entryName);

		if (entry.length == 0)
			return Unsafe("Boş entry adı.");

		if (StringTools.startsWith(entry, "/"))
			return Unsafe('Absolute path tespit edildi: $entry');

		if (~/^[A-Za-z]:/.match(entry))
			return Unsafe('Windows absolute path tespit edildi: $entry');

		if (entry == ".." || StringTools.startsWith(entry, "../") || entry.indexOf("/../") != -1)
			return Unsafe('Path traversal tespit edildi: $entry');

		if (entry.indexOf("\x00") != -1)
			return Unsafe('Null byte tespit edildi: $entry');

		var normalizedRoot = normalizeDir(destinationRoot);
		var fullPath = normalizePath(Path.join([normalizedRoot, entry]));

		if (!StringTools.startsWith(fullPath, normalizedRoot))
			return Unsafe('Entry hedef klasör dışına çıkıyor: $entry');

		return Safe(entry);
	}

	public static function scanEntries(entries:Array<ZipEntryInfo>, destinationRoot:String):ArchiveScanResult {
		if (entries == null)
			return Dangerous(["ZIP entry listesi null geldi."]);

		var reasons:Array<String> = [];

		for (entry in entries) {
			if (entry == null) {
				reasons.push("Null entry bulundu.");
				continue;
			}

			if (entry.isSymlink == true) {
				reasons.push('Symlink desteklenmiyor: ${entry.fileName}');
				continue;
			}

			switch (checkEntryPath(entry.fileName, destinationRoot)) {
				case Safe(_):
				case Unsafe(reason):
					reasons.push(reason);
			}
		}

		return reasons.length > 0 ? Dangerous(reasons) : Clean;
	}

	static function sanitizeEntryName(entryName:String):String {
		var result = StringTools.replace(entryName, "\\", "/");

		while (StringTools.startsWith(result, "./"))
			result = result.substr(2);

		while (result.indexOf("//") != -1)
			result = StringTools.replace(result, "//", "/");

		result = StringTools.trim(result);
		return result;
	}

	static function normalizePath(path:String):String {
		var normalized = Path.normalize(path);
		return StringTools.replace(normalized, "\\", "/");
	}

	static function normalizeDir(path:String):String {
		var normalized = normalizePath(path);

		if (!StringTools.endsWith(normalized, "/"))
			normalized += "/";

		return normalized;
	}
}

package backend.modpack;

/**
 * Tier tanımları ve yardımcıları: backend.modpack.ModpackTier
 * (ModpackId kaldırıldı — tier sistemi onun yerini aldı:
 *  lite / medium / further, eski id'ler otomatik eşlenir.)
 */

typedef ModpackManifestChecksum = {
	var algorithm:String;
	var value:String;
}

typedef ModpackManifestChangelogEntry = {
	var version:String;
	@:optional var date:String;
	@:optional var changes:Array<String>;
	@:optional var added:Array<String>;
	@:optional var removed:Array<String>;
	@:optional var updated:Array<String>;
}

typedef ModpackManifest = {
	var packId:String;
	var displayName:String;
	var version:String;
	var engineVersion:String;
	var modFolders:Array<String>;

	@:optional var author:String;
	@:optional var description:String;
	@:optional var totalFileCount:Int;
	@:optional var totalSizeBytes:Float;
	@:optional var minEngineVersion:String;
	@:optional var maxEngineVersion:String;
	@:optional var checksum:ModpackManifestChecksum;
	@:optional var changelog:Array<ModpackManifestChangelogEntry>;

	// ── Further Engine tier sistemi ──
	/** Tier kimliği: "lite", "medium", "further" (backend.modpack.ModpackTier). */
	@:optional var tier:String;
	/** Kurulum zamanı (Date.now().toString()). */
	@:optional var installedAt:String;
	/** Kurulumu yapan engine sürümü (UpdateConfig.CURRENT_ENGINE_VERSION). */
	@:optional var installedEngineVersion:String;
	/** Paketin indirildiği kaynak (katalog URL'si / MediaFire sayfası). */
	@:optional var sourceUrl:String;
	/** Kurulan mod klasörü sayısı (modFolders.length). */
	@:optional var modCount:Int;
	/** ZIP açılmış halinin tahmini boyutu (bayt). */
	@:optional var estimatedSizeBytes:Float;
}

enum ModpackInstallPhase {
	Validating;
	Extracting;
	Verifying;
	InstallingMods;
	Cleanup;
	Complete;
	Failed;
}

typedef ModpackInstallProgress = {
	var phase:ModpackInstallPhase;
	var phaseProgress:Float;
	var overallProgress:Float;
	var currentFile:String;
	var message:String;
}

typedef ModpackInstallCallbacks = {
	?onProgress:ModpackInstallProgress->Void,
	?onComplete:ModpackManifest->Void,
	?onError:String->Void,
	?onCancelled:Void->Void,
	?onWarning:String->Void
}
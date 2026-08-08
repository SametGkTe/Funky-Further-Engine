package backend.update;
import haxe.Http;
import haxe.Json;
import backend.modpack.ModpackTier;

typedef ModpackListData = {
    @:optional var lastUpdated:String;
    var modpacks:Array<RemoteModpackInfo>;
}

typedef ModpackUpdateInfo = {
    var remote:RemoteModpackInfo;
    var installedVersion:String;
    var newVersion:String;
}

typedef CheckResult = {
    var allModpacks:Array<RemoteModpackInfo>;
    var availableUpdates:Array<ModpackUpdateInfo>;
    var hasUpdates:Bool;
}

typedef RemoteModpackInfo = {
	var id:String;
	var displayName:String;
	var version:String;

	@:optional var versionLabel:String;
	@:optional var author:String;
	@:optional var description:String;
	@:optional var category:String;

	@:optional var downloadMode:String;
	@:optional var directDownloadUrl:String;
	@:optional var externalPageUrl:String;

	@:optional var fileSize:String;
	@:optional var fileSizeBytes:Float;
	@:optional var modCount:Int;

	@:optional var tier:String;
	@:optional var tierLabel:String;

	@:optional var thumbnail:String;
	@:optional var includes:Array<String>;
	@:optional var updatedAt:String;
	@:optional var downloads:Int;
	@:optional var mediafireUrl:String;
	@:optional var githubUrl:String;
}

class UpdateChecker {
    public var onError:Null<String->Void> = null;
    public var isChecking:Bool = false;
    public var lastResult:Null<CheckResult> = null;
    public var cachedModpacks:Null<Array<RemoteModpackInfo>> = null;

    public var hasPendingModpackUpdates:Bool = false;

    /** Mağaza güncellemeleri yapılınca rozetin bir daha çıkmaması için temizlenir. */
    public function clearModpackUpdates():Void
    {
        hasPendingModpackUpdates = false;
    }

    static var _instance:UpdateChecker;
    public static var instance(get, never):UpdateChecker;

    static function get_instance():UpdateChecker {
        if (_instance == null) _instance = new UpdateChecker();
        return _instance;
    }

    public function new() {}

    public function fetchModpackList(?callback:CheckResult->Void):Void {
        if (isChecking) return;
        isChecking = true;

        var url = UpdateConfig.MODPACK_JSON_URL;
        trace('[UpdateChecker] Modpack listesi çekiliyor: $url');

        var http = new Http(url);
        http.addHeader("User-Agent", "PsychEngineTR-Updater");

        http.onData = function(data:String) {
            isChecking = false;

            try {
                var parsed:ModpackListData = cast Json.parse(data);

                if (parsed.modpacks == null) {
                    if (onError != null)
                        onError("modpacks alanı bulunamadı.");
                    if (callback != null)
                        callback(emptyResult());
                    return;
                }

                cachedModpacks = parsed.modpacks;

                for (mp in parsed.modpacks) {
                    var tier:Null<ModpackTier> = ModpackTier.fromString(mp.tier != null ? mp.tier : mp.id);
                    if (tier != null) {
                        mp.tier = tier;
                        mp.tierLabel = tier.getLabel();
                    }
                }

                var updates = findUpdates(parsed.modpacks);

                var result:CheckResult = {
                    allModpacks: parsed.modpacks,
                    availableUpdates: updates,
                    hasUpdates: updates.length > 0
                };

                lastResult = result;

                trace('[UpdateChecker] ${parsed.modpacks.length} modpack bulundu, ${updates.length} güncelleme mevcut.');

                if (callback != null)
                    callback(result);

            } catch (e:Dynamic) {
                if (onError != null)
                    onError('JSON parse hatası: ${Std.string(e)}');
                if (callback != null)
                    callback(emptyResult());
            }
        };

        http.onError = function(error:String) {
            isChecking = false;

            if (onError != null)
                onError('Bağlantı hatası: $error');
            if (callback != null)
                callback(emptyResult());
        };

        http.request(false);
    }

	function findUpdates(remoteList:Array<RemoteModpackInfo>):Array<ModpackUpdateInfo> {
		var updates:Array<ModpackUpdateInfo> = [];

		for (remote in remoteList) {
			var installedVersion = getInstalledVersion(remote.id);

			if (UpdateConfig.DEBUG_FORCE_UPDATES) {
				// Debug: tüm modpackleri güncelleme olarak göster
				updates.push({
					remote: remote,
					installedVersion: installedVersion != null ? installedVersion : "0.0.0",
					newVersion: remote.version
				});
				trace('[UpdateChecker] DEBUG: Zorla güncelleme eklendi: ${remote.id}');
				continue;
			}

			if (installedVersion == null)
				continue;

			if (isRemoteNewer(installedVersion, remote.version)) {
				updates.push({
					remote: remote,
					installedVersion: installedVersion,
					newVersion: remote.version
				});
			}
		}

		return updates;
	}

    function getInstalledVersion(packId:String):Null<String> {
        var v = getInstalledVersionExact(packId);
        if (v != null) return v;

        for (legacyId in ModpackTier.legacyIdsFor(packId)) {
            v = getInstalledVersionExact(legacyId);
            if (v != null) return v;
        }

        return null;
    }

    function getInstalledVersionExact(packId:String):Null<String> {
        #if sys
        var manifestPath = backend.modpack.ModpackPaths.getInstalledManifestPath(packId);

        if (!sys.FileSystem.exists(manifestPath))
            return null;

        try {
            var raw = sys.io.File.getContent(manifestPath);
            var manifest:Dynamic = Json.parse(raw);
            return manifest.version;
        } catch (e:Dynamic) {
            return null;
        }
        #else
        return null;
        #end
    }

    function emptyResult():CheckResult {
        return {
            allModpacks: [],
            availableUpdates: [],
            hasUpdates: false
        };
    }

    public static function isRemoteNewer(current:String, remote:String):Bool {
        var c = parseVersion(current);
        var r = parseVersion(remote);

        var maxLen = c.length > r.length ? c.length : r.length;

        for (i in 0...maxLen) {
            var cv = i < c.length ? c[i] : 0;
            var rv = i < r.length ? r[i] : 0;
            if (rv > cv) return true;
            if (rv < cv) return false;
        }

        return false;
    }
	
	
	public function fetchStoreList(?callback:Array<RemoteModpackInfo>->Void):Void {
		fetchModpackList(function(result:CheckResult) {
			if (callback != null)
				callback(result.allModpacks);
		});
	}

    static function parseVersion(v:String):Array<Int> {
        if (v == null || v.length == 0)
            return [0, 0, 0];

        var cleaned = v;
        if (StringTools.startsWith(cleaned, "v"))
            cleaned = cleaned.substr(1);

        var dashIdx = cleaned.indexOf("-");
        if (dashIdx != -1)
            cleaned = cleaned.substr(0, dashIdx);

        var spaceIdx = cleaned.indexOf(" ");
        if (spaceIdx != -1)
            cleaned = cleaned.substr(0, spaceIdx);

        var parts = cleaned.split(".");
        var out:Array<Int> = [];

        for (p in parts) {
            var n = Std.parseInt(p);
            out.push(n == null ? 0 : n);
        }

        while (out.length < 3)
            out.push(0);

        return out;
    }
}

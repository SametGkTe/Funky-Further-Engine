package backend.modpack.zip;

import backend.modpack.zip.ZipTypes.ExtractCallbacks;
import backend.modpack.zip.ZipTypes.ExtractResult;
import backend.modpack.zip.ZipTypes.ZipEntryInfo;
import backend.modpack.zip.ZipTypes.ExtractError;

class UnsupportedZipExtractor implements IZipExtractor {
	var busy:Bool = false;
	var reason:String;

	public function new(?reason:String) {
		this.reason = (reason != null && reason.length > 0)
			? reason
			: "Bu platformda ZIP çıkarma henüz desteklenmiyor.";
	}

	public function getBackendName():String {
		return "unsupported";
	}

	public function extract(zipPath:String, destinationPath:String, callbacks:ExtractCallbacks):Void {
		busy = false;

		if (callbacks != null && callbacks.onError != null) {
			callbacks.onError(ExtractError.NotSupported(reason));
		}
	}

	public function listEntries(zipPath:String):ExtractResult<Array<ZipEntryInfo>> {
		return ExtractResult.Failure(ExtractError.NotSupported(reason));
	}

	public function cancel():Void {
		busy = false;
	}

	public function isExtracting():Bool {
		return busy;
	}

	public function isSupported():Bool {
		return false;
	}
}

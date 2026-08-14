package backend.modpack.zip;

import backend.modpack.zip.ZipTypes.ExtractCallbacks;
import backend.modpack.zip.ZipTypes.ExtractResult;
import backend.modpack.zip.ZipTypes.ZipEntryInfo;

interface IZipExtractor {
	function getBackendName():String;
	function extract(zipPath:String, destinationPath:String, callbacks:ExtractCallbacks):Void;
	function listEntries(zipPath:String):ExtractResult<Array<ZipEntryInfo>>;
	function cancel():Void;
	function isExtracting():Bool;
	function isSupported():Bool;
}

package backend.modpack.zip;

typedef ZipEntryInfo = {
	var fileName:String;
	var compressedSize:Float;
	var uncompressedSize:Float;
	var isDirectory:Bool;

	@:optional var crc32:String;
	@:optional var isSymlink:Bool;
}

typedef ExtractProgressInfo = {
	var currentEntries:Int;
	var totalEntries:Int;
	var currentFile:String;
	var processedBytes:Float;
	var totalBytes:Float;
}

typedef ExtractCompleteInfo = {
	var destination:String;
	var extractedEntries:Int;
	var extractedBytes:Float;
}

typedef ExtractCallbacks = {
	?onProgress:ExtractProgressInfo->Void,
	?onComplete:ExtractCompleteInfo->Void,
	?onError:ExtractError->Void,
	?onCancelled:Void->Void
}

enum ExtractError {
	FileNotFound(path:String);
	CorruptArchive(detail:String);
	DiskFull(requiredBytes:Float, availableBytes:Float);
	PermissionDenied(path:String);
	PathTraversal(entryName:String);
	UnsupportedFormat(detail:String);
	NotSupported(detail:String);
	CommandFailed(command:String, exitCode:Int, stderr:String);
	Cancelled;
	Unknown(message:String);
}

enum ExtractResult<T> {
	Success(data:T);
	Failure(error:ExtractError);
}

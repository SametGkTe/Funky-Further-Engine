package backend.modpack;

typedef StoreModpackEntry = {
	var id:String;
	var displayName:String;
	var version:String;
	var versionLabel:String;
	var downloadMode:String;
	var directDownloadUrl:String;
	var externalPageUrl:String;

	@:optional var author:String;
	@:optional var description:String;
	@:optional var category:String;
	@:optional var fileSize:String;
	@:optional var fileSizeBytes:Float;
	@:optional var modCount:Int;
	@:optional var thumbnail:String;
	@:optional var tags:Array<String>;
	@:optional var changelog:String;

	@:optional var tier:String;

	@:optional var tierLabel:String;
}

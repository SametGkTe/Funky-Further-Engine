package backend.freeplay;

class FreeplayEntry
{
	public var songName:String = '';
	public var weekIndex:Int = 0;
	public var weekFile:String = '';
	public var weekName:String = '';
	public var songCharacter:String = 'bf';
	public var color:Int = -7179779;
	public var folder:String = '';
	public var difficulties:Array<String> = [];
	public var modDisplayName:String = '';
	public var modpackId:String = '';
	public var modpackName:String = '';
	public var songPlayer:String = '';
	public var albumId:String = '';
	public var songRating:Int = 0;
	public var allowErect:Bool = false;
	public var startingBpm:Float = 0;

	public function new() {}

	public function toDynamic():Dynamic
	{
		return {
			songName: songName,
			weekIndex: weekIndex,
			weekFile: weekFile,
			weekName: weekName,
			songCharacter: songCharacter,
			color: color,
			folder: folder,
			difficulties: difficulties,
			modDisplayName: modDisplayName,
			modpackId: modpackId,
			modpackName: modpackName,
			songPlayer: songPlayer,
			albumId: albumId,
			songRating: songRating,
			allowErect: allowErect,
			startingBpm: startingBpm
		};
	}

	public static function fromDynamic(raw:Dynamic):FreeplayEntry
	{
		if (raw == null || raw.songName == null)
			return null;
		var e = new FreeplayEntry();
		e.songName = Std.string(raw.songName);
		e.weekIndex = raw.weekIndex != null ? Std.int(raw.weekIndex) : 0;
		e.weekFile = raw.weekFile != null ? Std.string(raw.weekFile) : '';
		e.weekName = raw.weekName != null ? Std.string(raw.weekName) : '';
		e.songCharacter = raw.songCharacter != null ? Std.string(raw.songCharacter) : 'bf';
		e.color = raw.color != null ? Std.int(raw.color) : -7179779;
		e.folder = raw.folder != null ? Std.string(raw.folder) : '';
		if (raw.difficulties != null)
		{
			try e.difficulties = cast raw.difficulties catch (err:Dynamic) e.difficulties = [];
		}
		e.modDisplayName = raw.modDisplayName != null ? Std.string(raw.modDisplayName) : '';
		e.modpackId = raw.modpackId != null ? Std.string(raw.modpackId) : '';
		e.modpackName = raw.modpackName != null ? Std.string(raw.modpackName) : '';
		e.songPlayer = raw.songPlayer != null ? Std.string(raw.songPlayer) : '';
		e.albumId = raw.albumId != null ? Std.string(raw.albumId) : '';
		e.songRating = raw.songRating != null ? Std.int(raw.songRating) : 0;
		e.allowErect = raw.allowErect == true;
		e.startingBpm = raw.startingBpm != null ? Std.parseFloat(Std.string(raw.startingBpm)) : 0;
		if (Math.isNaN(e.startingBpm))
			e.startingBpm = 0;
		return e;
	}
}

package backend;

import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import haxe.Json;

typedef WeekFile =
{
	// JSON variables
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
}

class WeekData {
	public static var weeksLoaded:Map<String, WeekData> = new Map<String, WeekData>();
	public static var weeksList:Array<String> = [];
	public var folder:String = '';

	// JSON variables
	public var songs:Array<Dynamic>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:String;

	public var fileName:String;

	public static function createWeekFile():WeekFile {
		var weekFile:WeekFile = {
			songs: [["Bopeebo", "face", [146, 113, 253]], ["Fresh", "face", [146, 113, 253]], ["Dad Battle", "face", [146, 113, 253]]],
			#if BASE_GAME_FILES
			weekCharacters: ['dad', 'bf', 'gf'],
			#else
			weekCharacters: ['bf', 'bf', 'gf'],
			#end
			weekBackground: 'stage',
			weekBefore: 'tutorial',
			storyName: 'Your New Week',
			weekName: 'Custom Week',
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: false,
			hideFreeplay: false,
			difficulties: ''
		};
		return weekFile;
	}

	// HELP: Is there any way to convert a WeekFile to WeekData without having to put all variables there manually? I'm kind of a noob in haxe lmao
	public function new(weekFile:WeekFile, fileName:String) {
		// here ya go - MiguelItsOut
		for (field in Reflect.fields(weekFile))
			if(Reflect.fields(this).contains(field)) // Reflect.hasField() won't fucking work :/
				Reflect.setProperty(this, field, Reflect.getProperty(weekFile, field));

		this.fileName = fileName;
	}

	public static function reloadWeekFiles(isStoryMode:Null<Bool> = false)
	{
		weeksList = [];
		weeksLoaded.clear();
		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods(), Paths.getSharedPath()];
		var originalLength:Int = directories.length;

		for (mod in Mods.parseList().enabled)
			directories.push(Paths.mods(mod + '/'));
		#else
		var directories:Array<String> = [Paths.getSharedPath()];
		var originalLength:Int = directories.length;
		#end

		var sexList:Array<String> = CoolUtil.coolTextFile(Paths.getSharedPath('weeks/weekList.txt'));
		for (i in 0...sexList.length) {
			for (j in 0...directories.length) {
				var fileToCheck:String = directories[j] + 'weeks/' + sexList[i] + '.json';
				if(!weeksLoaded.exists(sexList[i])) {
					var week:WeekFile = getWeekFile(fileToCheck);
					if(week != null) {
						var weekFile:WeekData = new WeekData(week, sexList[i]);

						#if MODS_ALLOWED
						if(j >= originalLength) {
							weekFile.folder = directories[j].substring(Paths.mods().length, directories[j].length-1);
						}
						#end

						if(weekFile != null && (isStoryMode == null || (isStoryMode && !weekFile.hideStoryMode) || (!isStoryMode && !weekFile.hideFreeplay))) {
							weeksLoaded.set(sexList[i], weekFile);
							weeksList.push(sexList[i]);
						}
					}
				}
			}
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i] + 'weeks/';
			if(FileSystem.exists(directory)) {
				var listOfWeeks:Array<String> = CoolUtil.coolTextFile(directory + 'weekList.txt');
				for (daWeek in listOfWeeks)
				{
					var path:String = directory + daWeek + '.json';
					if(FileSystem.exists(path))
					{
						addWeek(daWeek, path, directories[i], i, originalLength);
					}
				}

				for (file in Paths.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						addWeek(file.substr(0, file.length - 5), path, directories[i], i, originalLength);
					}
				}
			}

			// V-SLICE KÖPRÜSÜ: Psych 'weeks/' yoksa, V-Slice modunun
			// 'data/levels/<level>.json' dosyalarını Psych week'e çevir.
			if (!FileSystem.exists(directory)) {
				var vdir:String = directories[i] + 'data/levels/';
				if (FileSystem.exists(vdir)) {
					for (file in Paths.readDirectory(vdir)) {
						if (file.endsWith('.json')) {
							var levelName:String = file.substr(0, file.length - 5);
							addVSliceWeek(levelName, vdir + file, directories[i], i, originalLength);
						}
					}
				}
			}
		}
		// CODENAME ENGINE KÖPRÜSÜ: CNE hafta XML'lerini ve haftasız CNE şarkılarını
		// week sistemine ekle. Modül döngüsünü kırmak için reflection ile çağrılır
		// (WeekData, cne.compatibility paketini derleme zamanında import etmez).
		try
		{
			var cneWeeks:Class<Dynamic> = cast Type.resolveClass('cne.compatibility.CNEWeekConverter');
			if (cneWeeks != null)
			{
				var fnAdd:Dynamic = Reflect.field(cneWeeks, 'addAllFromMods');
				if (fnAdd != null) Reflect.callMethod(cneWeeks, fnAdd, []);
			}
			else trace('[WeekData][CNE] CNEWeekConverter sınıfı bulunamadı — Project.xml include makrosu eksik olabilir!');

			// V-SLICE KÖPRÜSÜ: level'ı olmayan V-Slice şarkı modları için sentetik hafta.
			var vsliceLoose:Class<Dynamic> = cast Type.resolveClass('vslice.compatibility.VSliceLooseSongs');
			if (vsliceLoose != null)
			{
				var fnLoose:Dynamic = Reflect.field(vsliceLoose, 'addAllFromMods');
				if (fnLoose != null) Reflect.callMethod(vsliceLoose, fnLoose, []);
			}
		}
		catch (e:Dynamic)
		{
			trace('[WeekData] CNE hafta taraması hatası: $e');
		}
		#end
	}

	/** V-Slice 'data/levels/<level>.json' dosyasını okuyup Psych week olarak ekler. */
	private static function addVSliceWeek(levelName:String, path:String, directory:String, i:Int, originalLength:Int)
	{
		if (weeksLoaded.exists(levelName)) return;
		try {
			var raw:String = File.getContent(path);
			var lvl:Dynamic = Json.parse(raw);
			if (lvl == null || lvl.songs == null) return;
			var rawSongs:Array<Dynamic> = cast lvl.songs;
			var psychSongs:Array<Dynamic> = [];
			for (s in rawSongs) {
				if (s == null) continue;
				var songName:String = Std.isOfType(s, String) ? Std.string(s) : (Reflect.hasField(s, 'name') ? Std.string(s.name) : '');
				if (songName.length < 1) continue;
				psychSongs.push([songName, extractPlayerIcon(directory, songName), [146, 113, 253]]); // Fucking Fix
			}
			if (psychSongs.length < 1) return;

			var week:WeekFile = {
				songs: psychSongs,
				weekCharacters: ["dad", "bf", "gf"],
				weekBackground: "stage",
				weekBefore: "week1",
				storyName: (lvl.name != null) ? Std.string(lvl.name) : levelName,
				weekName: (lvl.name != null) ? Std.string(lvl.name) : levelName,
				startUnlocked: true,
				hiddenUntilUnlocked: false,
				hideStoryMode: false,
				hideFreeplay: false,
				difficulties: ""
			};
			var weekFile:WeekData = new WeekData(week, levelName);
			if (i >= originalLength) {
				#if MODS_ALLOWED
				weekFile.folder = directory.substring(Paths.mods().length, directory.length - 1);
				#end
			}
			if (!PlayState.isStoryMode || !weekFile.hideStoryMode) {
				weeksLoaded.set(levelName, weekFile);
				weeksList.push(levelName);
			}
		} catch (e:Dynamic) {
			trace('[WeekData] V-Slice week okunamadı ($levelName): $e');
		}
	}

	/** V-Slice metadata'dan player karakter ikon adını çeker (yoksa şarkı adı). */
	private static function extractPlayerIcon(directory:String, songName:String):String
	{
		var sp:String = Paths.formatToSongPath(songName);
		var metaPath:String = directory + 'data/songs/$sp/${sp}-metadata.json';
		try {
			if (FileSystem.exists(metaPath)) {
				var meta:Dynamic = Json.parse(File.getContent(metaPath));
				var chars:Dynamic = meta != null && Reflect.hasField(meta, 'playData') ? Reflect.field(meta.playData, 'characters') : null;
				var p:Dynamic = chars != null ? Reflect.field(chars, 'player') : null;
				if (p != null && Std.string(p) != 'null' && Std.string(p).length > 0) return Std.string(p);
			}
		} catch (e:Dynamic) {}
		return songName;
	}

	private static function addWeek(weekToCheck:String, path:String, directory:String, i:Int, originalLength:Int)
	{
		if(!weeksLoaded.exists(weekToCheck))
		{
			var week:WeekFile = getWeekFile(path);
			if(week != null)
			{
				var weekFile:WeekData = new WeekData(week, weekToCheck);
				if(i >= originalLength)
				{
					#if MODS_ALLOWED
					weekFile.folder = directory.substring(Paths.mods().length, directory.length-1);
					#end
				}
				if((PlayState.isStoryMode && !weekFile.hideStoryMode) || (!PlayState.isStoryMode && !weekFile.hideFreeplay))
				{
					weeksLoaded.set(weekToCheck, weekFile);
					weeksList.push(weekToCheck);
				}
			}
		}
	}

	private static function getWeekFile(path:String):WeekFile {
		var rawJson:String = null;
		#if MODS_ALLOWED
		if(FileSystem.exists(path)) {
			rawJson = File.getContent(path);
		}
		#else
		if(OpenFlAssets.exists(path)) {
			rawJson = Assets.getText(path);
		}
		#end

		if(rawJson != null && rawJson.length > 0) {
			return cast tjson.TJSON.parse(rawJson);
		}
		return null;
	}

	//   FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE

	//To use on PlayState.hx or Highscore stuff
	public static function getWeekFileName():String {
		return weeksList[PlayState.storyWeek];
	}

	//Used on LoadingState, nothing really too relevant
	public static function getCurrentWeek():WeekData {
		return weeksLoaded.get(weeksList[PlayState.storyWeek]);
	}

	public static function setDirectoryFromWeek(?data:WeekData = null) {
		Mods.currentModDirectory = '';
		if(data != null && data.folder != null && data.folder.length > 0) {
			Mods.currentModDirectory = data.folder;
		}
	}
}
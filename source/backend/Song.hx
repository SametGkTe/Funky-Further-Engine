package backend;

import haxe.Json;
import lime.utils.Assets;

import objects.Note;
import vslice.compatibility.VSliceSongConverter;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psych_v1';

	public static function convert(songJson:Dynamic) // Convert old charts to psych_v1 format
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		var sectionsData:Array<SwagSection> = songJson.notes;
		if(sectionsData == null) return;

		for (section in sectionsData)
		{
			var beats:Null<Float> = cast section.sectionBeats;
			if (beats == null || Math.isNaN(beats))
			{
				section.sectionBeats = 4;
				if(Reflect.hasField(section, 'lengthInSteps')) Reflect.deleteField(section, 'lengthInSteps');
			}

			for (note in section.sectionNotes)
			{
				var gottaHitNote:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);

				if(!Std.isOfType(note[3], String))
					note[3] = Note.defaultNoteTypes[note[3]]; //compatibility with Week 7 and 0.1-0.3 psych charts
			}
		}
	}

	public static var chartPath:String;
	public static var loadedSongName:String;

	/**
	 * Legacy data/<song>/events.json yalnızca event kabıdır; tam SwagSong gibi
	 * psych_v1 converter'a sokulması bazı modlarda eksik notes alanına erişiyordu.
	 */
	public static function getExternalEvents(folder:String):Array<Dynamic>
	{
		var formattedFolder = Paths.formatToSongPath(folder);
		var path = Paths.json('$formattedFolder/events');
		var raw:String = null;
		#if MODS_ALLOWED
		if (FileSystem.exists(path)) raw = File.getContent(path);
		else
		#end
		try raw = Assets.getText(path) catch (e:Dynamic) {}
		if (raw == null || StringTools.trim(raw) == '') return [];
		try
		{
			var parsed:Dynamic = Json.parse(raw);
			if (parsed != null && Reflect.hasField(parsed, 'song'))
			{
				var sub = Reflect.field(parsed, 'song');
				if (sub != null && Type.typeof(sub) == TObject) parsed = sub;
			}
			var events:Dynamic = parsed != null ? Reflect.field(parsed, 'events') : null;
			return Std.isOfType(events, Array) ? cast events : [];
		}
		catch (e:Dynamic)
		{
			trace('[Song] events.json okunamadı: $path | $e');
			return [];
		}
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		PlayState.SONG = getChart(jsonInput, folder);
		loadedSongName = folder;
		chartPath = _lastPath;
		#if windows
		// prevent any saving errors by fixing the path on Windows (being the only OS to ever use backslashes instead of forward slashes for paths)
		chartPath = chartPath.replace('/', '\\');
		#end
		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}

	static var _lastPath:String;
	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		var rawData:String = null;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		_lastPath = Paths.json('$formattedFolder/$formattedSong');

		#if MODS_ALLOWED
		if(FileSystem.exists(_lastPath))
			rawData = File.getContent(_lastPath);
		else
		#end
		{
			// Assets.getText dosya yoksa exception fırlatabilir; null döndür.
			try rawData = Assets.getText(_lastPath) catch(e:Dynamic) rawData = null;
		}

		// ---------- V-SLICE KÖPRÜSÜ ----------
		// Psych chart yoksa, V-Slice mod path'ini dene (mods/<mod>/data/songs/<song>/<song>-chart.json)
		if (rawData == null)
		{
			var vsliceSong:String = tryVSlicelside(folder, jsonInput);
			if (vsliceSong != null)
			{
				rawData = vsliceSong;
				_lastPath = Paths.formatToSongPath(folder) + '/' + Paths.formatToSongPath(jsonInput);
			}
		}

			if (rawData != null)
			{
				try
				{
					var parsed:SwagSong = parseJSON(rawData, jsonInput);
					if (parsed != null) return parsed;
				}
				catch(e:Dynamic)
				{
					trace('[Song] CHART PARSE HATASI');
					trace('[Song] Mod: ${Mods.currentModDirectory}');
					trace('[Song] Chart: $jsonInput | Yol: $_lastPath');
					trace('[Song] Hata: ${Std.string(e)}');
					trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack(true)));
				}
			}
			// Boş ama geçerli bir chart döndür (çökme yerine boş şarkı).
			return emptySong(formattedSong);
	}

	/** Boş ama geçerli bir chart üretir (bozuk/null chart'larda crash önler). */
	static function emptySong(name:String):SwagSong
	{
		return {
			song: name,
			notes: [],
			events: [],
			bpm: 120,
			needsVoices: false,
			speed: 1,
			offset: 0,
			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',
			stage: 'stage',
			format: 'psych_v1'
		};
	}

	/** Boş ama geçerli bir section üretir (null section'ları değiştirmek için). */
	static function emptySection():Dynamic
	{
		return {
			sectionNotes: [],
			sectionBeats: 4,
			mustHitSection: true,
			altAnim: false,
			bpm: 120,
			changeBPM: false
		};
	}

	/** V-Slice şarkı dosyasını arar ve JSON string olarak döndürür (bulunamazsa null). */
	static function tryVSlicelside(folder:String, song:String):String
	{
		#if (MODS_ALLOWED && sys)

		// Gerçek V-Slice şarkı adı: `folder` parametresi (ChartingState cur) ya da
		// `song`'dan diff suffixi atılmış hali. Örn. folder='foolhardy-2023',
		// song='foolhardy-2023-hard' -> doğru ad folder'dır.
		var songPath:String = Paths.formatToSongPath(folder != null && folder.length > 0 ? folder : stripDifficulty(song));

		// Aranacak modlar: aktif mod + global modlar (+ aktif yoksa tüm modlar)
		var searchDirs:Array<String> = [];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			searchDirs.push(Mods.currentModDirectory);
		for (g in Mods.getGlobalMods())
			if (!searchDirs.contains(g)) searchDirs.push(g);
		if (searchDirs.length == 0)
			searchDirs = Mods.getModDirectories();

		for (m in searchDirs)
		{
			// Paths.mods() Android'de dış depolama kökünü verir (relative 'mods/' değil!)
			var base:String = Paths.mods(m + '/data/songs/$songPath/');
			var chart:String = base + songPath + '-chart.json';
			if (FileSystem.exists(chart))
			{
				var meta:String = base + songPath + '-metadata.json';
				var metaContent:String = FileSystem.exists(meta) ? File.getContent(meta) : null;
				var chartContent:String = File.getContent(chart);
				var metaJson:Dynamic = (metaContent != null && metaContent.length > 0) ? try Json.parse(metaContent) catch(e:Dynamic) null : null;

				// V-Slice chart'ı Psych formatına çevir
				var chartJson:Dynamic = try Json.parse(chartContent) catch(e:Dynamic) null;
				if (chartJson != null && VSliceSongConverter.isVSliceChart(chartJson))
				{
					var converted:backend.Song.SwagSong = VSliceSongConverter.convert(chartJson, metaJson, getDifficulty(), songPath);
					return Json.stringify(converted);
				}
				else if (chartJson != null)
				{
					// Zaten Psych formatında bir chart (Psych Engine Port modu).
					// 'format' alanı yoksa 'unknown' olur ve parseJSON onu convert edip bozar.
					// Bu yüzden 'psych_v1' olarak işaretle ki convert uygulanmasın.
					if (!Reflect.hasField(chartJson, 'format') || chartJson.format == null)
						chartJson.format = 'psych_v1';
					// Section null'ları temizle (bozuk chart'larda crash önler)
					var notesArr:Array<Dynamic> = cast chartJson.notes;
					if (notesArr != null)
						for (i in 0...notesArr.length)
							if (notesArr[i] == null) notesArr[i] = emptySection();
					return Json.stringify(chartJson);
				}
			}
		}
		#end
		return null;
	}

	/** Şarkı adından bilinen Psych difficulty suffixini atar. */
	static function stripDifficulty(name:String):String
	{
		var suffixes:Array<String> = ['-easy', '-normal', '-hard', '-erect', '-nightmare'];
		for (difficulty in backend.Difficulty.list)
		{
			var suffix = '-' + Paths.formatToSongPath(difficulty);
			if (!suffixes.contains(suffix)) suffixes.push(suffix);
		}
		// En uzun suffix önce; benzer isimlerde kısa olan erken eşleşmesin.
		suffixes.sort(function(a, b) return b.length - a.length);
		for (s in suffixes)
			if (name.endsWith(s)) return name.substr(0, name.length - s.length);
		return name;
	}

	/** Aktif zorluğu döndürür (PlayState kurulmadan önce Difficulty sabitinden). */
	static function getDifficulty():String
	{
		// Difficulty.getString() 'Normal' gibi büyük harfle başlayabilir;
		// V-Slice notes map anahtarları küçük harf (easy/normal/hard) bekler.
		return backend.Difficulty.getString().toLowerCase();
	}

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);
		if(Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if(convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if(fmt == null) fmt = songJson.format = 'unknown';

			switch(convertTo)
			{
				case 'psych_v1':
					// V-SLICE KÖPRÜSÜ: zaten V-Slice'ten Psych'e çevrilmiş chart'ı
					// tekrar Psych dönüşümüne sokma (bozulur).
					if (fmt == vslice.compatibility.VSliceSongConverter.FORMAT)
						return songJson;

					if(!fmt.startsWith('psych_v1')) //Convert to Psych 1.0 format
					{
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						songJson.format = 'psych_v1_convert';
						convert(songJson);
					}
			}
		}
		return songJson;
	}
}

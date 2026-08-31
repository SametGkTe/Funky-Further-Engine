package cne.compatibility;

import backend.Mods;
import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

// CNE Chart Converter

class CNESongConverter
{
	public static var lastConvertedPath:String = '';

	static final SKIP_EVENTS:Array<String> = ['camera movement', 'alt animation toggle', 'hscript call', 'unknown'];

	public static function convertFromMods(folder:String, difficulty:String):Dynamic
	{
		#if (MODS_ALLOWED && sys)
		for (mod in CNECompat.modSearchOrder())
		{
			if (CNECompat.cneRoot(mod) == null) continue;
			var chartPath:String = CNECompat.findChartFile(mod, folder, difficulty);
			if (chartPath == null) continue;
			var song:Dynamic = convert(mod, folder, difficulty, chartPath);
			if (song != null)
			{
				Mods.currentModDirectory = mod;
				return song;
			}
		}
		#end
		return null;
	}

	public static function convert(mod:String, songName:String, difficulty:String, chartPath:String):Dynamic
	{
		#if (MODS_ALLOWED && sys)
		try
		{
			var chart:Dynamic = Json.parse(File.getContent(chartPath));
			if (chart == null || chart.codenameChart != true) return null;

			var meta:Dynamic = CNECompat.getSongMeta(mod, songName);
			if (chart.meta != null)
			{
				if (meta == null) meta = {};
				for (f in Reflect.fields(chart.meta))
					Reflect.setField(meta, f, Reflect.field(chart.meta, f));
			}

			// CNE ayrı bir global event dosyası da kullanabilir: songs/<song>/events.json
			var extraEvents:Array<Dynamic> = null;
			var songFolder:String = CNECompat.songDir(mod, songName);
			if (songFolder != null && FileSystem.exists(songFolder + '/events.json'))
			{
				try
				{
					var evFile:Dynamic = Json.parse(File.getContent(songFolder + '/events.json'));
					if (evFile != null && evFile.events != null)
						extraEvents = evFile.events;
				}
				catch (e:Dynamic) {}
			}

			var song:Dynamic = convertParsed(chart, songName, meta, extraEvents);
			if (song != null)
				lastConvertedPath = chartPath;
			return song;
		}
		catch (e:Dynamic)
		{
			trace('[CNESong] "$songName" chart çevrilemedi ($chartPath): $e');
			return null;
		}
		#else
		return null;
		#end
	}

	public static function convertRaw(rawJson:Dynamic, ?suggestedName:String):Dynamic
	{
		if (rawJson == null) return null;
		var isCNE:Bool = false;
		try isCNE = (rawJson.codenameChart == true) catch (e:Dynamic) isCNE = false;
		if (!isCNE) return null;

		var songName:String = null;
		if (suggestedName != null)
		{
			var clean:String = suggestedName;
			var i:Int = clean.lastIndexOf('/');
			if (i >= 0) clean = clean.substr(i + 1);
			if (StringTools.endsWith(clean.toLowerCase(), '.json'))
				clean = clean.substr(0, clean.length - 5);
			if (StringTools.trim(clean).length > 0) songName = clean;
		}

		var meta:Dynamic = rawJson.meta;
		if (songName == null && meta != null && Reflect.hasField(meta, 'name') && meta.name != null)
			songName = Std.string(meta.name);
		if (songName == null) songName = 'unknown';

		return convertParsed(rawJson, songName, meta, null);
	}

	/** Saf dönüşüm çekirdeği: parse edilmiş chart + meta → Psych SwagSong. */
	public static function convertParsed(chart:Dynamic, songName:String, meta:Dynamic, extraEvents:Array<Dynamic>):Dynamic
	{
		try
		{
			if (chart == null) return null;

			var bpm:Float = getFloatField(meta, 'bpm', 100);
			var beatsPerMeasure:Float = getFloatField(meta, 'beatsPerMeasure', 4);
			if (bpm <= 0) bpm = 100;
			if (beatsPerMeasure <= 0) beatsPerMeasure = 4;

			var strumLines:Array<Dynamic> = (chart.strumLines != null) ? chart.strumLines : [];

			// Characters
			var player1:String = 'bf';
			var player2:String = 'dad';
			var gfVersion:String = 'gf';
			var p1Set:Bool = false;
			var p2Set:Bool = false;
			var gfSet:Bool = false;
			for (sl in strumLines)
			{
				if (sl == null) continue;
				var type:Int = (sl.type != null) ? Std.int(sl.type) : 0;
				var chars:Array<Dynamic> = (sl.characters != null) ? sl.characters : [];
				var firstChar:String = (chars.length > 0 && chars[0] != null) ? Std.string(chars[0]) : null;
				var pos:String = (sl.position != null) ? Std.string(sl.position).toLowerCase() : '';
				if (pos == 'girlfriend' && !gfSet && firstChar != null)
				{
					gfVersion = firstChar;
					gfSet = true;
				}
				if (firstChar == null) continue;
				if (type == 0 && !p2Set)
				{
					player2 = firstChar;
					p2Set = true;
				}
				else if (type == 1 && !p1Set)
				{
					player1 = firstChar;
					p1Set = true;
				}
			}

			var speed:Float = 1;
			if (chart.scrollSpeed != null)
			{
				if (Std.isOfType(chart.scrollSpeed, Float) || Std.isOfType(chart.scrollSpeed, Int))
					speed = chart.scrollSpeed;
				else
				{
					var sp:Dynamic = chart.scrollSpeed;
					var v:Dynamic = Reflect.field(sp, 'default');
					if (v == null)
					{
						var fields:Array<String> = Reflect.fields(sp);
						if (fields.length > 0) v = Reflect.field(sp, fields[0]);
					}
					if (v != null) speed = v;
				}
			}
			if (speed <= 0) speed = 1;

			var bpmChanges:Array<{time:Float, bpm:Float}> = [];
			var psychEvents:Array<Dynamic> = [];
			var rawEvents:Array<Dynamic> = (chart.events != null) ? chart.events : [];
			if (extraEvents != null)
				rawEvents = rawEvents.concat(extraEvents);

			for (ev in rawEvents)
			{
				if (ev == null) continue;
				var name:String = (ev.name != null) ? Std.string(ev.name) : '';
				var time:Float = (ev.time != null) ? ev.time : 0;
				var params:Array<Dynamic> = (ev.params != null) ? ev.params : [];
				if (name == 'BPM Change')
				{
					var nb:Null<Float> = (params.length > 0 && params[0] != null) ? params[0] : null;
					if (nb != null && nb > 0) bpmChanges.push({time: time, bpm: nb});
					continue;
				}
				if (SKIP_EVENTS.contains(name.toLowerCase())) continue;
				var v1:Dynamic = params.length > 0 ? params[0] : '';
				var v2:Dynamic = params.length > 1 ? params[1] : '';
				var evArr:Array<Dynamic> = [time, [[name, v1, v2]]];
				psychEvents.push(evArr);
			}
			bpmChanges.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

			var noteTypes:Array<String> = (chart.noteTypes != null) ? chart.noteTypes : [];
			var allNotes:Array<{time:Float, lane:Int, sLen:Float, type:Int, player:Bool}> = [];
			var lastTime:Float = 0;
			var maxPlayerId:Int = -1;
			for (sl in strumLines)
			{
				if (sl == null) continue;
				var type:Int = (sl.type != null) ? Std.int(sl.type) : 0;
				var isPlayer:Bool = type == 1;
				var notes:Array<Dynamic> = (sl.notes != null) ? sl.notes : [];
				for (n in notes)
				{
					if (n == null) continue;
					var t:Float = (n.time != null) ? n.time : 0;
					var id:Int = (n.id != null) ? Std.int(n.id) : 0;
					if (id < 0) continue;
					// Oyuncu: id 0-3 → lane 0-3; id 4-7 → lane 8-11 (mania ekstra tuşları)
					// Rakip: yalnızca id 0-3 → lane 4-7 (4K üstü rakip desteklenmez)
					var lane:Int = -1;
					if (isPlayer)
					{
						lane = (id < 4) ? id : 8 + (id - 4);
						if (lane > 11) continue;
						if (id > maxPlayerId) maxPlayerId = id;
					}
					else
					{
						if (id > 3) continue;
						lane = id + 4;
					}
					var sLen:Float = (n.sLen != null) ? n.sLen : 0;
					var nType:Int = (n.type != null) ? Std.int(n.type) : 0;
					allNotes.push({time: t, lane: lane, sLen: sLen, type: nType, player: isPlayer});
					if (t + sLen > lastTime) lastTime = t + sLen;
				}
			}
			allNotes.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

			var sections:Array<Dynamic> = [];

			// [t0, t1) aralığını b BPM'inde beatsPerMeasure'lik bölümlere böler.
			// pendingChange true ise ilk bölüm changeBPM/bpm alır. Bölüm
			// üretilemediyse pendingChange olduğu gibi geri döner.
			function buildRegion(t0:Float, t1:Float, b:Float, pendingChange:Bool):Bool
			{
				var beatMs:Float = 60000 / b;
				var len:Float = beatMs * beatsPerMeasure;
				var t:Float = t0;
				while (t < t1 - 0.001)
				{
					var secEnd:Float = Math.min(t + len, t1);
					var sec:Dynamic = {
						sectionNotes: [],
						sectionBeats: (secEnd - t) / beatMs,
						mustHitSection: false
					};
					if (pendingChange)
					{
						sec.changeBPM = true;
						sec.bpm = b;
						pendingChange = false;
					}
					sections.push(sec);
					t = secEnd;
				}
				return pendingChange;
			}

			var pendingChange:Bool = false;
			var point:Float = 0;
			var curBpm:Float = bpm;
			for (ch in bpmChanges)
			{
				if (ch.time > point)
				{
					pendingChange = buildRegion(point, ch.time, curBpm, pendingChange);
					point = ch.time;
				}
				curBpm = ch.bpm;
				pendingChange = true;
			}
			var endMs:Float = Math.max(lastTime + (60000 / curBpm) * beatsPerMeasure, point + 1);
			buildRegion(point, endMs, curBpm, pendingChange);

			if (sections.length < 1)
			{
				sections.push({
					sectionNotes: [],
					sectionBeats: beatsPerMeasure,
					mustHitSection: false
				});
			}

			var starts:Array<Float> = [];
			var acc:Float = 0;
			for (sec in sections)
			{
				starts.push(acc);
				var secBpm:Float = (sec.bpm != null) ? sec.bpm : bpm;
				acc += sec.sectionBeats * (60000 / secBpm);
			}

			var si:Int = 0;
			for (n in allNotes)
			{
				while (si < sections.length - 1 && n.time >= starts[si + 1])
					si++;
				var sec:Dynamic = sections[si];
				var typeName:String = '';
				if (n.type > 0 && n.type - 1 < noteTypes.length && noteTypes[n.type - 1] != null)
					typeName = Std.string(noteTypes[n.type - 1]);
				var noteArr:Array<Dynamic> = [n.time, n.lane, n.sLen, typeName];
				sec.sectionNotes.push(noteArr);
				if (n.player) sec.mustHitSection = true;
			}

			// Vokal
			var needsVoices:Bool = true;
			if (meta != null && Reflect.hasField(meta, 'needsVoices') && Reflect.field(meta, 'needsVoices') != null)
				needsVoices = Reflect.field(meta, 'needsVoices') == true;
			#if (MODS_ALLOWED && sys)
			else
				needsVoices = CNECompat.findSongAudioInMod(Mods.currentModDirectory, songName, 'Voices') != null
					|| CNECompat.findSongAudio(songName, 'Voices') != null;
			#end

			var stageName:String = (chart.stage != null && Std.string(chart.stage).length > 0) ? Std.string(chart.stage) : 'stage';

			// CNE mania chart: oyuncu strumline'ında 4K üstü id varsa şarkı mania değerini bildirir
			// (PlayState bu değeri görünce Mania Modu otomatik devreye girer)
			var mania:Null<Int> = null;
			if (maxPlayerId >= 4) mania = Std.int(Math.min(9, maxPlayerId + 1));

			return {
				song: songName,
				notes: sections,
				events: psychEvents,
				bpm: bpm,
				needsVoices: needsVoices,
				speed: speed,
				offset: 0,
				player1: player1,
				player2: player2,
				gfVersion: gfVersion,
				stage: stageName,
				format: 'psych_v1',
				mania: mania
			};
		}
		catch (e:Dynamic)
		{
			trace('[CNESong] Chart çevrilemedi: $e');
			return null;
		}
	}

	// Event Convert
	public static function convertEventsList(rawEvents:Array<Dynamic>):Array<Dynamic>
	{
		var out:Array<Dynamic> = [];
		if (rawEvents == null) return out;
		for (ev in rawEvents)
		{
			if (ev == null) continue;
			var name:String = (ev.name != null) ? Std.string(ev.name) : '';
			var time:Float = (ev.time != null) ? ev.time : 0;
			var params:Array<Dynamic> = (ev.params != null) ? ev.params : [];
			if (name == 'BPM Change' || SKIP_EVENTS.contains(name.toLowerCase())) continue;
			var v1:Dynamic = params.length > 0 ? params[0] : '';
			var v2:Dynamic = params.length > 1 ? params[1] : '';
			var arr:Array<Dynamic> = [time, [[name, v1, v2]]];
			out.push(arr);
		}
		return out;
	}

	static function getFloatField(obj:Dynamic, field:String, def:Float):Float
	{
		if (obj == null || !Reflect.hasField(obj, field)) return def;
		var v:Dynamic = Reflect.field(obj, field);
		if (v == null) return def;
		var f:Float = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? def : f;
	}
}

package vslice.compatibility;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
import haxe.Json;
import backend.Song;

/**
 * VSliceSongConverter — V-Slice (FunkinCrew/Funkin 0.8) şarkı chart'larını
 * runtime'da Psych (Further-Engine) formatına çevirir.
 *
 * NEDEN BU KATMAN?
 * ----------------
 * V-Slice şarkı modları, Psych'in beklediğinden farklı bir format ve klasör
 * yapısı kullanır. Bunları PlayState'e dokunmadan çözmek için `Song` yükleme
 * katmanına köprü kurarız (PlayState zaten `Song.loadFromJson` üzerinden SONG
 * alır). Böylece Psych modları tamamen aynı kalır, V-Slice şarkı modları da
 * aynı `Song` akışından geçip otomatik çevrilir.
 *
 * FORMAT FARKLARI (V-Slice -> Psych):
 *   - Chart:  `data/songs/<song>/<song>-chart.json`
 *   - Metadata:`data/songs/<song>/<song>-metadata.json`
 *   - Audio:  `songs/<Song>/Inst.ogg` , `Voices-Bf.ogg`, `Voices-Zardy.ogg`
 *   - Nota:   {t: strumTime_ms, d: data(0-3 player, 4-7 opponent), l: sustain_ms, k: tip}
 *   - Psych:  [strumTime, notaNo(0-3 veya +4), sustain, tip], sections ayrıştırılır
 *   - BPM:    metadata.timeChanges[{t, bpm}] -> Psych song.bpm + section bpm
 *   - speed:  chart.scrollSpeed[diff]
 *
 * DESTEK SINIRI:
 *   - class-tabanlı .hxc scriptler (ScriptedStage, ScriptedCharacter) burada
 *     çalışmaz; şarkı temel sahneyle oynanır.
 *   - note kind'leri (k) Psych özel nota tipi olarak haritalanır; bilinmeyenler
 *     standart nota olur.
 */
class VSliceSongConverter
{
	/** Bu formatın üretildiğini işaretleyen Psych format değeri. */
	public static inline var FORMAT:String = 'vslice_conv';

	/** Bir dosyanın V-Slice chart olup olmadığını (notes map + version) kontrol eder. */
	public static function isVSliceChart(songJson:Dynamic):Bool
	{
		if (songJson == null) return false;
		// V-Slice chart: üst düzey 'notes' bir MAP (difficulty -> array), ve
		// notalar {t,d,l,k} kullanır; Psych'te 'notes' bir Array<backend.Song.SwagSection>'dır.
		if (songJson.notes == null) return false;
		var notes:Dynamic = songJson.notes;

		// Psych: notes array'dir. V-Slice: notes object'dir.
		return Std.isOfType(notes, Array) == false;
	}

	/**
	 * Bir V-Slice chart JSON'unu (hint: metadata ile birlikte) Psych SwagSong'a çevirir.
	 * @param chart  V-Slice chart JSON (parse edilmiş)
	 * @param meta   V-Slice metadata JSON (playData, timeChanges) — null olabilir
	 * @param diff   Çevrilecek zorluk (easy/normal/hard)
	 * @param songName Şarkı adı
	 */
	public static function convert(chart:Dynamic, meta:Dynamic, diff:String, songName:String):backend.Song.SwagSong
	{
		var metaPlay:Dynamic = (meta != null) ? Reflect.field(meta, 'playData') : null;
		var characters:Dynamic = (metaPlay != null) ? Reflect.field(metaPlay, 'characters') : null;
		var timeChanges:Array<Dynamic> = (meta != null) ? cast Reflect.field(meta, 'timeChanges') : null;
		if (timeChanges == null) timeChanges = [];

		var bpm:Float = 120;
		if (timeChanges.length > 0) bpm = Reflect.field(timeChanges[0], 'bpm');

		var scrollSpeed:Dynamic = Reflect.field(chart, 'scrollSpeed');
		var speed:Float = 1;
		if (scrollSpeed != null) {
			var s:Dynamic = Reflect.field(scrollSpeed, diff);
			if (s == null) for (k in Reflect.fields(scrollSpeed)) if (k.toLowerCase() == diff.toLowerCase()) { s = Reflect.field(scrollSpeed, k); break; }
			if (s == null) s = Reflect.field(scrollSpeed, 'normal');
			if (s != null) speed = Std.parseFloat(Std.string(s));
		}

		// Notaları topla
		var notesMap:Dynamic = Reflect.field(chart, 'notes');
		var diffKey:String = diff;
		// diff anahtarını case-insensitive bul (easy/Easy, hard/Hard ...)
		if (notesMap != null && Reflect.field(notesMap, diffKey) == null)
		{
			var found:Null<String> = null;
			for (k in Reflect.fields(notesMap))
				if (k.toLowerCase() == diff.toLowerCase()) { found = k; break; }
			if (found != null) diffKey = found;
		}
		if (notesMap == null || Reflect.field(notesMap, diffKey) == null) {
			// diff yoksa ilk zorluğu kullan
			var keys = Reflect.fields(notesMap);
			diffKey = (keys != null && keys.length > 0) ? keys[0] : diff;
		}
		var rawNotes:Array<Dynamic> = cast Reflect.field(notesMap, diffKey);
		if (rawNotes == null) rawNotes = [];

		// Sections'a çevir
		var sections:Array<backend.Song.SwagSection> = buildSections(rawNotes, timeChanges);

		var player1:String = 'bf';
		var player2:String = 'dad';
		var gfVersion:String = 'gf';
		var stage:String = 'stage';
		if (characters != null) {
			var p:Dynamic = Reflect.field(characters, 'player');
			if (p != null && Std.string(p) != 'null' && Std.string(p).length > 0) player1 = Std.string(p);
			var o:Dynamic = Reflect.field(characters, 'opponent');
			if (o != null && Std.string(o) != 'null' && Std.string(o).length > 0) player2 = Std.string(o);
			var g:Dynamic = Reflect.field(characters, 'girlfriend');
			if (g != null && Std.string(g) != 'null' && Std.string(g).length > 0) gfVersion = Std.string(g);
		}
		if (metaPlay != null) {
			var st:Dynamic = Reflect.field(metaPlay, 'stage');
			if (st != null && Std.string(st) != 'null' && Std.string(st).length > 0) stage = Std.string(st);
		}

		return {
			song: songName,
			notes: sections,
			events: [],
			bpm: bpm,
			needsVoices: true,
			speed: speed,
			offset: 0,
			player1: player1,
			player2: player2,
			gfVersion: gfVersion,
			stage: stage,
			format: FORMAT
		};
	}

	/**
	 * V-Slice notalarını Psych sections'a çevirir.
	 * V-Slice 'd' 0-3 = player, 4-7 = opponent; mustHitSection ölçü bazlıdır.
	 * Karışık ölçüler 4 adımlık bloklara bölünür.
	 */
	static function buildSections(rawNotes:Array<Dynamic>, timeChanges:Array<Dynamic>):Array<backend.Song.SwagSection>
	{
		var out:Array<backend.Song.SwagSection> = [];
		if (rawNotes == null) return out;

		// Nota adaylarını topla, step indeksi hesapla
		var parsed:Array<{t:Float, side:Int, dir:Int, l:Float, k:String, step:Float}> = [];
		for (n in rawNotes)
		{
			var t:Float = Reflect.field(n, 't');
			var d:Int = Std.int(Reflect.field(n, 'd'));
			var l:Float = (Reflect.field(n, 'l') != null) ? Reflect.field(n, 'l') : 0;
			var k:Dynamic = Reflect.field(n, 'k');
			var kstr:String = (k != null) ? Std.string(k) : '';
			var side:Int = (d >= 4) ? 1 : 0;
			var dir:Int = d % 4;
			parsed.push({t: t, side: side, dir: dir, l: l, k: kstr, step: msToStep(t, timeChanges)});
		}
		parsed.sort(function(a, b) return (a.step > b.step) ? 1 : ((a.step < b.step) ? -1 : 0));

		if (parsed.length == 0) return out;

		var maxStep:Float = parsed[parsed.length - 1].step;
		var baseLen:Int = 16;
		var segCount:Int = Std.int(Math.ceil(maxStep / baseLen)) + 1;

		for (si in 0...segCount)
		{
			var start:Float = si * baseLen;
			var end:Float = start + baseLen;
			var seg:Array<Dynamic> = [for (p in parsed) if (p.step >= start && p.step < end) p];

			if (seg.length == 0)
			{
				out.push(makeSection(start, [], baseLen, timeChanges));
				continue;
			}
			buildRecursive(out, seg, start, end, baseLen, timeChanges);
		}
		return out;
	}

	static function buildRecursive(out:Array<backend.Song.SwagSection>, notes:Array<Dynamic>, start:Float, end:Float, len:Int, timeChanges:Array<Dynamic>):Void
	{
		var sides = new Map<Int, Bool>();
		for (n in notes) sides.set(n.side, true);
		var sideCount:Int = 0;
		for (_ in sides.keys()) sideCount++;
		if (sideCount <= 1 || len <= 4)
		{
			out.push(makeSection(start, notes, len, timeChanges));
			return;
		}
		var mid:Float = start + len / 2;
		var left:Array<Dynamic> = [for (n in notes) if (n.step < mid) n];
		var right:Array<Dynamic> = [for (n in notes) if (n.step >= mid) n];
		buildRecursive(out, left, start, mid, Std.int(len / 2), timeChanges);
		buildRecursive(out, right, mid, end, Std.int(len / 2), timeChanges);
	}

	static function makeSection(startStep:Float, notes:Array<Dynamic>, len:Int, timeChanges:Array<Dynamic>):backend.Song.SwagSection
	{
		var side:Int = 0;
		if (notes.length > 0) side = notes[0].side;
		var mustHit:Bool = (side == 0);
		var sectionNotes:Array<Dynamic> = [];
		for (n in notes)
		{
			var ntype:Null<String> = (n.k != null && n.k.length > 0) ? n.k : null;
			// Psych nota data'sı: mustHitSection (player) ise 0-3, değilse (opponent) 4-7.
			// format='vslice_conv' olduğu için convert() atlanır; bu yüzden burada kendimiz
			// normalize ederiz. Aksi halde tüm notalar BF tarafında toplanır.
			var noteData:Int = mustHit ? n.dir : n.dir + 4;
			sectionNotes.push([n.t, noteData, n.l, ntype]);
		}
		return {
			sectionNotes: sectionNotes,
			sectionBeats: len / 4,
			mustHitSection: mustHit,
			altAnim: false,
			bpm: bpmAt(startStep, timeChanges),
			changeBPM: false
		};
	}

	/** V-Slice timeChanges'ından verilen step'teki bpm'i bulur. */
	static function bpmAt(step:Float, timeChanges:Array<Dynamic>):Float
	{
		var bpm:Float = 120;
		// step'i yaklaşık ms'e çevir (ilk bpm üzerinden); kesin hesap için
		// msToStep'in tersi gerekir ama section bpm'i yalnızca bilgi amaçlıdır.
		for (tc in timeChanges)
		{
			var t:Float = Reflect.field(tc, 't');
			var b:Dynamic = Reflect.field(tc, 'bpm');
			if (b != null) bpm = Std.parseFloat(Std.string(b));
		}
		return bpm;
	}

	/** ms'yi step indeksine çevirir (BPM değişimlerini kümülatif hesaba katar). */
	static function msToStep(ms:Float, timeChanges:Array<Dynamic>):Float
	{
		if (timeChanges == null || timeChanges.length == 0)
		{
			return ms / (60000.0 / 120.0 / 4.0);
		}
		var tcs:Array<Dynamic> = timeChanges.copy();
		tcs.sort(function(a, b) return (Reflect.field(a, 't') > Reflect.field(b, 't')) ? 1 : -1);
		var totalMs:Float = 0;
		var step:Float = 0;
		for (i in 0...tcs.length)
		{
			var t:Float = Reflect.field(tcs[i], 't');
			var bpm:Float = Reflect.field(tcs[i], 'bpm');
			var nextT:Float = (i + 1 < tcs.length) ? Reflect.field(tcs[i + 1], 't') : ms;
			var segMs:Float = nextT - t;
			var segSteps:Float = segMs / (60000.0 / bpm / 4.0);
			if (ms <= t + segMs + 0.001)
			{
				var local:Float = (ms - t) / (60000.0 / bpm / 4.0);
				return step + local;
			}
			step += segSteps;
		}
		return step;
	}

	/** V-Slice mod path'ini bulur (metadata + chart + audio). */
	public static function findSongFiles(modDir:String, songId:String):{chart:Null<String>, meta:Null<String>}
	{
		var base:String = 'mods/$modDir/data/songs/$songId/';
		var chart:String = null;
		var meta:String = null;
		#if sys
		if (FileSystem.exists(base + songId + '-chart.json')) chart = base + songId + '-chart.json';
		if (FileSystem.exists(base + songId + '-metadata.json')) meta = base + songId + '-metadata.json';
		#end
		return {chart: chart, meta: meta};
	}
}

package backend;

import backend.Song;
import objects.Note;

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	var stepCrochet:Float;
	var invStepCrochet:Float;
}

class Conductor
{
	public static var bpm(default, set):Float = 100;
	public static var crochet:Float = ((60 / bpm) * 1000);
	public static var stepCrochet:Float = crochet / 4;
	public static var invStepCrochet:Float = 1 / stepCrochet;
	public static var songPosition:Float = 0;
	public static var offset:Float = 0;

	public static var safeZoneOffset:Float = 0;

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];
	static var _lastBPMIndex:Int = 0;

	public static function judgeNote(arr:Array<Rating>, diff:Float=0):Rating
	{
		var len = arr.length;
		for(i in 0...len - 1)
			if (diff <= arr[i].hitWindow)
				return arr[i];
		return arr[len - 1];
	}

	public static function getCrotchetAtTime(time:Float):Float
	{
		return getBPMFromSeconds(time).stepCrochet * 4;
	}

	public static function getBPMFromSeconds(time:Float):BPMChangeEvent
	{
		var map = bpmChangeMap;
		var len = map.length;
		if (len == 0)
			return _defaultEvent();
		var i:Int = _lastBPMIndex;
		if (i >= len) i = len - 1;

		while (i < len - 1 && time >= map[i + 1].songTime) i++;
		while (i > 0 && time < map[i].songTime) i--;

		_lastBPMIndex = i;
		return map[i];
	}

	public static function getBPMFromStep(step:Float):BPMChangeEvent
	{
		var map = bpmChangeMap;
		var len = map.length;
		if (len == 0) return _defaultEvent();
		var i:Int = Std.int(Math.min(_lastBPMIndex, len - 1));
		while (i < len - 1 && step >= map[i + 1].stepTime) i++;
		while (i > 0 && step < map[i].stepTime) i--;
		_lastBPMIndex = i;
		return map[i];
	}

	public static function beatToSeconds(beat:Float):Float
	{
		var step = beat * 4;
		var lastChange = getBPMFromStep(step);
		return lastChange.songTime + ((step - lastChange.stepTime) * lastChange.stepCrochet);
	}
	public static function getStep(time:Float):Float
	{
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + (time - lastChange.songTime) * lastChange.invStepCrochet;
	}
	public static function getStepRounded(time:Float):Int
	{
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + Std.int(Math.floor((time - lastChange.songTime) * lastChange.invStepCrochet));
	}

	public static function getBeat(time:Float):Float
	{
		return getStep(time) * 0.25;
	}

	public static function getBeatRounded(time:Float):Int
	{
		return Std.int(Math.floor(getStep(time) * 0.25));
	}

	public static function reset():Void
	{
		bpmChangeMap = [];
		_lastBPMIndex = 0;
		songPosition = 0;
	}

	public static function mapBPMChanges(song:SwagSong):Void
	{
		bpmChangeMap = [];
		_lastBPMIndex = 0;

		if (song == null || song.notes == null)
		{
			Log.warn('chart', 'mapBPMChanges: song veya notes null — BPM map boş');
			return;
		}

		var curBPM:Float = song.bpm;
		if (Math.isNaN(curBPM) || !Math.isFinite(curBPM) || curBPM <= 0)
		{
			Log.warn('chart', 'Geçersiz BPM ($curBPM), 120 kullanılıyor');
			curBPM = 120;
		}
		var firstCrochet:Float = calculateCrochet(curBPM) / 4;
		bpmChangeMap.push({
			stepTime: 0,
			songTime: 0,
			bpm: curBPM,
			stepCrochet: firstCrochet,
			invStepCrochet: 1 / firstCrochet
		});

		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		var sections:Array<SwagSection> = song.notes;
		var len:Int = sections.length;

		for (i in 0...len)
		{
			var sec:SwagSection = sections[i];
			if (sec == null) continue;

			if (sec.changeBPM && sec.bpm != curBPM)
			{
				curBPM = sec.bpm;
				if (Math.isNaN(curBPM) || !Math.isFinite(curBPM) || curBPM <= 0)
				{
					Log.warn('chart', 'Section $i: geçersiz BPM, atlanıyor');
					curBPM = bpmChangeMap[bpmChangeMap.length - 1].bpm;
				}
				else
				{
					var sc:Float = calculateCrochet(curBPM) / 4;
					bpmChangeMap.push({
						stepTime: totalSteps,
						songTime: totalPos,
						bpm: curBPM,
						stepCrochet: sc,
						invStepCrochet: 1 / sc
					});
				}
			}

			var beats:Float = _sectionBeats(sec);
			var deltaSteps:Int = Std.int(Math.round(beats * 4));
			totalSteps += deltaSteps;
			var sc = bpmChangeMap[bpmChangeMap.length - 1].stepCrochet;
			totalPos += sc * deltaSteps;
		}

		Log.debugLazy('chart', function() return 'BPM map oluşturuldu: ' + bpmChangeMap.length + ' event');
	}

	static inline function _sectionBeats(sec:SwagSection):Float
	{
		var v:Dynamic = sec.sectionBeats;
		if (v == null) return 4.0;
		var f:Float = v;
		if (Math.isNaN(f)) return 4.0;
		return f;
	}

	inline public static function calculateCrochet(bpm:Float):Float
	{
		return (60 / bpm) * 1000;
	}

	public static function set_bpm(newBPM:Float):Float
	{
		if (Math.isNaN(newBPM) || newBPM <= 0) return bpm;
		bpm = newBPM;
		crochet = calculateCrochet(bpm);
		stepCrochet = crochet / 4;
		invStepCrochet = 1 / stepCrochet;
		return bpm;
	}
	static function _defaultEvent():BPMChangeEvent
	{
		return {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet,
			invStepCrochet: invStepCrochet
		};
	}
}

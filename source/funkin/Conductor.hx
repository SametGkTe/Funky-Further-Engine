package funkin;

/**
 * V-Slice/FNF uyumluluk shim'i (Conductor) — v16.
 *
 * Resmî funkin v0.8.7 `funkin.Conductor` örnek (instance) API'si,
 * Psych `backend.Conductor` statikleri üzerine köprülenir:
 *
 *   Conductor.instance.songPosition   -> backend.Conductor.songPosition
 *   Conductor.instance.bpm            -> backend.Conductor.bpm
 *   Conductor.instance.stepLengthMs   -> backend.Conductor.stepCrochet
 *   Conductor.instance.getTimeInSteps(ms) -> backend.Conductor.getStep(ms)
 *   ...
 *
 * Ayrıca ESKİ override davranışı (funkin.Conductor -> backend.Conductor,
 * statik erişim) bozulmasın diye aynı alanların STATİK sürümleri de var:
 *   Conductor.songPosition, Conductor.bpm, Conductor.crochet ...
 *
 * DESTEKLENMEYEN: FlxSignal tabanlı onBeatHit/onStepHit/onMeasureHit
 * sinyalleri (Further'da beat/step yayını VSScriptEventDispatcher ve
 * MusicBeatState üzerinden yürür). Bu sinyalleri kullanan script nadirdir.
 */
@:noCustomClass
class Conductor
{
	static var _instance:Conductor = null;

	/** Resmî FNF: Conductor.instance */
	public static var instance(get, never):Conductor;

	static function get_instance():Conductor
	{
		if (_instance == null) _instance = new Conductor();
		return _instance;
	}

	public function new()
	{
	}

	/* ============================ ÖRNEK ALANLAR ============================ */

	public var songPosition(get, never):Float;
	public var bpm(get, never):Float;
	public var startingBPM(get, never):Float;

	/** Legacy/weekend-1 adı: beat uzunluğu (ms). */
	public var crochet(get, never):Float;
	/** Legacy/weekend-1 adı: step uzunluğu (ms). */
	public var stepCrochet(get, never):Float;

	public var beatLengthMs(get, never):Float;
	public var stepLengthMs(get, never):Float;
	public var measureLengthMs(get, never):Float;

	public var timeSignatureNumerator(get, never):Int;
	public var timeSignatureDenominator(get, never):Int;

	public var currentMeasure(get, never):Int;
	public var currentBeat(get, never):Int;
	public var currentStep(get, never):Int;

	public var currentMeasureTime(get, never):Float;
	public var currentBeatTime(get, never):Float;
	public var currentStepTime(get, never):Float;

	public var beatsPerMeasure(get, never):Float;
	public var stepsPerMeasure(get, never):Int;

	public var globalOffset(get, never):Int;
	public var combinedOffset(get, never):Float;

	function get_songPosition():Float return backend.Conductor.songPosition;
	function get_bpm():Float return backend.Conductor.bpm;
	function get_startingBPM():Float
	{
		var map = backend.Conductor.bpmChangeMap;
		return (map != null && map.length > 0) ? map[0].bpm : backend.Conductor.bpm;
	}
	function get_crochet():Float return backend.Conductor.crochet;
	function get_stepCrochet():Float return backend.Conductor.stepCrochet;
	function get_beatLengthMs():Float return backend.Conductor.crochet;
	function get_stepLengthMs():Float return backend.Conductor.stepCrochet;
	function get_measureLengthMs():Float return backend.Conductor.crochet * beatsPerMeasure;
	function get_timeSignatureNumerator():Int return 4;
	function get_timeSignatureDenominator():Int return 4;
	function get_currentStep():Int return backend.Conductor.getStepRounded(backend.Conductor.songPosition);
	function get_currentBeat():Int return backend.Conductor.getBeatRounded(backend.Conductor.songPosition);
	function get_currentMeasure():Int return Std.int(Math.floor(get_currentBeat() / beatsPerMeasure));
	function get_currentStepTime():Float return backend.Conductor.getStep(backend.Conductor.songPosition);
	function get_currentBeatTime():Float return backend.Conductor.getBeat(backend.Conductor.songPosition);
	function get_currentMeasureTime():Float return get_currentBeatTime() / beatsPerMeasure;
	function get_beatsPerMeasure():Float return timeSignatureNumerator;
	function get_stepsPerMeasure():Int return Std.int(beatsPerMeasure * 4);
	function get_globalOffset():Int return Std.int(backend.Conductor.offset);
	function get_combinedOffset():Float return backend.Conductor.offset + backend.Conductor.safeZoneOffset;

	/* ============================ SİNYALLER (v18) ============================ */

	/**
	 * Resmî FNF FlxSignal'leri (argümansız): script'ler
	 * `Conductor.instance.onBeatHit.add(function() { ... })` kullanabilir.
	 * Yayın backend.MusicBeatState.stepHit/beatHit içinden yapılır
	 * (yalnızca POLYMOD_ALLOWED derlemelerde).
	 */
	public var onMeasureHit(default, null):flixel.util.FlxSignal = new flixel.util.FlxSignal();
	public var onBeatHit(default, null):flixel.util.FlxSignal = new flixel.util.FlxSignal();
	public var onStepHit(default, null):flixel.util.FlxSignal = new flixel.util.FlxSignal();

	/* ========================== ÖRNEK FONKSİYONLAR ========================== */

	/** ms -> step cinsinden konum (BPM değişimlerini hesaba katar). */
	public function getTimeInSteps(ms:Float):Float return backend.Conductor.getStep(ms);

	/** ms -> beat cinsinden konum. */
	public function getTimeInBeats(ms:Float):Float return backend.Conductor.getBeat(ms);

	/** ms -> measure cinsinden konum (4/4). */
	public function getTimeInMeasures(ms:Float):Float return backend.Conductor.getBeat(ms) / beatsPerMeasure;

	/** step -> ms (BPM değişimlerini hesaba katar). */
	public function getStepTimeInMs(stepTime:Float):Float return backend.Conductor.beatToSeconds(stepTime / 4);

	/** beat -> ms. */
	public function getBeatTimeInMs(beatTime:Float):Float return backend.Conductor.beatToSeconds(beatTime);

	/** measure -> ms (4/4). */
	public function getMeasureTimeInMs(measureTime:Float):Float return backend.Conductor.beatToSeconds(measureTime * beatsPerMeasure);

	/** Verilen ms anındaki 'step'|'beat'|'measure' birim uzunluğu. */
	public function getTypeLengthAtMs(ms:Float, type:String = 'beat'):Float
	{
		var change = backend.Conductor.getBPMFromSeconds(ms);
		return switch (type)
		{
			case 'step': change.stepCrochet;
			case 'measure': change.stepCrochet * stepsPerMeasure;
			default: change.stepCrochet * 4;
		};
	}

	/* ===================== STATİK KISAYOLLAR (resmî adlar) ===================== */

	/** Resmî FNF: Conductor.reset() */
	public static function reset():Void
	{
		backend.Conductor.reset();
	}

	/**
	 * Resmî FNF'de statik alan YOKTUR (hepsi instance'tır); eski
	 * `funkin.Conductor -> backend.Conductor` override'ı statik erişime
	 * izin veriyordu. Statik erişim gerekiyorsa script'ler
	 * `Conductor.instance.songPosition` kullanmalı (resmî sözdizimi).
	 */
}

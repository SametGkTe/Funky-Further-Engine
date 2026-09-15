package funkin.modding.events;

/**
 * V-Slice/FNF uyumluluk shim'i (ScriptEventType).
 * Resmî funkin v0.8.7 `funkin.modding.events.ScriptEventType` ile birebir.
 *
 * enum abstract olduğu için Polymod'un PolymodScriptClassMacro'su
 * (abstractClassImpls) sayesinde script'lerden import edilip
 * `ScriptEventType.SONG_START` şeklinde kullanılabilir.
 */
enum abstract ScriptEventType(String) from String to String
{
	public var CREATE = 'CREATE';
	public var STATE_CREATE = 'STATE_CREATE';
	public var DESTROY = 'DESTROY';
	public var ADDED = 'ADDED';
	public var UPDATE = 'UPDATE';
	public var PAUSE = 'PAUSE';
	public var RESUME = 'RESUME';
	public var SONG_BEAT_HIT = 'SONG_BEAT_HIT';
	public var SONG_STEP_HIT = 'SONG_STEP_HIT';
	public var NOTE_INCOMING = 'NOTE_INCOMING';
	public var NOTE_HIT = 'NOTE_HIT';
	public var NOTE_MISS = 'NOTE_MISS';
	public var NOTE_HOLD_DROP = 'NOTE_HOLD_DROP';
	public var NOTE_GHOST_MISS = 'NOTE_GHOST_MISS';
	public var SONG_EVENT = 'SONG_EVENT';
	public var SONG_START = 'SONG_START';
	public var SONG_END = 'SONG_END';
	public var COUNTDOWN_START = 'COUNTDOWN_START';
	public var COUNTDOWN_STEP = 'COUNTDOWN_STEP';
	public var COUNTDOWN_END = 'COUNTDOWN_END';
	public var GAME_OVER = 'GAME_OVER';
	public var SONG_RETRY = 'SONG_RETRY';
	public var KEY_DOWN = 'KEY_DOWN';
	public var KEY_UP = 'KEY_UP';
	public var SONG_LOADED = 'SONG_LOADED';
	public var STATE_CHANGE_BEGIN = 'STATE_CHANGE_BEGIN';
	public var STATE_CHANGE_END = 'STATE_CHANGE_END';
	public var SUBSTATE_OPEN_BEGIN = 'SUBSTATE_OPEN_BEGIN';
	public var SUBSTATE_OPEN_END = 'SUBSTATE_OPEN_END';
	public var SUBSTATE_CLOSE_BEGIN = 'SUBSTATE_CLOSE_BEGIN';
	public var SUBSTATE_CLOSE_END = 'SUBSTATE_CLOSE_END';
	public var FOCUS_GAINED = 'FOCUS_GAINED';
	public var FOCUS_LOST = 'FOCUS_LOST';
	public var CAPSULE_SELECTED = 'CAPSULE_SELECTED';
	public var DIFFICULTY_SWITCH = 'DIFFICULTY_SWITCH';
	public var SONG_SELECTED = 'SONG_SELECTED';
	public var FREEPLAY_INTRO = 'FREEPLAY_INTRO';
	public var FREEPLAY_OUTRO = 'FREEPLAY_OUTRO';
	public var FREEPLAY_CLOSE = 'FREEPLAY_CLOSE';
	public var CHARACTER_SELECTED = 'CHARACTER_SELECTED';
	public var CHARACTER_DESELECTED = 'CHARACTER_DESELECTED';
	public var CHARACTER_CONFIRMED = 'CHARACTER_CONFIRMED';
	public var DIALOGUE_START = 'DIALOGUE_START';
	public var DIALOGUE_LINE = 'DIALOGUE_LINE';
	public var DIALOGUE_COMPLETE_LINE = 'DIALOGUE_COMPLETE_LINE';
	public var DIALOGUE_SKIP = 'DIALOGUE_SKIP';
	public var DIALOGUE_END = 'DIALOGUE_END';
}

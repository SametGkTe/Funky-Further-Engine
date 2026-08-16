package vslice.compatibility.script;

import psychlua.LuaUtils;

/**
 * ScriptEventBridge — V-Slice (Polymod) script event kavramı ile Psych Engine'in
 * mevcut `callOnHScript` callback isimleri arasındaki eşleştirmeyi yönetir.
 *
 * V-Slice'ın resmi `ScriptEventType` enum'ındaki olay adları (SONG_START, NOTE_HIT, ...)
 * ile Psych'in `PlayState` içindeki callback fonksiyon adları (onSongStart, goodNoteHit, ...)
 * birebir aynı değildir. Bu sınıf, "sınırlı alt küme" için aşağıdaki dönüşümü sağlar:
 *
 *   V-Slice event'i           -> Psych callback (callOnHScript'a geçirilen ad)
 *   CREATE                    -> onCreate
 *   STATE_CREATE              -> onCreatePost
 *   UPDATE                    -> onUpdate
 *   SONG_START                -> onSongStart
 *   SONG_BEAT_HIT             -> onBeatHit
 *   SONG_STEP_HIT             -> onStepHit
 *   NOTE_HIT                  -> goodNoteHit
 *   NOTE_MISS                 -> noteMiss
 *   PAUSE                     -> onPause
 *   RESUME                    -> onResume
 *   GAME_OVER                 -> onGameOver
 *   SONG_END                  -> onEndSong
 *
 * NOT: Bu bir "köprü"dür; tam V-Slice event sistemi DEĞİLDİR. V-Slice'ın class-tabanlı
 * modelleri (Module / ScriptedModule / ScriptedFunkinSprite ...) burada çalışmaz.
 * Desteklenen alt küme, düz fonksiyon (flat-function) tarzı .hxc/.hx scriptleridir.
 */
class ScriptEventBridge
{
	/**
	 * V-Slice ScriptEventType adını Psych callback adına çevirir.
	 * Bilinmeyen olaylar için `null` döner (çağrı yapılmaz).
	 */
	public static function eventToCallback(eventName:String):String
	{
		return switch (eventName)
		{
			case 'CREATE': 'onCreate';
			case 'STATE_CREATE': 'onCreatePost';
			case 'DESTROY': 'onDestroy';
			case 'UPDATE': 'onUpdate';
			case 'UPDATE_POST': 'onUpdatePost';
			case 'SONG_START': 'onSongStart';
			case 'SONG_BEAT_HIT': 'onBeatHit';
			case 'SONG_STEP_HIT': 'onStepHit';
			case 'NOTE_HIT': 'goodNoteHit';
			case 'NOTE_MISS': 'noteMiss';
			case 'NOTE_GHOST_MISS': 'onGhostTap';
			case 'PAUSE': 'onPause';
			case 'RESUME': 'onResume';
			case 'GAME_OVER': 'onGameOver';
			case 'SONG_END': 'onEndSong';
			case 'COUNTDOWN_START': 'onStartCountdown';
			case 'KEY_PRESS': 'onKeyPress';
			case 'KEY_RELEASE': 'onKeyRelease';
			case 'SONG_EVENT': 'onEvent';
			case 'FOCUS_LOST': 'onFocusLost';
			case 'FOCUS_GAINED': 'onFocus';
			default: null;
		}
	}

	/**
	 * Callback'lerin çalışmasını "durdurabilen" özel dönüş değerleri.
	 * V-Slice'ta `event.cancel()` mantığına karşılık gelir.
	 */
	public static inline function Function_Stop():Dynamic
	{
		return LuaUtils.Function_Stop;
	}

	public static inline function Function_StopHScript():Dynamic
	{
		return LuaUtils.Function_StopHScript;
	}
}

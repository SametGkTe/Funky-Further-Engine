package vslice.scripting;

import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEvent.CountdownScriptEvent;
import funkin.modding.events.ScriptEvent.GhostMissNoteScriptEvent;
import funkin.modding.events.ScriptEvent.HitNoteScriptEvent;
import funkin.modding.events.ScriptEvent.NoteScriptEvent;
import funkin.modding.events.ScriptEvent.PauseScriptEvent;
import funkin.modding.events.ScriptEvent.SongLoadScriptEvent;
import funkin.modding.events.ScriptEvent.SongTimeScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;
import funkin.play.Countdown.CountdownStep;

/**
 * VSScriptEventDispatcher — V-Slice tarzı script olaylarının dağıtıcısı (v15).
 *
 * FNF'de script'ler `onCreate(event)`, `onBeatHit(event)`, `onNoteHit(event)`
 * gibi metodları override eder. v15'ten itibaren olay nesneleri resmî
 * funkin v0.8.7 `ScriptEvent` ailesinin TİPLİ sınıflarıdır:
 *
 *   onBeatHit   -> SongTimeScriptEvent   (event.beat, event.step)
 *   onNoteHit   -> HitNoteScriptEvent    (event.note, event.judgement, event.score, ...)
 *   onNoteMiss  -> NoteScriptEvent       (event.note, event.healthChange, ...)
 *   onUpdate    -> UpdateScriptEvent     (event.elapsed)
 *   onPause     -> PauseScriptEvent      (event.gitaroo, cancelable)
 *   ...
 *
 * GERİYE UYUMLULUK: Her olayda eski isimsiz obje alanları da taşınır:
 *   event.data      (ham yük: nota, beat sayısı, elapsed...)
 *   event.eventName (Psych callback adı: 'onBeatHit')
 *   event.cancelled (eventCanceled takma adı — eski pause kontrolü çalışır)
 *   event.type      artık RESMÎ ScriptEventType değeridir ('SONG_BEAT_HIT').
 *
 * İPTAL SEMANTİĞİ (resmî FNF):
 *   - onPause iptali pause menüsünü engeller (PlayState kontrol eder)
 *   - onNoteMiss iptali miss cezasını engeller (PlayState kontrol eder)
 *   - onCountdownStep iptali countdown'ı durdurur (resmî davranış; PlayState)
 */
@:access(backend.MusicBeatState)
class VSScriptEventDispatcher
{
	/**
	 * Psych callback adından resmî ScriptEventType değerine eşleme.
	 */
	public static function typeForCallback(funcName:String):String
	{
		return switch (funcName)
		{
			case 'onCreate': 'CREATE';
			case 'onCreatePost': 'STATE_CREATE';
			case 'onDestroy': 'DESTROY';
			case 'onUpdate' | 'onUpdatePost': 'UPDATE';
			case 'onSongStart': 'SONG_START';
			case 'onSongEnd': 'SONG_END';
			case 'onGameOver': 'GAME_OVER';
			case 'onResume': 'RESUME';
			case 'onPause': 'PAUSE';
			case 'onBeatHit': 'SONG_BEAT_HIT';
			case 'onStepHit': 'SONG_STEP_HIT';
			case 'onNoteHit': 'NOTE_HIT';
			case 'onNoteMiss': 'NOTE_MISS';
			case 'onNoteGhostMiss' | 'onGhostTap': 'NOTE_GHOST_MISS';
			case 'onCountdownStart': 'COUNTDOWN_START';
			case 'onCountdownStep': 'COUNTDOWN_STEP';
			case 'onCountdownEnd': 'COUNTDOWN_END';
			case 'onSongLoaded': 'SONG_LOADED';
			case 'onSongEvent': 'SONG_EVENT';
			case 'onKeyPress': 'KEY_DOWN';
			case 'onKeyRelease': 'KEY_UP';
			default: funcName;
		};
	}

	/**
	 * TİPLİ olay nesnesi üretir (resmî ScriptEvent ailesi).
	 * `data` çağrı noktasının ham yüküdür (Note, Int beat, Float elapsed...).
	 */
	public static function make(type:String, ?data:Dynamic):ScriptEvent
	{
		var ev:ScriptEvent = buildTyped(type, data);
		ev.data = data;
		ev.eventName = type;
		return ev;
	}

	static function buildTyped(funcName:String, data:Dynamic):ScriptEvent
	{
		var state = states.PlayState.instance;
		switch (funcName)
		{
			case 'onUpdate' | 'onUpdatePost':
				var elapsed:Float = Std.isOfType(data, Float) || Std.isOfType(data, Int) ? data : 0;
				return new UpdateScriptEvent(elapsed);

			case 'onBeatHit':
				var beat:Int = Std.isOfType(data, Int) || Std.isOfType(data, Float) ? Std.int(data) : (state != null ? state.curBeat : 0);
				return new SongTimeScriptEvent('SONG_BEAT_HIT', beat, beat * 4);

			case 'onStepHit':
				var step:Int = Std.isOfType(data, Int) || Std.isOfType(data, Float) ? Std.int(data) : (state != null ? state.curStep : 0);
				return new SongTimeScriptEvent('SONG_STEP_HIT', Std.int(step / 4), step);

			case 'onCountdownStart':
				return new CountdownScriptEvent('COUNTDOWN_START', CountdownStep.BEFORE);

			case 'onCountdownStep':
				// Psych swagCounter: 0='3', 1='2', 2='1', 3='go'
				var counter:Int = Std.isOfType(data, Int) || Std.isOfType(data, Float) ? Std.int(data) : 0;
				var step:CountdownStep = switch (counter)
				{
					case 0: CountdownStep.THREE;
					case 1: CountdownStep.TWO;
					case 2: CountdownStep.ONE;
					case 3: CountdownStep.GO;
					default: CountdownStep.THREE;
				};
				return new CountdownScriptEvent('COUNTDOWN_STEP', step);

			case 'onCountdownEnd':
				return new CountdownScriptEvent('COUNTDOWN_END', CountdownStep.AFTER, false);

			case 'onPause':
				var gitaroo:Bool = data == true;
				return new PauseScriptEvent(gitaroo);

			case 'onNoteHit':
				var note:objects.Note = Std.isOfType(data, objects.Note) ? cast data : null;
				if (state != null && note != null)
				{
					// Rakip notaları can vermez; oyuncu notaları ~0.023 * healthGain.
					var healthChange:Float = (note.mustPress && !note.isSustainNote) ? 0.023 : 0;
					var hitEv = new HitNoteScriptEvent(note, healthChange, 0, note.rating != null ? note.rating : 'sick', false,
						state.combo, note.hitDiff, note.noteSplashData != null && !note.noteSplashData.disabled && !note.isSustainNote);
					return hitEv;
				}
				return new NoteScriptEvent('NOTE_HIT', note, 0, state != null ? state.combo : 0, true);

			case 'onNoteMiss':
				var note:objects.Note = Std.isOfType(data, objects.Note) ? cast data : null;
				return new NoteScriptEvent('NOTE_MISS', note, -0.0475, state != null ? state.combo : 0, true);

			case 'onNoteGhostMiss' | 'onGhostTap':
				var dir:Int = Std.isOfType(data, Int) || Std.isOfType(data, Float) ? Std.int(data) : 0;
				return new GhostMissNoteScriptEvent(dir, false, 0, 0);

			case 'onSongLoaded':
				var id:String = '';
				var diff:String = '';
				var notes:Array<Dynamic> = null;
				var events:Array<Dynamic> = null;
				if (states.PlayState.SONG != null)
				{
					id = states.PlayState.SONG.song;
					notes = cast states.PlayState.SONG.notes;
				}
				if (state != null)
				{
					diff = backend.Difficulty.getString(states.PlayState.storyDifficulty);
					events = cast state.eventNotes;
				}
				return new SongLoadScriptEvent(id, diff, notes, events);

			default:
				return new ScriptEvent(typeForCallback(funcName));
		}
	}

	/**
	 * Native crash (hxSehException) veya ağır hata veren hedef+fonksiyon
	 * çiftleri Kara listeye alınır: hem log spam'ı kesilir hem aynı
	 * çerçeve-içi crash tekrar tekrar tetiklenmez (v18.1 teşhis).
	 */
	static var _crashedDispatches:Map<String, Bool> = new Map<String, Bool>();

	/**
	 * Tek bir hedefe olay gönderir. Hedef scripted değilse veya script'te
	 * o fonksiyon yoksa sessizce false döner.
	 */
	public static function dispatch(target:Dynamic, funcName:String, ?event:Dynamic = null):Bool
	{
		if (target == null || funcName == null) return false;

		// Destroy edilmiş Flx nesnelerine dispatch YAPMA — C++ tarafında
		// dangling çağrı native crash (hxSehException) üretir.
		if (Std.isOfType(target, flixel.FlxBasic))
		{
			var basic:flixel.FlxBasic = cast target;
			if (!basic.exists) return false;
		}

		// KRİTİK (v21b / Faz 4.6b): Reflect.hasField, cpp hedefinde SINIF
		// METODLARINI göremez (hxcpp __HasField yalnızca dinamik alanları
		// sayar) → tüm script örnekleri sessizce [native] sayılıp olaylar
		// HİÇ iletilmiyordu (kara sahne kök nedeni). Çözüm, Polymod'un
		// kendi Interp'i ile aynı: DİNAMİK alan erişimi. hxcpp __GetField
		// metodları closure olarak çözer; olmayan alan için null döner
		// (cast YOK → native crash riski YOK, bkz. v18.2 notu).
		var shFn:Dynamic = null;
		var scFn:Dynamic = null;
		try
		{
			var d:Dynamic = target;
			shFn = d.scriptHas;
			scFn = d.scriptCall;
		}
		catch (e:Dynamic) {}
		if (shFn == null || scFn == null) return false;

		var tname:String = 'bilinmeyen';
		try { tname = Type.getClassName(Type.getClass(target)); } catch (_:Dynamic) {}
		var bkey:String = tname + '#' + funcName;
		if (_crashedDispatches.exists(bkey)) return false;

		try
		{
			var has:Bool = Reflect.callMethod(target, shFn, [funcName]);
			if (!has)
			{
				// v21 tanı: onCreate özelinde sessiz başarısızlığı görünür yap.
				if (funcName == 'onCreate')
					trace('[VSScriptEventDispatcher] $tname scriptHas("onCreate") = FALSE — script\'te onCreate yok veya _asc bagli degil!');
				return false;
			}
			Reflect.callMethod(target, scFn, [funcName, event == null ? [] : [event]]);
			return true;
		}
		catch (e:Dynamic)
		{
			_crashedDispatches.set(bkey, true);
			trace('[VSScriptEventDispatcher] "$tname" hedefinde $funcName CRASH — kara listeye alindi, tekrar denenmeyecek. Hata: $e');
			return false;
		}
	}

	/**
	 * PlayState'in tipik hedeflerine (dad, boyfriend, gf, şarkı script'i,
	 * module'ler, tüm stage'ler + kayıtlı V-Slice song event handler'ları)
	 * olayı yayar ve OLAY objesini DÖNDÜRÜR (script'ler iptal edebilir).
	 */
	public static function dispatchPlayState(funcName:String, ?data:Dynamic = null):Dynamic
	{
		#if POLYMOD_ALLOWED
		var event:ScriptEvent = make(funcName, data);
		return dispatchPlayStateEvent(funcName, event);
		#else
		return null;
		#end
	}

	/**
	 * ÖNCEDEN KURULMUŞ (tipli/zengin) bir olay nesnesini tüm hedeflere yayar.
	 * PlayState, HitNoteScriptEvent gibi alanları elle doldurduğunda bunu kullanır.
	 */
	public static function dispatchPlayStateEvent(funcName:String, event:Dynamic):Dynamic
	{
		#if POLYMOD_ALLOWED
		if (event == null || !Std.isOfType(event, ScriptEvent)) event = make(funcName, event);
		var state = states.PlayState.instance;
		if (state == null) return event;

		// Resmî FNF sırası: karakterler -> song -> module'ler -> stage'ler.
		if (!dispatchToTarget(state.dad, funcName, event)) return event;
		if (!dispatchToTarget(state.boyfriend, funcName, event)) return event;
		if (!dispatchToTarget(state.gf, funcName, event)) return event;
		if (state.vsSongScript != null)
			if (!dispatchToTarget(state.vsSongScript, funcName, event)) return event;
		if (!dispatchModulesEvent(funcName, event)) return event;
		if (!dispatchStagesEvent(state, funcName, event)) return event;
		dispatchSongEventHandlers(funcName, event);
		return event;
		#else
		return event;
		#end
	}

	/**
	 * Hedefe onScriptEvent + asıl olayı gönderir.
	 * @return false ise propagasyon durduruldu (event.stopPropagation()).
	 */
	static function dispatchToTarget(target:Dynamic, funcName:String, event:Dynamic):Bool
	{
		if (target == null) return true;
		dispatch(target, 'onScriptEvent', event);
		dispatch(target, funcName, event);
		var se:ScriptEvent = Std.isOfType(event, ScriptEvent) ? cast event : null;
		if (se != null && !se.shouldPropagate) return false;
		return true;
	}

	/**
	 * Module script'lerine yayar (active = false olanlar atlanır).
	 * NOT: Eski çağrı noktaları ham yük geçebiliyor (örn. dispatchModules('onUpdate', elapsed));
	 * ScriptEvent olmayan değerler otomatik olarak `data` alanına sarılır.
	 */
	public static function dispatchModules(funcName:String, ?event:Dynamic = null):Void
	{
		#if POLYMOD_ALLOWED
		if (event == null || !Std.isOfType(event, ScriptEvent)) event = make(funcName, event);
		dispatchModulesEvent(funcName, event);
		#end
	}

	static function dispatchModulesEvent(funcName:String, event:Dynamic):Bool
	{
		var mods = VSScriptRegistry.modules;
		if (mods == null) return true;
		for (m in mods)
		{
			if (m == null || !m.active) continue;
			if (!dispatchToTarget(m, funcName, event)) return false;
		}
		return true;
	}

	/** Sahne script'lerine yayar (scripted stage'ler de dahil). */
	public static function dispatchStages(state:states.PlayState, funcName:String, ?event:Dynamic = null):Void
	{
		if (state == null) return;
		if (event == null || !Std.isOfType(event, ScriptEvent)) event = make(funcName, event);
		dispatchStagesEvent(state, funcName, event);
	}

	static var _stagesDispatchLogged:Bool = false;

	static function dispatchStagesEvent(state:states.PlayState, funcName:String, event:Dynamic):Bool
	{
		try
		{
			// v21 tanı: ilk stage dispatch'te stages listesinin içeriğini bir kez logla.
			if (!_stagesDispatchLogged)
			{
				_stagesDispatchLogged = true;
				var info:Array<String> = [];
				for (s in state.stages)
				{
					if (s == null) { info.push('null'); continue; }
					var cn = 'bilinmeyen';
					try { cn = Type.getClassName(Type.getClass(s)); } catch (_:Dynamic) {}
					var isScripted:Bool = false;
					try { var dd:Dynamic = s; isScripted = (dd.scriptHas != null); } catch (_:Dynamic) {}
					info.push(cn + (isScripted ? ' [scripted]' : ' [native]'));
				}
				trace('[VSScriptEventDispatcher] Ilk stage dispatch (${funcName}): ${state.stages.length} sahne -> ${info.join(", ")}');
			}
			for (stage in state.stages)
				if (stage != null && stage.exists && stage.active)
					if (!dispatchToTarget(stage, funcName, event)) return false;
		}
		catch (e:Dynamic)
		{
			trace('[VSScriptEventDispatcher] stage dispatch hatasi: $e');
		}
		return true;
	}

	/**
	 * Kayıtlı V-Slice song event handler'larına (ScriptedSongEvent örnekleri)
	 * yaşam döngüsü olaylarını yayar — resmî FNF'de SongEventRegistry.callEvent
	 * + ScriptEventDispatcher bunu yapar.
	 */
	public static function dispatchSongEventHandlers(funcName:String, event:Dynamic):Void
	{
		try
		{
			var handlers = funkin.data.event.SongEventRegistry.getActiveHandlers();
			if (handlers == null) return;
			for (h in handlers)
				dispatchToTarget(h, funcName, event);
		}
		catch (e:Dynamic)
		{
		}
	}
}

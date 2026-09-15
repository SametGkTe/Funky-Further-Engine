package vslice.compatibility.script;

import haxe.Json;
import funkin.data.event.SongEventRegistry;
import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongData.SongEventDataRaw;
import funkin.modding.events.ScriptEvent.SongEventScriptEvent;

/**
 * VSliceEventBridge — Psych `triggerEvent` akışı ile resmî FNF
 * `SongEventRegistry` akışı arasındaki köprü (v15).
 *
 * Resmî FNF'de chart event'leri şöyle yürür:
 *   1. PlayState.dispatchEvent(new SongEventScriptEvent(eventData))
 *      -> module/karakter/sahne/şarkı script'leri `onSongEvent(event)` alır
 *   2. SongEventRegistry.handleEvent(eventData)
 *      -> eventKind ile eşleşen SongEvent handler'ının handleEvent(data)'sı çalışır
 *
 * Further'da chart event'leri VSliceSongConverter ile Psych eventNotes
 * formatına dönüşür: {t, e, v} -> [time, [[isim, v1, v2]]].
 *   - v nesne ise: v1 = Json.stringify(v)
 *   - v dizi ise:  v1 = v[0], v2 = v[1]
 *   - v skaler ise: v1 = v
 *
 * Bu köprü value1/value2'den özgün `SongEventData.value` yapısını geri
 * kurar (JSON parse + dizi/skaler sezgisi) ve iki resmî adımı çalıştırır.
 *
 * PlayState.triggerEvent sonundan çağrılır:
 *   VSliceEventBridge.onTriggerEvent(this, eventName, value1, value2, strumTime);
 */
class VSliceEventBridge
{
	/**
	 * @return true ise event bir V-Slice handler tarafından işlendi.
	 */
	public static function onTriggerEvent(state:states.PlayState, eventName:String, value1:String, value2:String, strumTime:Float):Bool
	{
		#if POLYMOD_ALLOWED
		if (eventName == null || eventName.length == 0) return false;

		var data:SongEventData = buildEventData(eventName, value1, value2, strumTime);

		// 1) Modüllere/şarkı script'lerine onSongEvent yay (resmî adım 1).
		try
		{
			var scriptEvent = new SongEventScriptEvent(data);
			vslice.scripting.VSScriptEventDispatcher.dispatchPlayStateEvent('onSongEvent', scriptEvent);
		}
		catch (e:Dynamic)
		{
			trace('[VSliceEventBridge] onSongEvent dispatch hatasi: $e');
		}

		// 2) Kayıtlı handler (scripted SongEvent veya yerleşik V-Slice event) çalıştır.
		var handled:Bool = SongEventRegistry.handleEvent(data);
		return handled;
		#else
		return false;
		#end
	}

	/**
	 * Psych value1/value2 çiftinden resmî SongEventData kurar.
	 */
	public static function buildEventData(eventName:String, value1:String, value2:String, strumTime:Float):SongEventData
	{
		var value:Dynamic = reconstructValue(value1, value2);
		return new SongEventDataRaw(strumTime, eventName, value);
	}

	/**
	 * Şarkının eventNotes listesinden SongEventData dizisi kurup
	 * SongEventRegistry.resetEvents'i çağırır — böylece bu şarkıda
	 * kullanılan event handler'ları yaşam döngüsü olaylarını da alır
	 * (resmî FNF'deki allEventHandlers mekanizması).
	 *
	 * PlayState.create() içinde eventNotes sıralandıktan SONRA çağrılır.
	 */
	public static function registerSongEventHandlers(eventNotes:Array<Dynamic>):Void
	{
		#if POLYMOD_ALLOWED
		var datas:Array<SongEventData> = [];
		if (eventNotes != null)
		{
			for (en in eventNotes)
			{
				if (en == null) continue;
				var name:Dynamic = Reflect.field(en, 'event');
				var v1:Dynamic = Reflect.field(en, 'value1');
				var v2:Dynamic = Reflect.field(en, 'value2');
				var t:Dynamic = Reflect.field(en, 'strumTime');
				datas.push(buildEventData(name != null ? Std.string(name) : '',
					v1 != null ? Std.string(v1) : '',
					v2 != null ? Std.string(v2) : '',
					t != null ? t : 0));
			}
		}
		SongEventRegistry.resetEvents(datas);
		#end
	}

	/**
	 * VSliceSongConverter'ın sıkıştırdığı v1/v2 çiftinden özgün `v` değerini
	 * geri kurar:
	 *   - v1 JSON nesne/dizi/skaler ise -> parse edilmiş değer
	 *   - v1 boş, v2 dolu -> v2 (skaler)
	 *   - ikisi de skaler dolu -> [v1, v2] (dizi v'nün 2 elemanlı hali)
	 */
	public static function reconstructValue(value1:String, value2:String):Dynamic
	{
		var v1:String = value1 != null ? StringTools.trim(value1) : '';
		var v2:String = value2 != null ? StringTools.trim(value2) : '';

		if (v1.length > 0)
		{
			// JSON nesne/dizi denenir (converter nesneleri Json.stringify ile koyar).
			var firstChar:String = v1.charAt(0);
			if (firstChar == '{' || firstChar == '[')
			{
				try
				{
					return Json.parse(v1);
				}
				catch (e:Dynamic)
				{
					// parse edilemedi — ham string olarak düş
				}
			}

			// İki skaler de doluysa büyük ihtimalle dizi v'ydü: [v[0], v[1]]
			if (v2.length > 0)
				return [coerceScalar(v1), coerceScalar(v2)];

			return coerceScalar(v1);
		}

		if (v2.length > 0) return coerceScalar(v2);
		return null;
	}

	/** Sayıya benzeyen string'i sayıya çevirir; değilse string bırakır. */
	static function coerceScalar(s:String):Dynamic
	{
		if (s == null) return null;
		if (s == 'true') return true;
		if (s == 'false') return false;
		if (~/^-?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.match(s))
		{
			var f:Float = Std.parseFloat(s);
			if (!Math.isNaN(f)) return f;
		}
		return s;
	}
}

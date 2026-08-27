package backend;

import backend.AudioChannel;
import flixel.sound.FlxSound;
import flixel.math.FlxMath;
import flixel.FlxG;

class AudioMixer
{
	static inline var MIN_VOLUME:Float = 0.0;
	static inline var MAX_VOLUME:Float = 2.0;
	static var _channelSounds:Map<String, Array<FlxSound>> = [];

	static var _initialized:Bool = false;

	public static function init():Void
	{
		if (_initialized) return;
		_initialized = true;

		var channels:Array<AudioChannel> = [MASTER, MUSIC, INST, VOICES, HIT, UI, SFX];
		for (ch in channels)
		{
			var key:String = cast ch;
			if (!_channelSounds.exists(key))
				_channelSounds.set(key, []);
		}
		syncFromPrefs();
	}
	public static function syncFromPrefs():Void
	{
		if (!_initialized) init();
		
		// Başlangıçta tüm sesleri kısmak için flixel'e bildir
		FlxG.sound.muted = muted;

		setPrefVolume(MASTER, getPrefField(MASTER));
		setPrefVolume(MUSIC,  getPrefField(MUSIC));
		setPrefVolume(INST,   getPrefField(INST));
		setPrefVolume(VOICES, getPrefField(VOICES));
		setPrefVolume(HIT,    getPrefField(HIT));
		setPrefVolume(UI,     getPrefField(UI));
		setPrefVolume(SFX,    getPrefField(SFX));
	}

	inline static function prefsKey(ch:AudioChannel):String
		return 'volume_${ch}';

	static function getPrefField(ch:AudioChannel):Float
	{
		try {
			var v:Dynamic = Reflect.getProperty(ClientPrefs.data, prefsKey(ch));
			if (v == null) return 1.0;
			return Std.parseFloat(Std.string(v));
		} catch (e:Dynamic) { return 1.0; }
	}
	inline static function setPrefVolume(ch:AudioChannel, v:Float):Void
	{
		try
		{
			var clamped:Float = FlxMath.bound(v, MIN_VOLUME, MAX_VOLUME);
			Reflect.setField(ClientPrefs.data, prefsKey(ch), clamped);
		}
		catch (e:Dynamic) {}
		_applyChannel(ch);
	}
	public static function getVolume(ch:AudioChannel):Float
	{
		if (!_initialized) init();
		var v = getPrefField(ch);
		return FlxMath.bound(v, MIN_VOLUME, MAX_VOLUME);
	}
	public static function setVolume(ch:AudioChannel, v:Float):Void
	{
		if (!_initialized) init();
		var clamped:Float = FlxMath.bound(v, MIN_VOLUME, MAX_VOLUME);
		Reflect.setField(ClientPrefs.data, prefsKey(ch), clamped);
		
		if (ch == MASTER)
		{
			// MASTER ayarını anında Flixel Global Volume'a aktar
			FlxG.sound.volume = FlxMath.bound(clamped, 0, 1);
			for (other in _channelSounds.keys())
			{
				if (other != (cast MASTER:String)) _applyChannel(cast other);
			}
		}
		else
		{
			_applyChannel(ch);
		}
	}
	public static var muted(get, set):Bool;
	static function get_muted():Bool
	{
		return ClientPrefs.data.volumeMuted == true;
	}
	static function set_muted(v:Bool):Bool
	{
		ClientPrefs.data.volumeMuted = v;
		// TÜM SESLERİ KAPAT ayarını Flixel Global Mute'a aktar!
		FlxG.sound.muted = v;
		
		for (key in _channelSounds.keys()) _applyChannel(cast key);
		return v;
	}
	public static function track(snd:FlxSound, channel:AudioChannel):Void
	{
		if (snd == null) return;
		if (!_initialized) init();
		var key:String = cast channel;
		if (!_channelSounds.exists(key)) _channelSounds.set(key, []);
		var list:Array<FlxSound> = _channelSounds.get(key);
		if (!list.contains(snd)) list.push(snd);
		snd.volume = _effectiveVolume(channel);
	}
	public static function untrack(snd:FlxSound):Void
	{
		if (snd == null) return;
		for (key in _channelSounds.keys())
		{
			var list:Array<FlxSound> = _channelSounds.get(key);
			if (list != null) list.remove(snd);
		}
	}
	public static function stopChannel(channel:AudioChannel):Void
	{
		if (!_initialized) return;
		var key:String = cast channel;
		var list:Array<FlxSound> = _channelSounds.get(key);
		if (list == null) return;
		for (snd in list)
		{
			if (snd != null && snd.playing)
			{
				@:privateAccess snd.stop();
			}
		}
		list.splice(0, list.length);
	}
	inline static function _effectiveVolume(ch:AudioChannel):Float
	{
		if (muted) return 0;
		return FlxMath.bound(getVolume(MASTER) * getVolume(ch), 0.0, MAX_VOLUME);
	}
	static function _applyChannel(ch:AudioChannel):Void
	{
		// MOTORA DOĞRUDAN ETKİ ETMESİ İÇİN FLIXEL NATIVE GRUPLARINI GÜNCELLE
		// Çünkü oyun içindeki seslerin çoğu track() ile eklenmemiştir!
		if (ch == MASTER) {
			FlxG.sound.volume = FlxMath.bound(getVolume(MASTER), 0, 1);
		} else if (ch == MUSIC) {
			if (FlxG.sound.defaultMusicGroup != null)
				FlxG.sound.defaultMusicGroup.volume = FlxMath.bound(getVolume(MUSIC), 0, 1);
		} else if (ch == SFX) {
			if (FlxG.sound.defaultSoundGroup != null)
				FlxG.sound.defaultSoundGroup.volume = FlxMath.bound(getVolume(SFX), 0, 1);
		}

		var key:String = cast ch;
		var list:Array<FlxSound> = _channelSounds.get(key);
		if (list == null) return;
		var v = _effectiveVolume(ch);
		var i = list.length;
		while (i-- > 0)
		{
			var snd = list[i];
			if (snd == null || (!snd.playing && !snd.active))
			{
				list.splice(i, 1);
				continue;
			}
			snd.volume = v;
		}
	}
	public static function allChannels():Array<AudioChannel>
	{
		return [MASTER, MUSIC, INST, VOICES, HIT, UI, SFX];
	}
	public static function channelLabel(ch:AudioChannel):String
	{
		switch (ch)
		{
			case MASTER: return 'Ana Ses';
			case MUSIC:  return 'Menü Müziği';
			case INST:   return 'Enstrüman';
			case VOICES: return 'Vokaller';
			case HIT:    return 'Vuruş Sesleri';
			case UI:     return 'Arayüz';
			case SFX:    return 'Efektler';
			default:     return Std.string(ch);
		}
	}
}
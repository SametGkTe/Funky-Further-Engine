package vslice.funkin;

import vslice.funkin.sound.FlxPartialSound;
import openfl.media.Sound;
import vslice.menus.freeplay.FreeplayState;
import flixel.system.FlxAssets.FlxSoundAsset;

class FunkinSound extends FlxSound
{
	/**
	 * Play a sound effect once, then destroy it.
	 * @param key
	 * @param volume
	 * @return static function construct():FunkinSound
	 */
	public static function playOnce(key:String, volume:Float = 1.0, ?onComplete:Void->Void, ?onLoad:Void->Void):Void
	{
		var result = FunkinSound.load(key, volume, false, true, true, onComplete, onLoad);
	}

	/**
	 * Creates a new `FunkinSound` object synchronously.
	 *
	 * @param embeddedSound   The embedded sound resource you want to play.  To stream, use the optional URL parameter instead.
	 * @param volume          How loud to play it (0 to 1).
	 * @param looped          Whether to loop this sound.
	 * @param group           The group to add this sound to.
	 * @param autoDestroy     Whether to destroy this sound when it finishes playing.
	 *                          Leave this value set to `false` if you want to re-use this `FunkinSound` instance.
	 * @param autoPlay        Whether to play the sound immediately or wait for a `play()` call.
	 * @param onComplete      Called when the sound finished playing.
	 * @param onLoad          Called when the sound finished loading.  Called immediately for succesfully loaded embedded sounds.
	 * @return A `FunkinSound` object, or `null` if the sound could not be loaded.
	 */
	public static function load(embeddedSound:FlxSoundAsset, volume:Float = 1.0, looped:Bool = false, autoDestroy:Bool = false, autoPlay:Bool = false,
			?onComplete:Void->Void, ?onLoad:Void->Void):Null<FunkinSound>
	{
		//? Why was that a thing again?
		// if (SoundMixer.__soundChannels.length >= SoundMixer.MAX_ACTIVE_CHANNELS)
		// {
		// 	FlxG.log.error('FunkinSound could not play sound, channels exhausted! Found ${SoundMixer.__soundChannels.length} active sound channels.');
		// 	return null;
		// }

		var sound:FunkinSound = new FunkinSound(); // pool.recycle(construct);

		// Sets `exists = true` as a side effect.
		if(embeddedSound is String) embeddedSound = Paths.sound(embeddedSound);
		sound.loadEmbedded(embeddedSound, looped, autoDestroy, onComplete);

		//   if (embeddedSound is String)
		//   {
		//     sound._label = embeddedSound;
		//   }
		//   {
		//     sound._label = 'unknown';
		//   }

		if (autoPlay)
			sound.play();
		sound.volume = volume;
		sound.group = FlxG.sound.defaultSoundGroup;
		sound.persist = true;

		// Make sure to add the sound to the list.
		// If it's already in, it won't get re-added.
		// If it's not in the list (it gets removed by FunkinSound.playMusic()),
		// it will get re-added (then if this was called by playMusic(), removed again)
		FlxG.sound.list.add(sound);

		// Call onLoad() because the sound already loaded
		if (onLoad != null && sound._sound != null)
			onLoad();

		return sound;
	}

	static function fileExists(path:String):Bool
	{
		if (path == null || path.length == 0) return false;
		#if sys
		try {
			if (sys.FileSystem.exists(path)) return true;
		} catch (e:Dynamic) {}
		#end
		try {
			var like = NativeFileSystem.getPathLike(path);
			return like != null;
		} catch (e:Dynamic) {}
		return false;
	}

	static function resolveInstPath(songKey:String):String
	{
		var song = Paths.formatToSongPath(songKey);
		var file = 'Inst.' + Paths.SOUND_EXT;
		var rel = 'songs/' + song + '/' + file;
		var candidates:Array<String> = [];

		#if MODS_ALLOWED
		candidates.push(Paths.modFolders(rel));
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			candidates.push(Paths.mods(Mods.currentModDirectory + '/' + rel));
		try
		{
			for (mod in Mods.parseList().enabled)
			{
				if (mod == null || mod.length == 0) continue;
				candidates.push(Paths.mods(mod + '/' + rel));
			}
		}
		catch (e:Dynamic) {}
		candidates.push(Paths.mods(rel));
		#end
		candidates.push('assets/songs/' + song + '/' + file);

		for (path in candidates)
		{
			if (path == null) continue;
			#if sys
			try {
				if (sys.FileSystem.exists(path)) return path;
			} catch (e:Dynamic) {}
			#end
			try {
				var like = NativeFileSystem.getPathLike(path);
				if (like != null) return like;
			} catch (e:Dynamic) {}
		}
		return candidates[candidates.length - 1];
	}

	static var prevSound:Sound = null;
	public static function playMusic(key:String, params:FunkinSoundPlayMusicParams):Bool {
		if(params.pathsFunction == INST){
			var instPath = "";
			
			try{
				instPath = resolveInstPath(key);
				
				var future = FlxPartialSound.partialLoadFromFile(instPath,params.partialParams.start,params.partialParams.end);
				if(future == null){
					trace('Internal failure loading instrumentals for ${key} "${instPath}"');
					return false;
				}
				future.future.onComplete(function(sound:Sound)
					{
						@:privateAccess{
							if(!Std.isOfType(FlxG.state.subState,FreeplayState)) return;
							var fp = cast (FlxG.state.subState,FreeplayState);

							var cap = fp.grpCapsules.activeSongItems[fp.curSelected];
							if(cap.songData == null || cap.songData.getNativeSongId() != key || fp.busy) return;
						}
						FlxG.sound.playMusic(sound,0);
						// #if (lime_vorbis && linux)
						// prevSound?.close();
						// #end
						params.onLoad();
					});
				return true;
			}
			catch (e:Dynamic)
			{
				trace('Internal failure loading instrumentals for ${key}: ' + e);
				return false;
			}
		}
		else{
			var targetPath = key+"/"+key;
			if(key == "freakyMenu") targetPath = "freakyMenu";
			FlxG.sound.playMusic(Paths.music(targetPath),params.startingVolume,params.loop);
			if(params.onLoad!= null)params.onLoad();
			return true;
		}
	}
}

/**
 * Additional parameters for `FunkinSound.playMusic()`
 */
 typedef FunkinSoundPlayMusicParams =
 {
   /**
	* The volume you want the music to start at.
	* @default `1.0`
	*/
   var ?startingVolume:Float;
 
   /**
	* The suffix of the music file to play. Usually for "-erect" tracks when loading an INST file
	* @default ``
	*/
   var ?suffix:String;
 
   /**
	* Whether to override music if a different track is already playing.
	* @default `false`
	*/
   var ?overrideExisting:Bool;
 
   /**
	* Whether to override music if the same track is already playing.
	* @default `false`
	*/
   var ?restartTrack:Bool;
 
   /**
	* Whether the music should loop or play once.
	* @default `true`
	*/
   var ?loop:Bool;
 
   /**
	* Whether to check for `SongMusicData` to update the Conductor with.
	* @default `true`
	*/
   var ?mapTimeChanges:Bool;
 
   /**
	* Which Paths function to use to load a song
	* @default `MUSIC`
	*/
   var ?pathsFunction:PathsFunction;
 
   var ?partialParams:PartialSoundParams;
 
   var ?onComplete:Void->Void;
   var ?onLoad:Void->Void;
 }

 typedef PartialSoundParams =
{
  var loadPartial:Bool;
  var start:Float;
  var end:Float;
}

enum abstract PathsFunction(String)
{
  var MUSIC;
  var INST;
  var VOICES;
  var SOUND;
}

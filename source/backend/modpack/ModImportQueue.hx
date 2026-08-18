package backend.modpack;

import flixel.FlxG;
import flixel.FlxState;
import backend.MusicBeatState;
import mobile.backend.StorageUtil;
import states.PlayState;
import objects.AlertMgr.AlertMsg;

class ModImportQueue
{
	public static var pendingZipPath:String = null;
	public static var deferredNoticeShown:Bool = false;
	static var hooked:Bool = false;
	static var pollElapsed:Float = 0;

	public static function hook():Void
	{
		if (hooked)
			return;
		hooked = true;

		FlxG.signals.focusGained.add(function()
		{
			poll();
			considerPresenting();
		});
		FlxG.signals.postStateSwitch.add(function()
		{
			poll();
			considerPresenting();
		});

		// Bazı Android cihazlarında focusGained, share activity dönüşünde güvenilir
		// çalışmıyor. Düşük frekanslı poll tüm menü/substate'lerde intent'i yakalar.
		FlxG.signals.postUpdate.add(function()
		{
			pollElapsed += FlxG.elapsed;
			if (pollElapsed < 0.5) return;
			pollElapsed = 0;
			poll();
			considerPresenting();
		});
	}

	public static function poll():Void
	{
		#if android
		try
		{
			var jni = lime.system.JNI.createStaticMethod('furtherengine/util/ShareImportUtil', 'consumeSharedZip', '()Ljava/lang/String;');
			if (jni != null)
			{
				var path:Dynamic = jni();
				if (path != null)
				{
					var text:String = StringTools.trim(Std.string(path));
					if (text.length > 0)
						pendingZipPath = text;
				}
			}
		}
		catch (e:Dynamic)
		{
			trace('[ModImportQueue] poll failed: $e');
		}
		#end
	}

	public static function isRealGameplay():Bool
	{
		var state:FlxState = FlxG.state;
		if (state == null)
			return false;

		// Yalnızca gerçek PlayState ertelenir. Pause ve GameOver da PlayState'in
		// substate'leri olduğundan bu kontrol tarafından kapsanır.
		if (Std.isOfType(state, PlayState))
			return true;

		if (state.subState != null)
		{
			if (Std.isOfType(state.subState, substates.PauseSubState))
				return true;
			if (Std.isOfType(state.subState, substates.GameOverSubstate))
				return true;
		}

		return false;
	}

	public static function shouldWaitSilently():Bool
	{
		var state:FlxState = FlxG.state;
		if (state == null)
			return true;
		if (Std.isOfType(state, states.ModImportState))
			return true;
		#if COPYSTATE_ALLOWED
		if (Std.isOfType(state, states.CopyState))
			return true;
		#end
		if (Std.isOfType(state, states.LoadingState))
			return true;
		return false;
	}

	public static function considerPresenting():Void
	{
		if (pendingZipPath == null || StringTools.trim(pendingZipPath) == '')
			return;

		if (isRealGameplay())
		{
			if (!deferredNoticeShown)
			{
				deferredNoticeShown = true;
				AlertMsg.show(
					Language.getPhrase('mod_import_title', 'MOD İÇE AKTARMA'),
					Language.getPhrase('mod_import_deferred', 'Mod ZIP alındı. Şarkı bittiğinde kurulum ekranı açılacak.'),
					7,
					AlertMsg.COLOR_INFO
				);
			}
			return;
		}

		if (shouldWaitSilently())
			return;

		openInstaller();
	}

	public static function openInstaller():Void
	{
		var path:String = pendingZipPath;
		if (path == null)
			return;

		pendingZipPath = null;
		deferredNoticeShown = false;
		MusicBeatState.switchState(new states.ModImportState(path));
	}

	public static function modsDirectory():String
	{
		#if android
		return StorageUtil.getModsDirectory();
		#elseif sys
		return haxe.io.Path.addTrailingSlash(Sys.getCwd()) + 'mods/';
		#else
		return 'mods/';
		#end
	}
}

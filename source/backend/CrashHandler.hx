package backend;

import openfl.events.UncaughtErrorEvent;
import openfl.events.ErrorEvent;
import openfl.errors.Error;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;
using flixel.util.FlxArrayUtil;

/**
 * Further Engine crash handler.
 * Tam ekranı zorla kapatır, logu kaydeder ve mümkünse kullanıcıyı oyun içi
 * CrashReportState'e aktarır. Ekran açılamazsa işletim sistemi popup'ına düşer.
 *
 * @author YoshiCrafter29, Ne_Eo, MAJigsaw77 and Homura Akemi (HomuHomu833)
 */
class CrashHandler
{
	static var handlingCrash:Bool = false;

	public static function init():Void
	{
		openfl.Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
		#if (cpp && !android)
		untyped __global__.__hxcpp_set_critical_error_handler(onError);
		#elseif hl
		hl.Api.setErrorHandler(onError);
		#end
	}

	private static function onUncaughtError(e:UncaughtErrorEvent):Void
	{
		e.preventDefault();
		e.stopPropagation();
		e.stopImmediatePropagation();

		var message:String = Std.string(e.error);
		if (Std.isOfType(e.error, Error))
			message = cast(e.error, Error).message;
		else if (Std.isOfType(e.error, ErrorEvent))
			message = cast(e.error, ErrorEvent).text;

		var stackLabelArr:Array<String> = [];
		for (entry in haxe.CallStack.exceptionStack())
		{
			switch (entry)
			{
				case CFunction:
					stackLabelArr.push('Non-Haxe (C) Function');
				case Module(c):
					stackLabelArr.push('Module $c');
				case FilePos(parent, file, line, col):
					switch (parent)
					{
						case Method(cla, func): stackLabelArr.push('${file.replace('.hx', '')}.$func() [line $line]');
						case _: stackLabelArr.push('${file.replace('.hx', '')} [line $line]');
					}
				case LocalFunction(v):
					stackLabelArr.push('Local Function $v');
				case Method(cl, method):
					stackLabelArr.push('$cl - $method');
			}
		}

		presentCrash('$message\n${stackLabelArr.join('\r\n')}');
	}

	#if (cpp || hl)
	private static function onError(message:Dynamic):Void
	{
		var log:Array<String> = [];
		if (message != null && Std.string(message).length > 0) log.push(Std.string(message));
		log.push(haxe.CallStack.toString(haxe.CallStack.exceptionStack(true)));
		presentCrash(log.join('\n'));
	}
	#end

	static function presentCrash(report:String):Void
	{
		// Crash ekranının kendisi çökerse sonsuz hata döngüsüne girme.
		if (handlingCrash)
		{
			forceWindowed();
			CoolUtil.showPopUp(report, 'Kritik Hata!');
			#if DISCORD_ALLOWED DiscordClient.shutdown(); #end
			lime.system.System.exit(1);
			return;
		}
		handlingCrash = true;

		forceWindowed();
		var logPath:String = '';
		#if sys
		logPath = saveErrorMessage(report);
		#end
		#if DISCORD_ALLOWED DiscordClient.shutdown(); #end

		try
		{
			if (FlxG.game == null) throw 'FlxGame henüz hazır değil.';
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.switchState(new states.CrashReportState(report, logPath));
		}
		catch (stateError:Dynamic)
		{
			var fallback = report + '\n\nCrash ekranı açılamadı: ' + Std.string(stateError);
			CoolUtil.showPopUp(fallback, 'Kritik Hata!');
			lime.system.System.exit(1);
		}
	}

	static function forceWindowed():Void
	{
		try
		{
			if (FlxG.game != null) FlxG.fullscreen = false;
			var window = lime.app.Application.current.window;
			if (window != null) window.fullscreen = false;
		}
		catch (e:Dynamic)
			trace('[CrashHandler] Tam ekrandan çıkılamadı: $e');
	}

	#if sys
	private static function saveErrorMessage(message:String):String
	{
		var folder:String = #if android StorageUtil.getExternalStorageDirectory() + #else Sys.getCwd() + #end 'logs/';
		try
		{
			if (!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
			var path = folder + Date.now().toString().replace(' ', '-').replace(':', "'") + '.txt';
			File.saveContent(path, message);
			return path;
		}
		catch (e:haxe.Exception)
		{
			trace('Couldn\'t save error message. (${e.message})');
			return '';
		}
	}
	#end
}

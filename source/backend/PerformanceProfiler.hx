package backend;

class PerformanceProfiler
{
	public static function apply(profile:PerformanceProfile, ?targetFps:Int = 0):Void
	{
		var prefs = ClientPrefs.data;
		switch profile
		{
			case PERFORMANCE:
				prefs.lowQuality       = true;
				prefs.shaders          = false;
				prefs.antialiasing     = false;
				prefs.camZooms         = false;
				prefs.camMovement      = false;
				prefs.cacheOnGPU       = false;
				prefs.holdSplashAlpha  = 0.3;
				prefs.splashAlpha      = 0.4;
				prefs.vsliceSmoothBar  = false;
				prefs.vsliceResults    = false;
				prefs.vsliceFreeplayColors = false;
				prefs.loadThreads      = 2;
				prefs.framerate        = targetFps > 0 ? targetFps : (#if mobile 60 #else 60 #end);
				Log.info('perf', 'Performans uygulandı (low quality, ${prefs.framerate} FPS)');

			case BALANCED:
				prefs.lowQuality       = false;
				prefs.shaders          = true;
				prefs.antialiasing     = true;
				prefs.camZooms         = true;
				prefs.camMovement      = true;
				prefs.cacheOnGPU       = #if mobile false #else true #end;
				prefs.holdSplashAlpha  = #if mobile 0.45 #else 0.6 #end;
				prefs.splashAlpha      = 0.6;
				prefs.vsliceSmoothBar  = true;
				prefs.vsliceResults    = true;
				prefs.vsliceFreeplayColors = true;
				prefs.loadThreads      = #if mobile 2 #else 4 #end;
				prefs.framerate        = targetFps > 0 ? targetFps : 60;
				Log.info('perf', 'Dengeli profil uygulandı');

			case HIGH:
				prefs.lowQuality       = false;
				prefs.shaders          = true;
				prefs.antialiasing     = true;
				prefs.camZooms         = true;
				prefs.camMovement      = true;
				prefs.cacheOnGPU       = true;
				prefs.holdSplashAlpha  = 0.7;
				prefs.splashAlpha      = 0.8;
				prefs.vsliceSmoothBar  = true;
				prefs.vsliceResults    = true;
				prefs.vsliceFreeplayColors = true;
				prefs.vsliceSpecialCards = true;
				prefs.vsliceNaughtyness = true;
				prefs.loadThreads      = Std.int(Math.min(4, Math.max(2, CoolUtil.getCPUThreadsCount() - 1)));
				var refresh = 60;
				#if (!html5 && !switch)
				try { refresh = Std.int(FlxMath.bound(FlxG.stage.application.window.displayMode.refreshRate, 60, 240)); } catch (e:Dynamic) {}
				#end
				prefs.framerate = targetFps > 0 ? targetFps : refresh;
				Log.infoLazy('perf', function() return 'Yüksek profil uygulandı (' + prefs.framerate + ' FPS, ' + prefs.loadThreads + ' thread)');
		}

		prefs.vsync = (profile == HIGH);
		ClientPrefs.saveSettings();
		applyRuntimeSettings();
	}

	public static function applyRuntimeSettings():Void
	{
		var prefs = ClientPrefs.data;
		#if (!html5 && !switch)
		try
		{
			FlxG.stage.window.vsync = prefs.vsync;
		}
		catch (e:Dynamic) {}
		#end

		if (prefs.fpsRework)
			FlxG.stage.window.frameRate = prefs.framerate;
		else
		{
			FlxG.updateFramerate = prefs.framerate;
			FlxG.drawFramerate = prefs.framerate;
		}
	}

	public static function detectBest():PerformanceProfile
	{
		try
		{
			var threads = CoolUtil.getCPUThreadsCount();
			#if mobile
			if (threads <= 4) return PERFORMANCE;
			if (threads <= 6) return BALANCED;
			return HIGH;
			#elseif desktop
			if (threads <= 2) return PERFORMANCE;
			if (threads <= 6) return BALANCED;
			return HIGH;
			#elseif web
			return BALANCED;
			#else
			return BALANCED;
			#end
		}
		catch (e:Dynamic)
		{
			return BALANCED;
		}
	}
}
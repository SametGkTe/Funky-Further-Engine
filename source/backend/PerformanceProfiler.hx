package backend;

class PerformanceProfiler
{
	public static function apply(profile:PerformanceProfile):Void
	{
		var prefs = ClientPrefs.data;
		switch profile
		{
			case PERFORMANCE:
				prefs.lowQuality   = true;
				prefs.shaders      = false;
				prefs.antialiasing = false;
				Log.info('perf', 'Düşük kalite profili uygulandı');

			case BALANCED, HIGH:
				prefs.lowQuality   = false;
				prefs.shaders      = true;
				prefs.antialiasing = true;
				Log.info('perf', 'Görsel ayarlar tam açık uygulandı');
		}

		prefs.camZooms             = true;
		prefs.camMovement          = true;
		prefs.vsliceResults        = true;
		prefs.vsliceSmoothBar      = true;
		prefs.vsliceFreeplayColors = true;
		prefs.holdSplashAlpha      = #if mobile 0.45 #else 0.6 #end;
		prefs.splashAlpha          = 0.6;

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
}
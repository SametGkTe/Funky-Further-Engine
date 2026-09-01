package vslice.menus.components.crash;

import vslice.menus.components.crash.UserErrorSubstate.CrashData;
import vslice.compatibility.VsliceOptions;
import vslice.compatibility.ModsHelper;
import flixel.FlxState;
import openfl.events.ErrorEvent;
import openfl.display.BitmapData;
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;

class CrashState extends FlxState
{
	var screenBelow:BitmapData;
	var stateCrash:CrashData;

	public function new(crash:CrashData)
	{
		this.stateCrash = crash;
		super();
	}

	override function create()
	{
		if (Main.debugDisplay != null)
			Main.debugDisplay.visible = false;

		super.create();
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end
		var previousScreen = new FlxSprite(0, 0, BitmapData.fromImage(FlxG.stage.window.readPixels()));
		previousScreen.setGraphicSize(FlxG.width,FlxG.height);
		previousScreen.updateHitbox();
		add(previousScreen);
		openSubState(new UserErrorSubstate(stateCrash,true));
		
	}
	#if sys
        static function saveError(error:vslice.menus.components.crash.UserErrorSubstate.CrashData)
        {
            var errMsg = "";
            var dateNow:String = error.date;
            var star = #if CHECK_FOR_UPDATES "" #else "*" #end;
            dateNow = dateNow.replace(' ', '_');
            dateNow = dateNow.replace(':', "'");
            errMsg += 'P-Slice ${MainMenuState.pSliceVersion}$star\n';
            errMsg += '\nUncaught Error: ' + error.message + "\n";
            for (x in error.extendedTrace)
            {
                errMsg += x + "\n";
            }
            errMsg += '----------\n';
            errMsg += 'Active mod: ${error.activeMod}\n';
            errMsg += 'Platform: ${error.systemName}\n';
            errMsg += '\n';
            errMsg += '\nPlease report this error to the GitHub page: https://github.com/Psych-Slice/P-Slice\n\n> Crash Handler written by: sqirra-rng';
    
            var path = './crash/' + 'PSlice_' + dateNow + '.txt';
            File.saveContent(path, errMsg + '\n');
            Sys.println(errMsg);
        }
    #end
	override function update(elapsed:Float)
	{
		super.update(elapsed);
	}

}

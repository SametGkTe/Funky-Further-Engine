package;

import online.GameClient;
import states.MainMenuState;
import externs.WinAPI;
import haxe.Exception;
import flixel.graphics.FlxGraphic;

import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import lime.app.Application;
import states.TitleState;

#if linux
import lime.graphics.Image;
#end

import sys.FileSystem;

//crash handler stuff
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
import sys.io.File;
import sys.io.Process;

#if (linux && !debug)
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end

class Main extends Sprite
{
	var game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: TitleState, // initial game state
		zoom: -1.0, // game state bounds
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var fpsVar:FPS;

	public static final PSYCH_ONLINE_VERSION:String = "0.13.3";
	public static final CLIENT_PROTOCOL:Float = 10;
	public static final NETWORK_PROTOCOL:Float = 8;
	public static final GIT_COMMIT:String = online.backend.Macros.getGitCommitHash();
	public static final LOW_STORAGE:Bool = online.backend.Macros.hasNoCapacity();
	
	/**
	 * ! ! ! ! ! !
	 * 
	 * ANY TRY TO CIRCUMVENT THE PROPER WORKING OF THIS VARIABLE
	 * WILL RESULT IN THE SOURCE/BUILD TO BE REPORTED
	 * 
	 * ! ! ! ! ! !
	 */
	public static var UNOFFICIAL_BUILD:Bool = Main.LOW_STORAGE;

	public static var wankyUpdate:String = null;
	public static var updatePageURL:String = '';
	public static var updateVersion:String = '';
	public static var repoHost:String = '';

	public static var view3D:online.away.View3DHandler;
	public static var onlineTweaks:OnlineTweaks;

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		#if !mobile
		if (Path.normalize(Sys.getCwd()) != Path.normalize(lime.system.System.applicationDirectory)) {
			Sys.setCwd(lime.system.System.applicationDirectory);

			if (Path.normalize(Sys.getCwd()) != Path.normalize(lime.system.System.applicationDirectory)) {
				Lib.application.window.alert("Your path is either not run from the game directory,\nor contains illegal UTF-8 characters!\n\nRun from: "
					+ Sys.getCwd()
					+ "\nExpected path: "
					+ lime.system.System.applicationDirectory,
					"Invalid Runtime Path!");
				Sys.exit(1);
			}
		}
		#end
		
		Lib.current.addChild(view3D = new online.away.View3DHandler());
		Lib.current.addChild(new online.gui.Alert());
		Lib.current.addChild(new online.gui.LoadingScreen());
		
		var daMain = new Main();
		Lib.current.addChild(daMain);
		Lib.current.setChildIndex(daMain, Lib.current.getChildIndex(view3D) + 1);
		Lib.current.addChild(new online.gui.sidebar.SideUI());
		toggleTweakMenu(ClientPrefs.data.showTweakMenu);
	}
	
	public static function toggleTweakMenu(show:Bool):Void {
		if (show) {
			if (onlineTweaks == null) {
				onlineTweaks = new OnlineTweaks('TWEAKS');
				Lib.current.stage.addChild(onlineTweaks);
			}
		} else {
			if (onlineTweaks != null) {
				if (Lib.current.stage.contains(onlineTweaks)) {
					Lib.current.stage.removeChild(onlineTweaks);
				}
				onlineTweaks = null;
			}
		}
	}

	public function new()
	{
		super();
		#if mobile
		#if android
		StorageUtil.initExternalStorageDirectory(); //do not make this jobs everytime
		StorageUtil.requestPermissions();
		StorageUtil.chmod(2777, AndroidContext.getExternalFilesDir() + '/mods');
		StorageUtil.chmod(2777, AndroidContext.getExternalFilesDir() + '/replays');
		StorageUtil.chmod(2777, AndroidContext.getExternalFilesDir() + '/core'); //allow ability to change core files of engine (saveData)
		StorageUtil.copySpesificFileFromAssets('mobile/storageModes.txt', StorageUtil.getCustomStoragePath());
		#end
		Sys.setCwd(StorageUtil.getStorageDirectory());
		#end
		backend.CrashHandler.init();

		#if (cpp && windows)
		backend.Native.fixScaling();
		#end

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		#if (openfl <= "9.2.0")
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (game.zoom == -1.0)
		{
			var ratioX:Float = stageWidth / game.width;
			var ratioY:Float = stageHeight / game.height;
			game.zoom = Math.min(ratioX, ratioY);
			game.width = Math.ceil(stageWidth / game.zoom);
			game.height = Math.ceil(stageHeight / game.zoom);
		}
		#else
		if (game.zoom == -1.0)
			game.zoom = 1.0;
		#end

		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if VIDEOS_ALLOWED
		hxvlc.util.Handle.init(#if (hxvlc >= "1.8.0")  ['--no-lua'] #end);
		#end

		CoolUtil.setDarkMode(true);

		FunkinFileSystem.validateLimeCache();

		#if lumod
		Lumod.addons.push(online.backend.LuaModuleSwap.LumodModuleAddon);
		Lumod.scriptPathHandler = scriptPath -> {
			var defaultPath:String = 'lumod/' + scriptPath;

			// check if script exists in any of loaded mods
			var path:String = Paths.modFolders(defaultPath);
			if (FunkinFileSystem.exists(path))
				return path;

			return defaultPath;
		}
		Lumod.classResolver = Deflection.resolveClass;
		Lumod.initializeLuaCallbacks = false;
		#end

		#if hl
		sys.ssl.Socket.DEFAULT_VERIFY_CERT = false;
		#end
	
		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();
		addChild(new FlxGame(game.width, game.height, game.initialState, #if (flixel < "5.0.0") game.zoom, #end game.framerate, game.framerate, game.skipSplash, game.startFullscreen));

		fpsVar = new FPS(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.data.showFPS;
		}

		#if (linux || mac)
		final icon:Image = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end
		
		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = #if mobile 30 #else 60 #end;
		#if web
		FlxG.keys.preventDefaultKeys.push(TAB);
		#else
		FlxG.keys.preventDefaultKeys = [TAB];
		#end

		#if android FlxG.android.preventDefaultKeys = [BACK]; #end

		#if DISCORD_ALLOWED
		DiscordClient.initialize();
		#end

		#if mobile
		ScreenUtil.wideScreen.enabled = ClientPrefs.data.wideScreen;
		#end

		// shader coords fix
		FlxG.signals.gameResized.add(function (w, h) {
			if(fpsVar != null)
				fpsVar.positionFPS(10, 3, Math.min(w / FlxG.width, h / FlxG.height));
			 if (FlxG.cameras != null) {
			   for (cam in FlxG.cameras.list) {
				@:privateAccess
				if (cam != null && cam.filters != null)
					resetSpriteCache(cam.flashSprite);
			   }
			 }

			 if (FlxG.game != null)
			 resetSpriteCache(FlxG.game);
		});

		//ONLINE STUFF, BELOW CODE USE FOR BACKPORTING

		#if CHECK_FOR_UPDATES
		if (ClientPrefs.data.checkForUpdates) {
			trace('checking for update');
			// should've done that earlier
			var response = new online.http.HTTPClient("https://api.github.com/repos/Snirozu/Funkin-Psych-Online/releases/latest").request();
			Main.repoHost = 'github';

			if (response.isFailed()) {
				response = new online.http.HTTPClient("https://codeberg.org/api/v1/repos/Snirozu/Funkin-Psych-Online/releases/latest").request();
				Main.repoHost = 'codeberg';
			}

			if (!response.isFailed()) {
				var latestRelease = haxe.Json.parse(response.getString());
				Main.updateVersion = latestRelease.tag_name;
				Main.updatePageURL = latestRelease.html_url;
				var curVersion:String = Main.PSYCH_ONLINE_VERSION.trim();
				trace('version online: ' + Main.updateVersion + ', your version: ' + curVersion);

				var updatVer:Array<Int> = Main.updateVersion.split('.').map(s -> {
					return Std.parseInt(s);
				});
				var curVer:Array<Int> = curVersion.split('.').map(s -> {
					return Std.parseInt(s);
				});

				if (curVersion.contains('-rc.')) {
					var candiVer = curVersion.split('-rc.');
					Main.wankyUpdate = 'Runnning on a\nRelease Candidate No. ' + candiVer[1] + '\nto version: ' + candiVer[0];
					lime.app.Application.current.window.title = lime.app.Application.current.window.title + ' [DEV]';
					states.TitleState.inDev = true;
				}
				else {
					trace('comparing ' + updatVer + ' > ' + curVer);
					for (i => num in updatVer) {
						if (num < curVer[i] ?? 0) {
							states.TitleState.inDev = true;
							trace('running on indev build! [' + i + "]");
							lime.app.Application.current.window.title = lime.app.Application.current.window.title + ' [DEV]';
							break;
						}
						if (num > curVer[i] ?? 0) {
							var updateTitle = '';
							switch (i) {
								case 0:
									// api breaking functionality or overhauls
									updateTitle = 'HUGE update';
								case 1:
									// new features with non breaking changes
									updateTitle = 'major version';
								default:
									// bug fixes and patches
									updateTitle = 'minor version';
							}
							Main.wankyUpdate = 'A new ${updateTitle} is available!\n(Click here to update)';
							states.TitleState.mustUpdate = true;
							trace('update version is newer! [' + i + "]");
							break;
						}
						if (i == updatVer.length - 1) {
							trace('running on latest version!');
						}
					}
				}
			}
			else {
				Main.repoHost = null;
				trace(response.getError());
			}
		}
		trace(Main.repoHost);
		#end

		GameClient.updateAddresses();

		online.mods.ModDownloader.checkDeleteDlDir();

		addChild(new online.gui.DownloadAlert.DownloadAlerts());

		FlxG.plugins.add(new online.backend.Waiter());

		online.backend.Thread.repeat(() -> {
			try {
				online.network.FunkinNetwork.ping();
			}
			catch (exc) {
				trace(exc);
			}
		}, 60, _ -> {}); // ping the server every minute
		
		//for some reason only cancels 2 downloads
		Lib.application.window.onClose.add(() -> {
			#if DISCORD_ALLOWED
			DiscordClient.shutdown();
			#end
			online.mods.ModDownloader.cancelAll();
			online.mods.ModDownloader.checkDeleteDlDir();
			try {
				GameClient.leaveRoom();
			} catch (exc) {}
			online.network.Auth.saveClose();
		});

		#if !mobile
		Lib.application.window.onDropFile.add(path -> {
			if (FileSystem.isDirectory(path))
				return;

			if (path.endsWith(".json") && (path.contains("-chart") || path.contains("-metadata"))) {
				online.util.vslice.VUtil.convertVSlice(path);
			}
			else {
				online.backend.Thread.run(() -> {
					online.gui.LoadingScreen.toggle(true);
					online.mods.OnlineMods.installMod(path);
					online.gui.LoadingScreen.toggle(false);
				});
			}
		});
		#end

		// clear messages before the current state gets destroyed and replaced with another
		FlxG.signals.preStateSwitch.add(() -> {
			GameClient.clearOnMessage();
		});

		FlxG.signals.postGameReset.add(() -> {
			online.gui.Alert.alert('Warning!', 'The game has been resetted, and there may occur visual bugs with the sidebar!\n\nIt\'s recommended to restart the game instead.');
		});
		
		#if HSCRIPT_ALLOWED
		FlxG.signals.postStateSwitch.add(() -> {
			online.backend.SyncScript.dispatch("switchState", [FlxG.state]);

			FlxG.state.subStateOpened.add(substate -> {
				online.backend.SyncScript.dispatch("openSubState", [substate]);
			});
		});

		FlxG.signals.postUpdate.add(() -> {
			if (online.backend.SyncScript.activeUpdate)
				online.backend.SyncScript.dispatch("update", [FlxG.elapsed]);
		});

		online.backend.SyncScript.initScript();

		#if interpret
		online.backend.InterpretLiveReload.init();
		#end
		#end
	}

	static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	public static function getTime():Float {
		#if flash
		return flash.Lib.getTimer();
		#elseif ((js && !nodejs) || electron)
		return js.Browser.window.performance.now();
		#elseif sys
		return Sys.time() * 1000;
		#elseif (lime_cffi && !macro)
		@:privateAccess
		return cast lime._internal.backend.native.NativeCFFI.lime_system_get_timer();
		#elseif cpp
		return untyped __global__.__time_stamp() * 1000;
		#else
		return 0;
		#end
	}
}

package funkin.backend.scripting;

#if (SCRIPTING_ALLOWED || HSC_ALLOWED)
import flixel.FlxState;
import backend.MusicBeatState;
import backend.FunkinFileSystem;
import states.PlayState;
import flixel.util.FlxColor;
import haxe.io.Path;
import haxe.exceptions.NotImplementedException;
import haxe.PosInfos;
import openfl.utils.Assets;
import sys.io.File;
import sys.FileSystem;
import flixel.FlxG;
import flixel.FlxBasic;
import cne.compatibility.codenamecrew.hscript.Expr.Error;
import cne.compatibility.codenamecrew.hscript.*;
import cne.compatibility.codenamecrew.hscript.Parser;
import cne.compatibility.codenamecrew.hscript.Interp;
import cne.compatibility.codenamecrew.hscript.Expr;
import lime.app.Application;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import cne.compatibility.codenamecrew.hscript.IHScriptCustomConstructor;
import flixel.util.FlxStringUtil;
import funkin.backend.scripting.events.CancellableEvent;
import flixel.util.FlxSave;
/**
	Handles Codename Engine's HScript Improved for PsychExtended Online.
**/
class HScript extends Script {
	public var interp:Interp;
	public var parser:Parser;
	public var expr:Expr;
	public var code:String = null;
	//public var folderlessPath:String;

	/** Global callbacks registered by scripts via createGlobalCallback; applied to every CNE script. */
	public static var globalCallbacks:Map<String, Dynamic> = new Map<String, Dynamic>();
	var __importedPaths:Array<String>;

	public static function initParser() {
		var parser = new Parser();
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
		parser.preprocessorValues = Script.getDefaultPreprocessors();
		return parser;
	}

	public override function onCreate(path:String) {
		super.onCreate(path);

		interp = new Interp();

		try {
			if(FunkinFileSystem.exists(rawPath)) code = FunkinFileSystem.getText(rawPath);
		} catch(e) CoolUtil.showPopUp('Error while reading $path: ${Std.string(e)}', "HScript Improved");

		parser = initParser();
		//folderlessPath = Path.directory(path);
		__importedPaths = [path];

		interp.errorHandler = _errorHandler;
		interp.warnHandler = _warnHandler;
		interp.importFailedCallback = importFailedCallback;
		interp.staticVariables = Script.staticVariables;
		interp.allowStaticVariables = interp.allowPublicVariables = true;

		interp.variables.set("trace", Reflect.makeVarArgs((args) -> {
			var v:String = Std.string(args.shift());
			for (a in args) v += ", " + Std.string(a);
			haxe.Log.trace(Std.string(v));
		}));

		#if GLOBAL_SCRIPT
		funkin.backend.scripting.GlobalScript.call("onScriptCreated", [this, "hscript"]);
		#end
		loadFromString(code);
	}

	public override function loadFromString(code:String) {
		try {
			if (code != null && code.trim() != "")
				expr = parser.parseString(code, fileName);
		} catch(e:Error) {
			_errorHandler(e);
		} catch(e) {
			_errorHandler(new Error(ECustom(e.toString()), 0, 0, fileName, 0));
		}

		return this;
	}

	private function importFailedCallback(cl:Array<String>, ?asName:String):Bool {
		if(_importFailedCallback(cl, "source/") || _importFailedCallback(cl, "")) {
			return true;
		}
		return false;
	}
	private function _importFailedCallback(cl:Array<String>, prefix:String):Bool {
		var assetsPath = 'assets/$prefix${cl.join("/")}';
		for(hxExt in ["hx", "hscript", "hsc", "hxs", "hxc"]) {
			var p = '$assetsPath.$hxExt';
			if (__importedPaths.contains(p))
				return true; // no need to reimport again
			if (FunkinFileSystem.exists(p)) {
				var code = FunkinFileSystem.getText(p);
				var expr:Expr = null;
				try {
					if (code != null && code.trim() != "") {
						parser.line = 1; // fun fact: this is all you need to reuse a parser without issues. all the other vars get reset on parse.
						expr = parser.parseString(code, cl.join("/") + "." + hxExt);
					}
				} catch(e:Error) {
					_errorHandler(e);
				} catch(e) {
					_errorHandler(new Error(ECustom(e.toString()), 0, 0, fileName, 0));
				}
				if (expr != null) {
					@:privateAccess
					interp.exprReturn(expr);
					__importedPaths.push(p);
				}
				return true;
			}
		}
		return false;
	}

	private function _errorHandler(error:Error) {
		var fileName = error.origin;
		var oldfn = '$fileName:${error.line}: ';
		if(remappedNames.exists(fileName))
			fileName = remappedNames.get(fileName);
		var fn = '$fileName:${error.line}: ';
		var err = error.toString();
		while(err.startsWith(oldfn) || err.startsWith(fn)) {
			if (err.startsWith(oldfn)) err = err.substr(oldfn.length);
			if (err.startsWith(fn)) err = err.substr(fn.length);
		}

		//trace("ERROR Caused in " + fn + err);
		DebugText.addTextToDebug(fn + err, FlxColor.RED);
	}

	private function _warnHandler(error:Error) {
		var fileName = error.origin;
		var oldfn = '$fileName:${error.line}: ';
		if(remappedNames.exists(fileName))
			fileName = remappedNames.get(fileName);
		var fn = '$fileName:${error.line}: ';
		var err = error.toString();
		while(err.startsWith(oldfn) || err.startsWith(fn)) {
			if (err.startsWith(oldfn)) err = err.substr(oldfn.length);
			if (err.startsWith(fn)) err = err.substr(fn.length);
		}

		trace("WARN Caused in " + err);
		DebugText.addTextToDebug(fn + err, FlxColor.YELLOW);
	}

	public override function setParent(parent:Dynamic) {
		interp.scriptObject = parent;
	}

	public override function onLoad() {
		@:privateAccess
		interp.execute(parser.mk(EBlock([]), 0, 0));
		if (expr != null) {
			interp.execute(expr);
			call("new", []);
		}

		#if GLOBAL_SCRIPT
		funkin.backend.scripting.GlobalScript.call("onScriptSetup", [this, "hscript"]);
		#end
	}

	public override function reload() {
		// save variables

		interp.allowStaticVariables = interp.allowPublicVariables = false;
		var savedVariables:Map<String, Dynamic> = [];
		for(k=>e in interp.variables) {
			if (!Reflect.isFunction(e)) {
				savedVariables[k] = e;
			}
		}
		var oldParent = interp.scriptObject;
		onCreate(path);

		for(k=>e in Script.getDefaultVariables(this))
			set(k, e);

		load();
		setParent(oldParent);

		for(k=>e in savedVariables)
			interp.variables.set(k, e);

		interp.allowStaticVariables = interp.allowPublicVariables = true;
	}

	private override function onCall(funcName:String, parameters:Array<Dynamic>):Dynamic {
		if (interp == null) return null;
		if (!interp.variables.exists(funcName)) return null;

		var func = interp.variables.get(funcName);
		if (func != null && Reflect.isFunction(func))
			return Reflect.callMethod(null, func, parameters);

		return null;
	}

	public override function get(val:String):Dynamic {
		return interp.variables.get(val);
	}

	public override function set(val:String, value:Dynamic) {
		interp.variables.set(val, value);
	}

	/* Some PlayState things */
	public override function setupPlayState() {
		set('setVar', function(name:String, value:Dynamic) {
			PlayState.instance.variables.set(name, value);
			return value;
		});
		set('getVar', function(name:String) {
			var result:Dynamic = null;
			if(PlayState.instance.variables.exists(name)) result = PlayState.instance.variables.get(name);
			return result;
		});
		set('removeVar', function(name:String)
		{
			if(PlayState.instance.variables.exists(name))
			{
				PlayState.instance.variables.remove(name);
				return true;
			}
			return false;
		});

		set('debugPrint', function(text:String, ?color:FlxColor = null) {
			if(color == null) color = FlxColor.WHITE;
			PlayState.instance.addTextToDebug(text, color);
		});

		// Callbacks registered by other scripts (via createGlobalCallback) apply to this one too
		for (name => func in globalCallbacks)
			set(name, func);

		// For adding your own callbacks (shared across all running CNE scripts)
		set('createGlobalCallback', function(name:String, func:Dynamic)
		{
			globalCallbacks.set(name, func);
			var state = PlayState.instance;
			if (state != null && state.cneScripts != null)
				for (script in state.cneScripts.scripts)
					if (script != null && script != this)
						script.set(name, func);
		});
	}

	public override function setPublicMap(map:Map<String, Dynamic>) {
		this.interp.publicVariables = map;
	}
}

class Script extends FlxBasic implements IFlxDestroyable {
	/**
	 * Use "static var thing = true;" in hscript to use those!!
	 * are reset every menu switch so once you're done with them make sure to make them null!!
	 */
	public static var staticVariables:Map<String, Dynamic> = [];

	public static function getDefaultVariables(?script:Script):Map<String, Dynamic> {
		return [
			/* Psych Extended related stuff */
			"Mods"		  => backend.Mods,
			"AttachedSprite"		  => objects.AttachedSprite,
			"ClientPrefs"		  => backend.ClientPrefs,
			"FunkinFileSystem"		  => backend.FunkinFileSystem,

			/* Sys related stuff */
			"File"		  => File,
			"Process"		  => sys.io.Process,
			"FileSystem"		  => FileSystem,
			"Thread"		  => getMacroAbstractClass("sys.thread.Thread"),
			"Mutex"		  => getMacroAbstractClass("sys.thread.Mutex"),

			/* Haxe related stuff */
			"Std"			   => Std,
			"Math"			  => Math,
			"Type"			  => Type,
			"Date"			  => Date,
			"Array"			  => Array,
			"Reflect"			  => Reflect,
			"StringTools"	   => StringTools,
			"Json"			  => haxe.Json,
			"Access"			  => getMacroAbstractClass("haxe.xml.Access"),

			/* OpenFL & Lime related stuff */
			"Assets"			=> openfl.utils.Assets,
			"TextField"		  => openfl.text.TextField,
			"Application"	   => lime.app.Application,
			"Main"				=> Main,
			"window"			=> lime.app.Application.current.window,

			/* Flixel related stuff */
			"FlxG"			  => flixel.FlxG,
			"FlxSprite"		 => flixel.FlxSprite,
			"FlxBasic"		  => flixel.FlxBasic,
			"FlxCamera"		 => flixel.FlxCamera,
			"state"			 => flixel.FlxG.state,
			"FlxEase"		   => flixel.tweens.FlxEase,
			"FlxTween"		  => flixel.tweens.FlxTween,
			"FlxSound"		  => flixel.sound.FlxSound,
			"FlxAssets"		 => flixel.system.FlxAssets,
			"FlxMath"		   => flixel.math.FlxMath,
			"FlxGroup"		  => flixel.group.FlxGroup,
			"FlxTypedGroup"	 => flixel.group.FlxGroup.FlxTypedGroup,
			"FlxSpriteGroup"	=> flixel.group.FlxSpriteGroup,
			"FlxTypeText"	   => flixel.addons.text.FlxTypeText,
			"FlxText"		   => flixel.text.FlxText,
			"FlxTimer"		  => flixel.util.FlxTimer,
			"FlxFlicker"		  => flixel.effects.FlxFlicker,
			"FlxBackdrop"		  => flixel.addons.display.FlxBackdrop,
			"FlxOgmo3Loader"		  => flixel.addons.editors.ogmo.FlxOgmo3Loader,
			"FlxTilemap"		  => flixel.tile.FlxTilemap,
			"FlxTextBorderStyle"		  => flixel.text.FlxTextBorderStyle,
			"FlxTextAlign"	  => getMacroAbstractClass("flixel.text.FlxText.FlxTextAlign"),
			"FlxPoint"		  => getMacroAbstractClass("flixel.math.FlxPoint"),
			"FlxAxes"		   => getMacroAbstractClass("flixel.util.FlxAxes"),
			"FlxColor"		  => getMacroAbstractClass("flixel.util.FlxColor"),
			"BlendMode"		  => getMacroAbstractClass("openfl.display.BlendMode"),

			/* Objects */
			"FlxAnimate"		=> flxanimate.FlxAnimate, //PsychFlxAnimate is removed for CNE compatibility
			"HealthIcon"		=> objects.HealthIcon,
			"Note"				=> objects.Note,
			"Character"		=> objects.Character,
			"Boyfriend"			=> objects.Character, // for compatibility

			/* Backend */
			"Alphabet"			=> objects.Alphabet,
			"Paths"			=> backend.Paths,
			"Conductor"		=> backend.Conductor,
			"CoolUtil"			=> backend.CoolUtil,

			/* Codename Engine related stuff */
			// FunkinShader / CustomShader: v1 portunda yok (TODO)
			"FunkinText"		=> funkin.backend.FunkinText,
			"FunkinSprite"		=> funkin.backend.FunkinSprite,

			/* States */
			"PlayState"		 => states.PlayState,
			"FreeplayState"	 => states.FreeplayState,
			"MainMenuState"	 => states.MainMenuState,
			"PauseSubState"	 => substates.PauseSubState,
			"StoryMenuState"	 => states.StoryMenuState,
			"TitleState"		 => states.TitleState,
			"OptionsState"		 => options.OptionsState,
			"LoadingState"		 => states.LoadingState,
			"MusicBeatState"	 => backend.MusicBeatState,

			/* Substates */
			"GameOverSubstate"  => substates.GameOverSubstate,
			"MusicBeatSubstate"  => backend.MusicBeatSubstate,
			"PauseSubstate"	 => substates.PauseSubState,

			/* Custom Menus */
			#if SCRIPTING_ALLOWED
			"ModState"		  => funkin.backend.scripting.ModState,
			"ModSubState"		  => funkin.backend.scripting.ModSubState,
			#end

			/* hxVLC */
			"FlxVideo"		  => hxvlc.flixel.FlxVideo,
			"FlxVideoSprite"		  => hxvlc.flixel.FlxVideoSprite,

		];
	}

	public static function getDefaultPreprocessors():Map<String, Dynamic> {
		var defines = macros.DefineMacro.defines;
		return defines;
	}

	/** Abstract sınıfların _HSC gölge sınıflarını çözer (AbstractHandler makrosu üretir) */
	private static inline function getMacroAbstractClass(className:String):Dynamic {
		return Type.resolveClass('${className}_HSC');
	}

	/**
	 * All available script extensions
	 */
	public static var scriptExtensions:Array<String> = [
		"hx", "hscript", "hxs", "hxc", "hsc",
		"pack" // combined file
	];

	/**
	 * Currently executing script.
	 */
	public static var curScript:Script = null;

	/**
	 * Script name (with extension)
	 */
	public var fileName:String;

	/**
	 * Script Extension
	 */
	public var extension:String;

	/**
	 * Path to the script.
	 */
	public var path:String = null;

	private var rawPath:String = null;

	/**
	 * Remapped filenames.
	 * Used for trace messages, to show what mod the script is from.
	 */
	private var didLoad:Bool = false;

	public var remappedNames:Map<String, String> = [];

	/**
	 * Creates a script from the specified asset path. The language is automatically determined.
	 * @param path Path in assets
	 */
	public static function create(path:String):Script {
		if (FunkinFileSystem.exists(path)) {
			return switch(Path.extension(path).toLowerCase()) {
				case "hx" | "hscript" | "hsc" | "hxs" | "hxc":
					new HScript(path);
				case "pack":
					var arr = FunkinFileSystem.getText(path).split("________PACKSEP________");
					fromString(arr[1], arr[0]);
				default:
					new DummyScript(path);
			}
		}
		return new DummyScript(path);
	}

	/**
	 * Creates a script from the string. The language is determined based on the path.
	 * @param code code
	 * @param path filename
	 */
	public static function fromString(code:String, path:String):Script {
		return switch(Path.extension(path).toLowerCase()) {
			case "hx" | "hscript" | "hsc" | "hxs" | "hxc":
				new HScript(path).loadFromString(code);
			case "lua":
				trace("Lua is not supported in this engine. Use HScript instead.");
				new DummyScript(path).loadFromString(code);
			default:
				new DummyScript(path).loadFromString(code);
		}
	}

	/**
	 * Creates a new instance of the script class.
	 * @param path
	 */
	public function new(path:String) {
		super();

		rawPath = path;
		//path = path;

		fileName = Path.withoutDirectory(path);
		extension = Path.extension(path);
		this.path = path;
		onCreate(path);
		for(k=>e in getDefaultVariables(this)) {
			set(k, e);
		}
		set("disableScript", () -> {
			active = false;
		});
		set("initSaveData", function(name:String, ?folder:String = 'psychenginemods') {
			var variables = MusicBeatState.getVariables();
			if(!variables.exists('save_$name'))
			{
				var save:FlxSave = new FlxSave();
				// folder goes unused for flixel 5 users. @BeastlyGhost
				save.bind(name, CoolUtil.getSavePath() + '/' + folder);
				variables.set('save_$name', save);
				return;
			}
			trace('initSaveData: Save file already initialized: ' + name);
		});
		set("getDataFromSave", function(name:String, field:String, ?defaultValue:Dynamic = null) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name'))
			{
				var saveData = variables.get('save_$name').data;
				if(Reflect.hasField(saveData, field))
					return Reflect.field(saveData, field);
				else
					return defaultValue;
			}
			trace('getDataFromSave: Save file not initialized: ' + name);
			return defaultValue;
		});
		set("setDataFromSave", function(name:String, field:String, value:Dynamic) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name'))
			{
				Reflect.setField(variables.get('save_$name').data, field, value);
				return;
			}
			trace('setDataFromSave: Save file not initialized: ' + name);
		});
		set("__script__", this);

		//trace('Loading script at path \'${path}\'');
	}

	/**
	 * Loads the script
	 */
	public function load() {
		if(didLoad) return;

		var oldScript = curScript;
		curScript = this;
		onLoad();
		curScript = oldScript;

		didLoad = true;
	}

	/**
	 * HSCRIPT ONLY FOR NOW
	 * Sets the "public" variables map for ScriptPack
	 */
	public function setPublicMap(map:Map<String, Dynamic>) {

	}

	/**
	 * Hot-reloads the script, if possible
	 */
	public function reload() {

	}

	/**
	 * Traces something as this script.
	 */
	public function trace(v:Dynamic) {
		var fileName = this.fileName;
		if(remappedNames.exists(fileName))
			fileName = remappedNames.get(fileName);
		trace('${fileName}: ' + Std.string(v));
	}

	/**
	 * Calls the function `func` defined in the script.
	 * @param func Name of the function
	 * @param parameters (Optional) Parameters of the function.
	 * @return Result (if void, then null)
	 */
	public function call(func:String, ?parameters:Array<Dynamic>):Dynamic {
		var oldScript = curScript;
		curScript = this;

		var result = onCall(func, parameters == null ? [] : parameters);

		curScript = oldScript;
		return result;
	}

	/**
	 * Loads the code from a string, doesn't really work after the script has been loaded
	 * @param code The code.
	 */
	public function loadFromString(code:String) {
		return this;
	}

	/**
	 * Sets a script's parent object so that its properties can be accessed easily. Ex: Passing `PlayState.instance` will allow `boyfriend` to be typed instead of `PlayState.instance.boyfriend`.
	 * @param variable Parent variable.
	 */
	public function setParent(variable:Dynamic) {}

	/**
	 * Gets the variable `variable` from the script's variables.
	 * @param variable Name of the variable.
	 * @return Variable (or null if it doesn't exists)
	 */
	public function get(variable:String):Dynamic {return null;}

	/**
	 * Sets the variable `variable` from the script's variables.
	 * @param variable Name of the variable.
	 * @return Variable (or null if it doesn't exists)
	 */
	public function set(variable:String, value:Dynamic):Void {}

	public function setupPlayState():Void {}

	/**
	 * Shows an error from this script.
	 * @param text Text of the error (ex: Null Object Reference).
	 * @param additionalInfo Additional information you could provide.
	 */
	public function error(text:String, ?additionalInfo:Dynamic):Void {
		var fileName = this.fileName;
		if(remappedNames.exists(fileName))
			fileName = remappedNames.get(fileName);
		trace(fileName + text);
	}

	override public function toString():String {
		return 'Script($path) active: $active loaded: $didLoad';
	}

	/**
	 * PRIVATE HANDLERS - DO NOT TOUCH
	 */
	private function onCall(func:String, parameters:Array<Dynamic>):Dynamic {
		return null;
	}
	/**
	 * Called when the script is created.
	 * @param path Path to the script
	 */
	public function onCreate(path:String) {}

	/**
	 * Called when the script is loaded.
	 */
	public function onLoad() {}
}







/**
 * Simple class for empty scripts or scripts whose language isn't imported yet.
 */
class DummyScript extends Script {
	public var variables:Map<String, Dynamic> = [];

	public override function get(v:String) {return variables.get(v);}
	public override function set(v:String, v2:Dynamic) {return variables.set(v, v2);}
	public override function onCall(method:String, parameters:Array<Dynamic>):Dynamic {
		var func = variables.get(method);
		if (Reflect.isFunction(func))
			return (parameters != null && parameters.length > 0) ? Reflect.callMethod(null, func, parameters) : func();

		return null;
	}
}










@:access(CancellableEvent)
class ScriptPack extends Script {
	public var scripts:Array<Script> = [];
	public var additionalDefaultVariables:Map<String, Dynamic> = [];
	public var publicVariables:Map<String, Dynamic> = [];
	public var parent:Dynamic = null;

	public override function load() {
		for(e in scripts) {
			e.load();
			//trace('Script Loaded: ${e}');
		}
	}

	public function contains(path:String) {
		for(e in scripts)
			if (e.path == path)
				return true;
		return false;
	}
	public function new(name:String) {
		additionalDefaultVariables["importScript"] = importScript;
		super(name);
	}

	public function getByPath(name:String) {
		for(s in scripts)
			if (s.path == name)
				return s;
		return null;
	}

	public function getByName(name:String) {
		for(s in scripts)
			if (s.fileName == name)
				return s;
		return null;
	}
	public function importScript(path:String):Script {
		var resolved:String = ScriptLoader.find(path);
		if (resolved == null) {
			throw 'Script at ${path} does not exist.';
			return null;
		}
		var script = Script.create(resolved);
		if (script is DummyScript) {
			throw 'Script at ${path} does not exist.';
			return null;
		}
		add(script);
		script.load();
		return script;
	}

	public override function call(func:String, ?parameters:Array<Dynamic>):Dynamic {
		for(e in scripts)
			if(e.active)
				e.call(func, parameters);
		return null;
	}

	/**
	 * Sends an event to every single script, and returns the event.
	 * @param func Function to call
	 * @param event Event (will be the first parameter of the function)
	 * @return (modified by scripts)
	 */
	public inline function event<T:CancellableEvent>(func:String, event:T):T {
		for(e in scripts) {
			if(!e.active) continue;

			e.call(func, [event]);
			if (event.cancelled && !event.__continueCalls) break;
		}
		return event;
	}

	public override function get(val:String):Dynamic {
		for(e in scripts) {
			var v = e.get(val);
			if (v != null) return v;
		}
		return null;
	}

	public override function reload() {
		for(e in scripts) e.reload();
	}

	public override function set(val:String, value:Dynamic) {
		for(e in scripts) e.set(val, value);
	}

	public override function setupPlayState() {
		for(e in scripts) e.setupPlayState();
	}

	public override function setParent(parent:Dynamic) {
		this.parent = parent;
		for(e in scripts) e.setParent(parent);
	}

	public override function destroy() {
		super.destroy();
		for(e in scripts) e.destroy();
	}

	public override function onCreate(path:String) {}

	public function add(script:Script) {
		scripts.push(script);
		__configureNewScript(script);
	}

	public function remove(script:Script) {
		scripts.remove(script);
	}

	public function insert(pos:Int, script:Script) {
		scripts.insert(pos, script);
		__configureNewScript(script);
	}

	private function __configureNewScript(script:Script) {
		if (parent != null) script.setParent(parent);
		script.setPublicMap(publicVariables);
		for(k=>e in additionalDefaultVariables) script.set(k, e);
	}

	override public function toString():String {
		return 'ScriptPack(parent: ' + FlxStringUtil.getClassName(parent, true) + ', total: ' + scripts.length + ')';
	}
}


#if GLOBAL_SCRIPT
/**
 * Class for THE Global Script, aka script that runs in the background at all times.
 * Only support by Scripting folder for now.
 */
class GlobalScript {
	public static var scripts:ScriptPack;

	private static var initialized:Bool = false;
	private static var reloading:Bool = false;
	private static var _lastAllow_Reload:Bool = false;

	public static function init() {
		if(initialized) return;
		initialized = true;

		onSetupScript();

		//maybe later
		//Conductor.onBeatHit.add(beatHit);
		//Conductor.onStepHit.add(stepHit);

		FlxG.signals.focusGained.add(function() {
			call("focusGained");
		});
		FlxG.signals.focusLost.add(function() {
			call("focusLost");
		});
		FlxG.signals.gameResized.add(function(w:Int, h:Int) {
			call("gameResized", [w, h]);
		});
		FlxG.signals.postDraw.add(function() {
			call("postDraw");
		});
		FlxG.signals.postGameReset.add(function() {
			call("postGameReset");
		});
		FlxG.signals.postGameStart.add(function() {
			call("postGameStart");
		});
		FlxG.signals.postStateSwitch.add(function() {
			call("postStateSwitch");
		});
		FlxG.signals.postUpdate.add(function() {
			call("postUpdate", [FlxG.elapsed]);
		});
		FlxG.signals.preDraw.add(function() {
			call("preDraw");
		});
		FlxG.signals.preGameReset.add(function() {
			call("preGameReset");
		});
		FlxG.signals.preGameStart.add(function() {
			call("preGameStart");
		});
		FlxG.signals.preStateCreate.add(function(state:FlxState) {
			call("preStateCreate", [state]);
		});
		FlxG.signals.preStateSwitch.add(function() {
			call("preStateSwitch", []);
		});

		FlxG.signals.preUpdate.add(function() {
			call("preUpdate", [FlxG.elapsed]);
			call("update", [FlxG.elapsed]);
		});
	}

	public static function onSetupScript() {
		destroy();
		scripts = new ScriptPack("GlobalScript");

		var path = ScriptLoader.find('data/global');
		trace(path);
		if (path == null) return;
		var script = Script.create(path);
		if (script is DummyScript) {
			trace('script is dummy');
			//do nothing
		} else {
			trace('script isn\'t dummy');
			script.remappedNames.set(script.fileName, '${script.fileName}');
			scripts.add(script);
			script.load();
		}
	}

	public static inline function event<T:CancellableEvent>(name:String, event:T):T {
		if (scripts != null)
			scripts.event(name, event);
		return event;
	}

	public static inline function call(name:String, ?args:Array<Dynamic>)
		if (scripts != null) scripts.call(name, args);

	public static inline function beatHit(curBeat:Int)
		call("beatHit", [curBeat]);

	public static inline function stepHit(curStep:Int)
		call("stepHit", [curStep]);

	public static inline function destroy() if (scripts != null) {
		call("destroy");
		scripts = FlxDestroyUtil.destroy(scripts);
	}
}
#end
#end
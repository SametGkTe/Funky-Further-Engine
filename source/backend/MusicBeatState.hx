package backend;

import flixel.FlxState;
import backend.PsychCamera;
#if POLYMOD_ALLOWED
import vslice.scripting.VSScriptEventDispatcher;
#end
#if HSC_ALLOWED
import funkin.backend.scripting.HScript.ScriptPack;
import funkin.backend.scripting.ScriptLoader;
import funkin.backend.scripting.EventManager;
import funkin.backend.scripting.events.CancellableEvent;
import flixel.util.FlxDestroyUtil;
#end

class MusicBeatState extends FlxState
{
	public var mobileManager:MobileControlManager;

	#if HSC_ALLOWED
	/** CNE tarzı state scripti: data/states/<StateAdı>.hx / .hscript / .hxs / .hxc / .hsc */
	public var stateScripts:ScriptPack;
	public static var lastScriptName:String = null;
	public static var lastStateName:String = null;
	public var scriptName:String = null;
	#end
	//makes code less messy & easier to write (yeni sistem yardımcıları)
	public inline function mobileButtonJustPressed(buttons:Dynamic):Bool {
		return mobileManager?.mobilePad?.justPressed(buttons);
	}
	public inline function mobileButtonPressed(buttons:Dynamic):Bool {
		return mobileManager?.mobilePad?.pressed(buttons);
	}
	public inline function mobileButtonJustReleased(buttons:Dynamic):Bool {
		return mobileManager?.mobilePad?.justReleased(buttons);
	}
	public inline function mobileButtonReleased(buttons:Dynamic):Bool {
		return mobileManager?.mobilePad?.released(buttons);
	}

	public function new()
	{
		super();
		mobileManager = new MobileControlManager(this);
		#if HSC_ALLOWED
		EventManager.init();
		loadStateScripts();
		#end
	}

	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	public var controls(get, never):Controls;
	private function get_controls()
	{
		return Controls.instance;
	}

	public var touchPad:TouchPad;
	public var touchPadCam:FlxCamera;
	public var mobileControls:FMobileControls;
	public var mobileControlsCam:FlxCamera;
	var lastPadDPad:String = null;
	var lastPadAction:String = null;

	public function addTouchPad(DPad:String, Action:String)
	{
		lastPadDPad = DPad;
		lastPadAction = Action;
		#if mobile
		if (!TouchControls.isEditorOwner(this) && TouchControls.canReplace(DPad, Action))
		{
			touchPad = new TouchControls(DPad, Action, this);
			add(touchPad);
			return;
		}
		#end
		touchPad = new TouchPad(DPad, Action);
		add(touchPad);
	}

	public function handleTouchTap(x:Float, y:Float):Bool
	{
		return false;
	}

	public function removeTouchPad()
	{
		if (touchPad != null)
		{
			remove(touchPad);
			touchPad = FlxDestroyUtil.destroy(touchPad);
		}

		if(touchPadCam != null)
		{
			FlxG.cameras.remove(touchPadCam);
			touchPadCam = FlxDestroyUtil.destroy(touchPadCam);
		}
	}

	public function refreshTouchPad():Void
	{
		if (touchPad == null || lastPadDPad == null)
			return;

		var padCams:Array<FlxCamera> = touchPad.cameras;
		remove(touchPad);
		touchPad = FlxDestroyUtil.destroy(touchPad);
		addTouchPad(lastPadDPad, lastPadAction);
		if (padCams != null && touchPad != null)
			touchPad.cameras = padCams;
	}

	override public function closeSubState():Void
	{
		super.closeSubState();
		refreshTouchPad();
	}

	public function addMobileControls(defaultDrawTarget:Bool = false):Void
	{
		if (ClientPrefs.data.ogGameControls) return; // Kodumun Hitbox'ını ekleme
		var extraMode = MobileData.extraActions.get(ClientPrefs.data.extraButtons);

		switch (MobileData.mode)
		{
			case 0: // RIGHT_FULL
				mobileControls = new TouchPad('RIGHT_FULL', 'NONE', extraMode);
			case 1: // LEFT_FULL
				mobileControls = new TouchPad('LEFT_FULL', 'NONE', extraMode);
			case 2: // CUSTOM
				mobileControls = MobileData.getTouchPadCustom(new TouchPad('RIGHT_FULL', 'NONE', extraMode));
			case 3: // HITBOX
				mobileControls = new Hitbox(extraMode);
		}

		mobileControls.instance = MobileData.setButtonsColors(mobileControls.instance);
		mobileControlsCam = new FlxCamera();
		mobileControlsCam.bgColor.alpha = 0;
		FlxG.cameras.add(mobileControlsCam, defaultDrawTarget);

		mobileControls.instance.cameras = [mobileControlsCam];
		mobileControls.instance.visible = false;
		add(mobileControls.instance);
	}

	public function removeMobileControls()
	{
		if (mobileControls != null)
		{
			remove(mobileControls.instance);
			mobileControls.instance = FlxDestroyUtil.destroy(mobileControls.instance);
			mobileControls = null;
		}

		if (mobileControlsCam != null)
		{
			FlxG.cameras.remove(mobileControlsCam);
			mobileControlsCam = FlxDestroyUtil.destroy(mobileControlsCam);
		}
	}

	public function addTouchPadCamera(defaultDrawTarget:Bool = false):Void
	{
		if (touchPad != null)
		{
			touchPadCam = new FlxCamera();
			touchPadCam.bgColor.alpha = 0;
			FlxG.cameras.add(touchPadCam, defaultDrawTarget);
			touchPad.cameras = [touchPadCam];
		}
	}

	override function destroy()
	{
		removeTouchPad();
		removeMobileControls();
		if (mobileManager != null) mobileManager.destroy();
		#if HSC_ALLOWED
		call('destroy');
		stateScripts = FlxDestroyUtil.destroy(stateScripts);
		#end

		#if POLYMOD_ALLOWED
		if (!Std.isOfType(this, states.PlayState))
			VSScriptEventDispatcher.dispatchModules('onDestroy');
		#end

		super.destroy();
	}

	var _psychCameraInitialized:Bool = false;

	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	public static function getVariables()
		return getState().variables;

	#if HSC_ALLOWED
	/** data/states/<StateAdı> scriptini mod klasörlerinden yükler */
	function loadStateScripts()
	{
		var className = Type.getClassName(Type.getClass(this));
		if (stateScripts == null)
			(stateScripts = new ScriptPack(className)).setParent(this);
		if (stateScripts.scripts.length == 0)
		{
			var shortName = className.substr(className.lastIndexOf(".") + 1);
			var script = ScriptLoader.create('data/states/' + shortName);
			if (script != null)
			{
				stateScripts.add(script);
				script.load();
				call('create');
			}
		}
	}

	/** State scriptine fonksiyon çağrısı */
	public function call(name:String, ?args:Array<Dynamic>, ?defaultVal:Dynamic):Dynamic
	{
		if (stateScripts != null)
			return stateScripts.call(name, args);
		return defaultVal;
	}

	/** State scriptine event gönderimi */
	public function event(name:String, event:CancellableEvent):CancellableEvent
	{
		if (stateScripts != null)
			stateScripts.call(name, [event]);
		return event;
	}
	#end

	override function create() {
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		#if MODS_ALLOWED Mods.updatedOnState = false; #end

		if(!_psychCameraInitialized) initPsychCamera();

		super.create();

		if(!skip) {
			openSubState(new CustomFadeTransition(0.5, true));
		}
		FlxTransitionableState.skipNextTransOut = false;
		timePassedOnState = 0;

		#if POLYMOD_ALLOWED
		// Module script'leri her state'te onCreate alir.
		// PlayState kendi dispatch'ini zaten yapiyor (cift olmasin).
		if (!Std.isOfType(this, states.PlayState))
			VSScriptEventDispatcher.dispatchModules('onCreate');
		#end
	}

	public function initPsychCamera():PsychCamera
	{
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		//trace('initialized psych camera ' + Sys.cpuTime());
		return camera;
	}

	public static var timePassedOnState:Float = 0;
	override function update(elapsed:Float)
	{
		#if FURTHER_ONLINE
		online.NetThread.pump();
		#end
		//everyStep();
		var oldStep:Int = curStep;
		timePassedOnState += elapsed;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep)
		{
			if(curStep > 0)
				stepHit();

			if(PlayState.SONG != null)
			{
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}

		if(FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;
		
		stagesFunc(function(stage:BaseStage) {
			stage.update(elapsed);
		});

		#if HSC_ALLOWED
		call('update', [elapsed]);
		call('postUpdate', [elapsed]);
		#end

		#if POLYMOD_ALLOWED
		// Module script'leri menü state'lerinde de onUpdate alir
		// (PlayState kendi dispatch'ini yapiyor).
		if (!Std.isOfType(this, states.PlayState))
			VSScriptEventDispatcher.dispatchModules('onUpdate', elapsed);
		#end

		super.update(elapsed);
	}

	private function updateSection():Void
	{
		if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while(curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}

	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if(stepsToDo > curStep) break;
				
				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public static function switchState(nextState:FlxState = null) {
		if(nextState == null) nextState = FlxG.state;
		if(nextState == FlxG.state)
		{
			resetState();
			return;
		}

		if(FlxTransitionableState.skipNextTransIn) FlxG.switchState(nextState);
		else startTransition(nextState);
		FlxTransitionableState.skipNextTransIn = false;
	}
	
	public static function resetState() {
		if(FlxTransitionableState.skipNextTransIn) FlxG.resetState();
		else startTransition();
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	public static function startTransition(nextState:FlxState = null)
	{
		if(nextState == null)
			nextState = FlxG.state;

		FlxG.state.openSubState(new CustomFadeTransition(0.5, false));
		if(nextState == FlxG.state)
			CustomFadeTransition.finishCallback = function() FlxG.resetState();
		else
			CustomFadeTransition.finishCallback = function() FlxG.switchState(nextState);
	}

	public static function getState():MusicBeatState {
		if (FlxG.state != null && Std.isOfType(FlxG.state, MusicBeatState))
			return cast FlxG.state;
		return null;
	}

	public function stepHit():Void
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();
	}

	public var stages:Array<BaseStage> = [];
	public function beatHit():Void
	{
		//trace('Beat: ' + curBeat);
		stagesFunc(function(stage:BaseStage) {
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
	}

	public function sectionHit():Void
	{
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});
	}

	function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if(stage != null && stage.exists && stage.active)
				func(stage);
	}

	function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		if(PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}
}

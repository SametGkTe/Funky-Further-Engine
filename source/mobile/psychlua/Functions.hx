package mobile.psychlua;

import psychlua.CustomSubstate;
#if LUA_ALLOWED
import lime.ui.Haptic;
import psychlua.FunkinLua;
import psychlua.LuaUtils;
import mobile.backend.TouchUtil;
#if android import mobile.backend.PsychJNI; #end

/**
 * Mobile Lua functions — MERGED:
 *  - eski Further Engine API'si (addTouchPad / removeTouchPad / touchPadJustPressed ...),
 *  - yeni Psych Engine Online Mobile API'si (addMobilePad / addHitbox / addJoyStick /
 *    mobilePadPressed / hitboxPressed / createNewMobileManager ...).
 */
class MobileFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua:State = funk.lua;

		// ---------------- ESKİ API ----------------
		Lua_helper.add_callback(lua, 'mobileC', Controls.instance.mobileC);

		Lua_helper.add_callback(lua, 'mobileControlsMode', getMobileControlsAsString());

		Lua_helper.add_callback(lua, "extraButtonPressed", (button:String) ->
		{
			button = button.toLowerCase();
			if (MusicBeatState.getState().mobileControls != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().mobileControls.buttonExtra2.pressed;
					default:
						return MusicBeatState.getState().mobileControls.buttonExtra.pressed;
				}
			}
			return false;
		});

		Lua_helper.add_callback(lua, "extraButtonJustPressed", (button:String) ->
		{
			button = button.toLowerCase();
			if (MusicBeatState.getState().mobileControls != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().mobileControls.buttonExtra2.justPressed;
					default:
						return MusicBeatState.getState().mobileControls.buttonExtra.justPressed;
				}
			}
			return false;
		});

		Lua_helper.add_callback(lua, "extraButtonJustReleased", (button:String) ->
		{
			button = button.toLowerCase();
			if (MusicBeatState.getState().mobileControls != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().mobileControls.buttonExtra2.justReleased;
					default:
						return MusicBeatState.getState().mobileControls.buttonExtra.justReleased;
				}
			}
			return false;
		});

		Lua_helper.add_callback(lua, "extraButtonReleased", (button:String) ->
		{
			button = button.toLowerCase();
			if (MusicBeatState.getState().mobileControls != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().mobileControls.buttonExtra2.released;
					default:
						return MusicBeatState.getState().mobileControls.buttonExtra.released;
				}
			}
			return false;
		});

		Lua_helper.add_callback(lua, "vibrate", (?duration:Int, ?period:Int) ->
		{
			if (duration == null)
				return FunkinLua.luaTrace('vibrate: No duration specified.');
			else if (period == null)
				period = 0;
			return Haptic.vibrate(period, duration);
		});

		Lua_helper.add_callback(lua, "addTouchPad", (DPadMode:String, ActionMode:String, ?addToCustomSubstate:Bool = false, ?posAtCustomSubstate:Int = -1) ->
		{
			PlayState.instance.makeLuaTouchPad(DPadMode, ActionMode);
			if (addToCustomSubstate)
			{
				if (PlayState.instance.luaTouchPad != null || !PlayState.instance.members.contains(PlayState.instance.luaTouchPad))
					CustomSubstate.insertLuaTpad(posAtCustomSubstate);
			}
			else
				PlayState.instance.addLuaTouchPad();
		});

		Lua_helper.add_callback(lua, "removeTouchPad", () ->
		{
			PlayState.instance.removeLuaTouchPad();
		});

		Lua_helper.add_callback(lua, "addTouchPadCamera", () ->
		{
			if (PlayState.instance.luaTouchPad == null)
			{
				FunkinLua.luaTrace('addTouchPadCamera: Touch Pad does not exist.');
				return;
			}
			PlayState.instance.addLuaTouchPadCamera();
		});

		Lua_helper.add_callback(lua, "touchPadJustPressed", function(button:Dynamic):Bool
		{
			if (PlayState.instance.luaTouchPad == null) return false;
			return PlayState.instance.luaTouchPadJustPressed(button);
		});

		Lua_helper.add_callback(lua, "touchPadPressed", function(button:Dynamic):Bool
		{
			if (PlayState.instance.luaTouchPad == null) return false;
			return PlayState.instance.luaTouchPadPressed(button);
		});

		Lua_helper.add_callback(lua, "touchPadJustReleased", function(button:Dynamic):Bool
		{
			if (PlayState.instance.luaTouchPad == null) return false;
			return PlayState.instance.luaTouchPadJustReleased(button);
		});

		Lua_helper.add_callback(lua, "touchPadReleased", function(button:Dynamic):Bool
		{
			if (PlayState.instance.luaTouchPad == null) return false;
			return PlayState.instance.luaTouchPadReleased(button);
		});
		
		// Extra Control Summon
		Lua_helper.add_callback(lua, "setExtraKeys", function(?count:Int):Void
		{
			var ps:PlayState = PlayState.instance;
			if (ps == null) return;
			ps.luaExtraKeys = (count == null) ? 0 : count;
		});

		Lua_helper.add_callback(lua, "getExtraKeys", function():Int
		{
			return PlayState.getExtraKeys();
		});

		Lua_helper.add_callback(lua, "extraKeyPressed", function(?index:Int):Bool
		{
			var ps:PlayState = PlayState.instance;
			if (ps == null) return false;
			var idx:Int = (index == null) ? 1 : index;
			var btn:TouchButton = null;
			if (ps.mobileControls != null && ps.mobileControls.instance != null)
				btn = (idx == 1) ? ps.mobileControls.buttonExtra : ps.mobileControls.buttonExtra2;
			if (btn != null) return btn.pressed;
			return false;
		});

		Lua_helper.add_callback(lua, "touchJustPressed", TouchUtil.justPressed);
		Lua_helper.add_callback(lua, "touchPressed", TouchUtil.pressed);
		Lua_helper.add_callback(lua, "touchJustReleased", TouchUtil.justReleased);
		Lua_helper.add_callback(lua, "touchReleased", TouchUtil.released);
		Lua_helper.add_callback(lua, "touchPressedObject", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchPressedObject: $object does not exist.');
				return false;
			}
			return TouchUtil.overlaps(obj, cam) && TouchUtil.pressed;
		});

		Lua_helper.add_callback(lua, "touchJustPressedObject", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchJustPressedObject: $object does not exist.');
				return false;
			}
			return TouchUtil.overlaps(obj, cam) && TouchUtil.justPressed;
		});

		Lua_helper.add_callback(lua, "touchJustReleasedObject", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchJustReleasedObject: $object does not exist.');
				return false;
			}
			return TouchUtil.overlaps(obj, cam) && TouchUtil.justReleased;
		});

		Lua_helper.add_callback(lua, "touchReleasedObject", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchReleasedObject: $object does not exist.');
				return false;
			}
			return TouchUtil.overlaps(obj, cam) && TouchUtil.released;
		});

		Lua_helper.add_callback(lua, "touchPressedObjectComplex", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchPressedObjectComplex: $object does not exist.');
				return false;
			}
			return TouchUtil.overlapsComplex(obj, cam) && TouchUtil.pressed;
		});

		Lua_helper.add_callback(lua, "touchJustPressedObjectComplex", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchJustPressedObjectComplex: $object does not exist.');
				return false;
			}
			return TouchUtil.overlapsComplex(obj, cam) && TouchUtil.justPressed;
		});

		Lua_helper.add_callback(lua, "touchJustReleasedObjectComplex", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchJustReleasedObjectComplex: $object does not exist.');
				return false;
			}
			return TouchUtil.overlapsComplex(obj, cam) && TouchUtil.justReleased;
		});

		Lua_helper.add_callback(lua, "touchReleasedObjectComplex", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchReleasedObjectComplex: $object does not exist.');
				return false;
			}
			return TouchUtil.overlapsComplex(obj, cam) && TouchUtil.released;
		});

		Lua_helper.add_callback(lua, "touchOverlapsObject", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchOverlapsObject: $object does not exist.');
				return false;
			}
			return TouchUtil.overlaps(obj, cam);
		});

		Lua_helper.add_callback(lua, "touchOverlapsObjectComplex", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchOverlapsObjectComplex: $object does not exist.');
				return false;
			}
			return TouchUtil.overlapsComplex(obj, cam);
		});

		// ---------------- YENİ API (Psych Engine Online Mobile) ----------------

		Lua_helper.add_callback(lua, 'createNewMobileManager', function(name:String, ?keyDetectionAllowed:Bool):Void
		{
			PlayState.instance.createNewManager(name, keyDetectionAllowed);
		});

		Lua_helper.add_callback(lua, 'connectControlToNotes', function(?managerName:String, ?control:String):Void
		{
			PlayState.instance.connectControlToNotes(managerName, control);
		});

		//JoyStick
		Lua_helper.add_callback(lua, 'addJoyStick', function(?managerName:String, x:Float = 0, y:Float = 0, ?graphic:String, size:Float = 1, ?addToCustomSubstate:Bool = false, ?posAtCustomSubstate:Int = -1):Void
		{
			var manager = PlayState.checkManager(managerName);
			manager.addJoyStick(x, y, graphic, null, size);
			if(PlayState.instance.variables.exists(managerName + '_joyStick')) PlayState.instance.variables.set(managerName + '_joyStick', manager.joyStick);
		});

		Lua_helper.add_callback(lua, 'addJoyStickCamera', function(?managerName:String, defaultDrawTarget:Bool = false):Void
		{
			PlayState.checkManager(managerName).addJoyStickCamera(defaultDrawTarget);
		});

		Lua_helper.add_callback(lua, 'removeJoyStick', function(?managerName:String):Void
		{
			PlayState.checkManager(managerName).removeJoyStick();
		});

		Lua_helper.add_callback(lua, 'joyStickPressed', function(?managerName:String, ?position:String):Bool
		{
			var mgr = PlayState.checkManager(managerName);
			return mgr.joyStick != null && mgr.joyStick.pressed(position);
		});

		Lua_helper.add_callback(lua, 'joyStickJustPressed', function(?managerName:String, ?position:String):Bool
		{
			var mgr = PlayState.checkManager(managerName);
			return mgr.joyStick != null && mgr.joyStick.justPressed(position);
		});

		Lua_helper.add_callback(lua, 'joyStickJustReleased', function(?managerName:String, ?position:String):Bool
		{
			var mgr = PlayState.checkManager(managerName);
			return mgr.joyStick != null && mgr.joyStick.justReleased(position);
		});

		//Hitbox
		Lua_helper.add_callback(lua, "addHitbox", function(?managerName:String, ?mode:String, ?hints:Bool, ?addToCustomSubstate:Bool = false, ?posAtCustomSubstate:Int = -1):Void
		{
			var manager = PlayState.checkManager(managerName);
			if (managerName == null || managerName == '')
				PlayState.instance.addPlayStateHitbox(mode, false, hints);
			else
				manager.addHitbox(mode, hints);
			if(PlayState.instance.variables.exists(managerName + '_hitbox')) PlayState.instance.variables.set(managerName + '_hitbox', manager.hitbox);
		});

		Lua_helper.add_callback(lua, "addHitboxCamera", function(?managerName:String, defaultDrawTarget:Bool = false):Void
		{
			PlayState.checkManager(managerName).addHitboxCamera(defaultDrawTarget);
		});

		Lua_helper.add_callback(lua, "addHitboxDeadZones", function(?managerName:String, buttons:Array<String>):Void
		{
			PlayState.instance.addHitboxDeadZone(managerName, buttons);
		});

		Lua_helper.add_callback(lua, "removeHitbox", function(?managerName:String):Void
		{
			var manager = PlayState.checkManager(managerName);
			manager.hitbox.forEachAlive((button) ->
			{
				if (button.deadZones != []) button.deadZones = [];
			});
			manager.removeHitbox();
		});

		Lua_helper.add_callback(lua, 'hitboxPressed', function(?managerName:String, ?hint:String):Bool
		{
			return PlayState.checkHBoxPress(hint, 'pressed', managerName);
		});

		Lua_helper.add_callback(lua, 'hitboxJustPressed', function(?managerName:String, ?hint:String):Bool
		{
			return PlayState.checkHBoxPress(hint, 'justPressed', managerName);
		});

		Lua_helper.add_callback(lua, 'hitboxReleased', function(?managerName:String, ?hint:String):Bool
		{
			return PlayState.checkHBoxPress(hint, 'released', managerName);
		});

		Lua_helper.add_callback(lua, 'hitboxJustReleased', function(?managerName:String, ?hint:String):Bool
		{
			return PlayState.checkHBoxPress(hint, 'justReleased', managerName);
		});

		//MobilePad
		Lua_helper.add_callback(lua, 'addMobilePad', function(?managerName:String, DPad:String, Action:String, ?addToCustomSubstate:Bool = false, ?posAtCustomSubstate:Int = -1):Void
		{
			var manager = PlayState.checkManager(managerName);
			manager.addMobilePad(DPad, Action);
			if(PlayState.instance.variables.exists(managerName + '_mobilePad')) PlayState.instance.variables.set(managerName + '_mobilePad', manager.mobilePad);
		});

		Lua_helper.add_callback(lua, 'addMobilePadCamera', function(?managerName:String, defaultDrawTarget:Bool = false):Void
		{
			PlayState.checkManager(managerName).addMobilePadCamera(defaultDrawTarget);
		});

		Lua_helper.add_callback(lua, 'removeMobilePad', function(?managerName:String):Void
		{
			PlayState.checkManager(managerName).removeMobilePad();
		});

		Lua_helper.add_callback(lua, 'mobilePadPressed', function(?managerName:String, ?button:String):Bool
		{
			return PlayState.checkMPadPress(button, 'pressed', managerName);
		});

		Lua_helper.add_callback(lua, 'mobilePadJustPressed', function(?managerName:String, ?button:String):Bool
		{
			return PlayState.checkMPadPress(button, 'justPressed', managerName);
		});

		Lua_helper.add_callback(lua, 'mobilePadReleased', function(?managerName:String, ?button:String):Bool
		{
			return PlayState.checkMPadPress(button, 'released', managerName);
		});

		Lua_helper.add_callback(lua, 'mobilePadJustReleased', function(?managerName:String, ?button:String):Bool
		{
			return PlayState.checkMPadPress(button, 'justReleased', managerName);
		});

		//Extra Things
		Lua_helper.add_callback(lua, "setHitboxVisibilty", function(?managerName:String, enabled:Bool = false):Void
		{
			var mgr = PlayState.checkManager(managerName);
			if (mgr.hitbox != null) mgr.hitbox.visible = enabled;
		});

		Lua_helper.add_callback(lua, "reloadHitbox", function(?managerName:String, ?mode:String):Void
		{
			var manager = PlayState.checkManager(managerName);
			manager.removeHitbox();
			manager.addHitbox(mode);
		});
	}

	public static function getMobileControlsAsString():String
	{
		switch (MobileData.mode)
		{
			case 0:
				return 'left';
			case 1:
				return 'right';
			case 2:
				return 'custom';
			case 3:
				return 'hitbox';
			default:
				return 'none';
		}
	}
}

#if android
class AndroidFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua:State = funk.lua;
		Lua_helper.add_callback(lua, "isDolbyAtmos", AndroidTools.isDolbyAtmos());
		Lua_helper.add_callback(lua, "isAndroidTV", AndroidTools.isAndroidTV());
		Lua_helper.add_callback(lua, "isTablet", AndroidTools.isTablet());
		Lua_helper.add_callback(lua, "isChromebook", AndroidTools.isChromebook());
		Lua_helper.add_callback(lua, "isDeXMode", AndroidTools.isDeXMode());

		Lua_helper.add_callback(lua, "backJustPressed", FlxG.android.justPressed.BACK);
		Lua_helper.add_callback(lua, "backPressed", FlxG.android.pressed.BACK);
		Lua_helper.add_callback(lua, "backJustReleased", FlxG.android.justReleased.BACK);

		Lua_helper.add_callback(lua, "menuJustPressed", FlxG.android.justPressed.MENU);
		Lua_helper.add_callback(lua, "menuPressed", FlxG.android.pressed.MENU);
		Lua_helper.add_callback(lua, "menuJustReleased", FlxG.android.justReleased.MENU);

		Lua_helper.add_callback(lua, "getCurrentOrientation", () -> PsychJNI.getCurrentOrientationAsString());
		Lua_helper.add_callback(lua, "setOrientation", function(?hint:String):Void
		{
			switch (hint.toLowerCase())
			{
				case 'portrait':
					hint = 'Portrait';
				case 'portraitupsidedown' | 'upsidedownportrait' | 'upsidedown':
					hint = 'PortraitUpsideDown';
				case 'landscapeleft' | 'leftlandscape':
					hint = 'LandscapeLeft';
				case 'landscaperight' | 'rightlandscape' | 'landscape':
					hint = 'LandscapeRight';
				default:
					hint = null;
			}
			if (hint == null)
				return FunkinLua.luaTrace('setOrientation: No orientation specified.');
			PsychJNI.setOrientation(FlxG.stage.stageWidth, FlxG.stage.stageHeight, false, hint);
		});

		Lua_helper.add_callback(lua, "minimizeWindow", () -> AndroidTools.minimizeWindow());

		Lua_helper.add_callback(lua, "showToast", function(text:String, ?duration:Int, ?xOffset:Int, ?yOffset:Int)
		{
			if (text == null)
				return FunkinLua.luaTrace('showToast: No text specified.');
			else if (duration == null)
				return FunkinLua.luaTrace('showToast: No duration specified.');

			if (xOffset == null)
				xOffset = 0;
			if (yOffset == null)
				yOffset = 0;

			AndroidToast.makeText(text, duration, -1, xOffset, yOffset);
		});

		Lua_helper.add_callback(lua, "isScreenKeyboardShown", () -> PsychJNI.isScreenKeyboardShown());

		Lua_helper.add_callback(lua, "clipboardHasText", () -> PsychJNI.clipboardHasText());
		Lua_helper.add_callback(lua, "clipboardGetText", () -> PsychJNI.clipboardGetText());
		Lua_helper.add_callback(lua, "clipboardSetText", function(?text:String):Void
		{
			if (text != null)
				return FunkinLua.luaTrace('clipboardSetText: No text specified.');
			PsychJNI.clipboardSetText(text);
		});

		Lua_helper.add_callback(lua, "manualBackButton", () -> PsychJNI.manualBackButton());

		Lua_helper.add_callback(lua, "setActivityTitle", function(text:String):Void
		{
			if (text != null)
				return FunkinLua.luaTrace('setActivityTitle: No text specified.');
			PsychJNI.setActivityTitle(text);
		});
	}
}
#end
#end

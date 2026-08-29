#if !macro
#if DISCORD_ALLOWED
import backend.Discord;
#end

#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end

import vslice.funkin.custom.NativeFileSystem as NativeFileSystem;
import vslice.funkin.*;
import vslice.funkin.utils.*;
import vslice.funkin.custom.*;
import vslice.funkin.players.*;
import states.FreeplayState as C_;

import vslice.stages.cutscenes.dialogueBox.*;
import vslice.stages.cutscenes.dialogueBox.DialogueBoxPsych.DialogueFile;
import vslice.stages.cutscenes.dialogueBox.styles.*;

using StringTools;
using vslice.funkin.utils.ArrayTools;
using vslice.funkin.utils.custom.FunkinTools;
import vslice.funkin.utils.custom.FunkinTools;
using vslice.funkin.utils.ArrayTools;
using vslice.funkin.utils.SpriteTools;
using vslice.funkin.utils.custom.PsychUITools;
using vslice.funkin.utils.StringTools;
import backend.ui.*; //Psych-UI
import flixel.ui.FlxBar;
import backend.CacheSystem;

import backend.update.UpdateConfig;

import mobile.objects.MobileControls;
import mobile.objects.Hitbox;
import mobile.objects.TouchPad;
import mobile.objects.TouchButton;
import mobile.input.MobileInputID;
import mobile.backend.MobileData;
import mobile.input.MobileInputManager;
import mobile.backend.TouchUtil;
import mobile.MobileConfig;
import mobile.MobileControlManager;
import mobile.MobileButton;
import mobile.objects.FMobileControls;
import mobile.Util;
import mobile.ScreenUtil;
import mobile.objects.FurtherPad;
import mobile.objects.FurtherHitbox;
import mobile.objects.UltraJoyStick;
import mobile.substates.MobileExtraControl;
import mobile.objects.TouchControls;
import objects.AlertMgr;
// Android
#if android
import android.content.Context as AndroidContext;
import android.widget.Toast as AndroidToast;
import android.os.Environment as AndroidEnvironment;
import android.Permissions as AndroidPermissions;
import android.Settings as AndroidSettings;
import android.Tools as AndroidTools;
import android.os.Build.VERSION as AndroidVersion;
import android.os.Build.VERSION_CODES as AndroidVersionCode;
import android.os.BatteryManager as AndroidBatteryManager;
#end

#if sys
import sys.*;
import sys.io.*;
#elseif js
import js.html.*;
#end

import backend.Paths;
import backend.Controls;
import backend.CoolUtil;
import backend.MusicBeatState;
import backend.MusicBeatSubstate;
import backend.CustomFadeTransition;
import backend.ClientPrefs;
import backend.Conductor;
import backend.BaseStage;
import backend.Difficulty;
import backend.Mods;
import backend.Language;
import mobile.backend.StorageUtil;

import backend.ui.*; //Psych-UI
import backend.MenuStyleRouter;

import objects.Alphabet;
import objects.BGSprite;

import states.PlayState;
import states.LoadingState;

#if flxanimate
import flxanimate.*;
import flxanimate.PsychFlxAnimate as FlxAnimate;
#end

import flixel.sound.FlxSound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;
import shaders.flixel.system.FlxShader;

using StringTools;
#end

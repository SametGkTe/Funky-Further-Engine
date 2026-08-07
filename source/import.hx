#if !macro
//Discord API
#if DISCORD_ALLOWED
import backend.Discord;
#end

//Psych
#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end

//P-Slice
import mikolka.funkin.custom.NativeFileSystem as NativeFileSystem;
import mikolka.funkin.*;
import mikolka.funkin.utils.*;
import mikolka.funkin.custom.*;
import mikolka.funkin.players.*;
import states.FreeplayState as C_;

//P-Slice Dialouges
import mikolka.stages.cutscenes.dialogueBox.*;
import mikolka.stages.cutscenes.dialogueBox.DialogueBoxPsych.DialogueFile;
import mikolka.stages.cutscenes.dialogueBox.styles.*;

//utils
using StringTools;
using mikolka.funkin.utils.ArrayTools;
using mikolka.funkin.utils.custom.FunkinTools;
import mikolka.funkin.utils.custom.FunkinTools;
using mikolka.funkin.utils.ArrayTools;
using mikolka.funkin.utils.SpriteTools;
using mikolka.funkin.utils.custom.PsychUITools;
using mikolka.funkin.utils.StringTools;
import backend.ui.*; //Psych-UI
import flixel.ui.FlxBar;
import backend.CacheSystem;

// Mobile Controls
import mobile.objects.MobileControls;
import mobile.objects.Hitbox;
import mobile.objects.TouchPad;
import mobile.objects.TouchButton;
import mobile.input.MobileInputID;
import mobile.backend.MobileData;
import mobile.input.MobileInputManager;
import mobile.backend.TouchUtil;
// Mobile Controls New
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
// Alert
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

//Flixel
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
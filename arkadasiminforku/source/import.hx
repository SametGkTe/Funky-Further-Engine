#if !macro
//Discord API
#if DISCORD_ALLOWED
import backend.Discord;
#end

#if sys
import sys.*;
import sys.io.*;
#elseif js
import js.html.*;
#end

//Psych
#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end

#if flxanimate
import flxanimate.FlxAnimate;
#end

#if lumod
import lumod.Lumod;
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

import objects.Alphabet;
import objects.BGSprite;

import states.PlayState;
import states.LoadingState;

//Flixel
#if (flixel >= "5.3.0")
import flixel.sound.FlxSound;
#else
import flixel.system.FlxSound;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import shaders.flixel.system.FlxShader;
import haxe.ds.StringMap;
import online.backend.Deflection;

// Mobile Controls

// Spesificly Extended Mobile-Controls Library Objects For FNF
import mobile.objects.FunkinMobilePad;
import mobile.objects.FunkinHitbox;
import mobile.objects.FunkinJoyStick;
// Others
import backend.FunkinFileSystem;
import mobile.ScreenUtil;
import mobile.MobileConfig;
import mobile.MobileButton;
import mobile.MobileControlManager;
import mobile.backend.StorageUtil;
import mobile.substates.MobileExtraControl;
import mobile.OnlineTweaks;
//Android
#if android
#if legacy_lime
import extension.androidtools.callback.CallBack as AndroidCallBack;
import extension.androidtools.content.Context as AndroidContext;
import extension.androidtools.widget.Toast as AndroidToast;
import extension.androidtools.os.Environment as AndroidEnvironment;
import extension.androidtools.Permissions as AndroidPermissions;
import extension.androidtools.Settings as AndroidSettings;
import extension.androidtools.Tools as AndroidTools;
import extension.androidtools.os.Build.VERSION as AndroidVersion;
import extension.androidtools.os.Build.VERSION_CODES as AndroidVersionCode;
#else
import android.callback.CallBack as AndroidCallBack;
import android.content.Context as AndroidContext;
import android.widget.Toast as AndroidToast;
import android.os.Environment as AndroidEnvironment;
import android.Permissions as AndroidPermissions;
import android.Settings as AndroidSettings;
import android.Tools as AndroidTools;
import android.os.Build.VERSION as AndroidVersion;
import android.os.Build.VERSION_CODES as AndroidVersionCode;
#end
#end

using StringTools;
using ArrayTools;
#end
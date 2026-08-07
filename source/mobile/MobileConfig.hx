package mobile;

import haxe.Json;
import haxe.io.Path;
import flixel.util.FlxSave;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

enum ButtonsModes
{
	ACTION;
	DPAD;
	HITBOX;
}

/**
 * Config / data loader for the new (ArkoseLabs "mobile-controls" based)
 * mobile controls. Reads the new-format JSON modes:
 *   - MobilePad/DPadModes
 *   - MobilePad/ActionModes
 *   - Hitbox/HitboxModes
 *
 * Adapted from Psych Engine Online Mobile to work with Further Engine's
 * Paths/Mods/FileSystem helpers.
 */
class MobileConfig {
	public static var actionModes:Map<String, MobileButtonsData> = new Map();
	public static var dpadModes:Map<String, MobileButtonsData> = new Map();
	public static var hitboxModes:Map<String, CustomHitboxData> = new Map();
	public static var mobileFolderPath:String = 'assets/mobile/';

	public static var save:FlxSave;

	public static function init(saveName:String, savePath:String, mobilePath:String = 'assets/mobile/', folders:Array<String>, modes:Array<ButtonsModes>)
	{
		save = new FlxSave();
		save.bind(saveName, savePath);
		if (mobilePath != null && mobilePath != '') mobileFolderPath = (mobilePath.endsWith('/') ? mobilePath : mobilePath + '/');

		var intNumber:Int = -1;
		for (i in folders) {
			intNumber++;
			switch (modes[intNumber]) {
				case ACTION:
					readDirectoryPart1(mobileFolderPath + i, actionModes, ACTION);
					#if MODS_ALLOWED
					for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'mobile/MobilePad/')) {
						readDirectoryPart1(Path.join([folder, 'ActionModes']), actionModes, ACTION);
					}
					#end
				case DPAD:
					readDirectoryPart1(mobileFolderPath + i, dpadModes, DPAD);
					#if MODS_ALLOWED
					for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'mobile/MobilePad/')) {
						readDirectoryPart1(Path.join([folder, 'DPadModes']), dpadModes, DPAD);
					}
					#end
				case HITBOX:
					readDirectoryPart1(mobileFolderPath + i, hitboxModes, HITBOX);
					#if MODS_ALLOWED
					for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'mobile/Hitbox/')) {
						readDirectoryPart1(Path.join([folder, 'HitboxModes']), hitboxModes, HITBOX);
					}
					#end
			}
		}
	}

	static function readDirectoryPart1(folder:String, map:Dynamic, mode:ButtonsModes)
	{
		folder = folder.contains(':') ? folder.split(':')[1] : folder;

		#if MODS_ALLOWED if (FileSystem.exists(folder)) #end
		for (file in readDirectoryPart2(folder))
		{
			var fileWithNoLib:String = file.contains(':') ? file.split(':')[1] : file;
			if (Path.extension(fileWithNoLib) == 'json')
			{
				file = Path.join([folder, Path.withoutDirectory(file)]);

				var str:String;
				#if MODS_ALLOWED
				if (FileSystem.exists(file))
					str = File.getContent(file);
				else #end
					str = Assets.getText(file);

				if (mode == HITBOX) {
					var json:CustomHitboxData = cast Json.parse(str);
					var mapKey:String = Path.withoutDirectory(Path.withoutExtension(fileWithNoLib));
					map.set(mapKey, json);
				}
				else if (mode == ACTION || mode == DPAD) {
					var json:MobileButtonsData = cast Json.parse(str);
					var mapKey:String = Path.withoutDirectory(Path.withoutExtension(fileWithNoLib));
					map.set(mapKey, json);
				}
			}
		}
	}

	static function readDirectoryPart2(directory:String):Array<String>
	{
		#if MODS_ALLOWED
		if (FileSystem.exists(directory))
			return FileSystem.readDirectory(directory);
		#end
		return Paths.readDirectory(directory);
	}
}

typedef MobileButtonsData =
{
	buttons:Array<ButtonsData>
}

typedef CustomHitboxData =
{
	hints:Array<HitboxData>, //support library's jsons
	none:Array<HitboxData>,
	single:Array<HitboxData>,
	double:Array<HitboxData>,
	triple:Array<HitboxData>,
	quad:Array<HitboxData>
}

typedef HitboxData =
{
	button:String, // what Hitbox Button should be used, must be a valid Hitbox Button var from Hitbox as a string.
	buttonIDs:Array<String>, // what Hitbox Button Iad should be used, If you're using a the library for PsychEngine 0.7 Versions, This is useful.
	buttonUniqueID:Dynamic, // the button's special ID for button
	//if custom ones isn't setted these will be used
	x:Dynamic, // the button's X position on screen.
	y:Dynamic, // the button's Y position on screen.
	width:Dynamic, // the button's Width on screen.
	height:Dynamic, // the button's Height on screen.
	color:String, // the button color, default color is white.
	returnKey:String, // the button return, default return is nothing (please don't add custom return if you don't need).
	extraKeyMode:Null<Int>,
	//Top
	topX:Dynamic,
	topY:Dynamic,
	topWidth:Dynamic,
	topHeight:Dynamic,
	topColor:String,
	topReturnKey:String,
	topExtraKeyMode:Null<Int>,
	//Middle
	middleX:Dynamic,
	middleY:Dynamic,
	middleWidth:Dynamic,
	middleHeight:Dynamic,
	middleColor:String,
	middleReturnKey:String,
	middleExtraKeyMode:Null<Int>,
	//Bottom
	bottomX:Dynamic,
	bottomY:Dynamic,
	bottomWidth:Dynamic,
	bottomHeight:Dynamic,
	bottomColor:String,
	bottomReturnKey:String,
	bottomExtraKeyMode:Null<Int>
}

typedef ButtonsData =
{
	button:String, // the button's name for checking pressed directly.
	buttonIDs:Array<String>, // what MobileButton Button Iad should be used, If you're using a the library for PsychEngine 0.7 Versions, This is useful.
	buttonUniqueID:Dynamic, // the button's special ID for button
	graphic:String, // the graphic of the button, usually can be located in the MobilePad xml.
	x:Float, // the button's X position on screen.
	y:Float, // the button's Y position on screen.
	color:String, // the button color, default color is white.
	scale:Null<Float>, //the button scale, default scale is 1.
	returnKey:String // the button return, default return is nothing but If you're game using a lua scripting this will be useful.
}

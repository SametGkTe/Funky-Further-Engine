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

		// TitleState points MobileConfig at assets/shared/mobile, but lime
		// packs the extra ActionModes under assets/mobile. Scan both.
		if (mobileFolderPath.indexOf('assets/shared/') == 0)
		{
			readDirectoryPart1('assets/mobile/MobilePad/ActionModes', actionModes, ACTION);
			readDirectoryPart1('assets/mobile/ActionModes', actionModes, ACTION);
			readDirectoryPart1('assets/mobile/MobilePad/DPadModes', dpadModes, DPAD);
			readDirectoryPart1('assets/mobile/DPadModes', dpadModes, DPAD);
		}

		ensureBuiltinActionModes();
		ensureBuiltinDpadModes();
	}

	static var defaultInited:Bool = false;

	public static function initDefault():Void
	{
		if (defaultInited)
			return;
		defaultInited = true;
		MobileData.init();
		init('MobileControls', CoolUtil.getSavePath(), 'assets/shared/mobile/',
			['MobilePad/DPadModes', 'MobilePad/ActionModes', 'Hitbox/HitboxModes'],
			[DPAD, ACTION, HITBOX]
		);
	}

	public static inline var FREEPLAY_ACTION_MODE:String = 'A_B_C_P_X_Y_Z';

	/**
	 * Freeplay needs A_B_C_P_X_Y_Z. The JSON may live under assets/mobile
	 * while MobileConfig reads assets/shared/mobile — inject the mode if
	 * the packed APK never copied that file.
	 */
	public static function ensureBuiltinActionModes():Void
	{
		if (!actionModes.exists(FREEPLAY_ACTION_MODE))
		{
			var buttons:Array<ButtonsData> = [];
			if (actionModes.exists('A_B_C_X_Y_Z') && actionModes.get('A_B_C_X_Y_Z').buttons != null)
			{
				for (b in actionModes.get('A_B_C_X_Y_Z').buttons)
					buttons.push(b);
			}
			else
			{
				buttons = defaultAbcxyzButtons();
			}

			var hasP:Bool = false;
			for (b in buttons)
			{
				if (b != null && b.button == 'buttonP')
				{
					hasP = true;
					break;
				}
			}
			if (!hasP)
				buttons.push(makeButton('buttonP', 'p', 1156, 348, '0xE5DE00', ['P']));

			actionModes.set(FREEPLAY_ACTION_MODE, {buttons: buttons});
		}

		if (!actionModes.exists('A'))
			actionModes.set('A', {buttons: [makeButton('buttonA', 'a', 1156, 596, '0xFF0000', ['A'])]});
		if (!actionModes.exists('B'))
			actionModes.set('B', {buttons: [makeButton('buttonB', 'b', 1032, 596, '0xFFCB00', ['B'])]});
		if (!actionModes.exists('P'))
			actionModes.set('P', {buttons: [makeButton('buttonP', 'p', 1156, 348, '0xE5DE00', ['P'])]});
		if (!actionModes.exists('E'))
			actionModes.set('E', {buttons: [makeButton('buttonE', 'e', 1156, 596, '0xFF0000', ['E'])]});
		if (!actionModes.exists('A_B'))
			actionModes.set('A_B', {buttons: [
				makeButton('buttonA', 'a', 1156, 596, '0xFF0000', ['A']),
				makeButton('buttonB', 'b', 1032, 596, '0xFFCB00', ['B'])
			]});
		if (!actionModes.exists('A_B_C'))
			actionModes.set('A_B_C', {buttons: [
				makeButton('buttonA', 'a', 1156, 596, '0xFF0000', ['A']),
				makeButton('buttonB', 'b', 1032, 596, '0xFFCB00', ['B']),
				makeButton('buttonC', 'c', 908, 596, '0x44FF00', ['C'])
			]});
		if (!actionModes.exists('B_C'))
			actionModes.set('B_C', {buttons: [
				makeButton('buttonB', 'b', 1032, 596, '0xFFCB00', ['B']),
				makeButton('buttonC', 'c', 908, 596, '0x44FF00', ['C'])
			]});
		if (!actionModes.exists('A_B_X_Y'))
			actionModes.set('A_B_X_Y', {buttons: [
				makeButton('buttonA', 'a', 1156, 596, '0xFF0000', ['A']),
				makeButton('buttonB', 'b', 1032, 596, '0xFFCB00', ['B']),
				makeButton('buttonX', 'x', 908, 472, '0x99062D', ['X']),
				makeButton('buttonY', 'y', 1032, 472, '0x4A35B9', ['Y'])
			]});
		if (!actionModes.exists('A_B_C_X_Y_Z'))
			actionModes.set('A_B_C_X_Y_Z', {buttons: defaultAbcxyzButtons()});
	}

	public static function ensureBuiltinDpadModes():Void
	{
		if (!dpadModes.exists('LEFT_RIGHT'))
			dpadModes.set('LEFT_RIGHT', {buttons: [
				makeButton('buttonLeft', 'left', 0, 585, '0xFFC24B99', ['LEFT']),
				makeButton('buttonRight', 'right', 126, 585, '0xFFF9393F', ['RIGHT'])
			]});
		if (!dpadModes.exists('UP_DOWN'))
			dpadModes.set('UP_DOWN', {buttons: [
				makeButton('buttonUp', 'up', 0, 465, '0xFF12FA05', ['UP']),
				makeButton('buttonDown', 'down', 0, 585, '0xFF00FFFF', ['DOWN'])
			]});
		if (!dpadModes.exists('LEFT_FULL'))
			dpadModes.set('LEFT_FULL', {buttons: [
				makeButton('buttonUp', 'up', 105, 372, '0xFF12FA05', ['UP']),
				makeButton('buttonLeft', 'left', 0, 477, '0xFFC24B99', ['LEFT']),
				makeButton('buttonRight', 'right', 207, 477, '0xFFF9393F', ['RIGHT']),
				makeButton('buttonDown', 'down', 105, 585, '0xFF00FFFF', ['DOWN'])
			]});
		if (!dpadModes.exists('RIGHT_FULL'))
			dpadModes.set('RIGHT_FULL', {buttons: [
				makeButton('buttonUp', 'up', 1022, 314, '0xFF12FA05', ['UP']),
				makeButton('buttonLeft', 'left', 896, 413, '0xFFC24B99', ['LEFT']),
				makeButton('buttonRight', 'right', 1148, 413, '0xFFF9393F', ['RIGHT']),
				makeButton('buttonDown', 'down', 1022, 521, '0xFF00FFFF', ['DOWN'])
			]});
		if (!dpadModes.exists('FULL') && dpadModes.exists('LEFT_FULL'))
			dpadModes.set('FULL', dpadModes.get('LEFT_FULL'));
	}

	static function defaultAbcxyzButtons():Array<ButtonsData>
	{
		return [
			makeButton('buttonX', 'x', 908, 472, '0x99062D', ['X']),
			makeButton('buttonC', 'c', 908, 596, '0x44FF00', ['C']),
			makeButton('buttonY', 'y', 1032, 472, '0x4A35B9', ['Y']),
			makeButton('buttonB', 'b', 1032, 596, '0xFFCB00', ['B']),
			makeButton('buttonZ', 'z', 1156, 472, '0xCCB98E', ['Z']),
			makeButton('buttonA', 'a', 1156, 596, '0xFF0000', ['A'])
		];
	}

	static function makeButton(name:String, graphic:String, x:Float, y:Float, color:String, ids:Array<String>):ButtonsData
	{
		return {
			button: name,
			buttonIDs: ids,
			buttonUniqueID: null,
			graphic: graphic,
			x: x,
			y: y,
			color: color,
			scale: null,
			returnKey: null
		};
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

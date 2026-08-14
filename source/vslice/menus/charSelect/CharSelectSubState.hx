package vslice.menus.charSelect;

#if TOUCH_CONTROLS_ALLOWED
import mobile.objects.TouchZone;
#end

import openfl.utils.Assets;
import openfl.utils.AssetType;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import vslice.funkin.custom.PsliceRegistry;
import haxe.io.Path;
import flixel.group.FlxGroup;
import vslice.funkin.custom.mobile.MobileScaleMode;
import vslice.compatibility.ModsHelper;
import vslice.compatibility.VsliceOptions;
import vslice.compatibility.freeplay.FreeplayHelpers;
import vslice.menus.freeplay.FreeplayState;
import openfl.filters.BitmapFilter;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.system.debug.watch.Tracker.TrackerProfile;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import vslice.funkin.FunkinSound;
import vslice.funkin.players.PlayerRegistry;
import vslice.funkin.FlxAtlasSprite;
import openfl.filters.DropShadowFilter;
import vslice.compatibility.funkin.FunkinCamera;
import shaders.BlueFade;
import vslice.funkin.players.PlayableCharacter;
import vslice.menus.freeplay.obj.PixelatedIcon;
import vslice.funkin.utils.MathUtil;
import funkin.vis.dsp.SpectralAnalyzer;
import openfl.display.BlendMode;
import openfl.filters.ShaderFilter;
import vslice.funkin.FramesJSFLParser;
import vslice.funkin.FramesJSFLParser.FramesJSFLInfo;
import vslice.funkin.custom.VsliceSubState as MusicBeatSubState;
import vslice.compatibility.funkin.FunkinPath as Paths;
import backend.Paths as BackendPaths;
import haxe.Json;

enum CharacterType
{
	VSLICE;
	PSYCH;
}

typedef CharSelectEntry =
{
	var id:String;
	var name:String;
	var type:CharacterType;
	var slot:Int;
	var ?imagePath:String;
	var ?idleAnim:String;
	var ?flipX:Bool;
	var ?scale:Float;
	var ?isBaseGame:Bool;
	var ?sourceMod:String;
}

class CharSelectSubState extends MusicBeatSubState
{
	var chrSelectCursor:FlxSprite;

	var cursorBlue:FlxSprite;
	var cursorDarkBlue:FlxSprite;
	var grpCursors:FlxTypedGroup<FlxSprite>;
	var cursorConfirmed:FlxSprite;
	var cursorDenied:FlxSprite;
	var cursorX:Int = 0;
	var cursorY:Int = 0;
	var cursorFactor:Float = 110;
	var cursorOffsetX:Float = -16;
	var cursorOffsetY:Float = -48;
	var cursorLocIntended:FlxPoint = new FlxPoint(0, 0);
	var lerpAmnt:Float = 0.95;
	var tmrFrames:Int = 60;
	var playerChill:CharSelectPlayer;
	var playerChillOut:CharSelectPlayer;
	var psychCharSprite:FlxSprite;
	var gfChill:CharSelectGF;
	var gfChillOut:CharSelectGF;
	var barthing:FlxAtlasSprite;
	var dipshitBacking:FlxSprite;
	var chooseDipshit:FlxSprite;
	var dipshitBlur:FlxSprite;
	var transitionGradient:FlxSprite;
	var curChar(default, set):String = "bf";
	var nametag:Nametag;
	var camFollow:FlxObject;
	var autoFollow:Bool = false;
	var availableChars:Map<Int, String> = new Map<Int, String>();
	var pressedSelect:Bool = false;
	var selectTimer:FlxTimer = new FlxTimer();
	var allowInput:Bool = false;

	var selectSound:FunkinSound;
	var unlockSound:FunkinSound;
	var lockedSound:FunkinSound;
	var introSound:FunkinSound;
	var staticSound:FunkinSound;

	#if TOUCH_CONTROLS_ALLOWED
	var touchKeys:Array<TouchZone>;
	#end

	var selectedBizz:Array<BitmapFilter> = [
		new DropShadowFilter(0, 0, 0xFFFFFF, 1, 2, 2, 19, 1, false, false, false),
		new DropShadowFilter(5, 45, 0x000000, 1, 2, 2, 1, 1, false, false, false)
	];

	var bopInfo:FramesJSFLInfo;
	var blackScreen:FunkinSprite;
	var cutoutSize:Float = 0;

	// Sayfa sistemi ve karakter registry
	var allCharEntries:Array<CharSelectEntry> = [];
	var charEntryMap:Map<String, CharSelectEntry> = new Map();
	public var currentPage:Int = 0;
	var totalPages:Int = 1;
	var pageIndicatorText:FlxText;
	
	static function fsExists(path:String):Bool
	{
		#if sys
		return FileSystem.exists(path);
		#else
		return NativeFileSystem.exists(path);
		#end
	}

	static function fsIsDirectory(path:String):Bool
	{
		#if sys
		return FileSystem.exists(path) && FileSystem.isDirectory(path);
		#else
		return NativeFileSystem.exists(path);
		#end
	}

	static function fsReadDirectory(path:String):Array<String>
	{
		#if sys
		return FileSystem.readDirectory(path);
		#else
		return NativeFileSystem.readDirectory(path);
		#end
	}

	static function fsGetContent(path:String):String
	{
		#if sys
		return File.getContent(path);
		#else
		return NativeFileSystem.getContent(path);
		#end
	}

	// Hangi mod context aktifti (geri dönüş için)
	var originalMod:String = "";

	public function new()
	{
		super();
		originalMod = ModsHelper.getActiveMod() ?? "";

		var charData = VsliceOptions.LAST_MOD;
		if (ModsHelper.isModDirEnabled(charData.mod_dir) || charData.mod_dir == '')
		{
			ModsHelper.loadModDir(charData.mod_dir);
			@:bypassAccessor
			curChar = charData.char_name;
		}
		loadAvailableCharacters();
	}

	function debugAvailableChars(label:String):Void
	{
		var slots:Array<String> = [];
		for (i in 0...9)
		{
			slots.push(i + ":" + (availableChars.exists(i) ? availableChars.get(i) : "EMPTY"));
		}

		var all:Array<String> = [];
		for (k => v in availableChars)
		{
			all.push(k + ":" + v);
		}

		trace('[CS] ' + label + ' slots=' + slots.join(" | "));
		trace('[CS] ' + label + ' all=' + all.join(" | "));
	}

	public function loadAvailableCharacters():Void
	{
		availableChars = new Map<Int, String>();
		allCharEntries = [];
		charEntryMap = new Map();

		var prevMod = ModsHelper.getActiveMod() ?? "";

		loadVSliceCharacters();
		loadPsychCharacters();

		ModsHelper.loadModDir(prevMod);

		buildPages();
		applyCurrentPage();

		trace("[CS] loadAvailableCharacters complete. Total entries: " + allCharEntries.length + " Pages: " + totalPages);
		debugAvailableChars("after loadAvailableCharacters");
	}
	
	function getAllModsFromFolder():Array<String>
	{
		var result:Array<String> = [];
		var modsRoot = PsliceRegistry.resolveModsRoot();

		if (modsRoot == null)
		{
			trace("[CS] mods folder not found");
			return result;
		}

		trace("[CS] resolved mods root: " + modsRoot);

		for (entry in fsReadDirectory(modsRoot))
		{
			if (entry == null || entry.length < 1)
				continue;

			var playersDir = Path.join([modsRoot, entry, "data", "players"]);
			var charsDir = Path.join([modsRoot, entry, "characters"]);

			if (fsIsDirectory(playersDir) || fsIsDirectory(charsDir))
			{
				result.push(entry);
			}
		}

		trace("[CS] All mods from folder: " + result.join(", "));
		return result;
	}

	function loadVSliceCharacters():Void
	{
		var allPlayerIds:Array<{id:String, mod:String}> = [];
		var seen:Map<String, Bool> = new Map();
		var modsRoot = PsliceRegistry.resolveModsRoot();

		inline function addPlayer(id:String, mod:String):Void
		{
			if (id == null || id.length < 1 || seen.exists(id))
				return;

			seen.set(id, true);
			allPlayerIds.push({id: id, mod: mod});
		}

		ModsHelper.loadModDir("");

		var sharedPrefix = BackendPaths.getSharedPath("registry/players/");
		for (asset in Assets.list(AssetType.TEXT))
		{
			if (!asset.endsWith(".json"))
				continue;

			if (asset.indexOf(sharedPrefix) != 0)
				continue;

			var relative = asset.substr(sharedPrefix.length);
			if (relative.indexOf("/") != -1 || relative.indexOf("\\") != -1)
				continue;

			var id = relative.substr(0, relative.length - 5);
			addPlayer(id, "");
		}

		if (modsRoot != null)
		{
			for (mod in getAllModsFromFolder())
			{
				var playersDir = Path.join([modsRoot, mod, "data", "players"]);
				if (!fsIsDirectory(playersDir))
					continue;

				for (file in fsReadDirectory(playersDir))
				{
					if (!file.endsWith(".json"))
						continue;

					var id = file.substr(0, file.length - 5);
					addPlayer(id, mod);
				}
			}
		}

		trace("[CS] V-Slice player IDs found: " + [for (p in allPlayerIds) p.id + "(" + (p.mod == "" ? "base" : p.mod) + ")"].join(", "));

		for (playerInfo in allPlayerIds)
		{
			ModsHelper.loadModDir(playerInfo.mod);
			var player:Null<PlayableCharacter> = PlayerRegistry.instance.fetchEntry(playerInfo.id);

			if (player == null)
				continue;

			var charSelectData = player.getCharSelectData();
			var slot:Int = (charSelectData != null && charSelectData.position != null) ? charSelectData.position : -1;

			var entry:CharSelectEntry = {
				id: playerInfo.id,
				name: player.getName(),
				type: VSLICE,
				slot: slot,
				isBaseGame: (playerInfo.mod == ""),
				sourceMod: playerInfo.mod
			};

			allCharEntries.push(entry);
			charEntryMap.set(playerInfo.id, entry);
			trace("[CS] Loaded V-Slice character: " + playerInfo.id + " slot=" + slot + " mod=" + (playerInfo.mod == "" ? "base" : playerInfo.mod));
		}
	}

	function loadPsychCharacters():Void
	{
		var modsRoot = PsliceRegistry.resolveModsRoot();
		if (modsRoot == null)
			return;

		for (mod in getAllModsFromFolder())
		{
			var modCharDir = Path.join([modsRoot, mod, "characters"]);

			if (!fsIsDirectory(modCharDir))
				continue;

			var files = fsReadDirectory(modCharDir);
			trace("[CS] Psych files in " + mod + ": " + files.join(", "));

			for (file in files)
			{
				// Sadece .json uzantılı dosyalar
				if (!file.endsWith(".json"))
					continue;

				var fullPath = Path.join([modCharDir, file]);
				if (fsIsDirectory(fullPath))
					continue;

				var charId = file.substr(0, file.length - 5);

				if (charEntryMap.exists(charId))
					continue;

				loadSinglePsychCharacter(charId, fullPath, mod);
			}
		}
	}

	function loadSinglePsychCharacter(charId:String, jsonPath:String, sourceMod:String):Void
	{
		try
		{
			var content = fsGetContent(jsonPath);
			if (content == null || content.length < 1)
				return;

			var json:Dynamic = Json.parse(content);
			if (json == null)
				return;

			var imagePath:String = json.image;
			if (imagePath == null || imagePath.length < 1)
				return;

			var idleAnim:String = "BF idle dance";
			var anims:Array<Dynamic> = json.animations;
			if (anims != null)
			{
				for (anim in anims)
				{
					var animName:String = anim.anim;
					if (animName == "idle" || animName == "danceLeft" || animName == "danceRight")
					{
						idleAnim = anim.name;
						break;
					}
				}
			}

			var charName:String = charId.charAt(0).toUpperCase() + charId.substr(1);
			charName = charName.split("-").join(" ");

			var flipX:Bool = json.flip_x != null ? cast(json.flip_x, Bool) : false;
			var scale:Float = json.scale != null ? cast(json.scale, Float) : 1.0;

			var entry:CharSelectEntry = {
				id: charId,
				name: charName,
				type: PSYCH,
				slot: -1,
				imagePath: imagePath,
				idleAnim: idleAnim,
				flipX: flipX,
				scale: scale,
				isBaseGame: false,
				sourceMod: sourceMod
			};

			allCharEntries.push(entry);
			charEntryMap.set(charId, entry);
			trace("[CS] Loaded Psych character: " + charId + " mod=" + sourceMod + " image=" + imagePath);
		}
		catch (e)
		{
			trace("[CS] Failed to load Psych character: " + charId + " error=" + e);
		}
	}

	function isBaseGamePlayer(playerId:String):Bool
	{
		#if LEGACY_PSYCH
		var basePath = "assets/registry/players/" + playerId + ".json";
		#else
		var basePath = "assets/shared/registry/players/" + playerId + ".json";
		#end
		return NativeFileSystem.exists(basePath) || openfl.utils.Assets.exists(BackendPaths.getSharedPath("registry/players/" + playerId + ".json"), TEXT);
	}

	function buildPages():Void
	{
		var baseGameChars:Array<CharSelectEntry> = [];
		var modChars:Array<CharSelectEntry> = [];

		for (entry in allCharEntries)
		{
			if (entry.isBaseGame == true)
				baseGameChars.push(entry);
			else
				modChars.push(entry);
		}

		var usedSlots:Map<Int, Bool> = new Map();
		var sortedEntries:Array<CharSelectEntry> = [];

		// 1) Base game tercih edilen slotlara
		for (entry in baseGameChars)
		{
			if (entry.slot >= 0 && entry.slot < 9 && !usedSlots.exists(entry.slot))
			{
				usedSlots.set(entry.slot, true);
				sortedEntries.push(entry);
			}
		}

		// 2) Mod V-Slice tercih edilen slotlara
		for (entry in modChars)
		{
			if (entry.type == VSLICE && entry.slot >= 0 && entry.slot < 9 && !usedSlots.exists(entry.slot))
			{
				usedSlots.set(entry.slot, true);
				sortedEntries.push(entry);
			}
		}

		// 3) Kalan base game -> boş slot
		for (entry in baseGameChars)
		{
			if (!sortedEntries.contains(entry))
			{
				var freeSlot = findFreeSlot(usedSlots);
				if (freeSlot != -1)
				{
					entry.slot = freeSlot;
					usedSlots.set(freeSlot, true);
				}
				sortedEntries.push(entry);
			}
		}

		// 4) Kalan mod karakterleri -> boş slot
		for (entry in modChars)
		{
			if (!sortedEntries.contains(entry))
			{
				var freeSlot = findFreeSlot(usedSlots);
				if (freeSlot != -1)
				{
					entry.slot = freeSlot;
					usedSlots.set(freeSlot, true);
				}
				sortedEntries.push(entry);
			}
		}

		allCharEntries = [];

		var firstPage:Array<CharSelectEntry> = [];
		var overflow:Array<CharSelectEntry> = [];

		for (entry in sortedEntries)
		{
			if (entry.slot >= 0 && entry.slot < 9)
				firstPage.push(entry);
			else
				overflow.push(entry);
		}

		for (entry in firstPage)
			allCharEntries.push(entry);

		var pageSlotCounter:Int = 0;
		for (entry in overflow)
		{
			entry.slot = pageSlotCounter;
			pageSlotCounter++;
			if (pageSlotCounter >= 9)
				pageSlotCounter = 0;
			allCharEntries.push(entry);
		}

		totalPages = Math.ceil(allCharEntries.length / 9);
		if (totalPages < 1)
			totalPages = 1;

		trace("[CS] buildPages: " + allCharEntries.length + " chars, " + totalPages + " pages");
	}

	function findFreeSlot(usedSlots:Map<Int, Bool>):Int
	{
		for (i in 0...9)
		{
			if (!usedSlots.exists(i))
				return i;
		}
		return -1;
	}

	function applyCurrentPage():Void
	{
		availableChars = new Map<Int, String>();

		var startIndex = currentPage * 9;
		var endIndex = Std.int(Math.min(startIndex + 9, allCharEntries.length));

		for (i in startIndex...endIndex)
		{
			var entry = allCharEntries[i];
			var localSlot = entry.slot;
			if (currentPage > 0)
				localSlot = i - startIndex;

			availableChars.set(localSlot, entry.id);
		}

		trace("[CS] applyCurrentPage: page=" + currentPage + "/" + totalPages);
		debugAvailableChars("page " + currentPage);
	}

	function changePage(direction:Int):Void
	{
		var newPage = currentPage + direction;
		if (newPage < 0)
			newPage = totalPages - 1;
		if (newPage >= totalPages)
			newPage = 0;

		if (newPage == currentPage)
			return;

		currentPage = newPage;
		applyCurrentPage();

		remove(grpIcons);
		initLocks();
		ensureValidCursor();

		updatePageIndicator();

		selectSound.play(true);
		trace("[CS] changePage -> " + currentPage);
	}

	public function updatePageIndicator():Void
	{
		if (pageIndicatorText != null)
		{
			if (totalPages > 1)
			{
				pageIndicatorText.visible = true;
				pageIndicatorText.text = "< PAGE " + (currentPage + 1) + "/" + totalPages + " >  [Q/E]";
			}
			else
			{
				pageIndicatorText.visible = false;
			}
		}
	}

	function switchToCharMod(charId:String):Void
	{
		var entry = charEntryMap.get(charId);
		if (entry != null && entry.sourceMod != null)
		{
			ModsHelper.loadModDir(entry.sourceMod);
		}
		else
		{
			ModsHelper.loadModDir("");
		}
	}

	function getCharType(charId:String):CharacterType
	{
		if (charEntryMap.exists(charId))
			return charEntryMap.get(charId).type;
		return VSLICE;
	}

	function getCharEntry(charId:String):Null<CharSelectEntry>
	{
		return charEntryMap.get(charId);
	}

	var fadeShader:BlueFade = new BlueFade();

	override public function create():Void
	{
		super.create();

		cutoutSize = MobileScaleMode.gameCutoutSize.x / 2;

		bopInfo = FramesJSFLParser.parse("images/charSelect/iconBopInfo/iconBopInfo.txt");

		var bg:FlxSprite = new FlxSprite(cutoutSize + -153, -140);
		bg.loadGraphic(Paths.image('charSelect/charSelectBG'));
		bg.scrollFactor.set(0.1, 0.1);
		add(bg);

		var crowd:FlxAtlasSprite = new FlxAtlasSprite(cutoutSize, 0, "charSelect/crowd");
		crowd.anim.play();
		crowd.anim.onComplete.add(function() { crowd.anim.play(); });
		crowd.scrollFactor.set(0.3, 0.3);
		add(crowd);

		var stageSpr:FlxAtlasSprite = new FlxAtlasSprite(cutoutSize + -2, 1, "charSelect/charSelectStage");
		stageSpr.anim.play("");
		stageSpr.anim.onComplete.add(function() { stageSpr.anim.play(""); });
		add(stageSpr);

		var curtains:FlxSprite = new FlxSprite(cutoutSize + (-47 - 165), -49 - 50);
		curtains.loadGraphic(Paths.image('charSelect/curtains'));
		curtains.scrollFactor.set(1.4, 1.4);
		add(curtains);

		barthing = new FlxAtlasSprite(0, 0, "charSelect/barThing");
		barthing.anim.play("");
		barthing.anim.onComplete.add(function() { barthing.anim.play(""); });
		barthing.blend = BlendMode.MULTIPLY;
		barthing.scale.x = 2.5;
		barthing.scrollFactor.set(0, 0);
		add(barthing);

		barthing.y += 80;
		FlxTween.tween(barthing, {y: barthing.y - 80}, 1.3, {ease: FlxEase.expoOut});

		var charLight:FlxSprite = new FlxSprite(cutoutSize + 800, 250);
		charLight.loadGraphic(Paths.image('charSelect/charLight'));
		add(charLight);

		var charLightGF:FlxSprite = new FlxSprite(cutoutSize + 180, 240);
		charLightGF.loadGraphic(Paths.image('charSelect/charLight'));
		add(charLightGF);

		function setupPlayerChill(character:String)
		{
			gfChill = new CharSelectGF();
			gfChill.x += cutoutSize;
			add(gfChill);

			playerChillOut = new CharSelectPlayer(cutoutSize * 2, 0);
			playerChillOut.visible = false;
			add(playerChillOut);

			playerChill = new CharSelectPlayer(cutoutSize * 2.5, 0);
			playerChill.visible = false;
			add(playerChill);

			psychCharSprite = new FlxSprite(cutoutSize + 850, 75);
			psychCharSprite.visible = false;
			psychCharSprite.scrollFactor.set(1, 1);
			add(psychCharSprite);

			var charType = getCharType(character);
			switch (charType)
			{
				case PSYCH:
					applyPsychPreview(character);
				case VSLICE:
					applyVSlicePreview(character);
			}
		}

		var startChar:String = curChar;
		if (startChar == null || startChar.length < 1)
			startChar = Constants.DEFAULT_CHARACTER;

		var startIndex:Int = getIndexForChar(startChar);
		if (startIndex == -1)
			startIndex = getIndexForChar(Constants.DEFAULT_CHARACTER);
		if (startIndex == -1)
			startIndex = getFirstSelectableIndex();

		if (startIndex != -1)
		{
			startChar = availableChars.get(startIndex);
			setCursorPosition(startIndex);
		}
		else
		{
			startChar = Constants.DEFAULT_CHARACTER;
		}

		setupPlayerChill(startChar);
		@:bypassAccessor curChar = startChar;

		trace('[CS] startChar=' + startChar + ' startIndex=' + startIndex + ' cursor=(' + cursorX + ',' + cursorY + ')');

		var speakers:FlxAtlasSprite = new FlxAtlasSprite(cutoutSize - 10, 0, "charSelect/charSelectSpeakers");
		speakers.anim.play("");
		speakers.anim.onComplete.add(function() { speakers.anim.play(""); });
		speakers.scrollFactor.set(1.8, 1.8);
		speakers.scale.set(1.05, 1.05);
		add(speakers);

		var fgBlur:FlxSprite = new FlxSprite(cutoutSize + -125, 170);
		fgBlur.loadGraphic(Paths.image('charSelect/foregroundBlur'));
		fgBlur.blend = openfl.display.BlendMode.MULTIPLY;
		add(fgBlur);

		dipshitBlur = new FlxSprite(cutoutSize + 419, -65);
		dipshitBlur.frames = Paths.getSparrowAtlas("charSelect/dipshitBlur");
		dipshitBlur.animation.addByPrefix('idle', "CHOOSE vertical offset instance 1", 24, true);
		dipshitBlur.blend = BlendMode.ADD;
		dipshitBlur.animation.play("idle");
		add(dipshitBlur);

		dipshitBacking = new FlxSprite(cutoutSize + 423, -17);
		dipshitBacking.frames = Paths.getSparrowAtlas("charSelect/dipshitBacking");
		dipshitBacking.animation.addByPrefix('idle', "CHOOSE horizontal offset instance 1", 24, true);
		dipshitBacking.blend = BlendMode.ADD;
		dipshitBacking.animation.play("idle");
		add(dipshitBacking);

		dipshitBacking.y += 210;
		FlxTween.tween(dipshitBacking, {y: dipshitBacking.y - 210}, 1.1, {ease: FlxEase.expoOut});

		chooseDipshit = new FlxSprite(cutoutSize + 426, -13);
		chooseDipshit.loadGraphic(Paths.image('charSelect/chooseDipshit'));
		add(chooseDipshit);

		chooseDipshit.y += 200;
		FlxTween.tween(chooseDipshit, {y: chooseDipshit.y - 200}, 1, {ease: FlxEase.expoOut});

		dipshitBlur.y += 220;
		FlxTween.tween(dipshitBlur, {y: dipshitBlur.y - 220}, 1.2, {ease: FlxEase.expoOut});

		chooseDipshit.scrollFactor.set();
		dipshitBacking.scrollFactor.set();
		dipshitBlur.scrollFactor.set();

		nametag = new Nametag(curChar, charEntryMap);
		nametag.midpointX += cutoutSize;
		add(nametag);
		@:privateAccess
		{
			nametag.midpointY += 200;
			FlxTween.tween(nametag, {midpointY: nametag.midpointY - 200}, 1, {ease: FlxEase.expoOut});
		}
		nametag.scrollFactor.set();

		pageIndicatorText = new FlxText(0, FlxG.height - 85, FlxG.width, "", 24);
		pageIndicatorText.setFormat(BackendPaths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
		pageIndicatorText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		pageIndicatorText.scrollFactor.set();
		add(pageIndicatorText);
		updatePageIndicator();

		FlxG.debugger.addTrackerProfile(new TrackerProfile(FlxSprite, ["x", "y", "alpha", "scale", "blend"]));
		FlxG.debugger.addTrackerProfile(new TrackerProfile(FlxAtlasSprite, ["x", "y"]));
		FlxG.debugger.addTrackerProfile(new TrackerProfile(FlxSound, ["pitch", "volume"]));

		grpCursors = new FlxTypedGroup<FlxSprite>();
		add(grpCursors);

		chrSelectCursor = new FlxSprite(0, 0);
		chrSelectCursor.loadGraphic(Paths.image('charSelect/charSelector'));
		chrSelectCursor.color = 0xFFFFFF00;

		cursorBlue = new FlxSprite(0, 0);
		cursorBlue.loadGraphic(Paths.image('charSelect/charSelector'));
		cursorBlue.color = 0xFF3EBBFF;

		cursorDarkBlue = new FlxSprite(0, 0);
		cursorDarkBlue.loadGraphic(Paths.image('charSelect/charSelector'));
		cursorDarkBlue.color = 0xFF3C74F7;

		cursorBlue.blend = BlendMode.SCREEN;
		cursorDarkBlue.blend = BlendMode.SCREEN;

		cursorConfirmed = new FlxSprite(0, 0);
		cursorConfirmed.scrollFactor.set();
		cursorConfirmed.frames = Paths.getSparrowAtlas("charSelect/charSelectorConfirm");
		cursorConfirmed.animation.addByPrefix("idle", "cursor ACCEPTED instance 1", 24, true);
		cursorConfirmed.visible = false;
		add(cursorConfirmed);

		cursorDenied = new FlxSprite(0, 0);
		cursorDenied.scrollFactor.set();
		cursorDenied.frames = Paths.getSparrowAtlas("charSelect/charSelectorDenied");
		cursorDenied.animation.addByPrefix("idle", "cursor DENIED instance 1", 24, false);
		cursorDenied.visible = false;
		add(cursorDenied);

		grpCursors.add(cursorDarkBlue);
		grpCursors.add(cursorBlue);
		grpCursors.add(chrSelectCursor);

		selectSound = FunkinSound.load(Paths.sound('CS_select'), 0.7);
		selectSound.pitch = 1;
		FlxG.sound.defaultSoundGroup.add(selectSound);
		FlxG.sound.list.add(selectSound);

		unlockSound = FunkinSound.load(Paths.sound('CS_unlock'), 0);
		unlockSound.pitch = 1;
		unlockSound.play(true);
		FlxG.sound.defaultSoundGroup.add(unlockSound);
		FlxG.sound.list.add(unlockSound);

		lockedSound = FunkinSound.load(Paths.sound('CS_locked'), 1);
		lockedSound.pitch = 1;
		FlxG.sound.defaultSoundGroup.add(lockedSound);
		FlxG.sound.list.add(lockedSound);

		staticSound = FunkinSound.load(Paths.sound('static loop'), 0.6, true);
		staticSound.pitch = 1;
		FlxG.sound.defaultSoundGroup.add(staticSound);
		FlxG.sound.list.add(staticSound);

		FunkinSound.playMusic('stayFunky', {
			startingVolume: 0,
			overrideExisting: true,
			restartTrack: true,
		});

		FreeplayHelpers.BPM = 90;
		initLocks();
		ensureValidCursor();

		for (index => member in grpIcons.members)
		{
			member.y += 300;
			FlxTween.tween(member, {y: member.y - 300}, 1, {ease: FlxEase.expoOut});
		}

		chrSelectCursor.scrollFactor.set();
		cursorBlue.scrollFactor.set();
		cursorDarkBlue.scrollFactor.set();

		FlxTween.color(chrSelectCursor, 0.2, 0xFFFFFF00, 0xFFFFCC00, {type: PINGPONG});

		FlxG.debugger.addTrackerProfile(new TrackerProfile(CharSelectSubState, ["curChar", "grpXSpread", "grpYSpread"]));
		FlxG.debugger.track(this);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		camFollow.screenCenter();

		FlxG.camera.follow(camFollow, LOCKON);

		var fadeShaderFilter:ShaderFilter = new ShaderFilter(fadeShader);
		ModsHelper.setFiltersOnCam(FlxG.camera, [fadeShaderFilter]);

		transitionGradient = new FlxSprite(0, 0).loadGraphic(Paths.image('freeplay/transitionGradient'));
		transitionGradient.scale.set(1280, 1);
		transitionGradient.flipY = true;
		transitionGradient.updateHitbox();
		FlxTween.tween(transitionGradient, {y: -720}, 1, {ease: FlxEase.expoOut});
		add(transitionGradient);

		camFollow.screenCenter();
		camFollow.y -= 150;
		FlxG.camera.snapToTarget();
		fadeShader.fade(0.0, 1.0, 0.8, {ease: FlxEase.quadOut});
		FlxTween.tween(camFollow, {y: camFollow.y + 150}, 1.5, {
			ease: FlxEase.expoOut,
			onComplete: function(_)
			{
				ensureValidCursor();
				autoFollow = true;
				FlxG.camera.follow(camFollow, LOCKON, 0.01);
			}
		});

		var blackScreen = new FunkinSprite().makeSolidColor(FlxG.width * 2, FlxG.height * 2, 0xFF000000);
		blackScreen.x = -(FlxG.width * 0.5);
		blackScreen.y = -(FlxG.height * 0.5);
		add(blackScreen);

		introSound = FunkinSound.load(Paths.sound('CS_Lights'), 0);
		introSound.pitch = 1;
		FlxG.sound.defaultSoundGroup.add(introSound);
		FlxG.sound.list.add(introSound);

		#if TOUCH_CONTROLS_ALLOWED
		touchKeys = new Array();
		for (index in 0...9)
		{
			var posX:Float = (index % 3);
			var posY:Float = Math.floor(index / 3);

			var finalX = (posX * grpXSpread) + cutoutSize + 450 + 16;
			var finalY = (posY * grpYSpread) + 120 + 20;

			var touch = new TouchZone(finalX, finalY, 100, 100, FlxColor.PURPLE);
			touchKeys.push(touch);
			add(touch);
		}
		#end

		remove(blackScreen);
		checkNewChar();

		subStateClosed.addOnce((_) ->
		{
			remove(blackScreen);
			if (!Save.instance.oldChar)
			{
				camera.flash();
				introSound.volume = 1;
				introSound.play(true);
			}
			checkNewChar();
			Save.instance.oldChar = true;
		});

		#if TOUCH_CONTROLS_ALLOWED
		addTouchPad('NONE', 'A_B');
		addTouchPadCamera();
		#end
	}

	function checkNewChar():Void
	{
		FunkinSound.playMusic('stayFunky', {
			startingVolume: 1,
			overrideExisting: true,
			restartTrack: true,
			onLoad: function()
			{
				allowInput = true;

				@:privateAccess
				gfChill.analyzer = new SpectralAnalyzer(ModsHelper.getSoundChannel(FlxG.sound.music), 7, 0.1);
				#if (desktop || mobile)
				@:privateAccess
				gfChill.analyzer.fftN = 512;
				#end
			}
		});
	}

	var grpIcons:FlxSpriteGroup;
	var grpXSpread(default, set):Float = 107;
	var grpYSpread(default, set):Float = 127;
	var nonLocks = [];

	function hasSelectableAt(index:Int):Bool
	{
		if (!availableChars.exists(index))
			return false;
		var charId = availableChars.get(index);
		return charId != null && charId.length > 0;
	}

	function getFirstSelectableIndex():Int
	{
		for (i in 0...9)
		{
			if (hasSelectableAt(i))
				return i;
		}
		return -1;
	}

	function getIndexForChar(charId:String):Int
	{
		if (charId == null || charId.length < 1)
			return -1;
		for (pos => id in availableChars)
		{
			if (id == charId)
				return pos;
		}
		return -1;
	}

	function getSafeSelectedIndex():Int
	{
		var current:Int = getCurrentSelected();
		if (hasSelectableAt(current))
			return current;
		var currentCharIndex:Int = getIndexForChar(curChar);
		if (hasSelectableAt(currentCharIndex))
			return currentCharIndex;
		return getFirstSelectableIndex();
	}

	function ensureValidCursor():Void
	{
		var safeIndex:Int = getSafeSelectedIndex();
		if (safeIndex != -1 && safeIndex != getCurrentSelected())
			setCursorPosition(safeIndex);
	}

	function initLocks():Void
	{
		grpIcons = new FlxSpriteGroup();
		add(grpIcons);

		nonLocks = [];

		for (i in 0...9)
		{
			if (availableChars.exists(i))
			{
				var path:String = availableChars.get(i);

				// İkon yüklerken o karakterin mod context'ine geç
				switchToCharMod(path);

				var temp:PixelatedIcon = new PixelatedIcon(0, 0);
				temp.setCharacter(path);
				temp.setGraphicSize(128, 128);
				temp.updateHitbox();
				temp.ID = 0;
				grpIcons.add(temp);
			}
			else
			{
				var temp:Lock = new Lock(0, 0, i);
				temp.ID = 1;
				grpIcons.add(temp);
			}
		}

		// Base game context'e geri dön
		ModsHelper.loadModDir("");

		updateIconPositions();
		grpIcons.scrollFactor.set();
	}

	function updateIconPositions()
	{
		grpIcons.x = cutoutSize + 450;
		grpIcons.y = 120;
		for (index => member in grpIcons.members)
		{
			var posX:Float = (index % 3);
			var posY:Float = Math.floor(index / 3);
			member.x = posX * grpXSpread;
			member.y = posY * grpYSpread;
			member.x += grpIcons.x;
			member.y += grpIcons.y;
		}
	}

	function goToFreeplay():Void
	{
		staticSound.stop();
		allowInput = false;
		autoFollow = false;

		// Seçilen karakterin mod context'ine geç
		var selectedEntry = getCharEntry(curChar);
		var selectedMod = (selectedEntry != null && selectedEntry.sourceMod != null) ? selectedEntry.sourceMod : "";

		if (!wentBackToFreeplay)
			VsliceOptions.LAST_MOD = {mod_dir: selectedMod, char_name: curChar};

		ModsHelper.loadModDir(selectedMod);

		FlxTween.tween(chrSelectCursor, {alpha: 0}, 0.8, {ease: FlxEase.expoOut});
		FlxTween.tween(cursorBlue, {alpha: 0}, 0.8, {ease: FlxEase.expoOut});
		FlxTween.tween(cursorDarkBlue, {alpha: 0}, 0.8, {ease: FlxEase.expoOut});
		FlxTween.tween(cursorConfirmed, {alpha: 0}, 0.8, {ease: FlxEase.expoOut});

		FlxTween.tween(barthing, {y: barthing.y + 80}, 0.8, {ease: FlxEase.backIn});
		FlxTween.tween(nametag, {y: nametag.y + 80}, 0.8, {ease: FlxEase.backIn});
		FlxTween.tween(dipshitBacking, {y: dipshitBacking.y + 210}, 0.8, {ease: FlxEase.backIn});
		FlxTween.tween(chooseDipshit, {y: chooseDipshit.y + 200}, 0.8, {ease: FlxEase.backIn});
		FlxTween.tween(dipshitBlur, {y: dipshitBlur.y + 220}, 0.8, {ease: FlxEase.backIn});

		if (pageIndicatorText != null)
			FlxTween.tween(pageIndicatorText, {alpha: 0}, 0.8, {ease: FlxEase.backIn});

		for (index => member in grpIcons.members)
		{
			FlxTween.tween(member, {y: member.y + 300}, 0.8, {ease: FlxEase.backIn});
		}
		FlxG.camera.follow(camFollow, LOCKON);

		FlxTween.cancelTweensOf(transitionGradient);
		FlxTween.cancelTweensOf(fadeShader);
		FlxTween.cancelTweensOf(camFollow);

		FlxTween.tween(transitionGradient, {y: -150}, 0.8, {ease: FlxEase.backIn});
		fadeShader.fade(1.0, 0, 0.8, {ease: FlxEase.quadIn});
		FlxTween.tween(camFollow, {y: camFollow.y - 150}, 0.8, {
			ease: FlxEase.backIn,
			onComplete: function(_)
			{
				if (!FlxG.random.bool(0.01))
					FlxTransitionableState.skipNextTransOut = true;
				FlxG.switchState(FreeplayState.build({
					fromCharSelect: true
				}));
			}
		});
		#if TOUCH_CONTROLS_ALLOWED
		if (touchPad != null)
			FlxTween.tween(touchPad, {alpha: 0}, 0.8, {ease: FlxEase.expoOut});
		#end
	}

	var holdTmrUp:Float = 0;
	var holdTmrDown:Float = 0;
	var holdTmrLeft:Float = 0;
	var holdTmrRight:Float = 0;
	var spamUp:Bool = false;
	var spamDown:Bool = false;
	var spamLeft:Bool = false;
	var spamRight:Bool = false;
	var wentBackToFreeplay:Bool = false;

	override public function update(elapsed:Float):Void
	{
		controls.isInSubstate = true;
		super.update(elapsed);

		if (controls.UI_UP_R || controls.UI_DOWN_R || controls.UI_LEFT_R || controls.UI_RIGHT_R)
			selectSound.pitch = 1;

		syncAudio(elapsed);

		if (!pressedSelect && allowInput)
		{
			if (FlxG.keys.justPressed.Q)
				changePage(-1);
			if (FlxG.keys.justPressed.E)
				changePage(1);

			if (controls.UI_UP)
				holdTmrUp += elapsed;
			if (controls.UI_UP_R) { holdTmrUp = 0; spamUp = false; }
			if (controls.UI_DOWN)
				holdTmrDown += elapsed;
			if (controls.UI_DOWN_R) { holdTmrDown = 0; spamDown = false; }
			if (controls.UI_LEFT)
				holdTmrLeft += elapsed;
			if (controls.UI_LEFT_R) { holdTmrLeft = 0; spamLeft = false; }
			if (controls.UI_RIGHT)
				holdTmrRight += elapsed;
			if (controls.UI_RIGHT_R) { holdTmrRight = 0; spamRight = false; }

			var initSpam = 0.5;
			if (holdTmrUp >= initSpam) spamUp = true;
			if (holdTmrDown >= initSpam) spamDown = true;
			if (holdTmrLeft >= initSpam) spamLeft = true;
			if (holdTmrRight >= initSpam) spamRight = true;

			if (controls.UI_UP_P) { cursorY -= 1; cursorDenied.visible = false; holdTmrUp = 0; selectSound.play(true); }
			if (controls.UI_DOWN_P) { cursorY += 1; cursorDenied.visible = false; holdTmrDown = 0; selectSound.play(true); }
			if (controls.UI_LEFT_P) { cursorX -= 1; cursorDenied.visible = false; holdTmrLeft = 0; selectSound.play(true); }
			if (controls.UI_RIGHT_P) { cursorX += 1; cursorDenied.visible = false; holdTmrRight = 0; selectSound.play(true); }

			if (controls.BACK #if TOUCH_CONTROLS_ALLOWED || (touchPad != null && touchPad.buttonB.justPressed) #end)
			{
				wentBackToFreeplay = true;
				FunkinSound.playOnce(Paths.sound('cancelMenu'));
				FlxTween.tween(FlxG.sound.music, {volume: 0.0}, 0.7, {ease: FlxEase.quadInOut});
				goToFreeplay();
			}
		}

		if (cursorX < -1) { cursorX = 1; }
		if (cursorX > 1) { cursorX = -1; }
		if (cursorY < -1) { cursorY = 1; }
		if (cursorY > 1) { cursorY = -1; }

		#if TOUCH_CONTROLS_ALLOWED
		if (TouchUtil.pressed #if debug || FlxG.mouse.pressed #end)
		{
			for (index => member in touchKeys)
			{
				if (member.pressed)
				{
					var newCursorY = (Math.floor(index / 3));
					var newCursorX = (index % 3);
					if (cursorX == newCursorX - 1 && cursorY == newCursorY - 1 && member.justPressed)
					{
						if (!pressedSelect) onAcceptPress();
						else onBackPress();
					}
					else if (!pressedSelect)
					{
						if (cursorX != newCursorX - 1 || cursorY != newCursorY - 1)
							selectSound.play(true);
						cursorY = newCursorY - 1;
						cursorX = newCursorX - 1;
						cursorDenied.visible = false;
						holdTmrDown = 0;
					}
				}
			}
		}
		#end
		if (controls.ACCEPT #if TOUCH_CONTROLS_ALLOWED || (touchPad != null && touchPad.buttonA.justPressed) #end)
			onAcceptPress();
		if (controls.BACK #if TOUCH_CONTROLS_ALLOWED || (touchPad != null && touchPad.buttonB.justPressed) #end)
			onBackPress();

		updateLockAnims();

		if (autoFollow)
		{
			var rawSelected:Int = getCurrentSelected();
			if (hasSelectableAt(rawSelected))
			{
				var nextChar:String = availableChars.get(rawSelected);
				if (nextChar != null && nextChar.length > 0)
					curChar = nextChar;
				gfChill.visible = true;
			}
			else
			{
				curChar = "locked";
				gfChill.visible = false;
			}
		}

		if (autoFollow == true)
		{
			camFollow.screenCenter();
			camFollow.x += cursorX * 10;
			camFollow.y += cursorY * 10;
		}

		cursorLocIntended.x = (cursorFactor * cursorX) + (FlxG.width / 2) - chrSelectCursor.width / 2;
		cursorLocIntended.y = (cursorFactor * cursorY) + (FlxG.height / 2) - chrSelectCursor.height / 2;
		cursorLocIntended.x += cursorOffsetX;
		cursorLocIntended.y += cursorOffsetY;

		chrSelectCursor.x = MathUtil.coolLerp(chrSelectCursor.x, cursorLocIntended.x, lerpAmnt, false);
		chrSelectCursor.y = MathUtil.coolLerp(chrSelectCursor.y, cursorLocIntended.y, lerpAmnt, false);
		cursorBlue.x = MathUtil.coolLerp(cursorBlue.x, chrSelectCursor.x, lerpAmnt * 0.4, false);
		cursorBlue.y = MathUtil.coolLerp(cursorBlue.y, chrSelectCursor.y, lerpAmnt * 0.4, false);
		cursorDarkBlue.x = MathUtil.coolLerp(cursorDarkBlue.x, cursorLocIntended.x, lerpAmnt * 0.2, false);
		cursorDarkBlue.y = MathUtil.coolLerp(cursorDarkBlue.y, cursorLocIntended.y, lerpAmnt * 0.2, false);
	}

	var bopTimer:Float = 0;
	var delay = 1 / 24;
	var bopFr = 0;
	var bopPlay:Bool = false;
	var bopRefX:Float = 0;
	var bopRefY:Float = 0;

	var sync:Bool = false;
	var syncLock:Lock = null;
	var audioBizz:Float = 0;
	
	function applyPsychPreview(charId:String):Void
	{
		var prevMod = ModsHelper.getActiveMod();

		showPsychCharacter(charId);

		ModsHelper.loadModDir("");
		gfChill.switchGF("bf");
		ModsHelper.loadModDir(prevMod ?? "");

		gfChill.visible = true;

		if (playerChill != null) playerChill.visible = false;
		if (playerChillOut != null) playerChillOut.visible = false;
		if (psychCharSprite != null) psychCharSprite.visible = true;
	}

	function applyVSlicePreview(charId:String):Void
	{
		switchToCharMod(charId);

		if (psychCharSprite != null)
			psychCharSprite.visible = false;

		var ok:Bool = false;
		if (playerChill != null)
			ok = playerChill.switchChar(charId);

		if (playerChillOut != null)
			playerChillOut.visible = false;

		if (playerChill != null)
			playerChill.visible = ok;

		gfChill.switchGF(charId);
		gfChill.visible = true;
	}

	function syncAudio(elapsed:Float):Void
	{
		@:privateAccess
		if (sync && unlockSound.time > 0)
		{
			playerChillOut.anim._tick = 0;
			if (syncLock != null) syncLock.anim._tick = 0;
			if ((unlockSound.time - audioBizz) >= ((delay) * 100))
			{
				if (syncLock != null) syncLock.anim._tick = delay;
				playerChillOut.anim._tick = delay;
				audioBizz += delay * 100;
			}
		}
	}

	private function onAcceptPress()
	{
		if (!allowInput || pressedSelect)
			return;

		var rawSelected:Int = getCurrentSelected();
		var selectedChar:String = availableChars.get(rawSelected);
		var charType:CharacterType = getCharType(selectedChar ?? "");	

		if (autoFollow && hasSelectableAt(rawSelected))
		{
			var nextChar:String = availableChars.get(rawSelected);
			if (nextChar != null && nextChar.length > 0)
				curChar = nextChar;

			cursorConfirmed.visible = true;
			cursorConfirmed.x = chrSelectCursor.x - 2;
			cursorConfirmed.y = chrSelectCursor.y - 4;
			cursorConfirmed.animation.play("idle", true);
			grpCursors.visible = false;

			FunkinSound.playOnce(Paths.sound('CS_confirm'));

			FlxTween.tween(FlxG.sound.music, {pitch: 0.1}, 1, {ease: FlxEase.quadInOut});
			FlxTween.tween(FlxG.sound.music, {volume: 0.0}, 1.5, {ease: FlxEase.quadInOut});

			if (charType == VSLICE && playerChill != null)
			{
				playerChill.playAnimSafe("select");
			}

			gfChill.playAnimation("confirm", true, false, true);
			pressedSelect = true;
			selectTimer.start(1.5, (_) ->
			{
				pressedSelect = false;
				goToFreeplay();
			});
		}
		else
		{
			cursorDenied.visible = true;
			cursorDenied.x = chrSelectCursor.x - 2;
			cursorDenied.y = chrSelectCursor.y - 4;

			if (getCharType(availableChars.get(rawSelected) ?? "") == VSLICE)
				playerChill.playAnimation("cannot select Label", true);

			lockedSound.play(true);
			cursorDenied.animation.play("idle", true);
			cursorDenied.animation.finishCallback = (_) -> { cursorDenied.visible = false; };
		}
	}

	private function onBackPress()
	{
		if (!allowInput || !pressedSelect)
			return;
		var charType:CharacterType = getCharType(curChar);
		cursorConfirmed.visible = false;
		grpCursors.visible = true;

		FlxTween.globalManager.cancelTweensOf(FlxG.sound.music);
		FlxTween.tween(FlxG.sound.music, {pitch: 1.0, volume: 1.0}, 1, {ease: FlxEase.quartInOut});

		if (charType == VSLICE && playerChill != null)
		{
			playerChill.playAnimSafe("deselect");
		}

		gfChill.playAnimation("deselect");
		pressedSelect = false;
		FlxTween.tween(FlxG.sound.music, {pitch: 1.0}, 1, {
			ease: FlxEase.quartInOut,
			onComplete: (_) ->
			{
				if (getCharType(curChar) == VSLICE)
				{
					if (playerChill != null && playerChill.hasAnimSafe("idle"))
					{
						var curAnim = playerChill.getCurrentAnimation();
						if (curAnim == "deselect loop start" || curAnim == "deselect")
						{
							playerChill.playAnimation("idle", true, false, true);
						}
					}
				}
				gfChill.playAnimation("idle", true, false, true);
			}
		});
		selectTimer.cancel();
	}

	override function beatHit()
	{
		super.beatHit();
		if (getCharType(curChar) == VSLICE && playerChill != null && playerChill.hasValidAtlas())
			playerChill.onBeatHit();
		gfChill.onBeatHit(this.curBeat);
	}

	override function stepHit()
	{
		spamOnStep();
		super.stepHit();
	}

	function spamOnStep():Void
	{
		if (spamUp || spamDown || spamLeft || spamRight)
		{
			if (selectSound.pitch > 5) selectSound.pitch = 5;
			selectSound.play(true);
			cursorDenied.visible = false;
			if (spamUp) { cursorY -= 1; holdTmrUp = 0; }
			if (spamDown) { cursorY += 1; holdTmrDown = 0; }
			if (spamLeft) { cursorX -= 1; holdTmrLeft = 0; }
			if (spamRight) { cursorX += 1; holdTmrRight = 0; }
		}
	}

	private function updateLockAnims():Void
	{
		for (index => member in grpIcons.group.members)
		{
			switch (member.ID)
			{
				case 1:
					var lock:Lock = cast member;
					if (index == getCurrentSelected())
					{
						switch (lock.getCurrentAnimation())
						{
							case "idle": lock.playAnimation("selected");
							case "selected" | "clicked":
								if (controls.ACCEPT || TouchUtil.justPressed #if debug || FlxG.mouse.justPressed #end)
									lock.playAnimation("clicked", true);
						}
					}
					else lock.playAnimation("idle");
				case 0:
					var memb:PixelatedIcon = cast member;
					if (index == getCurrentSelected())
					{
						if (bopPlay)
						{
							if (bopRefX == 0) { bopRefX = memb.x; bopRefY = memb.y; }
							doBop(memb, FlxG.elapsed);
						}
						else { memb.filters = selectedBizz; memb.scale.set(2.6, 2.6); }
						if (pressedSelect && memb.animation.curAnim.name == "idle")
							memb.animation.play("confirm");
						if (autoFollow && !pressedSelect && memb.animation.curAnim.name != "idle")
						{
							memb.animation.play("confirm", false, true);
							member.animation.finishCallback = (_) -> {
								member.animation.play("idle");
								member.animation.finishCallback = null;
							};
						}
					}
					else { memb.filters = null; memb.scale.set(2, 2); }
			}
		}
	}

	function doBop(icon:PixelatedIcon, elapsed:Float):Void
	{
		if (bopFr >= bopInfo.frames.length)
		{
			bopRefX = 0; bopRefY = 0; bopPlay = false; bopFr = 0;
			return;
		}
		bopTimer += elapsed;
		if (bopTimer >= delay)
		{
			bopTimer -= bopTimer;
			var refFrame = bopInfo.frames[bopInfo.frames.length - 1];
			var curFrame = bopInfo.frames[bopFr];
			if (bopFr >= 13) icon.filters = selectedBizz;
			var scaleXDiff:Float = curFrame.scaleX - refFrame.scaleX;
			var scaleYDiff:Float = curFrame.scaleY - refFrame.scaleY;
			icon.scale.set(2.6, 2.6);
			icon.scale.add(scaleXDiff, scaleYDiff);
			bopFr++;
		}
	}

	function getCurrentSelected():Int
	{
		return (cursorX + 1) + (cursorY + 1) * 3;
	}

	function setCursorPosition(index:Int)
	{
		var copy = 3;
		var yThing = -1;
		while ((index + 1) > copy) { yThing++; copy += 3; }
		var xThing = (copy - index - 2) * -1;
		cursorY = yThing;
		cursorX = xThing;
		trace('[CS] setCursorPosition index=' + index + ' -> cursorX=' + cursorX + ' cursorY=' + cursorY);
	}

	function set_curChar(value:String):String
	{
		if (curChar == value)
			return value;

		curChar = value;
		trace('[CS] set_curChar new=' + value);

		if (value == "locked")
		{
			staticSound.play();

			if (psychCharSprite != null) psychCharSprite.visible = false;
			if (playerChill != null) playerChill.visible = false;
			if (playerChillOut != null) playerChillOut.visible = false;
			if (gfChill != null) gfChill.visible = false;

			return value;
		}
		else
		{
			staticSound.stop();
		}

		nametag.switchChar(value);

		switch (getCharType(value))
		{
			case PSYCH:
				applyPsychPreview(value);

			case VSLICE:
				applyVSlicePreview(value);
		}

		return value;
	}

	function showPsychCharacter(charId:String):Void
	{
		var entry = getCharEntry(charId);
		if (entry == null)
			 return;

		if (playerChill != null) playerChill.visible = false;
		if (playerChillOut != null) playerChillOut.visible = false;

		try
		{
			switchToCharMod(charId);

			var imagePath = entry.imagePath;
			psychCharSprite.frames = Paths.getSparrowAtlas(imagePath);

			// Eski animasyonları temizlemek iyi olur
			psychCharSprite.animation.destroyAnimations();

			var idlePrefix = entry.idleAnim ?? "BF idle dance";
			psychCharSprite.animation.addByPrefix("idle", idlePrefix, 24, true);
			psychCharSprite.animation.play("idle");

			var charScale = entry.scale ?? 1.0;
			psychCharSprite.scale.set(charScale, charScale);
			psychCharSprite.updateHitbox();
			psychCharSprite.flipX = entry.flipX ?? false;

			psychCharSprite.x = cutoutSize + 850;
			psychCharSprite.y = 75;
			psychCharSprite.visible = true;

			trace("[CS] Showing Psych character: " + charId + " image=" + imagePath);
		}
		catch (e)
		{
			trace("[CS] Failed to show Psych character: " + charId + " error=" + e);
			psychCharSprite.visible = false;
		}
	}

	function set_grpXSpread(value:Float):Float
	{
		grpXSpread = value;
		updateIconPositions();
		return value;
	}

	function set_grpYSpread(value:Float):Float
	{
		grpYSpread = value;
		updateIconPositions();
		return value;
	}
}

package states;

import backend.WeekData;
import backend.Mods;
import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import flash.geom.Rectangle;
import haxe.Json;
import flixel.util.FlxSpriteUtil;
import objects.AttachedSprite;
import openfl.display.BitmapData;
import lime.utils.Assets;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.display.FlxBackdrop;
import flxanimate.FlxAnimate;
import objects.Character;
import sys.FileSystem;
import sys.io.File;
import vslice.menus.charSelect.CharSelectGF;

class ModsMenuState extends MusicBeatState
{
	// Background elements (from AboutState)
	var crowdAnim:FlxAnimate;
	var bgSprite:FlxSprite;
	var server:FlxSprite;
	var lights:FlxSprite;
	
	var bfCharacter:Character;
	var gfCharacter:CharSelectGF;
	var bfLabel:FlxText;
	var gfLabel:FlxText;
	
	// Character positions (adjustable)
	var bfX:Float = 900;
	var bfY:Float = 250;
	var gfX:Float = 50;
	var gfY:Float = 100;
	
	var titleText:FlxText;
	
	var disabledColumnBG:FlxSprite;
	var activeColumnBG:FlxSprite;
	var disabledColumnTitle:FlxText;
	var activeColumnTitle:FlxText;
	
	var disabledModsGroup:FlxTypedGroup<ModCard>;
	var activeModsGroup:FlxTypedGroup<ModCard>;
	
	var disabledScrollY:Float = 0;
	var activeScrollY:Float = 0;
	var disabledTargetScrollY:Float = 0;
	var activeTargetScrollY:Float = 0;
	var disabledMaxScroll:Float = 0;
	var activeMaxScroll:Float = 0;
	
	var applyButton:ModernButton;
	
	var draggingCard:ModCard = null;
	var dragOffset:FlxPoint = new FlxPoint();
	var originalColumn:String = '';
	var originalIndex:Int = 0;
	
	var modsList:ModsList = null;
	var disabledMods:Array<String> = [];
	var activeMods:Array<String> = [];
	
	// Current loaded mod for BF
	var currentBFMod:String = "";
	
	static inline var COLUMN_WIDTH:Int = 400;
	static inline var COLUMN_HEIGHT:Int = 500;
	static inline var COLUMN_SPACING:Int = 40;
	static inline var CARD_HEIGHT:Int = 120;
	static inline var CARD_SPACING:Int = 10;
	static inline var CORNER_RADIUS:Float = 15;
	
	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Modlar Menüsü", null);
		#end
		
		persistentUpdate = persistentDraw = true;
		
		modsList = Mods.parseList();
		if (modsList != null)
		{
			if (modsList.disabled != null) disabledMods = modsList.disabled.copy();
			if (modsList.enabled != null) activeMods = modsList.enabled.copy();
		}
		
		setupBackground();
		setupTitle();
		setupModColumns();
		setupCharacters();
		setupApplyButton();
		
		updateCharacters();
		updateScrollLimits();
		
		FlxG.mouse.visible = true;
		
		#if mobile
		mobileManager.addMobilePad('NONE', 'A_B');
		mobileManager.addMobilePadCamera();
		#end
		
		super.create();
	}
	
	function setupBackground()
	{
		var darkFill:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(30, 30, 30));
		add(darkFill);
		
		try
		{
			var crowdPath = Paths.getPath('images/about/crowd/Animation.json', TEXT, 'shared');
			if (FileSystem.exists(crowdPath))
			{
				crowdAnim = new FlxAnimate(0, 0, Paths.getPath('images/about/crowd', TEXT, 'shared'));
				if (crowdAnim != null && crowdAnim.anim != null)
				{
					crowdAnim.anim.play();
					crowdAnim.antialiasing = ClientPrefs.data.antialiasing;
					crowdAnim.x = FlxG.width - 600;
					crowdAnim.y = FlxG.height - 720;
					add(crowdAnim);
				}
			}
		}
		catch (e:Dynamic)
		{
			trace('Crowd animation load failed: ' + e);
		}
		
		if (Paths.fileExists('images/about/bg.png', IMAGE, 'shared'))
		{
			bgSprite = new FlxSprite(0, 0).loadGraphic(Paths.image('about/bg', 'shared'));
			bgSprite.antialiasing = ClientPrefs.data.antialiasing;
			bgSprite.setGraphicSize(0, FlxG.height);
			bgSprite.updateHitbox();
			bgSprite.x = -50;
			bgSprite.y = 0;
			add(bgSprite);
		}
		
		var scrollBGs:Array<String> = ['menuBG', 'menuBGMagenta', 'menuDesat', 'menuBGBlue'];
		var nextBgY:Float = FlxG.height;
		
		for (bgName in scrollBGs)
		{
			if (Paths.fileExists('images/$bgName.png', IMAGE, 'shared'))
			{
				var bg:FlxSprite = new FlxSprite(0, nextBgY).loadGraphic(Paths.image(bgName, 'shared'));
				bg.antialiasing = ClientPrefs.data.antialiasing;
				bg.setGraphicSize(FlxG.width);
				bg.updateHitbox();
				add(bg);
				nextBgY += bg.height;
			}
		}
		
		if (Paths.fileExists('images/about/server.png', IMAGE, 'shared'))
		{
			server = new FlxSprite(0, 0).loadGraphic(Paths.image('about/server', 'shared'));
			server.antialiasing = ClientPrefs.data.antialiasing;
			server.scale.set(0.5, 0.5);
			server.updateHitbox();
			server.x = 0;
			server.y = FlxG.height - server.height - 30;
			add(server);
		}
		
		if (Paths.fileExists('images/about/lights.png', IMAGE, 'shared'))
		{
			lights = new FlxSprite(0, 0).loadGraphic(Paths.image('about/lights', 'shared'));
			lights.antialiasing = ClientPrefs.data.antialiasing;
			lights.scale.set(0.6, 0.6);
			lights.updateHitbox();
			lights.screenCenter(flixel.util.FlxAxes.X);
			lights.y = -20;
			add(lights);
		}
	}
	
	function setupCharacters()
	{
		try
		{
			gfCharacter = new CharSelectGF();
			gfCharacter.x = gfX;
			gfCharacter.y = gfY;
			gfCharacter.switchGF("bf"); // Load default GF
			add(gfCharacter);
			
			gfLabel = new FlxText(gfCharacter.x, gfCharacter.y - 40, 200, "GF Görünüşü");
			gfLabel.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			gfLabel.borderSize = 2;
			gfLabel.antialiasing = ClientPrefs.data.antialiasing;
			add(gfLabel);
			
			trace('[ModsMenu] GF character loaded successfully');
		}
		catch (e:Dynamic)
		{
			trace('[ModsMenu] GF character load failed: ' + e);
		}
		
		try
		{
			bfCharacter = new Character(bfX, bfY, 'bf', true);
			if (bfCharacter != null)
			{
				bfCharacter.dance();
				add(bfCharacter);
				currentBFMod = ""; // Default BF
				
				bfLabel = new FlxText(bfCharacter.x, bfCharacter.y - 40, 200, "BF Görünüşü");
				bfLabel.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				bfLabel.borderSize = 2;
				bfLabel.antialiasing = ClientPrefs.data.antialiasing;
				add(bfLabel);
				
				trace('[ModsMenu] BF character loaded successfully');
			}
		}
		catch (e:Dynamic)
		{
			trace('[ModsMenu] BF character load failed: ' + e);
		}
	}
	
	function setupTitle()
	{
		titleText = new FlxText(0, 30, FlxG.width, "MODLAR");
		titleText.setFormat(Paths.font("coolweekfont.ttf"), 56, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 3;
		titleText.antialiasing = ClientPrefs.data.antialiasing;
		add(titleText);
	}
	
	function setupModColumns()
	{
		var centerX = FlxG.width / 2;
		var leftColumnX = centerX - COLUMN_WIDTH - (COLUMN_SPACING / 2);
		var rightColumnX = centerX + (COLUMN_SPACING / 2);
		var columnY = 120;
		
		// Disabled Mods Column (Left) - Rounded corners
		disabledColumnBG = FlxSpriteUtil.drawRoundRect(
			new FlxSprite(leftColumnX, columnY).makeGraphic(COLUMN_WIDTH, COLUMN_HEIGHT, FlxColor.TRANSPARENT),
			0, 0, COLUMN_WIDTH, COLUMN_HEIGHT, CORNER_RADIUS, CORNER_RADIUS, FlxColor.BLACK
		);
		disabledColumnBG.alpha = 0.5;
		add(disabledColumnBG);
		
		disabledColumnTitle = new FlxText(leftColumnX, columnY + 10, COLUMN_WIDTH, "DEAKTİF MODLAR");
		disabledColumnTitle.setFormat(Paths.font("Avgardd.ttf"), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		disabledColumnTitle.borderSize = 2;
		disabledColumnTitle.antialiasing = ClientPrefs.data.antialiasing;
		add(disabledColumnTitle);
		
		// Active Mods Column (Right) - Rounded corners
		activeColumnBG = FlxSpriteUtil.drawRoundRect(
			new FlxSprite(rightColumnX, columnY).makeGraphic(COLUMN_WIDTH, COLUMN_HEIGHT, FlxColor.TRANSPARENT),
			0, 0, COLUMN_WIDTH, COLUMN_HEIGHT, CORNER_RADIUS, CORNER_RADIUS, FlxColor.BLACK
		);
		activeColumnBG.alpha = 0.5;
		add(activeColumnBG);
		
		activeColumnTitle = new FlxText(rightColumnX, columnY + 10, COLUMN_WIDTH, "AKTİF MODLAR");
		activeColumnTitle.setFormat(Paths.font("Avgardd.ttf"), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		activeColumnTitle.borderSize = 2;
		activeColumnTitle.antialiasing = ClientPrefs.data.antialiasing;
		add(activeColumnTitle);
		
		disabledModsGroup = new FlxTypedGroup<ModCard>();
		add(disabledModsGroup);
		
		activeModsGroup = new FlxTypedGroup<ModCard>();
		add(activeModsGroup);
		
		populateModCards();
	}
	
	function populateModCards()
	{
		disabledModsGroup.clear();
		activeModsGroup.clear();
		
		var centerX = FlxG.width / 2;
		var leftColumnX = centerX - COLUMN_WIDTH - (COLUMN_SPACING / 2);
		var rightColumnX = centerX + (COLUMN_SPACING / 2);
		var startY = 170;
		
		if (disabledMods != null)
		{
			for (i in 0...disabledMods.length)
			{
				var card = new ModCard(leftColumnX + 10, startY + (i * (CARD_HEIGHT + CARD_SPACING)), COLUMN_WIDTH - 20, CARD_HEIGHT, disabledMods[i], false);
				disabledModsGroup.add(card);
			}
		}
		
		if (activeMods != null)
		{
			for (i in 0...activeMods.length)
			{
				var card = new ModCard(rightColumnX + 10, startY + (i * (CARD_HEIGHT + CARD_SPACING)), COLUMN_WIDTH - 20, CARD_HEIGHT, activeMods[i], true);
				activeModsGroup.add(card);
			}
		}
	}
	
	function setupApplyButton()
	{
		var buttonWidth = 200;
		var buttonHeight = 60;
		var buttonX = (FlxG.width - buttonWidth) / 2;
		var buttonY = FlxG.height - 80;
		
		applyButton = new ModernButton(buttonX, buttonY, buttonWidth, buttonHeight, "UYGULA", onApplyClick);
		add(applyButton);
	}
	
	function onApplyClick()
	{
		saveMods();
		FlxG.sound.play(Paths.sound('confirmMenu'));
		MusicBeatState.switchState(new MainMenuState());
	}
	
	function saveMods()
	{
		var fileStr:String = '';
		
		// Save active mods first (with order)
		if (activeMods != null)
		{
			for (mod in activeMods)
			{
				if(mod.trim().length < 1) continue;
				if(fileStr.length > 0) fileStr += '\n';
				fileStr += '$mod|1';
			}
		}
		
		if (disabledMods != null)
		{
			for (mod in disabledMods)
			{
				if(mod.trim().length < 1) continue;
				if(fileStr.length > 0) fileStr += '\n';
				fileStr += '$mod|0';
			}
		}
		
		var path:String = #if android StorageUtil.getExternalStorageDirectory() + #else Sys.getCwd() + #end 'modsList.txt';
		File.saveContent(path, fileStr);
		Mods.parseList();
		Mods.loadTopMod();
		backend.freeplay.FreeplayCatalog.invalidate();
	}
	
	function updateCharacters()
	{
		// Determine which mod's BF to load
		var targetBFMod:String = "";
		
		if (activeMods != null && activeMods.length > 0)
		{
			var topMod = activeMods[0];
			var modBfPath = Paths.mods('$topMod/characters/bf.json');
			
			#if sys
			if (FileSystem.exists(modBfPath))
			{
				targetBFMod = topMod;
			}
			#end
		}
		
		// Only reload BF if the mod changed
		if (currentBFMod != targetBFMod)
		{
			trace('[ModsMenu] Updating BF: currentMod=${currentBFMod} -> targetMod=${targetBFMod}');
			loadBFCharacter(targetBFMod);
		}
		
		if (gfCharacter != null)
		{
			gfCharacter.switchGF("bf");
		}
	}
	
	function loadBFCharacter(modName:String)
	{
		trace('[ModsMenu] loadBFCharacter called with mod: ${modName}');
		
		if (bfCharacter != null)
		{
			trace('[ModsMenu] Removing old BF character');
			var oldIndex = members.indexOf(bfCharacter);
			remove(bfCharacter);
			bfCharacter.destroy();
			bfCharacter = null;
		}
		
		var characterToLoad:String = 'bf';
		var shouldPlayMiss:Bool = false;
		
		if (modName != "" && modName != null)
		{
			// Try to load mod BF
			var modBfPath = Paths.mods('$modName/characters/bf.json');
			trace('[ModsMenu] Checking mod BF path: ${modBfPath}');
			
			#if sys
			if (FileSystem.exists(modBfPath))
			{
				characterToLoad = modName + ':bf';
				trace('[ModsMenu] Found mod BF, will load: ${characterToLoad}');
			}
			else
			{
				trace('[ModsMenu] Mod BF not found, using default + miss');
				characterToLoad = 'bf';
				shouldPlayMiss = true;
			}
			#end
		}
		
		try
		{
			trace('[ModsMenu] Creating character: ${characterToLoad}');
			bfCharacter = new Character(bfX, bfY, characterToLoad, true);
			
			if (bfCharacter != null)
			{
				trace('[ModsMenu] Character created successfully');
				
				// Insert before label to maintain layer order
				if (bfLabel != null)
				{
					var labelIndex = members.indexOf(bfLabel);
					insert(labelIndex, bfCharacter);
				}
				else
				{
					add(bfCharacter);
				}
				
				currentBFMod = modName;
				
				if (shouldPlayMiss)
				{
					trace('[ModsMenu] Playing miss animation');
					if (bfCharacter.animOffsets.exists('singLEFTmiss'))
						bfCharacter.playAnim('singLEFTmiss', true);
					else if (bfCharacter.animOffsets.exists('singDOWNmiss'))
						bfCharacter.playAnim('singDOWNmiss', true);
					else if (bfCharacter.animOffsets.exists('singUPmiss'))
						bfCharacter.playAnim('singUPmiss', true);
					else if (bfCharacter.animOffsets.exists('singRIGHTmiss'))
						bfCharacter.playAnim('singRIGHTmiss', true);
					else
						bfCharacter.dance();
				}
				else
				{
					bfCharacter.dance();
				}
			}
			else
			{
				trace('[ModsMenu] ERROR: bfCharacter is null after creation!');
			}
		}
		catch (e:Dynamic)
		{
			trace('[ModsMenu] EXCEPTION loading BF: ' + e);
			
			// Fallback to default BF
			try
			{
				trace('[ModsMenu] Attempting fallback to default BF');
				bfCharacter = new Character(bfX, bfY, 'bf', true);
				
				if (bfCharacter != null)
				{
					if (bfLabel != null)
					{
						var labelIndex = members.indexOf(bfLabel);
						insert(labelIndex, bfCharacter);
					}
					else
					{
						add(bfCharacter);
					}
					
					currentBFMod = "";
					
					// Play miss animation on fallback
					if (bfCharacter.animOffsets.exists('singLEFTmiss'))
						bfCharacter.playAnim('singLEFTmiss', true);
					else
						bfCharacter.dance();
					
					trace('[ModsMenu] Fallback BF loaded successfully');
				}
			}
			catch (fallbackError:Dynamic)
			{
				trace('[ModsMenu] FATAL: Failed to load fallback BF: ' + fallbackError);
			}
		}
	}
	
	function updateScrollLimits()
	{
		var contentHeight = disabledMods != null ? disabledMods.length * (CARD_HEIGHT + CARD_SPACING) : 0;
		disabledMaxScroll = Math.max(0, contentHeight - (COLUMN_HEIGHT - 60));
		
		contentHeight = activeMods != null ? activeMods.length * (CARD_HEIGHT + CARD_SPACING) : 0;
		activeMaxScroll = Math.max(0, contentHeight - (COLUMN_HEIGHT - 60));
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (bfCharacter != null && bfCharacter.animation.curAnim != null)
		{
			var currentAnimName = bfCharacter.animation.curAnim.name;
			
			if (currentAnimName == "idle")
			{
				@:privateAccess
				{
					var curAnim = bfCharacter.animation.curAnim;
					if (curAnim.curFrame >= (curAnim.frames.length - 1))
					{
						bfCharacter.playAnim('idle', true);
					}
				}
			}
		}
		
		// GF - Manuel loop kontrol
		if (gfCharacter != null)
		{
			@:privateAccess
			{
				if (gfCharacter.anim != null)
				{
					if (gfCharacter.anim.finished)
					{
						gfCharacter.anim.play("idle");
						trace('[ModsMenu] GF animation restarted');
					}
				}
			}
		}
		
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
			FlxG.mouse.visible = false;
			return;
		}

		// ── Further Engine: A butonu → UYGULA (applyButton) ──
		if (controls.ACCEPT && applyButton != null)
		{
			FlxG.sound.play(Paths.sound('confirmMenu'));
			applyButton.onClick();
			return;
		}
		
		handleDragging();
		handleScrolling(elapsed);
		updateCardPositions();
	}

	override function beatHit()
	{
		super.beatHit();
		
		if (bfCharacter != null) 
		{
			if (bfCharacter.animation.curAnim != null)
			{
				var currentAnimName = bfCharacter.animation.curAnim.name;
				if (currentAnimName != "idle" && !currentAnimName.contains('miss'))
				{
					bfCharacter.dance();
				}
			}
		}
		
		if (gfCharacter != null)
		{
			gfCharacter.onBeatHit(curBeat);
		}
	}	
	function handleDragging()
	{
		if (FlxG.mouse.justPressed && draggingCard == null)
		{
			// Check if clicking on a card
			if (disabledModsGroup != null)
			{
				disabledModsGroup.forEachAlive(function(card:ModCard) {
					if (card != null && FlxG.mouse.overlaps(card) && !card.isDragging)
					{
						startDragging(card, 'disabled');
					}
				});
			}
			
			if (activeModsGroup != null)
			{
				activeModsGroup.forEachAlive(function(card:ModCard) {
					if (card != null && FlxG.mouse.overlaps(card) && !card.isDragging)
					{
						startDragging(card, 'active');
					}
				});
			}
		}
		
		if (FlxG.mouse.pressed && draggingCard != null)
		{
			draggingCard.x = FlxG.mouse.x - dragOffset.x;
			draggingCard.y = FlxG.mouse.y - dragOffset.y;
		}
		
		if (FlxG.mouse.justReleased && draggingCard != null)
		{
			stopDragging();
		}
	}
	
	function startDragging(card:ModCard, column:String)
	{
		draggingCard = card;
		dragOffset.x = FlxG.mouse.x - card.x;
		dragOffset.y = FlxG.mouse.y - card.y;
		originalColumn = column;
		
		if (column == 'disabled' && disabledMods != null)
			originalIndex = disabledMods.indexOf(card.modFolder);
		else if (activeMods != null)
			originalIndex = activeMods.indexOf(card.modFolder);
		
		card.isDragging = true;
		card.alpha = 0.7;
		
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	function stopDragging()
	{
		if (draggingCard == null) return;
		
		var centerX = FlxG.width / 2;
		var targetColumn = (FlxG.mouse.x < centerX) ? 'disabled' : 'active';
		
		if (originalColumn != targetColumn)
		{
			if (originalColumn == 'disabled' && disabledMods != null && activeMods != null)
			{
				disabledMods.remove(draggingCard.modFolder);
				activeMods.push(draggingCard.modFolder);
			}
			else if (activeMods != null && disabledMods != null)
			{
				activeMods.remove(draggingCard.modFolder);
				disabledMods.push(draggingCard.modFolder);
			}
			
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			populateModCards();
			updateCharacters();
			updateScrollLimits();
		}
		else
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
		}
		
		draggingCard.isDragging = false;
		draggingCard.alpha = 1.0;
		draggingCard = null;
	}
	
	function handleScrolling(elapsed:Float)
	{
		var centerX = FlxG.width / 2;
		var leftColumnX = centerX - COLUMN_WIDTH - (COLUMN_SPACING / 2);
		var rightColumnX = centerX + (COLUMN_SPACING / 2);
		
		// Determine which column to scroll
		if (FlxG.mouse.wheel != 0)
		{
			if (FlxG.mouse.x >= leftColumnX && FlxG.mouse.x <= leftColumnX + COLUMN_WIDTH)
			{
				disabledTargetScrollY -= FlxG.mouse.wheel * 40;
				disabledTargetScrollY = Math.max(0, Math.min(disabledMaxScroll, disabledTargetScrollY));
			}
			else if (FlxG.mouse.x >= rightColumnX && FlxG.mouse.x <= rightColumnX + COLUMN_WIDTH)
			{
				activeTargetScrollY -= FlxG.mouse.wheel * 40;
				activeTargetScrollY = Math.max(0, Math.min(activeMaxScroll, activeTargetScrollY));
			}
		}
		
		disabledScrollY += (disabledTargetScrollY - disabledScrollY) * 8 * elapsed;
		activeScrollY += (activeTargetScrollY - activeScrollY) * 8 * elapsed;
	}
	
	function updateCardPositions()
	{
		var centerX = FlxG.width / 2;
		var leftColumnX = centerX - COLUMN_WIDTH - (COLUMN_SPACING / 2);
		var rightColumnX = centerX + (COLUMN_SPACING / 2);
		var startY = 170;
		
		if (disabledModsGroup != null)
		{
			disabledModsGroup.forEachAlive(function(card:ModCard) {
				if (card != null && !card.isDragging)
				{
					var index = disabledModsGroup.members.indexOf(card);
					card.x = leftColumnX + 10;
					card.y = startY + (index * (CARD_HEIGHT + CARD_SPACING)) - disabledScrollY;
				}
			});
		}
		
		if (activeModsGroup != null)
		{
			activeModsGroup.forEachAlive(function(card:ModCard) {
				if (card != null && !card.isDragging)
				{
					var index = activeModsGroup.members.indexOf(card);
					card.x = rightColumnX + 10;
					card.y = startY + (index * (CARD_HEIGHT + CARD_SPACING)) - activeScrollY;
				}
			});
		}
	}
}

class ModCard extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var icon:FlxSprite;
	public var nameText:FlxText;
	public var descText:FlxText;
	public var modFolder:String;
	public var isDragging:Bool = false;
	
	public function new(x:Float, y:Float, width:Int, height:Int, folder:String, isActive:Bool)
	{
		super(x, y);
		
		this.modFolder = folder;
		
		// Background - Rounded corners (15px)
		bg = FlxSpriteUtil.drawRoundRect(
			new FlxSprite(0, 0).makeGraphic(width, height, FlxColor.TRANSPARENT),
			0, 0, width, height, 15, 15, FlxColor.BLACK
		);
		bg.alpha = 0.5;
		add(bg);
		
		icon = new FlxSprite(10, 10);
		icon.antialiasing = ClientPrefs.data.antialiasing;
		
		var iconPath = Paths.mods('$folder/pack.png');
		var iconLoaded = false;
		
		#if sys
		if (FileSystem.exists(iconPath))
		{
			try
			{
				icon.loadGraphic(iconPath);
				iconLoaded = true;
			}
			catch (e:Dynamic)
			{
				trace('Failed to load icon for $folder: ' + e);
			}
		}
		#end
		
		if (!iconLoaded)
		{
			if (Paths.fileExists('images/unknownMod.png', IMAGE))
			{
				icon.loadGraphic(Paths.image('unknownMod'));
			}
			else
			{
				icon.makeGraphic(100, 100, FlxColor.GRAY);
			}
		}
		
		icon.setGraphicSize(100, 100);
		icon.updateHitbox();
		add(icon);
		
		// Load pack.json
		var pack:Dynamic = null;
		try
		{
			pack = Mods.getPack(folder);
		}
		catch (e:Dynamic)
		{
			trace('Failed to get pack for $folder: ' + e);
		}
		
		var modName = folder;
		var modDesc = "Açıklama yok.";
		
		if (pack != null)
		{
			if (pack.name != null) modName = pack.name;
			if (pack.description != null) modDesc = pack.description;
		}
		
		nameText = new FlxText(120, 15, width - 130, modName);
		nameText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		nameText.borderSize = 1.5;
		nameText.antialiasing = ClientPrefs.data.antialiasing;
		add(nameText);
		
		descText = new FlxText(120, 45, width - 130, modDesc);
		descText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, LEFT);
		descText.antialiasing = ClientPrefs.data.antialiasing;
		add(descText);
	}
}

class ModernButton extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var outline:FlxSprite;
	public var text:FlxText;
	public var onClick:Void->Void;
	
	public function new(x:Float, y:Float, width:Int, height:Int, label:String, onClick:Void->Void)
	{
		super(x, y);
		
		this.onClick = onClick;
		
		// Black outline/border (4px)
		outline = FlxSpriteUtil.drawRoundRect(
			new FlxSprite(-4, -4).makeGraphic(width + 8, height + 8, FlxColor.TRANSPARENT),
			0, 0, width + 8, height + 8, 15, 15, FlxColor.BLACK
		);
		add(outline);
		
		// Background - Rounded corners (15px)
		bg = FlxSpriteUtil.drawRoundRect(
			new FlxSprite(0, 0).makeGraphic(width, height, FlxColor.TRANSPARENT),
			0, 0, width, height, 15, 15, FlxColor.BLACK
		);
		bg.alpha = 0.5;
		add(bg);
		
		text = new FlxText(0, 0, width, label);
		text.setFormat(Paths.font("Avgardd.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		text.antialiasing = ClientPrefs.data.antialiasing;
		text.y = (height - text.height) / 2;
		add(text);
	}
}

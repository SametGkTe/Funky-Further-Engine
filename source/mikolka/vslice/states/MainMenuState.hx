package mikolka.vslice.states;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import mikolka.vslice.StickerSubState;

class MainMenuState extends MusicBeatState
{
    public static var psychEngineVersion:String = '1.0.4';
    public static var curRow:Int = 0;
    public static var curCol:Int = 0;

    var allowMouse:Bool = true;
    var menuItems:FlxTypedGroup<FlxSprite>;

    var menuGrid:Array<Array<String>> = [
        ['story_mode', 'freeplay'],
        #if MODS_ALLOWED
        ['mods', 'credits'],
        #else
        ['credits', 'credits'],
        #end
        ['gallery'],
        #if ACHIEVEMENTS_ALLOWED
        ['achievements', 'options']
        #else
        ['options', 'options']
        #end
    ];

    var bg:FlxSprite;
    var magenta:FlxSprite;
    var camFollow:FlxObject;
    var selectedSomethin:Bool = false;
    var timeNotMoving:Float = 0;
    var breathe:Float = 0;
    var gridPositions:Map<String, {x:Float, y:Float, scale:Float}> = [];

    var leftX:Float = 0;
    var rightX:Float = 0;
    var row1Y:Float = 0;
    var row2Y:Float = 0;
    var row3Y:Float = 0;
    var row4Y:Float = 0;

    var topBar:FlxSprite;
    var topBarLine:FlxSprite;
    var bottomBar:FlxSprite;
    var bottomBarLine:FlxSprite;
    var titleText:FlxText;
    var clockText:FlxText;
    var descriptionText:FlxText;
    var psychVerText:FlxText;
    var fnfVerText:FlxText;
    var topBarHeight:Int = 50;
    var bottomBarHeight:Int = 56;

    var optionDescriptions:Map<String, String> = [];

    function initDescriptions():Void
    {
        optionDescriptions = [
            'story_mode' => Language.getPhrase('menu_desc_story_mode', 'Hikaye modunu oynayın'),
            'freeplay' => Language.getPhrase('menu_desc_freeplay', 'Açtığın şarkıları sınırsız oyna'),
            'mods' => Language.getPhrase('menu_desc_mods', 'Modlarını görüntüle ve yönet'),
            'credits' => Language.getPhrase('menu_desc_credits', 'Oyunun yapımında emeği geçenleri gör'),
            'achievements' => Language.getPhrase('menu_desc_achievements', 'Kazandığın başarımları görüntüle'),
            'options' => Language.getPhrase('menu_desc_options', 'Oyun ayarlarını ve kontrolleri düzenle'),
            'gallery' => Language.getPhrase('menu_desc_gallery', 'konseptleri ve ekstraları gör')
        ];
    }

    static var showOutdatedWarning:Bool = true;
	var stickerSubState:Null<StickerSubState> = null;
	
	public function new(?stickers:StickerSubState)
	{
		super();
		if (stickers != null && stickers.members != null)
			stickerSubState = stickers;
	}

    override function create()
    {
        super.create();
		
		initDescriptions();
		
        #if MODS_ALLOWED
        Mods.pushGlobalMods();
        #end
        Mods.loadTopMod();

        #if DISCORD_ALLOWED
        DiscordClient.changePresence("In the Menus", null);
        #end

        persistentUpdate = persistentDraw = true;
        calculateGridPositions();

        bg = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
        bg.antialiasing = ClientPrefs.data.antialiasing;
        bg.scrollFactor.set(0, 0.12);
        bg.setGraphicSize(Std.int(bg.width * 1.2));
        bg.updateHitbox();
        bg.screenCenter();
        add(bg);

        magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
        magenta.antialiasing = ClientPrefs.data.antialiasing;
        magenta.scrollFactor.set(0, 0.12);
        magenta.setGraphicSize(Std.int(magenta.width * 1.2));
        magenta.updateHitbox();
        magenta.screenCenter();
        magenta.visible = false;
        magenta.color = 0xFFfd719b;
        add(magenta);
		
        topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, topBarHeight, 0xFF000000);
        topBar.alpha = 0.72;
        topBar.scrollFactor.set();
        add(topBar);

        topBarLine = new FlxSprite(0, topBarHeight).makeGraphic(FlxG.width, 2, 0xFFFFFFFF);
        topBarLine.alpha = 0.15;
        topBarLine.scrollFactor.set();
        add(topBarLine);

        titleText = new FlxText(20, 0, 0, "PSYCH ENGINE", 18);
        titleText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
        titleText.y = (topBarHeight - titleText.height) / 2;
        titleText.scrollFactor.set();
        titleText.alpha = 0.9;
        add(titleText);

        clockText = new FlxText(0, 0, 0, "", 16);
        clockText.setFormat(Paths.font("clock.ttf"), 16, FlxColor.WHITE, RIGHT);
        clockText.y = (topBarHeight - clockText.height) / 2;
        clockText.scrollFactor.set();
        clockText.alpha = 0.6;
        add(clockText);
        updateClock();

        bottomBar = new FlxSprite(0, FlxG.height - bottomBarHeight).makeGraphic(FlxG.width, bottomBarHeight, 0xFF000000);
        bottomBar.alpha = 0.72;
        bottomBar.scrollFactor.set();
        add(bottomBar);

        bottomBarLine = new FlxSprite(0, FlxG.height - bottomBarHeight - 2).makeGraphic(FlxG.width, 2, 0xFFFFFFFF);
        bottomBarLine.alpha = 0.15;
        bottomBarLine.scrollFactor.set();
        add(bottomBarLine);

        psychVerText = new FlxText(20, FlxG.height - bottomBarHeight + 10, 0, "Psych Engine v" + psychEngineVersion, 14);
        psychVerText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT);
        psychVerText.scrollFactor.set();
        psychVerText.alpha = 0.7;
        add(psychVerText);

        fnfVerText = new FlxText(20, FlxG.height - bottomBarHeight + 30, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
        fnfVerText.setFormat(Paths.font("vcr.ttf"), 12, 0xFF888888, LEFT);
        fnfVerText.scrollFactor.set();
        fnfVerText.alpha = 0.5;
        add(fnfVerText);

        descriptionText = new FlxText(0, FlxG.height - bottomBarHeight + 10, FlxG.width - 30, "", 14);
        descriptionText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, RIGHT);
        descriptionText.scrollFactor.set();
        descriptionText.alpha = 0.6;
        add(descriptionText);
		
        menuItems = new FlxTypedGroup<FlxSprite>();
        add(menuItems);

        var createdOptions:Array<String> = [];
        for (row in 0...menuGrid.length)
        {
            for (col in 0...menuGrid[row].length)
            {
                var option = menuGrid[row][col];
                if (createdOptions.contains(option))
                    continue;
                createdOptions.push(option);

                var pos = gridPositions.get(option);
                if (pos == null) continue;

                var item = createMenuItem(option, pos.x, pos.y, pos.scale);
                if (item != null)
                    menuItems.add(item);
            }
        }
				
		var profileBox = new objects.ProfileBox(FlxG.width - 290, 10);
		profileBox.scrollFactor.set();
		add(profileBox);
		
        camFollow = new FlxObject(FlxG.width / 2, FlxG.height / 2, 1, 1);
        add(camFollow);
        FlxG.camera.follow(camFollow, null, 0.08);

        changeSelection();
        playEntranceAnimations();

        #if ACHIEVEMENTS_ALLOWED
        var leDate = Date.now();
        if (leDate.getDay() == 5 && leDate.getHours() >= 18)
            Achievements.unlock('friday_night_play');
        #if MODS_ALLOWED
        Achievements.reloadList();
        #end
        #end

        #if CHECK_FOR_UPDATES
        if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion)
        {
            persistentUpdate = false;
            showOutdatedWarning = false;
            openSubState(new substates.OutdatedSubState());
        }
        #end
		
		if (stickerSubState != null)
		{
			this.persistentUpdate = true;
			this.persistentDraw = true;
			openSubState(stickerSubState);
			stickerSubState.degenStickers();
		}
    }

    function updateClock():Void
    {
        var now = Date.now();
        var hours = now.getHours();
        var minutes = now.getMinutes();
        var h = StringTools.lpad(Std.string(hours), "0", 2);
        var m = StringTools.lpad(Std.string(minutes), "0", 2);
        clockText.text = h + ":" + m;
        clockText.x = FlxG.width - clockText.width - 20;
    }

    function calculateGridPositions():Void
    {
        leftX = FlxG.width * 0.28;
        rightX = FlxG.width * 0.72;
        var centerX = FlxG.width * 0.5;

        var contentTop = topBarHeight + 25;
        var contentBottom = FlxG.height - bottomBarHeight - 25;
        var contentHeight = contentBottom - contentTop;

        row1Y = contentTop + contentHeight * 0.12;
        row2Y = contentTop + contentHeight * 0.37;
        row3Y = contentTop + contentHeight * 0.62;
        row4Y = contentTop + contentHeight * 0.87;

        var mainScale:Float = 0.70;
        var galleryScale:Float = 0.60;
        var achOptScale:Float = 1.03;

        gridPositions = [
            'story_mode' => {x: leftX, y: row1Y, scale: mainScale},
            'freeplay' => {x: rightX, y: row1Y, scale: mainScale},
            #if MODS_ALLOWED
            'mods' => {x: leftX, y: row2Y, scale: mainScale},
            #end
            'credits' => {x: rightX, y: row2Y, scale: mainScale},
            'gallery' => {x: centerX, y: row3Y, scale: galleryScale},
            #if ACHIEVEMENTS_ALLOWED
            'achievements' => {x: leftX, y: row4Y, scale: achOptScale},
            #end
            'options' => {x: rightX, y: row4Y, scale: achOptScale}
        ];
    }

    function createMenuItem(option:String, x:Float, y:Float, scale:Float):FlxSprite
    {
        var item = new FlxSprite();
        try {
            item.frames = Paths.getSparrowAtlas('mainmenu/menu_' + option);
            item.animation.addByPrefix('idle', option + ' idle', 24, true);
            item.animation.addByPrefix('selected', option + ' selected', 24, true);
            item.animation.play('idle');
        } catch(e:Dynamic) {
            trace('[MainMenuV1] Could not load sprite for: ' + option);
            return null;
        }

        item.antialiasing = ClientPrefs.data.antialiasing;
        item.scrollFactor.set();
        item.scale.set(scale, scale);
        item.updateHitbox();
        item.x = x - (item.width / 2);
        item.y = y - (item.height / 2);
        item.ID = getOptionIndex(option);
        return item;
    }

    function getOptionIndex(option:String):Int
    {
        var allOptions = ['story_mode', 'freeplay', 'mods', 'credits', 'achievements', 'options', 'gallery'];
        return allOptions.indexOf(option);
    }

    function getOptionFromIndex(index:Int):String
    {
        var allOptions = ['story_mode', 'freeplay', 'mods', 'credits', 'achievements', 'options', 'gallery'];
        if (index >= 0 && index < allOptions.length)
            return allOptions[index];
        return 'story_mode';
    }

    function getCurrentOption():String
    {
        if (curRow >= 0 && curRow < menuGrid.length)
        {
            var row = menuGrid[curRow];
            if (curCol >= 0 && curCol < row.length)
                return row[curCol];
        }
        return 'story_mode';
    }

    function getItemByOption(option:String):FlxSprite
    {
        var index = getOptionIndex(option);
        for (item in menuItems)
        {
            if (item != null && item.ID == index)
                return item;
        }
        return null;
    }

    function playEntranceAnimations():Void
    {
        var topBarTargetY = topBar.y;
        topBar.y = -topBarHeight;
        topBarLine.y = -topBarHeight;
        titleText.y = -topBarHeight;
        clockText.y = -topBarHeight;
        FlxTween.tween(topBar, {y: topBarTargetY}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.05});
        FlxTween.tween(topBarLine, {y: cast(topBarHeight, Float)}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.05});
        FlxTween.tween(titleText, {y: (topBarHeight - titleText.height) / 2}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.05});
        FlxTween.tween(clockText, {y: (topBarHeight - clockText.height) / 2}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.05});

        var bottomBarTargetY = bottomBar.y;
        var bottomLineTargetY = bottomBarLine.y;
        bottomBar.y = FlxG.height;
        bottomBarLine.y = FlxG.height;
        psychVerText.y = FlxG.height;
        fnfVerText.y = FlxG.height;
        descriptionText.y = FlxG.height;
        FlxTween.tween(bottomBar, {y: bottomBarTargetY}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.05});
        FlxTween.tween(bottomBarLine, {y: bottomLineTargetY}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.05});
        FlxTween.tween(psychVerText, {y: FlxG.height - bottomBarHeight + 10}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.1});
        FlxTween.tween(fnfVerText, {y: FlxG.height - bottomBarHeight + 30}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.1});
        FlxTween.tween(descriptionText, {y: FlxG.height - bottomBarHeight + 10}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.1});

        for (item in menuItems)
        {
            if (item == null) continue;
            var targetY = item.y;
            item.y = targetY + 80;
            item.alpha = 0;
            var delay = 0.15 + (item.ID * 0.06);
            FlxTween.tween(item, {y: targetY, alpha: 1.0}, 0.45, {
                ease: FlxEase.backOut,
                startDelay: delay
            });
        }
    }

    var clockTimer:Float = 0;

    override function update(elapsed:Float)
    {
        breathe += elapsed;

        clockTimer += elapsed;
        if (clockTimer >= 1.0)
        {
            clockTimer = 0;
            updateClock();
        }

        if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
            FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

        if (!selectedSomethin)
        {
            var moved = false;

            if (controls.UI_LEFT_P)
            {
                var rowLen = menuGrid[curRow].length;
                if (rowLen > 1)
                    curCol = (curCol - 1 + rowLen) % rowLen;
                moved = true;
            }
            if (controls.UI_RIGHT_P)
            {
                var rowLen = menuGrid[curRow].length;
                if (rowLen > 1)
                    curCol = (curCol + 1) % rowLen;
                moved = true;
            }
            if (controls.UI_UP_P)
            {
                curRow = (curRow - 1 + menuGrid.length) % menuGrid.length;
                if (curCol >= menuGrid[curRow].length)
                    curCol = 0;
                moved = true;
            }
            if (controls.UI_DOWN_P)
            {
                curRow = (curRow + 1) % menuGrid.length;
                if (curCol >= menuGrid[curRow].length)
                    curCol = 0;
                moved = true;
            }

            if (moved)
                changeSelection();

            if (allowMouse && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0 || FlxG.mouse.justPressed))
            {
                FlxG.mouse.visible = true;
                timeNotMoving = 0;

                for (item in menuItems)
                {
                    if (item != null && FlxG.mouse.overlaps(item))
                    {
                        var option = getOptionFromIndex(item.ID);
                        var newPos = findGridPosition(option);
                        if (newPos != null && (newPos.row != curRow || newPos.col != curCol))
                        {
                            curRow = newPos.row;
                            curCol = newPos.col;
                            changeSelection();
                        }
                        if (FlxG.mouse.justPressed)
                            selectItem();
                        break;
                    }
                }
            }
            else
            {
                timeNotMoving += elapsed;
                if (timeNotMoving > 2)
                    FlxG.mouse.visible = false;
            }

            if (controls.BACK)
            {
                selectedSomethin = true;
                FlxG.mouse.visible = false;
                FlxG.sound.play(Paths.sound('cancelMenu'));
                MusicBeatState.switchState(new states.TitleState());
            }

            if (controls.ACCEPT)
                selectItem();

            #if desktop
            if (controls.justPressed('debug_1'))
            {
                selectedSomethin = true;
                FlxG.mouse.visible = false;
                MusicBeatState.switchState(new MasterEditorMenu());
            }
            #end
        }

        updateItemAnimations(elapsed);
        super.update(elapsed);
    }

    function findGridPosition(option:String):{row:Int, col:Int}
    {
        for (row in 0...menuGrid.length)
        {
            for (col in 0...menuGrid[row].length)
            {
                if (menuGrid[row][col] == option)
                    return {row: row, col: col};
            }
        }
        return null;
    }

    function updateItemAnimations(elapsed:Float):Void
    {
        var currentOption = getCurrentOption();

        for (item in menuItems)
        {
            if (item == null) continue;

            var option = getOptionFromIndex(item.ID);
            var pos = gridPositions.get(option);
            if (pos == null) continue;

            var isSelected = (option == currentOption);
            var targetScale = isSelected ? pos.scale * 1.12 : pos.scale * 0.9;
            var targetAlpha = isSelected ? 1.0 : 0.45;

            item.scale.x = FlxMath.lerp(item.scale.x, targetScale, elapsed * 12);
            item.scale.y = FlxMath.lerp(item.scale.y, targetScale, elapsed * 12);
            item.alpha = FlxMath.lerp(item.alpha, targetAlpha, elapsed * 10);
            item.updateHitbox();

            var targetX = pos.x - (item.width / 2);
            var targetY = pos.y - (item.height / 2);

            if (isSelected && !selectedSomethin)
            {
                var breatheOffset = Math.sin(breathe * 2.5) * 4;
                targetY += breatheOffset - 8;
            }

            item.x = FlxMath.lerp(item.x, targetX, elapsed * 10);
            item.y = FlxMath.lerp(item.y, targetY, elapsed * 10);
        }

        var selectedItem = getItemByOption(currentOption);
        if (selectedItem != null)
        {
            var targetCamY = FlxG.height / 2 + (curRow - 1) * 25;
            camFollow.y = FlxMath.lerp(camFollow.y, targetCamY, elapsed * 5);
        }
    }

    function changeSelection()
    {
        for (item in menuItems)
        {
            if (item != null)
                item.animation.play('idle');
        }

        FlxG.sound.play(Paths.sound('scrollMenu'));

        var currentOption = getCurrentOption();
        var selectedItem = getItemByOption(currentOption);
        if (selectedItem != null)
            selectedItem.animation.play('selected');

        var desc = optionDescriptions.get(currentOption);
        if (desc != null)
            descriptionText.text = desc;
        else
            descriptionText.text = "";
    }

    function selectItem()
    {
        var currentOption = getCurrentOption();
        var selectedItem = getItemByOption(currentOption);
        if (selectedItem == null) return;

        FlxG.sound.play(Paths.sound('confirmMenu'));
        selectedSomethin = true;
        FlxG.mouse.visible = false;

        if (ClientPrefs.data.flashing)
            FlxFlicker.flicker(magenta, 1.1, 0.15, false);

        FlxFlicker.flicker(selectedItem, 1, 0.06, false, false, function(flick:FlxFlicker)
        {
            goToState(currentOption);
        });

        for (item in menuItems)
        {
            if (item != selectedItem && item != null)
            {
                FlxTween.tween(item, {alpha: 0}, 0.4, {ease: FlxEase.quadIn});
            }
        }
    }

    function goToState(option:String):Void
    {
        switch (option)
        {
            case 'story_mode':
                MenuStyleRouter.goToStoryMode();
            case 'freeplay':
                MenuStyleRouter.goToFreeplay();
            #if MODS_ALLOWED
            case 'mods':
                MenuStyleRouter.goToMods();
            #end
            #if ACHIEVEMENTS_ALLOWED
            case 'achievements':
                MusicBeatState.switchState(new states.AchievementsMenuState());
            #end
            case 'credits':
                MenuStyleRouter.goToCredits();
            case 'options':
                OptionsState.onPlayState = false;
                MenuStyleRouter.goToOptions();
                if (PlayState.SONG != null)
                {
                    PlayState.SONG.arrowSkin = null;
                    PlayState.SONG.splashSkin = null;
                    PlayState.stageUI = 'normal';
                }
            case 'gallery':
                MusicBeatState.switchState(new states.GalleryState());
        }
    }

    override function destroy()
    {
        super.destroy();
    }
}
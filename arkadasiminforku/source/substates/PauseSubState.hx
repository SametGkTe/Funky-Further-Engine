package substates;

import online.util.ShitUtil;
import online.substates.PostTextSubstate;
import sys.io.File;
import online.network.Leaderboard;
import haxe.Json;
import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxStringUtil;

import states.StoryMenuState;
import states.FreeplayState;
import options.OptionsState;
import online.gui.Alert;
import online.util.FileUtils;

@:access(states.PlayState)
class PauseSubState extends MusicBeatSubstate
{
    var grpMenuShit:FlxTypedGroup<Alphabet>;

    var menuItems:Array<String> = [];
    var menuItemsOG:Array<String> = [
        'DEVAM ET',
        'YENIDEN BASLAT',
        'ZORLUGU DEGISTIR',
        'AYARLAR',
        'MENÜYE DÖN'
    ];

    var difficultyChoices = [];
    var curSelected:Int = 0;

    var pauseMusic:FlxSound;
    var practiceText:FlxText;

    // Skip Time / Playback Rate UI
    var skipTimeText:FlxText;
    var skipTimeTracker:Alphabet;
    var rateTracker:Alphabet;

    var curTime:Float = 0;

    var missingTextBG:FlxSprite;
    var missingText:FlxText;

    public static var songName:String = '';

    public function new(x:Float, y:Float)
    {
        controls.isInSubstate = true;
        super();

        // Set initial time
        curTime = Math.max(0, Conductor.songPosition);

        // Remove diff change if no alt difficulties
        if (Difficulty.list.length < 2)
            menuItemsOG.remove('ZORLUGU DEGISTIR');

        if (PlayState.chartingMode)
        {
            menuItemsOG.insert(3, 'CHART MODUNDAN CIK');

            var extra:Int = 0;
            if (!PlayState.instance.startingSong)
            {
                extra = 1;
                menuItemsOG.insert(3, 'ZAMAN ATLA');
            }

            menuItemsOG.insert(4 + extra, 'SARKIYI BITIR');
            menuItemsOG.insert(5 + extra, 'ALISTIRMA MODU');
            menuItemsOG.insert(6 + extra, 'BOTPLAY AC KAPA');
        }

        var offs = 0;

        if (!ClientPrefs.data.disableSongComments && PlayState.instance.songId != null)
        {
            menuItemsOG.insert(3, 'YORUM YAZ');
            offs++;
        }

        if (ClientPrefs.isDebug())
        {
            menuItemsOG.insert(3, 'AYIKLAMA ARACLARI');
            offs++;
        }

        if (PlayState.replayData != null)
        {
            menuItemsOG.remove('CHART DUZENLEYICI');
            menuItemsOG.remove('ZORLUGU DEGISTIR');

            menuItemsOG.insert(2 + offs, 'ZAMAN ATLA');
            menuItemsOG.insert(3 + offs, 'REPLAY KAYDET');

            if (PlayState.replayID != null)
                menuItemsOG.insert(4 + offs, 'REPLAY RAPORU');
        }

        menuItems = menuItemsOG.copy();

        // Difficulty list
        for (i in 0...Difficulty.list.length)
            difficultyChoices.push(Difficulty.getString(i));
        difficultyChoices.push('GERI');

        pauseMusic = new FlxSound();

        // load appropriate pause music (try songName first, fallback to prefs)
        if (songName != null && songName != '' && songName != 'None')
        {
            pauseMusic.loadEmbedded(Paths.music(songName), true, true);
        }
        else
        {
            var msc = null;

            if (ClientPrefs.data.modSkin != null)
            {
                ShitUtil.tempSwitchMod(ClientPrefs.data.modSkin[0], () -> {
                    msc = Paths.music(
                        Paths.formatToSongPath(ClientPrefs.data.pauseMusic + '-' + ClientPrefs.data.modSkin[1])
                    );
                });
            }

            if (msc == null)
                msc = Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic));

            pauseMusic.loadEmbedded(msc, true, true);
        }

        pauseMusic.volume = 0;
        // random start point
        var startRand:Int = FlxG.random.int(0, Std.int(pauseMusic.length / 2));
        pauseMusic.play(false, startRand);
        FlxG.sound.list.add(pauseMusic);

        // background
        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0;
        bg.scrollFactor.set();
        add(bg);

        // cache font path to avoid repeated calls
        var vcrFont = Paths.font("vcr.ttf");

        var info = new FlxText(20, 15, 0, PlayState.SONG.song, 32);
        info.setFormat(vcrFont, 32);
        info.alpha = 0;
        add(info);

        var diffText = new FlxText(20, 50, 0, Difficulty.getString().toUpperCase(), 32);
        diffText.setFormat(vcrFont, 32);
        diffText.alpha = 0;
        add(diffText);

        var deathText = new FlxText(20, 85, 0, "Ölümler: " + PlayState.deathCounter, 32);
        deathText.setFormat(vcrFont, 32);
        deathText.alpha = 0;
        add(deathText);

        practiceText = new FlxText(20, 120, 0, "Alıştırma Modu", 32);
        practiceText.setFormat(vcrFont, 32);
        practiceText.visible = PlayState.instance.practiceMode;
        add(practiceText);

        missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        missingTextBG.alpha = 0.6;
        missingTextBG.visible = false;
        add(missingTextBG);

        missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
        missingText.setFormat(vcrFont, 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        missingText.visible = false;
        add(missingText);

        skipTimeText = new FlxText(0, 0, 0, '', 64);
        skipTimeText.setFormat(vcrFont, 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        skipTimeText.borderSize = 2;
        skipTimeText.visible = false;
        add(skipTimeText);

        grpMenuShit = new FlxTypedGroup<Alphabet>();
        add(grpMenuShit);

        regenMenu();

        cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		mobileManager.addMobilePad(menuItems.contains('ZAMAN ATLA') ? 'FULL' : 'UP_DOWN', 'A_B');
		mobileManager.addMobilePadCamera();
        FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
        FlxTween.tween(info, {alpha: 1, y: info.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
        FlxTween.tween(diffText, {alpha: 1, y: diffText.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
        FlxTween.tween(deathText, {alpha: 1, y: deathText.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});
    }

    var holdTime:Float = 0;
    var cantUnpause:Float = 0.1;

    override function update(elapsed:Float)
    {
        cantUnpause -= elapsed;

        // cache frequently used things locally to reduce repeated property lookups
        var soundList = FlxG.sound;
        var ctrl = controls;
        var scrollSound = Paths.sound('scrollMenu'); // cached once per frame
        var musicLen = FlxG.sound.music != null ? FlxG.sound.music.length : 0;

        // smooth volume ramp for pause music
        if (pauseMusic != null && pauseMusic.volume < 0.5)
            pauseMusic.volume += 0.01 * elapsed;

        super.update(elapsed);

        // Update Skip Time / Playback Rate Text Position
        updateDynamicTextPositions();

        var up = ctrl.UI_UP_P;
        var down = ctrl.UI_DOWN_P;
        var accept = ctrl.ACCEPT;

        if (up) changeSelection(-1);
        if (down) changeSelection(1);

        var selected:String = menuItems[curSelected];

        // Optimize repeated checks by grouping similar logic
        if (selected == 'ZAMAN ATLA')
        {
            if (ctrl.UI_LEFT_P)
            {
                FlxG.sound.play(scrollSound, 0.4);
                curTime -= 1000;
                holdTime = 0;
                updateSkipTimeText();
            }
            if (ctrl.UI_RIGHT_P)
            {
                FlxG.sound.play(scrollSound, 0.4);
                curTime += 1000;
                holdTime = 0;
                updateSkipTimeText();
            }

            if (ctrl.UI_LEFT || ctrl.UI_RIGHT)
            {
                holdTime += elapsed;
                if (holdTime > 0.5)
                    curTime += 45000 * elapsed * (ctrl.UI_LEFT ? -1 : 1);

                if (musicLen > 0)
                {
                    if (curTime >= musicLen)
                        curTime = 0;
                    if (curTime < 0)
                        curTime = musicLen;
                }

                updateSkipTimeText();
            }
        }

        if (selected == 'OYNATMA HIZI')
        {
            if (ctrl.UI_LEFT_P)
            {
                FlxG.sound.play(scrollSound, 0.4);
                PlayState.instance.playbackRate -= 0.01;
                holdTime = 0;
                updatePlaybackRateText();
            }

            if (ctrl.UI_RIGHT_P)
            {
                FlxG.sound.play(scrollSound, 0.4);
                PlayState.instance.playbackRate += 0.01;
                holdTime = 0;
                updatePlaybackRateText();
            }

            if (ctrl.UI_LEFT || ctrl.UI_RIGHT)
            {
                holdTime += elapsed;
                if (holdTime > 0.5)
                    PlayState.instance.playbackRate += elapsed * (ctrl.UI_LEFT ? -1 : 1);

                if (PlayState.instance.playbackRate < 0.001)
                    PlayState.instance.playbackRate = 0.001;
                if (PlayState.instance.playbackRate > 3)
                    PlayState.instance.playbackRate = 3;

                updatePlaybackRateText();
            }
        }

        if (accept && (cantUnpause <= 0 || !controls.controllerMode))
        {
            handleAccept(selected, elapsed);
        }
    }

    function changeSelection(change:Int = 0)
    {
        curSelected += change;

        // cache scroll sound path and play once per selection change
        var scroll = Paths.sound('scrollMenu');
        FlxG.sound.play(scroll, 0.4);

        if (curSelected < 0)
            curSelected = menuItems.length - 1;
        if (curSelected >= menuItems.length)
            curSelected = 0;

        var index = 0;

        for (item in grpMenuShit.members)
        {
            item.targetY = index - curSelected;
            item.alpha = if (item.targetY == 0) 1 else 0.6;

            if (item.targetY == 0)
            {
                // Zaman atlama secili oldugunda zaman reset
                if (item == skipTimeTracker && item.text == 'ZAMAN ATLA')
                {
                    curTime = Math.max(0, Conductor.songPosition);
                    updateSkipTimeText();
                }

                // Oynatma hizi secili oldugunda hiz reset UI
                if (item == rateTracker && item.text == 'OYNATMA HIZI')
                {
                    updatePlaybackRateText();
                }
            }

            index++;
        }

        missingText.visible = false;
        missingTextBG.visible = false;
    }

    function regenMenu():Void
    {
        // Clean objects safely
        for (item in grpMenuShit.members)
        {
            item.kill();
            remove(item);
            item.destroy();
        }
        grpMenuShit.clear();

        skipTimeTracker = null;
        rateTracker = null;
        skipTimeText.visible = false;

        // Use flags to avoid repeated expensive calls inside loop
        var needUpdateSkipTime:Bool = false;
        var needUpdatePlaybackRate:Bool = false;

        for (i in 0...menuItems.length)
        {
            var it = new Alphabet(90, 320, menuItems[i], true);
            it.isMenuItem = true;
            it.targetY = i;
            grpMenuShit.add(it);

            switch (menuItems[i])
            {
                case 'ZAMAN ATLA':
                    skipTimeTracker = it;
                    needUpdateSkipTime = true;

                case 'OYNATMA HIZI':
                    rateTracker = it;
                    needUpdatePlaybackRate = true;
            }
        }

        // Update UI elements once after loop
        if (needUpdateSkipTime)
        {
            updateDynamicTextPositions();
            updateSkipTimeText();
            skipTimeText.visible = true;
        }
        else if (needUpdatePlaybackRate)
        {
            updateDynamicTextPositions();
            updatePlaybackRateText();
            skipTimeText.visible = true;
        }

        curSelected = 0;
        changeSelection(0);
    }

    function updateDynamicTextPositions()
    {
        if (skipTimeText == null) return;

        if (skipTimeTracker != null && skipTimeTracker.alpha >= 1)
        {
            skipTimeText.visible = true;
            skipTimeText.x = skipTimeTracker.x + skipTimeTracker.width + 60;
            skipTimeText.y = skipTimeTracker.y;
            return;
        }

        if (rateTracker != null && rateTracker.alpha >= 1)
        {
            skipTimeText.visible = true;
            skipTimeText.x = rateTracker.x + rateTracker.width + 60;
            skipTimeText.y = rateTracker.y;
            return;
        }

        skipTimeText.visible = false;
    }

    function updateSkipTimeText()
    {
        var now = Math.floor(curTime / 1000);
        var total = 0;
        if (FlxG.sound.music != null) total = Math.floor(FlxG.sound.music.length / 1000);
        skipTimeText.text = FlxStringUtil.formatTime(now, false)
            + ' / ' +
            FlxStringUtil.formatTime(total, false);
    }

    function updatePlaybackRateText()
    {
        skipTimeText.text = FlxMath.roundDecimal(PlayState.instance.playbackRate, 2) + 'x';
    }

    function handleAccept(selected:String, elapsed:Float)
    {
        if (menuItems == difficultyChoices)
        {
            try {
                if (selected != 'GERI' && difficultyChoices.contains(selected))
                {
                    PlayState.replayData = null;
                    var name = PlayState.SONG.song;
                    var idx = curSelected;
                    var song = Highscore.formatSong(name, idx);

                    PlayState.loadSong(song, name);
                    PlayState.storyDifficulty = idx;

                    FlxG.switchState(new PlayState());
                    FlxG.sound.music.volume = 0;

                    PlayState.changedDifficulty = true;
                    PlayState.chartingMode = false;
                    return;
                }
            }
            catch (e:Dynamic)
            {
                var msg:String = e.toString();
                if (msg.startsWith('[file_contents,assets/data/'))
                    msg = 'Eksik dosya: ' + msg.substring(27, msg.length - 1);

                missingText.text = 'CHART YUKLENIRKEN HATA:\n' + msg;
                missingText.screenCenter(Y);
                missingText.visible = true;
                missingTextBG.visible = true;

                FlxG.sound.play(Paths.sound('cancelMenu'));
                return;
            }

            menuItems = menuItemsOG.copy();
            regenMenu();
            return;
        }

        switch (selected)
        {
            case "DEVAM ET":
                close();

            case "YENIDEN BASLAT":
                PlayState.deathCounter++;
                restartSong();

            case "ZORLUGU DEGISTIR":
                menuItems = difficultyChoices;
                regenMenu();

            case "ALISTIRMA MODU":
                PlayState.instance.practiceMode = !PlayState.instance.practiceMode;
                PlayState.changedDifficulty = true;
                practiceText.visible = PlayState.instance.practiceMode;

            case "ZAMAN ATLA":
                if (curTime < Conductor.songPosition)
                {
                    PlayState.startOnTime = curTime;
                    restartSong(true);
                }
                else
                {
                    if (curTime != Conductor.songPosition)
                    {
                        PlayState.instance.clearNotesBefore(curTime);
                        PlayState.instance.setSongTime(curTime);
                    }
                    close();
                }

            case "SARKIYI BITIR":
                close();
                PlayState.instance.notes.clear();
                PlayState.instance.unspawnNotes = [];
                PlayState.instance.finishSong(true);

            case "BOTPLAY AC KAPA":
                PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
                PlayState.changedDifficulty = true;
                PlayState.instance.botplayTxt.visible = PlayState.instance.cpuControlled;
                PlayState.instance.botplayTxt.alpha = 1;
                PlayState.instance.botplaySine = 0;

            case "YORUM YAZ":
                close();
                persistentUpdate = false;
                persistentDraw = true;
                PlayState.instance.paused = true;
                PlayState.instance.openSubState(new PostTextSubstate(
                    'Yorum yaz:',
                    text -> {
                        online.network.FunkinNetwork.postSongComment(
                            PlayState.instance.songId,
                            text,
                            Conductor.songPosition
                        );
                    }
                ));

            case "AYARLAR":
                PlayState.instance.paused = true;
                PlayState.instance.vocals.volume = 0;
                FlxG.switchState(() -> new OptionsState());

                if (ClientPrefs.data.pauseMusic != 'None')
                {
                    FlxG.sound.playMusic(
                        Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)),
                        pauseMusic.volume
                    );

                    FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
                    FlxG.sound.music.time = pauseMusic.time;
                }

                OptionsState.onPlayState = true;
                OptionsState.onOnlineRoom = false;

            case "MENÜYE DÖN":
                #if DISCORD_ALLOWED
                DiscordClient.resetClientID();
                #end
                PlayState.deathCounter = 0;
                PlayState.seenCutscene = false;
                PlayState.replayData = null;

                Mods.loadTopMod();

                if (PlayState.isStoryMode)
                    FlxG.switchState(() -> new StoryMenuState());
                else
                    FlxG.switchState(() -> new FreeplayState());

                PlayState.cancelMusicFadeTween();
                states.TitleState.playFreakyMusic();

                PlayState.changedDifficulty = false;
                PlayState.chartingMode = false;
                FlxG.camera.followLerp = 0;

            case "REPLAY RAPORU":
                PlayState.instance.openSubState(new PostTextSubstate(
                    'Replay sorunu nedir?',
                    text -> {
                        if (Leaderboard.reportScore(PlayState.replayID, text) != null)
                            Alert.alert("Replay raporlandi");
                    }
                ));
                close();

            case "REPLAY KAYDET":
                var replayData = Json.stringify(PlayState.replayData);
                var path = FileUtils.joinFiles([
                    "replays",
                    PlayState.replayData.player +
                    "Replay-" + PlayState.SONG.song + "-" +
                    Difficulty.getString().toUpperCase() + ".funkinreplay"
                ]);

                File.saveContent(path, replayData);
                Alert.alert("Replay kaydedildi", path);
                close();

            case "AYIKLAMA ARACLARI":
                menuItems = [
                    'OYNATMA HIZI',
                    'SCRIPT CALISTIR',
                    'TARAF DEGISTIR',
                    'CHART DUZENLEYICI',
                    'KARAKTER DUZENLEYICI',
                    'POZISYON AYIKLA',
                    'SALINIM MODU',
                    'GERI'
                ];

                if (PlayState.instance.stage3D != null)
                    menuItems.insert(1, '3D SAHNE AYIKLAMA');

                if (!PlayState.chartingMode)
                    menuItems.insert(2, 'CHART MODU');

                regenMenu();

            case "TARAF DEGISTIR":
                PlayState.instance.toggleOpponentMode();
                close();

            case "3D SAHNE AYIKLAMA":
                close();
                Main.view3D.debugMode = !Main.view3D.debugMode;

            case "POZISYON AYIKLA":
                PlayState.instance.debugPoser.editMode = !PlayState.instance.debugPoser.editMode;
                close();

            case "CHART DUZENLEYICI":
                PlayState.instance.openChartEditor();
                close();

            case "KARAKTER DUZENLEYICI":
                PlayState.instance.openCharacterEditor();
                close();

            case "SALINIM MODU":
                PlayState.swingMode = !PlayState.swingMode;
                close();

            case "CHART MODU":
                PlayState.chartingMode = true;
                close();
                PlayState.instance.openPauseMenu();

            case "SCRIPT CALISTIR":
                close();
                persistentUpdate = false;
                persistentDraw = true;
                PlayState.instance.paused = true;
                PlayState.instance.openSubState(new PostTextSubstate(
                    'Calistirilacak Haxe kodu:',
                    text -> {
                        var hs = new psychlua.HScript(null, text);
                        Alert.alert(hs.returnValue);
                    }
                ));

            case "GERI":
                menuItems = menuItemsOG.copy();
                regenMenu();

            default:
                close();
        }
    }

    public static function restartSong(noTrans:Bool = false)
    {
        PlayState.instance.paused = true;
        FlxG.sound.music.volume = 0;
        PlayState.instance.vocals.volume = 0;

        if (noTrans)
        {
            FlxTransitionableState.skipNextTransIn = true;
            FlxTransitionableState.skipNextTransOut = true;
        }

        FlxG.switchState(new PlayState());
    }

    override function destroy()
    {
        controls.isInSubstate = false;

        if (pauseMusic != null)
            pauseMusic.destroy();

        super.destroy();
    }
}
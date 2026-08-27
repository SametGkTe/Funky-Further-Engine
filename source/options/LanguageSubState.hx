package options;

import flixel.effects.FlxFlicker;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import openfl.utils.Assets;
#if MODS_ALLOWED
import sys.io.File;
#end

class LanguageSubState extends MusicBeatSubstate
{
    #if TRANSLATIONS_ALLOWED

    static inline final ITEM_HEIGHT:Float = 100;
    static inline final ITEM_SELECTED_ALPHA:Float = 1.0;
    static inline final ITEM_UNSELECTED_ALPHA:Float = 0.6;
    static inline final CHECKMARK:String = " ~";
    static inline final MAX_VISIBLE_WITHOUT_SCROLL:Int = 7;
    static inline final SELECTOR_HEIGHT:Int = 6;
    static inline final INFO_Y_OFFSET:Float = 56;
    static inline final PREVIEW_Y_OFFSET:Float = 32;

    var grpLanguages:FlxTypedGroup<Alphabet> = new FlxTypedGroup<Alphabet>();
    var languages:Array<String> = [];
    var displayLanguages:Map<String, String> = [];
    var curSelected:Int = 0;
    var changedLanguage:Bool = false;
    var originalLanguage:String = '';
    var confirmed:Bool = false;

    var bg:FlxSprite;
    var infoText:FlxText;
    var previewText:FlxText;
    var hintText:FlxText;
    var selector:FlxSprite;
    var noLanguagesText:FlxText;

    public function new()
    {
        super();

        originalLanguage = ClientPrefs.data.language;

        createBackground();
        createSelector();
        loadLanguages();

        if (languages.length == 0)
        {
            createNoLanguagesMessage();
        }
        else
        {
            createLanguageList();
            createInfoBar();
            createPreviewText();
            createHintBar();
            updateSelection(true);
        }

        addTouchPad('LEFT_FULL', 'A_B');
        playIntro();
    }

    function createBackground():Void
    {
        bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFFea71fd;
        bg.antialiasing = ClientPrefs.data.antialiasing;
        bg.screenCenter();
        add(bg);
    }

    function createSelector():Void
    {
        selector = new FlxSprite().makeGraphic(Std.int(FlxG.width * 0.7), SELECTOR_HEIGHT, FlxColor.WHITE);
        selector.screenCenter(X);
        selector.alpha = 0;
        add(selector);
    }

    function createNoLanguagesMessage():Void
    {
        noLanguagesText = new FlxText(0, 0, FlxG.width - 100,
            Language.getPhrase('no_languages_found', 'Dil dosyası bulunamadı.\ndata/ klasörüne .lang dosyaları ekleyin.'));
        noLanguagesText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER);
        noLanguagesText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
        noLanguagesText.screenCenter();
        noLanguagesText.alpha = 0;
        add(noLanguagesText);
    }

    function createLanguageList():Void
    {
        add(grpLanguages);

        for (num => lang in languages)
        {
            var name:String = getDisplayName(lang);

            if (lang == ClientPrefs.data.language)
                name += CHECKMARK;

            var text:Alphabet = new Alphabet(0, 300, name, true);
            text.isMenuItem = true;
            text.targetY = num;
            text.changeX = false;
            text.distancePerItem.y = ITEM_HEIGHT;

            if (languages.length < MAX_VISIBLE_WITHOUT_SCROLL)
            {
                text.changeY = false;
                text.screenCenter(Y);
                text.y += (ITEM_HEIGHT * (num - (languages.length / 2))) + 45;
            }

            text.screenCenter(X);
            text.alpha = 0;

            if (lang == ClientPrefs.data.language)
                colorAlphabet(text, FlxColor.LIME);

            grpLanguages.add(text);
        }
    }

    function createInfoBar():Void
    {
        infoText = new FlxText(0, FlxG.height - INFO_Y_OFFSET - PREVIEW_Y_OFFSET - 10, FlxG.width, '');
        infoText.setFormat(Paths.font("vcr.ttf"), 16, 0xFFBBBBBB, CENTER);
        infoText.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
        infoText.alpha = 0;
        add(infoText);
    }

    function createPreviewText():Void
    {
        previewText = new FlxText(0, FlxG.height - INFO_Y_OFFSET - PREVIEW_Y_OFFSET + 16, FlxG.width, '');
        previewText.setFormat(Paths.font("vcr.ttf"), 14, 0xFF999999, CENTER);
        previewText.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
        previewText.alpha = 0;
        add(previewText);
    }

    function createHintBar():Void
    {
        var isMobile = controls.mobileC;
        var hintStr = isMobile
            ? Language.getPhrase('lang_hint_mobile', '[A] Seç   [B] Geri')
            : Language.getPhrase('lang_hint_desktop', '[ENTER] Seç   [ESC] Geri');

        hintText = new FlxText(0, FlxG.height - INFO_Y_OFFSET + 14, FlxG.width, hintStr);
        hintText.setFormat(Paths.font("vcr.ttf"), 14, 0xFF888888, CENTER);
        hintText.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
        hintText.alpha = 0;
        add(hintText);
    }

    function loadLanguages():Void
    {
        languages.push(ClientPrefs.defaultData.language);
        displayLanguages.set(ClientPrefs.defaultData.language, Language.defaultLangName);

        var directories:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'data/');

        for (directory in directories)
        {
            for (file in Paths.readDirectory(directory))
            {
                if (!file.toLowerCase().endsWith('.lang'))
                    continue;

                var langFile:String = file.substring(0, file.length - '.lang'.length).trim();

                if (languages.contains(langFile))
                    continue;

                languages.push(langFile);

                if (!displayLanguages.exists(langFile))
                {
                    var name = extractLanguageName('$directory/$file');
                    if (name != null && name.length > 0)
                        displayLanguages.set(langFile, name);
                }
            }
        }

        languages.sort(function(a:String, b:String)
        {
            var nameA = getDisplayName(a).toLowerCase();
            var nameB = getDisplayName(b).toLowerCase();
            if (nameA < nameB) return -1;
            else if (nameA > nameB) return 1;
            return 0;
        });

        curSelected = languages.indexOf(ClientPrefs.data.language);
        if (curSelected < 0)
        {
            ClientPrefs.data.language = ClientPrefs.defaultData.language;
            curSelected = Std.int(Math.max(0, languages.indexOf(ClientPrefs.data.language)));
        }
    }

    function extractLanguageName(path:String):String
    {
        var txt:String = '';

        try
        {
            #if MODS_ALLOWED
            txt = File.getContent(path);
            #else
            txt = Assets.getText(path);
            #end
        }
        catch (e:Dynamic)
        {
            return null;
        }

        if (txt == null || txt.length == 0)
            return null;

        if (txt.charCodeAt(0) == 0xFEFF)
            txt = txt.substr(1);

        var id:Int = txt.indexOf('\n');
        if (id > 0)
        {
            var name:String = txt.substr(0, id).trim();
            if (name.length > 0 && !name.contains(':'))
                return name;
        }
        else if (txt.trim().length > 0 && !txt.contains(':'))
        {
            return txt.trim();
        }

        return null;
    }

    function playIntro():Void
    {
        bg.alpha = 0;
        FlxTween.tween(bg, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});

        if (languages.length > 0)
        {
            for (num => item in grpLanguages.members)
            {
                if (item == null) continue;
                var delay = 0.06 + (num * 0.04);
                if (delay > 0.5) delay = 0.5;
                FlxTween.tween(item, {alpha: (num == curSelected) ? ITEM_SELECTED_ALPHA : ITEM_UNSELECTED_ALPHA}, 0.3, {
                    startDelay: delay,
                    ease: FlxEase.quadOut
                });
            }

            FlxTween.tween(selector, {alpha: 0.15}, 0.3, {startDelay: 0.12, ease: FlxEase.quadOut});
            FlxTween.tween(infoText, {alpha: 1}, 0.3, {startDelay: 0.20, ease: FlxEase.quadOut});
            FlxTween.tween(previewText, {alpha: 1}, 0.3, {startDelay: 0.25, ease: FlxEase.quadOut});
            FlxTween.tween(hintText, {alpha: 0.8}, 0.3, {startDelay: 0.30, ease: FlxEase.quadOut});
        }
        else if (noLanguagesText != null)
        {
            FlxTween.tween(noLanguagesText, {alpha: 1}, 0.4, {startDelay: 0.15, ease: FlxEase.quadOut});
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (confirmed)
            return;

        if (languages.length == 0)
        {
            if (controls.BACK)
            {
                FlxG.sound.play(Paths.sound('cancelMenu'));
                close();
            }
            return;
        }

        handleNavigation();
        handleSelection();
        updateSelectorPosition(elapsed);
    }

    function handleNavigation():Void
    {
        if (controls.UI_UP_P)
            changeSelected(-1);
        if (controls.UI_DOWN_P)
            changeSelected(1);
        if (FlxG.mouse.wheel != 0)
            changeSelected(-FlxG.mouse.wheel);
    }

    function handleSelection():Void
    {
        if (controls.BACK)
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));

            if (changedLanguage)
	            {
	                FlxTransitionableState.skipNextTransIn = true;
	                FlxTransitionableState.skipNextTransOut = true;
	                MusicBeatState.switchState(new options.OptionsState());
	            }
	            else
	            {
	                close();
	            }
            return;
        }

        if (controls.ACCEPT)
        {
            confirmLanguage();
        }
    }

    function changeSelected(change:Int = 0):Void
    {
        if (change != 0)
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);

        curSelected = FlxMath.wrap(curSelected + change, 0, languages.length - 1);
        updateSelection();
    }

    function updateSelection(?instant:Bool = false):Void
    {
        for (num => lang in grpLanguages.members)
        {
            if (lang == null) continue;
            lang.targetY = num - curSelected;
            lang.alpha = (num == curSelected) ? ITEM_SELECTED_ALPHA : ITEM_UNSELECTED_ALPHA;
        }

        updateInfoBar();
        updatePreviewText();
    }

    function updateInfoBar():Void
    {
        if (infoText == null) return;

        var langID = languages[curSelected];
        var isActive = (langID == ClientPrefs.data.language);
        var isDefault = (langID == ClientPrefs.defaultData.language);

        var info = '[ $langID ]';

        if (isDefault)
            info += '  |  ' + Language.getPhrase('lang_default', 'Varsayılan');

        if (isActive)
            info += '  |  ' + Language.getPhrase('lang_active', 'Aktif');

        infoText.text = info;
    }

    function updatePreviewText():Void
    {
        if (previewText == null) return;

        var langID = languages[curSelected];

        if (langID == ClientPrefs.defaultData.language)
        {
            previewText.text = Language.getPhrase('lang_hardcoded_hint', '(Oyunun yerleşik dili)');
            return;
        }

        var preview = loadPreviewFromFile(langID);
        if (preview != null && preview.length > 0)
        {
            previewText.text = '"$preview"';
        }
        else
        {
            previewText.text = '';
        }
    }

    function loadPreviewFromFile(langID:String):String
    {
        var directories:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'data/');

        for (directory in directories)
        {
            var path = '$directory/$langID.lang';
            var txt:String = null;

            try
            {
                #if MODS_ALLOWED
                if (sys.FileSystem.exists(path))
                    txt = File.getContent(path);
                #else
                txt = Assets.getText(path);
                #end
            }
            catch (e:Dynamic)
            {
                continue;
            }

            if (txt == null || txt.length == 0)
                continue;

            var previewKeys = ['yes', 'no', 'pause_resume', 'pause_back'];

            for (line in txt.split('\n'))
            {
                line = line.trim();
                if (line.length < 4 || line.startsWith('//') || line.startsWith('#'))
                    continue;

                var colonPos = line.indexOf(':');
                if (colonPos < 0) continue;

                var key = line.substr(0, colonPos).trim().toLowerCase();

                if (previewKeys.contains(key))
                {
                    var value = line.substr(colonPos + 1);
                    var q1 = value.indexOf('"');
                    var q2 = value.lastIndexOf('"');
                    if (q1 >= 0 && q2 > q1)
                        return value.substring(q1 + 1, q2);
                }
            }
        }

        return null;
    }

    function updateSelectorPosition(elapsed:Float):Void
    {
        if (selector == null || grpLanguages.members.length == 0) return;

        var targetItem = grpLanguages.members[curSelected];
        if (targetItem == null) return;

        var targetY = targetItem.y + targetItem.height + 4;
        selector.y = FlxMath.lerp(selector.y, targetY, FlxMath.bound(elapsed * 12, 0, 1));
    }

    function confirmLanguage():Void
    {
        var selectedLang = languages[curSelected];

        if (selectedLang == ClientPrefs.data.language && !changedLanguage)
        {
            FlxG.sound.play(Paths.sound('cancelMenu'), 0.5);
            return;
        }

        confirmed = true;
        FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);

        var selectedItem = grpLanguages.members[curSelected];
        if (selectedItem != null)
        {
            FlxFlicker.flicker(selectedItem, 0.8, 0.08, true, true, function(_)
            {
                applyLanguage(selectedLang);
            });
        }
        else
        {
            applyLanguage(selectedLang);
        }
    }

    function applyLanguage(langID:String):Void
    {
        ClientPrefs.data.language = langID;
        ClientPrefs.saveSettings();
        Language.reloadPhrases();
        changedLanguage = true;
        confirmed = false;

        refreshColors();
        updateInfoBar();
        updatePreviewText();
    }

    function refreshColors():Void
    {
        for (num => item in grpLanguages.members)
        {
            if (item == null) continue;

            var langID = languages[num];

            if (langID == ClientPrefs.data.language)
                colorAlphabet(item, FlxColor.LIME);
            else
                colorAlphabet(item, FlxColor.WHITE);
        }
    }

    function colorAlphabet(alphabet:Alphabet, color:FlxColor):Void
    {
        for (letter in alphabet.members)
        {
            if (letter != null)
                letter.color = color;
        }
    }

    function getDisplayName(langID:String):String
    {
        var name = displayLanguages.get(langID);
        return (name != null) ? name : langID;
    }

    #end
}
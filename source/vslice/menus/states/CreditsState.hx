package vslice.menus.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import objects.AttachedSprite;
import substates.LinkSubState;

class CreditsState extends MusicBeatState
{
	var curSelected:Int = -1;
	var grpOptions:FlxTypedGroup<Alphabet>;
	var iconArray:Array<AttachedSprite> = [];
	var sectionIconArray:Array<{icon:FlxSprite, tracker:Alphabet}> = [];
	var creditsStuff:Array<Array<String>> = [];

	var bg:FlxSprite;
	var bgOverlay:FlxSprite;
	var intendedColor:FlxColor;

	var descPanel:FlxSprite;
	var descText:FlxText;
	var descDivider:FlxSprite;

	var topBar:FlxSprite;
	var topBarLine:FlxSprite;
	var titleText:FlxText;

	var bottomBar:FlxSprite;
	var bottomBarLine:FlxSprite;
	var navHintText:FlxText;
	var personCountText:FlxText;

	var quitting:Bool = false;
	var holdTime:Float = 0;

	var topBarHeight:Int = 50;
	var bottomBarHeight:Int = 44;
	var descPanelHeight:Int = 90;

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = true;

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);

		bgOverlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
		bgOverlay.alpha = 0.35;
		bgOverlay.scrollFactor.set();
		add(bgOverlay);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		#if MODS_ALLOWED
		for (mod in Mods.parseList().enabled) pushModCreditsToList(mod);
		#end

		var defaultList:Array<Array<String>> = [
			['Psych Engine Türkiye', '', 'pet'],
			['SametGkTe', 'gkte', 'Psych Engine Türkiye nin ana yapımcısı', 'tiktok::https://tiktok.com/@gktegameplay||youtube::https://youtube.com/@gkte', 'FFE7C0'],
			['Mobile Porting Team', '', 'mobile_icon'],
			['HomuHomu833', 'homura', 'Head Porter of Psych Engine and Author of linc_luajit-rewriten', 'youtube::https://youtube.com/@HomuHomu833', 'FFE7C0'],
			['Karim Akra', 'karim', 'Second Porter of Psych Engine', 'youtube::https://youtube.com/@Karim0690', 'FFB4F0'],
			['Moxie', 'moxie', 'Helper of Psych Engine Mobile', 'twitter::https://twitter.com/moxie_specalist', 'F592C4'],
			[''],
			['Psych Engine Team', '', 'psych_icon'],
			['Shadow Mario', 'shadowmario', 'Main Programmer and Head of Psych Engine', 'kofi::https://ko-fi.com/shadowmario||twitter::https://x.com/ShadowMario_', '444444'],
			['Riveren', 'riveren', 'Main Artist/Animator of Psych Engine', 'twitter::https://x.com/riverennn', '14967B'],
			[''],
			['Former Engine Members'],
			['bb-panzu', 'bb', 'Ex-Programmer of Psych Engine', 'twitter::https://x.com/bbsub3', '3E813A'],
			[''],
			['Engine Contributors'],
			['crowplexus', 'crowplexus', 'Linux Support, HScript Iris, Input System v3, and Other PRs', 'twitter::https://twitter.com/IamMorwen', 'CFCFCF'],
			['Kamizeta', 'kamizeta', 'Creator of Pessy, Psych Engine\'s mascot.', 'instagram::https://www.instagram.com/cewweey/', 'D21C11'],
			['MaxNeton', 'maxneton', 'Loading Screen Easter Egg Artist/Animator.', 'bsky::https://bsky.app/profile/maxneton.bsky.social', '3C2E4E'],
			['Keoiki', 'keoiki', 'Note Splash Animations and Latin Alphabet', 'twitter::https://x.com/Keoiki_', 'D2D2D2'],
			['SqirraRNG', 'sqirra', 'Crash Handler and Base code for Chart Editor\'s Waveform', 'twitter::https://x.com/gedehari', 'E1843A'],
			['EliteMasterEric', 'mastereric', 'Runtime Shaders support and Other PRs', 'twitter::https://x.com/EliteMasterEric', 'FFBD40'],
			['MAJigsaw77', 'majigsaw', '.MP4 Video Loader Library (hxvlc)', 'twitter::https://x.com/MAJigsaw77', '5F5F5F'],
			['iFlicky', 'flicky', 'Composer of Psync and Tea Time and some sound effects', 'twitter::https://x.com/flicky_i', '9E29CF'],
			['KadeDev', 'kade', 'Fixed some issues on Chart Editor and Other PRs', 'twitter::https://x.com/kade0912', '64A250'],
			['superpowers04', 'superpowers04', 'LUA JIT Fork', 'twitter::https://x.com/superpowers04', 'B957ED'],
			['CheemsAndFriends', 'cheems', 'Creator of FlxAnimate', 'twitter::https://x.com/CheemsnFriendos', 'E1E1E1'],
			[''],
			['Funkin\' Crew'],
			['ninjamuffin99', 'ninjamuffin99', 'Programmer of Friday Night Funkin\'', 'twitter::https://x.com/ninja_muffin99', 'CF2D2D'],
			['PhantomArcade', 'phantomarcade', 'Animator of Friday Night Funkin\'', 'twitter::https://x.com/PhantomArcade3K', 'FADC45'],
			['evilsk8r', 'evilsk8r', 'Artist of Friday Night Funkin\'', 'twitter::https://x.com/evilsk8r', '5ABD4B'],
			['kawaisprite', 'kawaisprite', 'Composer of Friday Night Funkin\'', 'twitter::https://x.com/kawaisprite', '378FC7'],
			[''],
			['Psych Engine Discord'],
			['Join the Psych Ward!', 'discord', '', 'discord::https://discord.gg/2ka77eMXDv', '5165F6']
		];

		for (i in defaultList)
			creditsStuff.push(i);

		var selectableCount:Int = 0;
		for (i => credit in creditsStuff)
		{
			var isSelectable:Bool = !unselectableCheck(i);
			var isSectionHeader:Bool = isSectionCheck(i);

			var optionText:Alphabet = new Alphabet(FlxG.width / 2, 300, credit[0], !isSelectable);
			optionText.isMenuItem = true;
			optionText.targetY = i;
			optionText.changeX = false;
			optionText.snapToPosition();
			grpOptions.add(optionText);

			if (isSectionHeader)
			{
				optionText.alignment = CENTERED;

				var sectionIconName:String = (credit.length > 2 && credit[2] != null && credit[2].length > 0) ? credit[2] : null;
				if (sectionIconName != null)
				{
					var str:String = 'credits/missing_icon';
					var fileName = 'credits/' + sectionIconName;
					if (Paths.fileExists('images/$fileName.png', IMAGE)) str = fileName;

					var sIcon:FlxSprite = new FlxSprite().loadGraphic(Paths.image(str));
					sIcon.antialiasing = ClientPrefs.data.antialiasing;
					// scrollFactor.set() KALDIRILDI - tracker ile birlikte scroll edecek
					var iconScale:Float = Math.min(36 / sIcon.width, 36 / sIcon.height);
					sIcon.scale.set(iconScale, iconScale);
					sIcon.updateHitbox();
					sectionIconArray.push({icon: sIcon, tracker: optionText});
					add(sIcon);
				}
			}
			else if (isSelectable)
			{
				selectableCount++;

				if (credit[5] != null)
					Mods.currentModDirectory = credit[5];

				var str:String = 'credits/missing_icon';
				if (credit[1] != null && credit[1].length > 0)
				{
					var fileName = 'credits/' + credit[1];
					if (Paths.fileExists('images/$fileName.png', IMAGE)) str = fileName;
					else if (Paths.fileExists('images/$fileName-pixel.png', IMAGE)) str = fileName + '-pixel';
				}

				var icon:AttachedSprite = new AttachedSprite(str);
				if (str.endsWith('-pixel')) icon.antialiasing = false;
				icon.xAdd = optionText.width + 10;
				icon.sprTracker = optionText;
				iconArray.push(icon);
				add(icon);
				Mods.currentModDirectory = '';

				if (curSelected == -1) curSelected = i;
			}
			else
			{
				optionText.alignment = CENTERED;
			}
		}

		topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, topBarHeight, 0xFF000000);
		topBar.alpha = 0.78;
		topBar.scrollFactor.set();
		add(topBar);

		topBarLine = new FlxSprite(0, topBarHeight).makeGraphic(FlxG.width, 2, 0xFFFFFFFF);
		topBarLine.alpha = 0.12;
		topBarLine.scrollFactor.set();
		add(topBarLine);

		titleText = new FlxText(20, 0, 0, Language.getPhrase('credits_title', 'YAPIMCILAR'), 20);
		titleText.setFormat("VCR OSD Mono", 20, FlxColor.WHITE, LEFT);
		titleText.y = (topBarHeight - titleText.height) / 2;
		titleText.scrollFactor.set();
		titleText.alpha = 0.9;
		add(titleText);

		descPanel = new FlxSprite(0, FlxG.height - bottomBarHeight - descPanelHeight).makeGraphic(FlxG.width, descPanelHeight, 0xFF000000);
		descPanel.alpha = 0.65;
		descPanel.scrollFactor.set();
		add(descPanel);

		descDivider = new FlxSprite(0, descPanel.y).makeGraphic(FlxG.width, 1, 0xFFFFFFFF);
		descDivider.alpha = 0.1;
		descDivider.scrollFactor.set();
		add(descDivider);

		descText = new FlxText(30, descPanel.y + 14, FlxG.width - 60, "", 22);
		descText.setFormat("VCR OSD Mono", 22, FlxColor.WHITE, CENTER);
		descText.scrollFactor.set();
		descText.alpha = 0.85;
		add(descText);

		bottomBar = new FlxSprite(0, FlxG.height - bottomBarHeight).makeGraphic(FlxG.width, bottomBarHeight, 0xFF000000);
		bottomBar.alpha = 0.78;
		bottomBar.scrollFactor.set();
		add(bottomBar);

		bottomBarLine = new FlxSprite(0, FlxG.height - bottomBarHeight - 1).makeGraphic(FlxG.width, 1, 0xFFFFFFFF);
		bottomBarLine.alpha = 0.12;
		bottomBarLine.scrollFactor.set();
		add(bottomBarLine);

		navHintText = new FlxText(20, FlxG.height - bottomBarHeight + 10, 0,
			Language.getPhrase('credits_nav', 'YUKARI/ASAGI Gezin | ENTER Linkleri Aç | ESC Geri'), 14);
		navHintText.setFormat("VCR OSD Mono", 14, 0xFF888888, LEFT);
		navHintText.scrollFactor.set();
		navHintText.alpha = 0.6;
		add(navHintText);

		personCountText = new FlxText(0, FlxG.height - bottomBarHeight + 10, FlxG.width - 20, '$selectableCount ' +
			Language.getPhrase('credits_people', 'kişi'), 14);
		personCountText.setFormat("VCR OSD Mono", 14, 0xFF888888, RIGHT);
		personCountText.scrollFactor.set();
		personCountText.alpha = 0.5;
		add(personCountText);

		if (curSelected >= 0 && creditsStuff[curSelected].length > 4)
		{
			bg.color = CoolUtil.colorFromString(creditsStuff[curSelected][4]);
			intendedColor = bg.color;
		}
		else
		{
			bg.color = 0xFF333333;
			intendedColor = bg.color;
		}

		changeSelection();
		playEntranceAnim();

		addTouchPad('UP_DOWN', 'A_B');

		super.create();
	}

	function playEntranceAnim():Void
	{
		var topTarget = topBar.y;
		topBar.y = -topBarHeight;
		topBarLine.y = -topBarHeight;
		titleText.y = -topBarHeight;
		FlxTween.tween(topBar, {y: topTarget}, 0.35, {ease: FlxEase.quartOut});
		FlxTween.tween(topBarLine, {y: cast(topBarHeight, Float)}, 0.35, {ease: FlxEase.quartOut});
		FlxTween.tween(titleText, {y: (topBarHeight - titleText.height) / 2}, 0.35, {ease: FlxEase.quartOut});

		var bottomTarget = bottomBar.y;
		bottomBar.y = FlxG.height;
		bottomBarLine.y = FlxG.height;
		navHintText.y = FlxG.height;
		personCountText.y = FlxG.height;
		FlxTween.tween(bottomBar, {y: bottomTarget}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.05});
		FlxTween.tween(bottomBarLine, {y: FlxG.height - bottomBarHeight - 1}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.05});
		FlxTween.tween(navHintText, {y: FlxG.height - bottomBarHeight + 10}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.08});
		FlxTween.tween(personCountText, {y: FlxG.height - bottomBarHeight + 10}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.08});

		descPanel.alpha = 0;
		descDivider.alpha = 0;
		descText.alpha = 0;
		FlxTween.tween(descPanel, {alpha: 0.65}, 0.3, {startDelay: 0.15});
		FlxTween.tween(descDivider, {alpha: 0.1}, 0.3, {startDelay: 0.15});
		FlxTween.tween(descText, {alpha: 0.85}, 0.3, {startDelay: 0.2});
	}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		if (!quitting && subState == null)
		{
			if (creditsStuff.length > 1)
			{
				var shiftMult:Int = 1;
				if (FlxG.keys.pressed.SHIFT) shiftMult = 3;

				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}
			}

			if (controls.ACCEPT && !unselectableCheck(curSelected))
			{
				var linkData:String = creditsStuff[curSelected].length > 3 ? creditsStuff[curSelected][3] : null;
				var personName:String = creditsStuff[curSelected][0];

				if (linkData != null && linkData.length > 4)
				{
					FlxG.sound.play(Paths.sound('confirmMenu'));
					LinkSubState.requestMultiLink(personName, linkData);
				}
			}

			if (controls.BACK)
			{
				quitting = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxG.camera.fade(FlxColor.BLACK, 0.4, false, function()
				{
					MusicBeatState.switchState(new MainMenuState());
				});
			}
		}

		for (item in grpOptions.members)
		{
			if (!item.bold)
			{
				var lerpVal:Float = Math.exp(-elapsed * 12);
				if (item.targetY == 0)
				{
					var lastX:Float = item.x;
					item.screenCenter(X);
					item.x = FlxMath.lerp(item.x - 70, lastX, lerpVal);
				}
				else
				{
					item.x = FlxMath.lerp(200 + -40 * Math.abs(item.targetY), item.x, lerpVal);
				}
			}
		}
		
		for (entry in sectionIconArray)
		{
			if (entry.icon != null && entry.tracker != null)
			{
				var trackerWidth:Float = entry.tracker.width;
				var trackerCenterX:Float = entry.tracker.x + trackerWidth / 2;
				// İkonu başlığın soluna koy (başlık + ikon toplam genişliği merkeze göre)
				var totalWidth:Float = entry.icon.width + 10 + trackerWidth;
				var startX:Float = trackerCenterX - totalWidth / 2;

				entry.icon.x = startX;
				entry.icon.y = entry.tracker.y + (entry.tracker.height - entry.icon.height) / 2;
				entry.icon.alpha = entry.tracker.alpha;
			}
		}

		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		do
		{
			curSelected = FlxMath.wrap(curSelected + change, 0, creditsStuff.length - 1);
		}
		while (unselectableCheck(curSelected));

		if (creditsStuff[curSelected].length > 4)
		{
			var newColor:FlxColor = CoolUtil.colorFromString(creditsStuff[curSelected][4]);
			if (newColor != intendedColor)
			{
				intendedColor = newColor;
				FlxTween.cancelTweensOf(bg);
				FlxTween.color(bg, 0.6, bg.color, intendedColor);
			}
		}

		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelected;
			if (!unselectableCheck(num))
				item.alpha = (item.targetY == 0) ? 1.0 : 0.45;
		}

		var descString = creditsStuff[curSelected].length > 2 ? creditsStuff[curSelected][2] : "";
		if (descString != null && descString.trim().length > 0)
		{
			descText.text = descString;
			descText.visible = true;
			descPanel.visible = true;
			descDivider.visible = true;
		}
		else
		{
			descText.text = "";
			descText.visible = false;
			descPanel.visible = false;
			descDivider.visible = false;
		}

		var hasLinks = creditsStuff[curSelected].length > 3
			&& creditsStuff[curSelected][3] != null
			&& creditsStuff[curSelected][3].length > 4;

		navHintText.text = hasLinks
			? Language.getPhrase('credits_nav_links', 'YUKARI/ASAGI Gezin | ENTER Linkleri Aç | ESC Geri')
			: Language.getPhrase('credits_nav_nolinks', 'YUKARI/ASAGI Gezin | ESC Geri');
	}

	#if MODS_ALLOWED
	function pushModCreditsToList(folder:String)
	{
		var creditsFile:String = Paths.mods(folder + '/data/credits.txt');

		#if TRANSLATIONS_ALLOWED
		var translatedCredits:String = Paths.mods(folder + '/data/credits-${ClientPrefs.data.language}.txt');
		#end

		if (#if TRANSLATIONS_ALLOWED (FileSystem.exists(translatedCredits) && (creditsFile = translatedCredits) == translatedCredits) || #end FileSystem.exists(creditsFile))
		{
			var firstarray:Array<String> = File.getContent(creditsFile).split('\n');
			for (i in firstarray)
			{
				var arr:Array<String> = i.replace('\\n', '\n').split("::");
				if (arr.length >= 5) arr.push(folder);
				creditsStuff.push(arr);
			}
			creditsStuff.push(['']);
		}
	}
	#end

	function unselectableCheck(num:Int):Bool
	{
		return creditsStuff[num].length <= 1 || isSectionCheck(num);
	}

	function isSectionCheck(num:Int):Bool
	{
		var credit = creditsStuff[num];
		if (credit.length <= 1) return false;
		if (credit.length == 2 && credit[1] == '') return true;
		if (credit.length == 3 && credit[1] == '') return true;
		return false;
	}

	override function destroy()
	{
		super.destroy();
	}
}

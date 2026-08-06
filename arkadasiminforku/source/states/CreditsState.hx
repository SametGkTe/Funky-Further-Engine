package states;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

import objects.AttachedSprite;

class CreditsState extends MusicBeatState
{
	var curSelected:Int = -1;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<AttachedSprite> = [];
	private var creditsStuff:Array<Array<String>> = [];

	var bg:FlxSprite;
	var descText:FlxText;
	var intendedColor:FlxColor;
	var colorTween:FlxTween;
	var descBox:AttachedSprite;

	var offsetThing:Float = -75;

	override function create()
	{
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", "Credits");
		#end

		persistentUpdate = true;
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();
		
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		#if MODS_ALLOWED
		for (mod in Mods.parseList().enabled) pushModCreditsToList(mod);
		#end

		var defaultList:Array<Array<String>> = [ //Name - Icon name - Description - Link - BG Color
			['P.E.T Online'],
			['SametGkTe', 'gkte', 'Psych Engine Türkiye Yapımcısı / Çevirmen / Kodlayıcı', 'https://tiktok.com/@gktegameplay', '24ED13'],
			['Yardimcilar'],
			['Nexus', 'nexusbotu', 'Yardımcı / Çevirmen', 'https://tiktok.com/@nexus00.3', '24ED13'],
			['Beta kullanicilari'],
			['Nixamic', 'shucks', 'Beta Kullanıcısı', 'https://tiktok.com/@nixamic_amz', 'C96116'],
			['XQZ64', 'tabi', 'Beta Kullanıcısı', 'https://tiktok.com/@xqz248', '3B3734'],
			['Feyza', 'fey', 'Beta Kullanıcısı', 'https://tiktok.com/@feyzawashere', 'B01E1E'],
			['Umut', 'bf2', 'Beta Kullanıcısı', 'https://tiktok.com/@lxbs0', '2472B3'],
			['Mert', 'matt', 'Beta Kullanıcısı', 'https://tiktok.com/@fnf_oynuyom_real', '41464A'],
			['Ömer FK', 'bob', 'Beta Kullanıcısı', 'https://tiktok.com/@0mbi_efendi23', '211E1E'],
			['mvoreZz', 'bulut', 'Beta Kullanıcısı', 'https://tiktok.com/@mvorezz', 'BF179A'],
			['Syran', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@syran_moon', '2472B3'],
			['ProMusas', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@fnf_gamer4231', '2472B3'],
			['Mortis Meain', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@bs_editorx', '2472B3'],
			['Ardaa', 'sarv', 'Beta Kullanıcısı', 'https://tiktok.com/@ardaa.fnf', 'B51F95'],
			['MuratGkTe', 'darnell', 'Beta Kullanıcısı', 'https://tiktok.com/@metal1_1sonic', '6A1FB5'],
			['RiasFNF', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@baki.1223', '2472B3'],
			['ilovepico', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@browhyiamlovefnf', '2472B3'],
			['BilalGkTe', 'nonsense', 'Beta Kullanıcısı', 'https://tiktok.com/@gktegameplay1', '1FB1CC'],
			['Slasher', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@chikenjokey0', '2472B3'],
			['Sahin', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@tofassahin3', '2472B3'],
			['Black Impostor', 'bimpostor', 'Beta Kullanıcısı', 'https://tiktok.com/@diren.rek', '353A3B'],
			['Emir', 'finn', 'Beta Kullanıcısı', 'https://tiktok.com/@wtexyn', '282D2E'],
			['Xonetai', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@xoversfebel', '2472B3'],
			['Sükrü Özel', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@sukruozel.1515', '2472B3'],
			['KuriSpyder', 'pico', 'Beta Kullanıcısı', 'https://tiktok.com/@kurispyder', '5D8F27'],
			['Hamza', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@hamza_1w02', '2472B3'],
			['Merkur', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@merkur72', '2472B3'],
			['Ahmet', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@hh.kk7828', '2472B3'],
			['Dust', 'sans', 'Beta Kullanıcısı', 'https://tiktok.com/@kingerfan992', 'EBE1E1'],
			['Antiki', 'monika', 'Beta Kullanıcısı', 'https://tiktok.com/@m3hm5t_ant1ki', '30BA22'],
			['dortayaklisandalye', 'pump', 'Beta Kullanıcısı', 'https://tiktok.com/@fnfturkiye0', 'EBE1E1'],
			['Cem', 'soulbf', 'Beta Kullanıcısı', 'https://tiktok.com/@cem13933', '292323'],
			['Sae', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@itoshisae67', '2472B3'],
			['Arkose Labs', 'arkoselabs', 'Beta Kullanıcısı', 'https://tiktok.com/@arkoselabsofficial', '95240E'],
			['Bf Yiyen', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@bf_sever', '2472B3'],
			['Hunter Jax', 'jax', 'Beta Kullanıcısı', 'https://tiktok.com/@nugget.elliot', '9E2095'],
			['br4syaert', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@yusufxddr', '2472B3'],
			['Flexxy', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@flexxy.cc', '2472B3'],
			['Balc', 'whitty', 'Beta Kullanıcısı', 'https://tiktok.com/@balc_tr', '302B30'],
			['iplusdVRXD', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@iplusd_vr', '2472B3'],
			['Tolga', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@t0lg00', '2472B3'],
			['SaxtEr', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@saxter190', '2472B3'],
			['Fnf Adam', 'finn', 'Beta Kullanıcısı', 'https://tiktok.com/@fnf.adam', '282D2E'],
			['Cehver', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@batucevher1545', '2472B3'],
			['IsagiTech', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@isagi_techh', '2472B3'],
			['Ren Zhengfei', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@huwi_p50prohype', '2472B3'],
			['KeremTech', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@keremtech84', '2472B3'],
			['Bora', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@imtherealreze0', '2472B3'],
			['Synxtra', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@_synxtra_', '2472B3'],
			['Oozora Edits', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@oozoraedits6', '2472B3'],
			['Cagan', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@yusuficargan', '2472B3'],
			['Fnfci', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@hamzaaa0102', '2472B3'],
			['Yusuf Tunca', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@yusuftunca23', '2472B3'],
			['AlperenPETV2', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@alperenxpetv2', '2472B3'],
			['ForwinGkTe', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@egenonunanasini', '2472B3'],
			['Egewewe', 'bambii', 'Beta Kullanıcısı', 'https://tiktok.com/@egewewe5', '37D111'],
			['ibowewe', 'thearcy', 'Beta Kullanıcısı', 'https://tiktok.com/@.bowewe', 'E3EDE1'],
			['Emirhan_Edits', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@eq_edits0.1', '2472B3'],
			['Ömerr', 'ruv', 'Beta Kullanıcısı', 'https://tiktok.com/@jceho', 'C5CCC4'],
			['isimsiz', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@ahmetsadikara', '2472B3'],
			['Muhammet', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@armedipek5', '2472B3'],
			['Kirik Umut', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@kirikumut07', '2472B3'],
			['Sinister Mark', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@sinisterbaba33', '2472B3'],
			['Sayori', 'sayori', 'Beta Kullanıcısı', 'https://tiktok.com/@popeepy', '30BDD1'],
			['BarooFnF', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@baroo_fnf_', '2472B3'],
			['emreeq', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@emreeq_v', '2472B3'],
			['Mari', 'gf', 'Beta Kullanıcısı', 'https://tiktok.com/@impianoofthemari', 'E30E3F'],
			['QuaresmaFan', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@_quaresma_fan810627921', '2472B3'],
			['Chihan', 'pomni', 'Beta Kullanıcısı', 'https://tiktok.com/@chihanhanim', 'E30E3F'],
			['Agotimmisss', 'agoti', 'Beta Kullanıcısı', 'https://tiktok.com/@swonk79', 'FF0841'],
			['CrazyOpsGame', 'sans', 'Beta Kullanıcısı', 'https://tiktok.com/@crazy.ops.game', 'EBE1E1'],
			['Noxter', 'pico', 'Beta Kullanıcısı', 'https://tiktok.com/@noxter5462', '5D8F27'],
			['KYRkapi', 'kapi', 'Beta Kullanıcısı', 'https://tiktok.com/@kapifnf_3321', '3D3A3A'],
			['batin', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@bwtinalp', '2472B3'],
			['Hicbisey', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@hicbisey87', '2472B3'],
			['HavaliRumuz', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@zelenskirumuz', '2472B3'],
			['Recepcan', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@recepcan301', '2472B3'],
			['Rüzgar Enes', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@enes2753_kral', '2472B3'],
			['Emirhan', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@sedatkoyluoglu', '2472B3'],
			['BachiraTech', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@bachiratech5_31', '2472B3'],
			['EvilTGS', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@turkeysharkamedits10', '2472B3'],
			['HankGkt', 'darnell', 'Beta Kullanıcısı', 'https://tiktok.com/@hankgkt', '6A1FB5'],
			['Ozna', 'matt', 'Beta Kullanıcısı', 'https://tiktok.com/@ozan.can623', '41464A'],
			['Ios Tech', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@iostech02', '2472B3'],
			['saddds', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@sanspros0', '2472B3'],
			['PandezFNF', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@pandez.amp', '2472B3'],
			['Shadows', 'shadow', 'Beta Kullanıcısı', 'https://tiktok.com/@ateistsiken213', 'E31414'],
			['KaanIos', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@kaanios66', '2472B3'],
			['Rosie', 'bf', 'Beta Kullanıcısı', 'https://tiktok.com/@5justrosie5', '2472B3'],
			['Özel Beta Kullanicilari'],
			['Nixamic', 'shucks', 'Özel Beta Kullanıcısı', 'https://tiktok.com/@nixamic_amz', 'C96116'],
			['XQZ64', 'tabi', 'Özel Beta Kullanıcısı', 'https://tiktok.com/@xqz248', '3B3734'],
			['Umut', 'bf2', 'Özel Beta Kullanıcısı', 'https://tiktok.com/@lxbs0', '2472B3'],
			['CrazyOpsGame', 'sans', 'Özel Beta Kullanıcısı', 'https://tiktok.com/@crazy.ops.game', 'EBE1E1'],
			['Syran', 'bf', 'Özel Beta Kullanıcısı', 'https://tiktok.com/@syran_moon', '2472B3'],
			['Balc', 'whitty', 'Özel Beta Kullanıcısı', 'https://tiktok.com/@balc_tr', '302B30'],
			['Ozna', 'matt', 'Özel Beta Kullanıcısı', 'https://tiktok.com/@ozan.can623', '41464A'],
			['Özel Üyeler'],
			['Sen', 'bf', 'Oynadığın için Teşekkürler! :D', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 'FFCC33'],
			['Discord'],
			['P.E.T Discord', 'discord', 'Psych Engine Türkiye Discord Sunucusu!', 'https://discord.gg/juHypjWuNc"', '2472B3'],
			['Mobile Porters'],
			['ArkoseLabs',	 'arkoselabs',	'Porter of Psych Online Mobile',					'https://youtube.com/@arkoselabsofficial',		'95240E'],
			[''],
			['Psych Online'],
			['Snirozu', 'snirozu', 'Developer', 'https://sniro.boo', 'FFCC33'],
			[''],
			['Contributors'],
			['Til', 'til', 'Awesome Code Contributor!', 'https://techniktil.tilnotdrip.org', 'FFFF00'],
			['Poyo', 'pojo', '2v2 Update Playtester and Network Helper', 'https://twitter.com/_Poyo_09', 'B462DD'],
			['Mad!', 'mad', 'Results Screen Re-Assets', 'https://twitter.com/MadWolfAround', 'BF53D1'],
			['Magniill', 'notmagniill', 'Redrew the Online Menu Button', 'https://twitter.com/magniill', '910000'],
			['Vortex', 'vor', 'Multiple Atlas Support', 'https://github.com/Vortex2Oblivion', '00FFFF'],
			['xenkap', '', 'Code Contributor', 'https://github.com/xenkap', '9370DB'],
			[''],
			['Psych Engine Team'],
			['Shadow Mario',		'shadowmario',		'Main Programmer of Psych Engine',								'https://twitter.com/Shadow_Mario_',	'444444'],
			['Riveren',				'riveren',			'Main Artist/Animator of Psych Engine',							'https://twitter.com/riverennn',		'B42F71'],
			[''],
			['Psych Engine Contributors'],
			['iFlicky',				'flicky',			'Composer of Psync and Tea Time\nMade the Dialogue Sounds',		'https://twitter.com/flicky_i',			'9E29CF'],
			['SqirraRNG',			'sqirra',			'Crash Handler and Base code for\nChart Editor\'s Waveform',	'https://twitter.com/gedehari',			'E1843A'],
			['EliteMasterEric',		'mastereric',		'Runtime Shaders support',										'https://twitter.com/EliteMasterEric',	'FFBD40'],
			['PolybiusProxy',		'proxy',			'.MP4 Video Loader Library (hxCodec)',							'https://twitter.com/polybiusproxy',	'DCD294'],
			['KadeDev',				'kade',				'Fixed some cool stuff on Chart Editor\nand other PRs',			'https://twitter.com/kade0912',			'64A250'],
			['Keoiki',				'keoiki',			'Note Splash Animations and Latin Alphabet',					'https://twitter.com/Keoiki_',			'D2D2D2'],
			['superpowers04',		'superpowers04',	'LUA JIT Fork',													'https://twitter.com/superpowers04',	'B957ED'],
			['Smokey',				'smokey',			'Sprite Atlas Support',											'https://twitter.com/Smokey_5_',		'483D92'],
			['bb-panzu',			'bb',				'Ex-Programmer of Psych Engine',								'https://twitter.com/bbsub3',			'3E813A'],
			[''],
			["Funkin' Crew"],
			['ninjamuffin99',		'ninjamuffin99',	"Programmer of Friday Night Funkin'",							'https://twitter.com/ninja_muffin99',	'CF2D2D'],
			['PhantomArcade',		'phantomarcade',	"Animator of Friday Night Funkin'",								'https://twitter.com/PhantomArcade3K',	'FADC45'],
			['evilsk8r',			'evilsk8r',			"Artist of Friday Night Funkin'",								'https://twitter.com/evilsk8r',			'5ABD4B'],
			['kawaisprite',			'kawaisprite',		"Composer of Friday Night Funkin'",								'https://twitter.com/kawaisprite',		'378FC7']
		];
		
		for(i in defaultList) {
			creditsStuff.push(i);
		}
	
		for (i in 0...creditsStuff.length)
		{
			var isSelectable:Bool = !unselectableCheck(i);
			var optionText:Alphabet = new Alphabet(FlxG.width / 2, 300, creditsStuff[i][0], !isSelectable);
			optionText.isMenuItem = true;
			optionText.targetY = i;
			optionText.changeX = false;
			optionText.snapToPosition();
			grpOptions.add(optionText);

			if(isSelectable) {
				if(creditsStuff[i][5] != null)
				{
					Mods.currentModDirectory = creditsStuff[i][5];
				}

				var str:String = 'credits/missing_icon';
				if (Paths.image('credits/' + creditsStuff[i][1]) != null) str = 'credits/' + creditsStuff[i][1];
				var icon:AttachedSprite = new AttachedSprite(str);
				icon.xAdd = optionText.width + 10;
				icon.sprTracker = optionText;
	
				// using a FlxGroup is too much fuss!
				iconArray.push(icon);
				add(icon);
				Mods.currentModDirectory = '';

				if(curSelected == -1) curSelected = i;
			}
			else optionText.alignment = CENTERED;
		}
		
		descBox = new AttachedSprite();
		descBox.makeGraphic(1, 1, FlxColor.BLACK);
		descBox.xAdd = -10;
		descBox.yAdd = -10;
		descBox.alphaMult = 0.8;
		descBox.alpha = 0.6;
		add(descBox);

		descText = new FlxText(50, FlxG.height + offsetThing - 25, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER/*, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK*/);
		descText.scrollFactor.set();
		//descText.borderSize = 2.4;
		descBox.sprTracker = descText;
		add(descText);

		bg.color = CoolUtil.colorFromString(creditsStuff[curSelected][4]);
		intendedColor = bg.color;
		changeSelection();
		mobileManager.addMobilePad('UP_DOWN', 'A_B');
		super.create();
	}

	var quitting:Bool = false;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		if(!quitting)
		{
			if(creditsStuff.length > 1)
			{
				var shiftMult:Int = 1;
				if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

				var upP = controls.UI_UP_P;
				var downP = controls.UI_DOWN_P;

				if (upP)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (downP)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if (FlxG.mouse.wheel != 0) {
					changeSelection(-shiftMult * FlxG.mouse.wheel);
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					{
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
					}
				}
			}

			if(controls.ACCEPT && (creditsStuff[curSelected][3] == null || creditsStuff[curSelected][3].length > 4)) {
				CoolUtil.browserLoad(creditsStuff[curSelected][3]);
			}
			if (controls.BACK)
			{
				if(colorTween != null) {
					colorTween.cancel();
				}
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxG.switchState(() -> new MainMenuState());
				quitting = true;
			}
		}
		
		for (item in grpOptions.members)
		{
			if(!item.bold)
			{
				var lerpVal:Float = FlxMath.bound(elapsed * 12, 0, 1);
				if(item.targetY == 0)
				{
					var lastX:Float = item.x;
					item.screenCenter(X);
					item.x = FlxMath.lerp(lastX, item.x - 70, lerpVal);
				}
				else
				{
					item.x = FlxMath.lerp(item.x, 200 + -40 * Math.abs(item.targetY), lerpVal);
				}
			}
		}
		super.update(elapsed);
	}

	var moveTween:FlxTween = null;
	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		do {
			curSelected += change;
			if (curSelected < 0)
				curSelected = creditsStuff.length - 1;
			if (curSelected >= creditsStuff.length)
				curSelected = 0;
		} while(unselectableCheck(curSelected));

		var newColor:FlxColor = CoolUtil.colorFromString(creditsStuff[curSelected][4]);
		//trace('The BG color is: $newColor');
		if(newColor != intendedColor) {
			if(colorTween != null) {
				colorTween.cancel();
			}
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
				onComplete: function(twn:FlxTween) {
					colorTween = null;
				}
			});
		}

		var bullShit:Int = 0;

		for (item in grpOptions.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			if(!unselectableCheck(bullShit-1)) {
				item.alpha = 0.6;
				if (item.targetY == 0) {
					item.alpha = 1;
				}
			}
		}

		descText.text = creditsStuff[curSelected][2];
		descText.y = FlxG.height - descText.height + offsetThing - 60;

		if(moveTween != null) moveTween.cancel();
		moveTween = FlxTween.tween(descText, {y : descText.y + 75}, 0.25, {ease: FlxEase.sineOut});

		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();
	}

	#if MODS_ALLOWED
	function pushModCreditsToList(folder:String)
	{
		var creditsFile:String = null;
		if(folder != null && folder.trim().length > 0) creditsFile = Paths.mods(folder + '/data/credits.txt');
		else creditsFile = Paths.mods('data/credits.txt');

		if (FunkinFileSystem.exists(creditsFile))
		{
			var firstarray:Array<String> = FunkinFileSystem.getText(creditsFile).split('\n');
			for(i in firstarray)
			{
				var arr:Array<String> = i.replace('\\n', '\n').split("::");
				if(arr.length >= 5) arr.push(folder);
				creditsStuff.push(arr);
			}
			creditsStuff.push(['']);
		}
	}
	#end

	private function unselectableCheck(num:Int):Bool {
		return creditsStuff[num].length <= 1;
	}
}

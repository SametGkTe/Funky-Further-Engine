package states;

import backend.Log;
import backend.TesterProgram;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.graphics.FlxGraphic;
import backend.TesterProgram.TesterCredit;   // ← bu satırı 
import objects.AttachedSprite;
import objects.CreditEntry;
import objects.CreditRainDrop;
import objects.CreditStyle;
import openfl.utils.AssetType;
import substates.LinkSubState;

/**
 * CREDITS STATE — kişiselleştirilebilir sürüm.
 *
 * Neler değişti?
 *  1) İsimler artık başlıklarla aynı DÜZ ALPHABET (beyaz / büyük harf) ile yazılıyor.
 *  2) Her credit satırı kendi arkaplanını seçebiliyor:
 *       - icondrop  → arkaplan FlxBackdrop grid + yukarıdan aşağı icon yağmuru
 *       - custom    → arkaplan özel resim (grid/yağmur yok)
 *       - bu ikisi AYRI seçeneklerdir, aynı satırda birlikte kullanılmaz
 *  2b) "Testers" bölümü: sunucudan (Supabase) doğrulanmış tester programı
 *      üyeleri listeye otomatik eklenir. Liste disk önbelleğinden gelir,
 *      arka planda tazelenir — menü açılışını yavaşlatmaz.
 *  3) Grid ve yağmur rengi, o an seçili credit'in rengine göre değişiyor.
 *  4) Icon yağmuru, seçili credit'in kendi iconunu kullanır ve rastgele
 *     açılardan rastgele dönerek SADECE aşağı doğru sürüklenir.
 *
 * Satır formatı (modlar için data/credits.txt):
 *   İsim::icon::Açıklama::Link::Renk::bayraklar
 * Örnek:
 *   Perez Sen::SAO::Cuenta De youtube::https://www.youtube.com/...::FFA500::icondrop
 *   Perez Sen::SAO::Cuenta De youtube::https://www.youtube.com/...::FFA500::custom::shared/images/özel.png::
 *
 * Tüm bayraklar için: source/objects/CreditStyle.hx ve docs/credits-personalization.md
 */
class CreditsState extends MusicBeatState
{
	/** Aynı anda ekranda olabilecek en fazla damla (havuz boyutu). */
	static inline var MAX_RAIN_DROPS:Int = 40;
	/** Varsayılan (renkli) arkaplan. */
	static inline var DEFAULT_BG:String = 'menuDesat';

	var curSelected:Int = -1;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<AttachedSprite> = [];
	private var iconByIndex:Map<Int, AttachedSprite> = new Map();

	/** Ham satırlar: önce modlardan gelenler, sonra varsayılan liste. */
	private var rawCredits:Array<Array<String>> = [];
	/** Ham satırların çözümlenmiş hali. */
	private var entries:Array<CreditEntry> = [];

	// --- arkaplan katmanları (altta → üstte) ---
	var bgA:FlxSprite; // renk tintli menuDesat
	var bgB:FlxSprite; // özel arkaplan resmi
	var bgDim:FlxSprite; // karartma katmanı
	var gridBg:FlxBackdrop; // FlxGridOverlay gridi
	var rainGroup:FlxTypedGroup<CreditRainDrop>; // icon yağmuru

	var descText:FlxText;
	var intendedColor:FlxColor;
	var descBox:AttachedSprite;

	var offsetThing:Float = -75;

	// ---------------------------------------------------------------------------
	// VARSAYILAN (HARDCODED) GÖRÜNÜM BAYRAKLARI
	//
	// Aşağıdaki defaultList'te her satırın 6. alanına bu bayraklar eklenebilir.
	// Boş bırakırsan (alan yoksa) o satır klasik renkli arkaplanı kullanır.
	// Biçim:  'icondrop'   ya da   'custom::shared/images/özel.png, dim::0.4'
	// Tüm bayraklar: source/objects/CreditStyle.hx
	// ---------------------------------------------------------------------------
	/**
	 * SEÇENEK 1 — icondrop: arkaplan FlxBackdrop grid olur, üstüne
	 * yukarıdan aşağı icon yağmuru biner. Renk credit rengine göre değişir.
	 */
	static inline var FLAGS_ICONDROP:String = 'icondrop';
	/** Sadece grid arkaplan, icon yağmuru yok. */
	static inline var FLAGS_GRID:String = 'grid';
	/** SEÇENEK 2 — custom: arkaplan özel resim olur (grid ve yağmur YOK). */
	static inline var FLAGS_CUSTOM:String = 'custom::shared/images/özel.png, dim::0.4';
	/** Sadece icon yağmuru (arkaplan klasik renkli kalır). */
	static inline var FLAGS_RAIN:String = 'rain';

	// tween takipleri (tek bir tween'i iptal ederken diğerlerini bozmamak için)
	var bgColorTween:FlxTween = null;
	var bgAFade:FlxTween = null;
	var bgBFade:FlxTween = null;
	var dimFade:FlxTween = null;
	var gridFade:FlxTween = null;

	/** O an yüklü özel arkaplan key'i (null = özel arkaplan yok). */
	var curBgKey:String = null;

	// icon yağmuru durumu
	var rainGraphic:FlxGraphic = null;
	var rainPixel:Bool = false;
	var rainCount:Int = 0;
	var rainSpeed:Float = 1;

	override function create()
	{
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = true;

		// ---------------------------------------------------------- ARKAPLAN
		bgA = new FlxSprite().loadGraphic(Paths.image(DEFAULT_BG));
		bgA.antialiasing = ClientPrefs.data.antialiasing;
		bgA.screenCenter();
		add(bgA);

		bgB = new FlxSprite();
		bgB.makeGraphic(1, 1);
		bgB.antialiasing = ClientPrefs.data.antialiasing;
		bgB.alpha = 0;
		bgB.visible = false;
		add(bgB);

		bgDim = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bgDim.alpha = 0;
		bgDim.visible = false;
		bgDim.scrollFactor.set();
		add(bgDim);

		// FlxGridOverlay tabanlı kayan grid (icondrop seçeneği)
		// Rengi beyaz çizgilerden oluşur, sprite'ın `color` değeri ile
		// o an seçili credit'in rengine boyanır.
		gridBg = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		gridBg.velocity.set(40, 40);
		gridBg.alpha = 0;
		gridBg.visible = false;
		gridBg.scrollFactor.set();
		add(gridBg);

		// Icon yağmuru havuzu
		rainGroup = new FlxTypedGroup<CreditRainDrop>();
		add(rainGroup);
		for (i in 0...MAX_RAIN_DROPS)
		{
			var drop:CreditRainDrop = new CreditRainDrop();
			drop.onRecycle = function()
			{
				drop.prepare(rainGraphic, rainPixel, rainSpeed);
			};
			rainGroup.add(drop);
		}

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		#if MODS_ALLOWED
		for (mod in Mods.parseList().enabled) pushModCreditsToList(mod);
		#end

		var defaultList:Array<Array<String>> = [ //Name - Icon name - Description - Link - BG Color - (opsiyonel) görünüm bayrakları
			// ['[ayarlar]', FLAGS_ICONDROP], // ← açarsan bu listenin TAMAMI icondrop kullanır
			['Further Engine'],
			['SametGkTe',			'gkte',             'Further Engine in ana yapımcısı',                       'https://tiktok.com/@gktegameplay',		'15E237', FLAGS_ICONDROP],
			['Özel Üyeler'],
			['ExieGkTe',			'exie',             'WDYM DESC? ITS A SPECIAL MEMBER GRRRR.',                       'https://tiktok.com/@exievesky',		'FD35BB', FLAGS_ICONDROP],
			['Mobil Port'],
			['SametGkTe', 'gkte', 'Wrapped & Ported Mobile Controls', 'https://tiktok.com/@gktegameplay', 'FFE7C0',
 'custom::bg/samet.png, dim::0.4'],
			['ArkoseLabs',	 'arkoselabs',	'Original Mobile Controls',					'https://youtube.com/@arkoselabsofficial',	'95240E'],
			['Temsilciler'],
			['XQZ64',				'tabi',			'Psych Engine Türkiye Temsilcisi',						 'https://www.tiktok.com/@xqz_64',		'C2BDB8'],
			['Nexus',				'nexus',			'Psych Engine Türkiye Temsilcisi',						 'https://www.tiktok.com/@skynexus0.03',	'14967B'],
			['Syran',				'syran',			'Psych Engine Türkiye Temsilcisi',						 'https://www.tiktok.com/@ssyrann',		'14967B'],
			['Ahmet Tanelan',				'goku',			'Psych Engine Türkiye Temsilcisi',						 'https://www.tiktok.com/@hh.kk7828',		'14967B'],
			['Haiden',				'kaithefendi',			'Psych Engine Türkiye Temsilcisi',						 'https://www.tiktok.com/@khaitenn_',		'14967B'],
			['Antiki',				'antiko',			'Psych Engine Türkiye Temsilcisi',						 'https://www.tiktok.com/@antikiemily',		'14967B'],
			['RüzgarGkTe',				'bf',			'Psych Engine Türkiye Temsilcisi',						 'https://www.tiktok.com/@rzgar8565',		'14967B'],
			[''],
			["Psych Engine Team"],
			["Shadow Mario",		"shadowmario",		"Main Programmer and Head of Psych Engine",					"https://ko-fi.com/shadowmario",	"444444"],
			["Riveren",				"riveren",			"Main Artist/Animator of Psych Engine",						"https://x.com/riverennn",	"14967B"],
			[""],
			["Former Engine Members"],
			["bb-panzu",			"bb",				"Ex-Programmer of Psych Engine",							"https://x.com/bbsub3",				"3E813A"],
			[""],
			["Engine Contributors"],
			["crowplexus",			"crowplexus",	"Linux Support, HScript Iris, Input System v3, and Other PRs",	"https://twitter.com/IamMorwen",	"CFCFCF"],
			["Kamizeta",			"kamizeta",			"Creator of Pessy, Psych Engine's mascot.",				"https://www.instagram.com/cewweey/",	"D21C11"],
			["MaxNeton",			"maxneton",			"Loading Screen Easter Egg Artist/Animator.",	"https://bsky.app/profile/maxneton.bsky.social","3C2E4E"],
			["Keoiki",				"keoiki",			"Note Splash Animations and Latin Alphabet",				"https://x.com/Keoiki_",			"D2D2D2"],
			["SqirraRNG",			"sqirra",			"Crash Handler and Base code for\nChart Editor's Waveform",	"https://x.com/gedehari",			"E1843A"],
			["EliteMasterEric",		"mastereric",		"Runtime Shaders support and Other PRs",					"https://x.com/EliteMasterEric",	"FFBD40"],
			["MAJigsaw77",			"majigsaw",			".MP4 Video Loader Library (hxvlc)",						"https://x.com/MAJigsaw77",			"5F5F5F"],
			["iFlicky",				"flicky",			"Composer of Psync and Tea Time\nAnd some sound effects",	"https://x.com/flicky_i",			"9E29CF"],
			["KadeDev",				"kade",				"Fixed some issues on Chart Editor and Other PRs",			"https://x.com/kade0912",			"64A250"],
			["superpowers04",		"superpowers04",	"LUA JIT Fork",											"https://x.com/superpowers04",		"B957ED"],
			["CheemsAndFriends",	"cheems",			"Creator of FlxAnimate",									"https://x.com/CheemsnFriendos",	"E1E1E1"],
			[""],
			["Funkin' Crew"],
			["ninjamuffin99",		"ninjamuffin99",	"Programmer of Friday Night Funkin'",						"https://x.com/ninja_muffin99",		"CF2D2D"],
			["PhantomArcade",		"phantomarcade",	"Animator of Friday Night Funkin'",							"https://x.com/PhantomArcade3K",	"FADC45"],
			["evilsk8r",			"evilsk8r",			"Artist of Friday Night Funkin'",							"https://x.com/evilsk8r",			"5ABD4B"],
			["kawaisprite",			"kawaisprite",		"Composer of Friday Night Funkin'",							"https://x.com/kawaisprite",		"378FC7"],
			[""],
			["Psych Engine Discord"],
			["Join the Psych Ward!", "discord", "", "https://discord.gg/2ka77eMXDv", "5165F6"]
		];

		// Hardcoded liste de modlarla aynı kuralları kullanır:
		// 6. alan bayrak metnidir, '[ayarlar]' satırı listenin varsayılanı olur.
		for (line in defaultList)
			rawCredits.push(line);

		// Tester programı üyeleri (sunucudan doğrulanmış liste)
		insertTesterCredits();

		buildEntries();
		createEntrySprites();
		createDescriptionBox();

		if (curSelected < 0)
		{
			for (i in 0...entries.length)
			{
				if (!unselectableCheck(i))
				{
					curSelected = i;
					break;
				}
			}
		}

		if (curSelected >= 0)
			bgA.color = accentColor(curSelected);
		intendedColor = bgA.color;

		changeSelection();

		addTouchPad('UP_DOWN', 'A_B');

		super.create();
	}

	// ------------------------------------------------------------ LISTE KURULUMU

	/**
	 * Tester Programı üyelerini "Testers" başlığı altında listeye ekler.
	 *
	 * Liste `TesterProgram.cachedCredits()` (disk önbelleği) üzerinden SENKRON
	 * okunur; ağ beklemesi olmaz, menü açılışı yavaşlamaz. Aynı anda arka planda
	 * tazeleme yapılır, bir sonraki açılışta güncel liste görünür.
	 *
	 * Güvenlik: kimin tester olduğu istemcide tutulmaz; sunucu yalnızca onaylı
	 * kayıtları döndürür (bkz. supabase/migrations/*_tester_program.sql).
	 */
	function insertTesterCredits():Void
	{
		var testers:Array<TesterCredit> = TesterProgram.cachedCredits();

		// Arka planda tazele (sonucu bekletmiyoruz).
		TesterProgram.fetchCredits(null);

		if (testers == null || testers.length == 0)
			return;

		var rows:Array<Array<String>> = [['Testers']];
		for (t in testers)
			rows.push([t.name, t.icon, 'Tester Programı üyesi', '', t.color]);
		rows.push(['']);

		// "Funkin' Crew" başlığından hemen önce ekle; bulunamazsa listenin sonuna.
		var insertAt:Int = rawCredits.length;
		for (i in 0...rawCredits.length)
		{
			var line:Array<String> = rawCredits[i];
			if (line != null && line.length == 1 && line[0] != null
				&& line[0].toLowerCase().indexOf('funkin') == 0)
			{
				insertAt = i;
				break;
			}
		}

		for (i in 0...rows.length)
			rawCredits.insert(insertAt + i, rows[i]);
	}

	function buildEntries():Void
	{
		var parsed:Array<CreditEntry> = [];
		var globalStyle:CreditStyle = new CreditStyle();

		for (fields in rawCredits)
		{
			var entry:CreditEntry = new CreditEntry();

			// 1 alanlı satır → başlık ya da ayırıcı
			if (fields == null || fields.length <= 1)
			{
				// CRLF dosyalarında satır sonundaki \r başlığa "?" olarak düşmesin
				entry.name = fieldAt(fields, 0).replace('\r', '').trim();
				entry.isHeader = entry.name.length > 0;
				entry.isSeparator = !entry.isHeader;
				parsed.push(entry);
				continue;
			}

			entry.name = fieldAt(fields, 0).trim();
			entry.iconName = fieldAt(fields, 1).trim();
			entry.desc = fieldAt(fields, 2).trim();
			entry.link = fieldAt(fields, 3).trim();
			entry.color = fieldAt(fields, 4).trim();
			entry.rawFlags = fieldAt(fields, 5);
			entry.modFolder = fieldAt(fields, 6);

			// [ayarlar] / [global] satırı: listelenmez, tüm liste için varsayılan olur.
			if (isGlobalName(entry.name))
			{
				entry.isGlobal = true;
				// kısa yazım desteği: [ayarlar]::icondrop   /   [ayarlar]::custom::bg.png
				if (fields.length <= 5)
					entry.rawFlags = joinFrom(fields, 1);
				globalStyle = CreditStyle.parse(entry.rawFlags, globalStyle);
				parsed.push(entry);
				continue;
			}

			entry.style = CreditStyle.parse(entry.rawFlags);
			parsed.push(entry);
		}

		// Global ayarların üzerine her satırın kendi bayraklarını bindir.
		entries = [];
		for (entry in parsed)
		{
			if (entry.isGlobal) continue;
			if (!entry.isSectionLine())
				entry.style = CreditStyle.parse(entry.rawFlags, globalStyle.copy());
			entries.push(entry);
		}
	}

	function createEntrySprites():Void
	{
		for (i => entry in entries)
		{
			var isSelectable:Bool = !unselectableCheck(i);

			// DÜZ ALPHABET: başlıklarda kullanılan beyaz/büyük harf alphabet artık
			// isimlerde de kullanılıyor (bold = true).
			var optionText:Alphabet = new Alphabet(FlxG.width / 2, 300, entry.name, true);
			optionText.isMenuItem = true;
			optionText.targetY = i;
			optionText.changeX = false;
			optionText.snapToPosition();
			grpOptions.add(optionText);

			if (!isSelectable)
			{
				optionText.alignment = CENTERED;
				continue;
			}

			// Icon ve özel arkaplan, satırın kendi mod klasöründe aranmalı.
			var lastMod:String = Mods.currentModDirectory;
			if (entry.modFolder != null && entry.modFolder.length > 0)
				Mods.currentModDirectory = entry.modFolder;

			entry.iconPath = resolveIconPath(entry.iconName);
			entry.bgKey = resolveCustomBgKey(entry.style.customBg);
			if (entry.style.customBg != null && entry.bgKey == null)
				Log.warn('credits', 'Özel arkaplan bulunamadı: "' + entry.style.customBg + '" (' + entry.name + ')');

			var icon:AttachedSprite = new AttachedSprite(entry.iconPath);
			if (entry.iconPath.endsWith('-pixel')) icon.antialiasing = false;
			icon.xAdd = optionText.width + 10;
			icon.sprTracker = optionText;

			iconByIndex.set(i, icon);
			iconArray.push(icon);
			add(icon);

			Mods.currentModDirectory = lastMod;

			if (curSelected == -1) curSelected = i;
		}
	}

	function createDescriptionBox():Void
	{
		descBox = new AttachedSprite();
		descBox.makeGraphic(1, 1, FlxColor.BLACK);
		descBox.xAdd = -10;
		descBox.yAdd = -10;
		descBox.alphaMult = 0.6;
		descBox.alpha = 0.6;
		add(descBox);

		descText = new FlxText(50, FlxG.height + offsetThing - 25, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER/*, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK*/);
		descText.scrollFactor.set();
		//descText.borderSize = 2.4;
		descBox.sprTracker = descText;
		add(descText);
	}

	// ---------------------------------------------------------- SATIR ÇÖZÜMLEME

	/** Icon yolunu bulur: credits/<icon>.png, yoksa credits/<icon>-pixel.png, yoksa missing_icon. */
	function resolveIconPath(iconName:String):String
	{
		var path:String = 'credits/missing_icon';
		if (iconName != null && iconName.length > 0)
		{
			var fileName:String = 'credits/' + iconName;
			if (Paths.fileExists('images/$fileName.png', AssetType.IMAGE)) path = fileName;
			else if (Paths.fileExists('images/$fileName-pixel.png', AssetType.IMAGE)) path = fileName + '-pixel';
		}
		return path;
	}

	/**
	 * Özel arkaplan yolunu Paths key'ine çevirir.
	 * Kabul edilen biçimler:
	 *   özel.png / images/özel.png / shared/images/özel.png
	 *   mods/ModAdı/images/bg/özel.png
	 * Bulunamazsa null döner (o zaman renkli arkaplana düşer).
	 */
	function resolveCustomBgKey(rawPath:String):String
	{
		if (rawPath == null) return null;

		var key:String = rawPath.trim().replace('\\', '/');
		if (key.length == 0) return null;

		var savedMod:String = Mods.currentModDirectory;
		var result:String = null;

		// mods/ModAdı/... → geçici olarak o modun klasöründe ara
		if (key.startsWith('mods/'))
		{
			var rest:String = key.substring('mods/'.length);
			var slash:Int = rest.indexOf('/');
			if (slash > 0)
			{
				Mods.currentModDirectory = rest.substring(0, slash);
				key = rest.substring(slash + 1);
			}
		}

		// ".../images/xxx.png" → "xxx" (alt klasörler korunur)
		var imgIdx:Int = key.indexOf('/images/');
		if (imgIdx > -1) key = key.substring(imgIdx + '/images/'.length);
		else if (key.startsWith('images/')) key = key.substring('images/'.length);

		if (key.toLowerCase().endsWith('.png'))
			key = key.substring(0, key.length - 4);

		if (key.length > 0 && Paths.fileExists('images/$key.png', AssetType.IMAGE))
			result = key;

		Mods.currentModDirectory = savedMod;
		return result;
	}

	static inline function fieldAt(fields:Array<String>, index:Int):String
	{
		return (fields != null && index >= 0 && index < fields.length && fields[index] != null) ? fields[index] : '';
	}

	/** fields[from...] dizisini "::" ile birleştirir (kısa global yazımı için). */
	static function joinFrom(fields:Array<String>, from:Int):String
	{
		if (fields == null || from >= fields.length) return '';
		var parts:Array<String> = [];
		for (i in from...fields.length)
			if (fields[i] != null) parts.push(fields[i]);
		return parts.join('::');
	}

	static function isGlobalName(name:String):Bool
	{
		if (name == null) return false;
		var n:String = name.trim().toLowerCase();
		return n == '[global]' || n == '[settings]' || n == '[ayarlar]' || n == '[genel]';
	}

	// --------------------------------------------------------------- GÖRÜNÜM

	/** Satırın vurgu rengi (önce satır içi color bayrağı, sonra renk alanı). */
	function accentColor(index:Int):FlxColor
	{
		if (index < 0 || index >= entries.length) return FlxColor.WHITE;

		var entry:CreditEntry = entries[index];
		if (entry.style != null && entry.style.color != null && entry.style.color.length > 0)
			return CoolUtil.colorFromString(entry.style.color);
		if (entry.color != null && entry.color.length > 0)
			return CoolUtil.colorFromString(entry.color);
		return FlxColor.WHITE;
	}

	function applyStyle(animate:Bool = true):Void
	{
		if (curSelected < 0 || curSelected >= entries.length) return;

		var entry:CreditEntry = entries[curSelected];
		var style:CreditStyle = entry.style != null ? entry.style : new CreditStyle();
		var accent:FlxColor = accentColor(curSelected);

		// --- Arkaplan modu: aynı anda SADECE biri aktif ---
		// BG_ICONDROP → FlxBackdrop grid, BG_CUSTOM → özel resim, BG_DEFAULT → renkli menuDesat.
		var useCustom:Bool = (style.bgMode == CreditStyle.BG_CUSTOM && style.customBg != null && entry.bgKey != null);
		var useGrid:Bool = (style.bgMode == CreditStyle.BG_ICONDROP);

		// ---------------------------------------------------- ARKAPLAN RESMİ
		if (useCustom && curBgKey != entry.bgKey)
		{
			// Özel arkaplan, satırın kendi mod klasöründe aranmalı.
			var lastMod:String = Mods.currentModDirectory;
			if (entry.modFolder != null && entry.modFolder.length > 0)
				Mods.currentModDirectory = entry.modFolder;

			var customGraphic:FlxGraphic = Paths.image(entry.bgKey);
			Mods.currentModDirectory = lastMod;

			if (customGraphic == null)
			{
				Log.warn('credits', 'Özel arkaplan yüklenemedi: ' + entry.bgKey);
				useCustom = false;
				curBgKey = null;
			}
			else
			{
				curBgKey = entry.bgKey;
				bgB.loadGraphic(customGraphic);
				bgB.antialiasing = ClientPrefs.data.antialiasing;
				fitSprite(bgB, true);
			}
		}

		if (useCustom)
		{
			bgB.visible = true;
			fadeTo(bgB, 1, animate);
			fadeTo(bgA, 0, animate);
			bgA.color = accent; // geri dönüldüğünde hazır olsun
		}
		else if (useGrid)
		{
			// icondrop / grid: arkada RENKLİ KATMAN OLMAZ.
			// Grid tam opak (alpha 1.0) durur, arkasında bgA görünmez.
			curBgKey = null;
			fadeTo(bgA, 0, animate);
			fadeTo(bgB, 0, animate);
			bgA.color = accent; // gridden çıkınca hazır olsun
		}
		else
		{
			curBgKey = null;
			fadeTo(bgA, 1, animate);
			fadeTo(bgB, 0, animate);

			if (bgA.color != accent)
			{
				if (bgColorTween != null) bgColorTween.cancel();
				if (animate) bgColorTween = FlxTween.color(bgA, 0.8, bgA.color, accent);
				else bgA.color = accent;
			}
		}
		intendedColor = accent;

		// ---------------------------------------------------------- KARARTMA
		var dimTarget:Float = (style.dim >= 0) ? style.dim : (useCustom ? 0.35 : 0.0);
		if (Math.abs(bgDim.alpha - dimTarget) > 0.001)
		{
			if (dimFade != null) dimFade.cancel();
			bgDim.visible = true;
			if (animate) dimFade = FlxTween.tween(bgDim, {alpha: dimTarget}, 0.4, {
				ease: FlxEase.quadOut,
				onComplete: function(_)
				{
					if (dimTarget <= 0.001) bgDim.visible = false;
				}
			});
			else
			{
				bgDim.alpha = dimTarget;
				bgDim.visible = dimTarget > 0.001;
			}
		}

		// --------------------------------------------------------------- GRID
		// icondrop/grid modunda grid TAM OPAK çalışır (1.0).
		// Sadece açıkça `gridalpha::` yazılmışsa o değer kullanılır.
		var gridTarget:Float = useGrid ? (style.gridAlphaSet ? Math.max(0, Math.min(1, style.gridAlpha)) : 1.0) : 0;
		gridBg.velocity.set(style.gridSpeed, style.gridSpeed);
		gridBg.color = accent; // grid çizgileri credit rengine göre
		if (gridFade != null) gridFade.cancel();

		if (!animate || Math.abs(gridBg.alpha - gridTarget) < 0.001)
		{
			gridBg.alpha = gridTarget;
			gridBg.visible = gridTarget > 0.001;
		}
		else
		{
			gridBg.visible = true;
			gridFade = FlxTween.tween(gridBg, {alpha: gridTarget}, 0.5, {
				ease: FlxEase.quadOut,
				onComplete: function(_)
				{
					if (gridTarget <= 0.001) gridBg.visible = false;
				}
			});
		}

		// -------------------------------------------------------- ICON YAĞMURU
		refreshRainGraphic(entry);
		var rainAmount:Int = (style.rain && style.bgMode != CreditStyle.BG_CUSTOM) ? style.rainCount : 0;
		setRain(rainAmount, style.rainSpeed);
	}

	function fitSprite(sprite:FlxSprite, cover:Bool):Void
	{
		if (!cover)
		{
			sprite.setGraphicSize(Std.int(sprite.frameWidth), Std.int(sprite.frameHeight));
			sprite.screenCenter();
			return;
		}

		// Ekranı tamamen kapla (oranı bozmadan, taşan kısım kırpılır).
		var ratio:Float = Math.max(FlxG.width / sprite.frameWidth, FlxG.height / sprite.frameHeight);
		sprite.setGraphicSize(Std.int(sprite.frameWidth * ratio), Std.int(sprite.frameHeight * ratio));
		sprite.screenCenter();
	}

	function fadeTo(sprite:FlxSprite, target:Float, animate:Bool):Void
	{
		if (sprite == null) return;

		var tween:FlxTween = (sprite == bgA) ? bgAFade : bgBFade;
		if (tween != null) tween.cancel();

		if (!animate || Math.abs(sprite.alpha - target) < 0.001)
		{
			sprite.alpha = target;
			sprite.visible = target > 0.001;
			return;
		}

		sprite.visible = true;
		var newTween:FlxTween = FlxTween.tween(sprite, {alpha: target}, 0.45, {
			ease: FlxEase.quadOut,
			onComplete: function(_)
			{
				if (target <= 0.001) sprite.visible = false;
			}
		});

		if (sprite == bgA) bgAFade = newTween;
		else bgBFade = newTween;
	}

	/** Yağmur, o an seçili credit'in iconunu kullanır. */
	function refreshRainGraphic(entry:CreditEntry):Void
	{
		var icon:AttachedSprite = iconByIndex.get(curSelected);
		var graphic:FlxGraphic = (icon != null) ? icon.graphic : null;
		var pixel:Bool = entry != null && entry.iconPath != null && entry.iconPath.endsWith('-pixel');

		rainPixel = pixel;
		if (graphic == rainGraphic) return;

		rainGraphic = graphic;
		for (drop in rainGroup.members)
		{
			if (drop != null && drop.visible)
				drop.setDropGraphic(rainGraphic, rainPixel);
		}
	}

	function setRain(count:Int, speed:Float):Void
	{
		rainCount = Std.int(Math.max(0, Math.min(MAX_RAIN_DROPS, count)));
		rainSpeed = Math.max(0.1, Math.min(4, speed));

		for (i in 0...rainGroup.length)
		{
			var drop:CreditRainDrop = rainGroup.members[i];
			if (drop == null) continue;

			if (i < rainCount && rainGraphic != null)
			{
				if (!drop.visible) drop.prepare(rainGraphic, rainPixel, rainSpeed);
			}
			else if (drop.visible) drop.visible = false;
		}
	}

	// ---------------------------------------------------------------- GÜNCELLEME

	var quitting:Bool = false;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * elapsed;
		}

		if (!quitting && subState == null)
		{
			if (entries.length > 1)
			{
				var shiftMult:Int = 1;
				if (FlxG.keys.pressed.SHIFT) shiftMult = 3;

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

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					{
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
					}
				}
			}

			if (controls.ACCEPT && curSelected >= 0 && !unselectableCheck(curSelected))
			{
				var link:String = entries[curSelected].link;

				if (link != null && link.length > 4)
				{
					LinkSubState.request(
						"Yapımcının bu bağlantısını açmak istiyor musunuz?",
						link,
						function()
						{
							CoolUtil.browserLoad(link);
						}
					);
				}
			}

			if (controls.BACK)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MenuStyleRouter.goToMainMenu();
				quitting = true;
			}
		}

		// Seçili satır sağa kayar; başlık/ayırıcılar sabit kalır.
		for (i in 0...grpOptions.length)
		{
			var item:Alphabet = grpOptions.members[i];
			if (item == null || unselectableCheck(i)) continue;

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
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		if (entries.length == 0) return;

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		do
		{
			curSelected = FlxMath.wrap(curSelected + change, 0, entries.length - 1);
		}
		while (unselectableCheck(curSelected));

		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelected;
			if (!unselectableCheck(num))
			{
				item.alpha = 0.6;
				if (item.targetY == 0)
					item.alpha = 1;
			}
		}

		updateDescription();
		applyStyle(change != 0);
	}

	function updateDescription():Void
	{
		if (curSelected < 0 || curSelected >= entries.length) return;

		descText.text = entries[curSelected].desc;
		if (descText.text != null && descText.text.trim().length > 0)
		{
			descText.visible = descBox.visible = true;
			descText.y = FlxG.height - descText.height + offsetThing - 60;

			if (moveTween != null) moveTween.cancel();
			moveTween = FlxTween.tween(descText, {y: descText.y + 75}, 0.25, {ease: FlxEase.sineOut});

			descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
			descBox.updateHitbox();
		}
		else descText.visible = descBox.visible = false;
	}

	var moveTween:FlxTween = null;

	// -------------------------------------------------------------------- MODLAR

	#if MODS_ALLOWED
	function pushModCreditsToList(folder:String)
	{
		var creditsFile:String = Paths.mods(folder + '/data/credits.txt');

		#if TRANSLATIONS_ALLOWED
		//trace('/data/credits-${ClientPrefs.data.language}.txt');
		var translatedCredits:String = Paths.mods(folder + '/data/credits-${ClientPrefs.data.language}.txt');
		#end

		if (#if TRANSLATIONS_ALLOWED (FileSystem.exists(translatedCredits) && (creditsFile = translatedCredits) == translatedCredits) || #end FileSystem.exists(creditsFile))
		{
			var firstarray:Array<String> = File.getContent(creditsFile).split('\n');
			for (line in firstarray)
			{
				var arr:Array<String> = line.replace('\\n', '\n').split("::");

				// Başlık / ayırıcı satır
				if (arr.length <= 1)
				{
					rawCredits.push([line.replace('\\n', '\n')]);
					continue;
				}

				// [ayarlar] / [global] satırı: isimden sonraki HER ŞEY bayrak metnidir.
				// ([ayarlar]::icondrop)   /   ([ayarlar]::custom::bg.png)
				if (isGlobalName(arr[0]))
				{
					rawCredits.push([arr[0], '', '', '', '', arr.slice(1).join('::'), folder]);
					continue;
				}

				// İsim::icon::açıklama::link::renk::bayraklar
				// Kalan tüm alanlar (6. dahil) bayrak metni sayılır, mod klasörü sona eklenir.
				var flags:String = (arr.length > 5) ? arr.slice(5).join('::') : '';
				var fixed:Array<String> = [];
				for (i in 0...5)
					fixed.push(arr[i] != null ? arr[i] : '');
				fixed.push(flags);
				fixed.push(folder);
				rawCredits.push(fixed);
			}
			rawCredits.push(['']);
		}
	}
	#end

	private function unselectableCheck(num:Int):Bool
	{
		if (num < 0 || num >= entries.length) return true;
		return entries[num].isSectionLine();
	}
}

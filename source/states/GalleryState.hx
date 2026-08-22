package states;

import backend.Paths;
import backend.ClientPrefs;
import backend.Conductor;
import backend.Language;
import backend.MusicBeatState;
// import substates.KlavyeSubState; // F — easter egg kapalı

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;

#if VIDEOS_ALLOWED
import objects.VideoSprite;
#end

#if mobile
import mobile.objects.TouchPad;
import mobile.objects.TouchButton;
import mobile.input.MobileInputID;
import mobile.MobileConfig;
import openfl.utils.Assets;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxTileFrames;
import flixel.math.FlxPoint;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import haxe.Json;

using StringTools;

typedef GalleryItem = {
	var fileName:String;
	var title:String;
	var description:String;
	var type:GalleryType;
	var ?category:String;
	var ?artist:String;
	var ?unlocked:Bool;
	var ?favorited:Bool;
	var ?dateAdded:String;
	var ?modDirectory:String;
}

enum GalleryType {
	IMAGE;
	VIDEO;
	SOUND_EFFECT;
	MUSIC;
	ANIMATED;
}

enum GalleryViewMode {
	GALLERY_GRID;
	SINGLE_VIEW;
	FULLSCREEN;
	SLIDESHOW;
	VIDEO_PLAYING;
}

class GalleryState extends MusicBeatState {
	var galleryItems:Array<GalleryItem> = [
		{
			fileName: "ekip",
			title: "Ekip",
			description: "balc cano araba sürüyor.",
			type: IMAGE,
			category: "Art",
			artist: "Güneş",
			unlocked: true,
			favorited: false,
			dateAdded: "2026-06-12",
			modDirectory: null
		},
		{
			fileName: "ekip2",
			title: "Ekip 2",
			description: "ekip2 ig",
			type: IMAGE,
			category: "Art",
			artist: "Güneş",
			unlocked: true,
			favorited: false,
			dateAdded: "2026-06-12",
			modDirectory: null
		},
		{
			fileName: "cool",
			title: "cool girl",
			description: "cool drawing ngl",
			type: IMAGE,
			category: "Art",
			artist: "s1r3nmoney0 / klavye",
			unlocked: true,
			favorited: false,
			dateAdded: "2026-06-15",
			modDirectory: null
		},
		{
			fileName: "ivy",
			title: "ivy girl",
			description: "It was better than I expected",
			type: IMAGE,
			category: "Art",
			artist: "s1r3nmoney0 / klavye",
			unlocked: true,
			favorited: false,
			dateAdded: "2026-06-15",
			modDirectory: null
		},
		{
			fileName: "deneme",
			title: "Yapımcı Mesajı",
			description: "bişeyide başar aw",
			type: SOUND_EFFECT,
			category: "Audio",
			artist: "SametGkTe",
			unlocked: true,
			favorited: false,
			dateAdded: "2026-06-15",
			modDirectory: null
		},
		{
			fileName: "balcaraba",
			title: "Balc Car Incident",
			description: "Balc araba ile dağ taşa giriyor (4k)",
			type: VIDEO,
			category: "Videos",
			artist: "Team",
			unlocked: true,
			favorited: false,
			dateAdded: "2026-06-15",
			modDirectory: null
		},
		{
			fileName: "balcaraba2",
			title: "..",
			description: "Balc araba ile dağ taşa giriyor (4k)",
			type: VIDEO,
			category: "Videos",
			artist: "Balc & Güneş & XQ",
			unlocked: true,
			favorited: false,
			dateAdded: "2026-06-15",
			modDirectory: null
		},
		{
			fileName: "petu",
			title: "Cancelled Version",
			description: "PET'nin iptal edilen kayıp versiyonu",
			type: IMAGE,
			category: "Concept Art",
			artist: "SametGkTe",
			unlocked: true,
			favorited: false,
			dateAdded: "2026-06-15",
			modDirectory: null
		},
		{
			fileName: "petv1cancelledscreen",
			title: "Cancelled Loading Image",
			description: "PET V1'in iptal edilen yükleme ekranı resmi",
			type: IMAGE,
			category: "Concept Art",
			artist: "SametGkTe",
			unlocked: true,
			favorited: false,
			dateAdded: "2026-06-15",
			modDirectory: null
		},
		{
			fileName: "sans",
			title: "sans",
			description: "sans.",
			type: MUSIC,
			category: "Music",
			artist: "sans",
			unlocked: true,
			favorited: false,
			dateAdded: "sans",
			modDirectory: null
		},
		{
			fileName: "ayran",
			title: "Syran ifşa",
			description: "Ayran",
			type: IMAGE,
			category: "Art",
			artist: "sametgkte",
			unlocked: true,
			favorited: false,
			dateAdded: "2026-07-3",
			modDirectory: null
		},
		{
			fileName: "eternalsugar",
			title: "External Sugar :D",
			description: "rlly like this char ngl",
			type: IMAGE,
			category: "Art",
			artist: "sametgkte",
			unlocked: true,
			favorited: false,
			dateAdded: "2026-08-22",
			modDirectory: null
		}
	];

	var filteredItems:Array<GalleryItem> = [];
	var categories:Array<String> = ["All"];
	var currentCategory:Int = 0;
	var curSelected:Int = 0;
	var viewMode:GalleryViewMode = GALLERY_GRID;
	var disableInput:Bool = true;
	var textVisible:Bool = true;
	var showingInfo:Bool = false;
	var isPanning:Bool = false;

	var gridColumns:Int = 4;
	var gridRows:Int = 2;
	var gridPage:Int = 0;
	var gridThumbnails:FlxTypedGroup<FlxSprite>;

	// KlavyeSubState easter egg (4x R) — kapalı
	// var secretRCount:Int = 0;
	// var secretRTimer:Float = 0;
	// static inline var SECRET_R_TIMEOUT:Float = 2.0;
	// static inline var SECRET_R_NEEDED:Int = 4;
	
	var gridIntroTweens:Array<FlxTween> = [];
	var imageIntroTween:FlxTween;
	var gridBuildToken:Int = 0;
	var imageTweenToken:Int = 0;

	var img:FlxSprite;
	var imgZoom:Float = 0.8;
	var imgOffsetX:Float = 0;
	var imgOffsetY:Float = 0;
	var imgRotation:Float = 0;
	var minZoom:Float = 0.1;
	var maxZoom:Float = 5.0;
	var zoomStep:Float = 0.1;
	var panSpeed:Float = 5.0;
	var smoothPan:Bool = true;
	var targetX:Float = 0;
	var targetY:Float = 0;

	#if VIDEOS_ALLOWED
	var videoObj:VideoSprite;
	#end
	var isVideoPlaying:Bool = false;

	var daSound:FlxSound;
	var audioPlaying:Bool = false;
	var audioPaused:Bool = false;
	var audioProgressBar:FlxSprite;
	var audioProgressFill:FlxSprite;
	var audioTimeText:FlxText;
	var audioTitleText:FlxText;

	var bg:FlxSprite;
	var bgAccent:FlxSprite;
	var bottomBar:FlxSprite;
	var topBar:FlxSprite;
	var titleG:FlxText;
	var artistText:FlxText;
	var descG:FlxText;
	var typeText:FlxText;
	var instDisplay:FlxText;
	var pageDisplay:FlxText;
	var categoryText:FlxText;
	var graphic:FlxSprite;
	var overlayDark:FlxSprite;
	var separator:FlxSprite;

	var infoBG:FlxSprite;
	var infoTitleText:FlxText;
	var infoDescText:FlxText;
	var infoArtistText:FlxText;
	var infoCategoryText:FlxText;
	var infoDateText:FlxText;
	var infoTypeText:FlxText;
	var infoFavText:FlxText;
	var infoTextGroup:Array<FlxText> = [];

	var slideshowTimer:FlxTimer;
	var slideshowInterval:Float = 3.0;
	var slideshowActive:Bool = false;

	#if mobile
	var galleryPad:TouchPad;

	var touchStartX:Float = 0;
	var touchStartY:Float = 0;
	var isTouching:Bool = false;
	var swipeThreshold:Float = 50;
	var pinchStartDist:Float = 0;
	var isPinching:Bool = false;
	#end

	var fontPath:String;
	var accentColor:FlxColor = FlxColor.fromRGB(80, 160, 255);
	var bgDark:FlxColor = FlxColor.fromRGB(18, 18, 24);
	var bgMedium:FlxColor = FlxColor.fromRGB(28, 28, 38);
	var textDim:FlxColor = FlxColor.fromRGB(140, 140, 160);
	var textBright:FlxColor = FlxColor.fromRGB(240, 240, 250);

	override function create() {
		#if DISCORD_ALLOWED
		DiscordClient.changePresence(phrase("discord_gallery_browsing", "Galeriyi İnceliyor"), null);
		#end

		fontPath = Paths.font("vcr.ttf");

		loadModGalleryItems();

		buildCategories();
		filteredItems = galleryItems.copy();

		bg = new FlxSprite().makeGraphic(FlxG.width + 100, FlxG.height + 100, bgDark);
		bg.screenCenter();
		bg.scrollFactor.set(0, 0);
		add(bg);

		bgAccent = new FlxSprite().makeGraphic(FlxG.width, 3, accentColor);
		bgAccent.scrollFactor.set(0, 0);
		bgAccent.y = 0;
		bgAccent.alpha = 0.8;
		add(bgAccent);

		topBar = new FlxSprite().makeGraphic(FlxG.width, 50, FlxColor.fromRGB(12, 12, 18));
		topBar.scrollFactor.set(0, 0);
		topBar.y = 3;
		topBar.alpha = 0.9;
		add(topBar);

		bottomBar = new FlxSprite().makeGraphic(FlxG.width, 130, FlxColor.fromRGB(12, 12, 18));
		bottomBar.scrollFactor.set(0, 0);
		bottomBar.y = FlxG.height - 130;
		bottomBar.alpha = 0.85;
		add(bottomBar);

		separator = new FlxSprite().makeGraphic(FlxG.width - 80, 1, accentColor);
		separator.scrollFactor.set(0, 0);
		separator.screenCenter(X);
		separator.y = FlxG.height - 130;
		separator.alpha = 0.4;
		add(separator);

		gridThumbnails = new FlxTypedGroup<FlxSprite>();
		add(gridThumbnails);

		img = new FlxSprite();
		img.scrollFactor.set(0, 0);
		img.antialiasing = ClientPrefs.data.antialiasing;
		img.visible = false;
		add(img);

		graphic = new FlxSprite();
		graphic.scrollFactor.set(0, 0);
		graphic.antialiasing = ClientPrefs.data.antialiasing;
		graphic.visible = false;
		add(graphic);

		overlayDark = new FlxSprite().makeGraphic(FlxG.width + 100, FlxG.height + 100, FlxColor.BLACK);
		overlayDark.screenCenter();
		overlayDark.scrollFactor.set(0, 0);
		overlayDark.alpha = 0;
		add(overlayDark);

		categoryText = new FlxText(20, 12, 300, "");
		categoryText.setFormat(fontPath, 20, accentColor, LEFT);
		categoryText.scrollFactor.set(0, 0);
		categoryText.alpha = 0;
		add(categoryText);

		pageDisplay = new FlxText(0, 12, FlxG.width - 20, "");
		pageDisplay.setFormat(fontPath, 20, textDim, RIGHT);
		pageDisplay.scrollFactor.set(0, 0);
		pageDisplay.alpha = 0;
		add(pageDisplay);

		titleG = new FlxText(40, FlxG.height - 120, FlxG.width - 80, "");
		titleG.setFormat(fontPath, 28, textBright, LEFT);
		titleG.scrollFactor.set(0, 0);
		titleG.alpha = 0;
		add(titleG);

		artistText = new FlxText(40, FlxG.height - 90, FlxG.width - 80, "");
		artistText.setFormat(fontPath, 18, accentColor, LEFT);
		artistText.scrollFactor.set(0, 0);
		artistText.alpha = 0;
		add(artistText);

		descG = new FlxText(40, FlxG.height - 68, FlxG.width - 400, "");
		descG.setFormat(fontPath, 16, textDim, LEFT);
		descG.scrollFactor.set(0, 0);
		descG.alpha = 0;
		add(descG);

		typeText = new FlxText(0, FlxG.height - 40, FlxG.width - 40, "");
		typeText.setFormat(fontPath, 14, FlxColor.fromRGB(100, 100, 120), RIGHT);
		typeText.scrollFactor.set(0, 0);
		typeText.alpha = 0;
		add(typeText);

		instDisplay = new FlxText(15, 60, 280, "");
		instDisplay.setFormat(fontPath, 13, FlxColor.fromRGB(80, 80, 100), LEFT);
		instDisplay.scrollFactor.set(0, 0);
		instDisplay.alpha = 0;
		add(instDisplay);

		createInfoPanel();
		createAudioPlayer();

		#if mobile
		createMobileControls();
		#end

		switchToGridView();
		updateInstructions();
		refreshCategoryText();

		FlxTween.tween(categoryText, {alpha: 1}, 0.5, {ease: FlxEase.sineOut, startDelay: 0.1});
		FlxTween.tween(titleG, {alpha: 1}, 0.5, {ease: FlxEase.sineOut, startDelay: 0.15});
		FlxTween.tween(artistText, {alpha: 1}, 0.5, {ease: FlxEase.sineOut, startDelay: 0.2});
		FlxTween.tween(descG, {alpha: 1}, 0.5, {ease: FlxEase.sineOut, startDelay: 0.25});
		FlxTween.tween(typeText, {alpha: 1}, 0.5, {ease: FlxEase.sineOut, startDelay: 0.3});
		FlxTween.tween(pageDisplay, {alpha: 1}, 0.5, {ease: FlxEase.sineOut, startDelay: 0.35});
		FlxTween.tween(instDisplay, {alpha: 1}, 0.5, {
			ease: FlxEase.sineOut,
			startDelay: 0.4,
			onComplete: function(twn:FlxTween) { disableInput = false; }
		});

		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.5);

		super.create();
	}

	function loadModGalleryItems() {
		#if MODS_ALLOWED
		var modsPath:String = "mods/";

		if (!FileSystem.exists(modsPath)) return;

		for (modFolder in FileSystem.readDirectory(modsPath)) {
			var modDir:String = modsPath + modFolder + "/";
			if (!FileSystem.isDirectory(modDir)) continue;

			var galleryJsonPath:String = modDir + "other/gallery.json";
			if (!FileSystem.exists(galleryJsonPath)) continue;

			try {
				var rawJson:String = File.getContent(galleryJsonPath);
				var parsed:Array<Dynamic> = Json.parse(rawJson);

				if (parsed == null) continue;

				for (entry in parsed) {
					var item:GalleryItem = {
						fileName: entry.fileName != null ? entry.fileName : "",
						title: entry.title != null ? entry.title : "???",
						description: entry.description != null ? entry.description : "",
						type: parseGalleryType(entry.type),
						category: entry.category != null ? entry.category : "Mods",
						artist: entry.artist != null ? entry.artist : "",
						unlocked: entry.unlocked != null ? entry.unlocked : true,
						favorited: entry.favorited != null ? entry.favorited : false,
						dateAdded: entry.dateAdded != null ? entry.dateAdded : "",
						modDirectory: modFolder
					};

					if (item.fileName.length > 0 && validateModAsset(item, modDir)) {
						galleryItems.push(item);
					}
				}
			} catch (e) {
				trace('[GalleryState] Mod gallery JSON hatasi ($modFolder): $e');
			}
		}
		#end
	}

	function validateModAsset(item:GalleryItem, modDir:String):Bool {
		#if MODS_ALLOWED
		switch (item.type) {
			case IMAGE | ANIMATED:
				return FileSystem.exists(modDir + "images/gallery/" + item.fileName + ".png");
			case VIDEO:
				var mp4 = modDir + "videos/gallery/" + item.fileName + ".mp4";
				var webm = modDir + "videos/gallery/" + item.fileName + ".webm";
				return FileSystem.exists(mp4) || FileSystem.exists(webm);
			case SOUND_EFFECT:
				return FileSystem.exists(modDir + "sounds/gallery/" + item.fileName + ".ogg");
			case MUSIC:
				return FileSystem.exists(modDir + "music/gallery/" + item.fileName + ".ogg");
		}
		#end
		return false;
	}

	function parseGalleryType(typeStr:Dynamic):GalleryType {
		if (typeStr == null) return IMAGE;
		var s:String = Std.string(typeStr).toUpperCase();
		return switch (s) {
			case "IMAGE": IMAGE;
			case "VIDEO": VIDEO;
			case "SOUND_EFFECT" | "SFX": SOUND_EFFECT;
			case "MUSIC": MUSIC;
			case "ANIMATED" | "ANIMATION": ANIMATED;
			default: IMAGE;
		};
	}

	function getItemImagePath(item:GalleryItem):Dynamic {
		if (item.modDirectory != null && item.modDirectory.length > 0) {
			#if MODS_ALLOWED
			var modPath:String = "mods/" + item.modDirectory + "/images/gallery/" + item.fileName + ".png";
			if (FileSystem.exists(modPath)) {
				return openfl.display.BitmapData.fromFile(modPath);
			}
			#end
		}
		return Paths.image("gallery/img/" + item.fileName);
	}

	function getItemSoundPath(item:GalleryItem):Dynamic {
		if (item.modDirectory != null && item.modDirectory.length > 0) {
			#if MODS_ALLOWED
			var soundPath:String = "mods/" + item.modDirectory + "/sounds/gallery/" + item.fileName + ".ogg";
			if (FileSystem.exists(soundPath)) {
				return soundPath;
			}
			#end
		}
		return Paths.sound('gallery/' + item.fileName);
	}

	function getItemMusicPath(item:GalleryItem):Dynamic {
		if (item.modDirectory != null && item.modDirectory.length > 0) {
			#if MODS_ALLOWED
			var musicPath:String = "mods/" + item.modDirectory + "/music/gallery/" + item.fileName + ".ogg";
			if (FileSystem.exists(musicPath)) {
				return musicPath;
			}
			#end
		}
		return Paths.music('gallery/' + item.fileName);
	}

	function getItemVideoPath(item:GalleryItem):String {
		if (item.modDirectory != null && item.modDirectory.length > 0) {
			#if MODS_ALLOWED
			var mp4Path:String = "mods/" + item.modDirectory + "/videos/gallery/" + item.fileName + ".mp4";
			if (FileSystem.exists(mp4Path)) return mp4Path;
			var webmPath:String = "mods/" + item.modDirectory + "/videos/gallery/" + item.fileName + ".webm";
			if (FileSystem.exists(webmPath)) return webmPath;
			#end
		}
		return Paths.video('gallery/' + item.fileName);
	}
	
	function cancelGridIntroTweens() {
		for (t in gridIntroTweens) {
			if (t != null) t.cancel();
		}
		gridIntroTweens = [];
	}

	function cancelImageIntroTween() {
		if (imageIntroTween != null) {
			imageIntroTween.cancel();
			imageIntroTween = null;
		}
	}

	function createInfoPanel() {
		infoBG = new FlxSprite(FlxG.width - 310, 58).makeGraphic(300, 290, FlxColor.fromRGB(16, 16, 22));
		infoBG.scrollFactor.set(0, 0);
		infoBG.alpha = 0;
		add(infoBG);

		var px:Float = FlxG.width - 300;
		var py:Float = 68;
		var lh:Float = 28;

		infoTitleText = makeInfoText(px, py, 20, accentColor);
		infoDescText = makeInfoText(px, py + lh * 1.5, 14, textDim);
		infoArtistText = makeInfoText(px, py + lh * 4, 15, FlxColor.fromRGB(160, 200, 255));
		infoCategoryText = makeInfoText(px, py + lh * 5, 15, FlxColor.fromRGB(160, 230, 160));
		infoTypeText = makeInfoText(px, py + lh * 6, 15, FlxColor.fromRGB(230, 190, 100));
		infoDateText = makeInfoText(px, py + lh * 7, 15, FlxColor.fromRGB(160, 160, 170));
		infoFavText = makeInfoText(px, py + lh * 8, 15, FlxColor.fromRGB(255, 220, 80));

		infoTextGroup = [infoTitleText, infoDescText, infoArtistText, infoCategoryText, infoTypeText, infoDateText, infoFavText];
	}

	function makeInfoText(x:Float, y:Float, size:Int, color:FlxColor):FlxText {
		var t = new FlxText(x, y, 280, "");
		t.setFormat(fontPath, size, color, LEFT);
		t.scrollFactor.set(0, 0);
		t.alpha = 0;
		add(t);
		return t;
	}

	function createAudioPlayer() {
		var barY = FlxG.height - 175;

		audioProgressBar = new FlxSprite(FlxG.width / 2 - 180, barY).makeGraphic(360, 4, FlxColor.fromRGB(40, 40, 50));
		audioProgressBar.scrollFactor.set(0, 0);
		audioProgressBar.visible = false;
		add(audioProgressBar);

		audioProgressFill = new FlxSprite(audioProgressBar.x, barY).makeGraphic(1, 4, accentColor);
		audioProgressFill.scrollFactor.set(0, 0);
		audioProgressFill.visible = false;
		add(audioProgressFill);

		audioTimeText = new FlxText(0, barY - 20, FlxG.width, "0:00 / 0:00");
		audioTimeText.setFormat(fontPath, 16, textDim, CENTER);
		audioTimeText.scrollFactor.set(0, 0);
		audioTimeText.visible = false;
		add(audioTimeText);

		audioTitleText = new FlxText(0, barY - 42, FlxG.width, "");
		audioTitleText.setFormat(fontPath, 18, accentColor, CENTER);
		audioTitleText.scrollFactor.set(0, 0);
		audioTitleText.visible = false;
		add(audioTitleText);
	}

	#if mobile
	function createMobileControls() {
		galleryPad = new TouchPad('LEFT_FULL', 'NONE', NONE);

		var rightBaseX:Float = FlxG.width - 132;
		var rightBaseY:Float = FlxG.height - 137;
		var btnSpacing:Float = 132;

		// Yeni MobilePad dokuları: Q→Y yakın, E→Z uzak, R→D döndür, P→V bilgi
		galleryPad.buttonA = createGalleryButton(rightBaseX, rightBaseY, 'a', 0xFF00FF00, [MobileInputID.A], 'A');
		galleryPad.add(galleryPad.buttonA);

		galleryPad.buttonB = createGalleryButton(rightBaseX - btnSpacing, rightBaseY, 'b', 0xFFFF0000, [MobileInputID.B], 'B');
		galleryPad.add(galleryPad.buttonB);

		galleryPad.buttonC = createGalleryButton(rightBaseX, rightBaseY - btnSpacing, 'c', 0xFFFFCC00, [MobileInputID.C], 'C');
		galleryPad.add(galleryPad.buttonC);

		galleryPad.buttonX = createGalleryButton(rightBaseX - btnSpacing, rightBaseY - btnSpacing, 'x', 0xFFA020F0, [MobileInputID.X], 'X');
		galleryPad.add(galleryPad.buttonX);

		galleryPad.buttonP = createGalleryButton(rightBaseX, rightBaseY - btnSpacing * 2, 'v', 0xFF0088FF, [MobileInputID.P], 'P');
		galleryPad.add(galleryPad.buttonP);

		galleryPad.buttonE = createGalleryButton(rightBaseX - btnSpacing, rightBaseY - btnSpacing * 2, 'z', 0xFFFF4444, [MobileInputID.E], 'E');
		galleryPad.add(galleryPad.buttonE);

		galleryPad.buttonQ = createGalleryButton(rightBaseX - btnSpacing * 2, rightBaseY - btnSpacing * 2, 'y', 0xFF44FF44, [MobileInputID.Q], 'Q');
		galleryPad.add(galleryPad.buttonQ);

		galleryPad.buttonR = createGalleryButton(rightBaseX - btnSpacing * 2, rightBaseY - btnSpacing, 'd', 0xFFFFAA00, [MobileInputID.R], 'R');
		galleryPad.add(galleryPad.buttonR);

		galleryPad.alpha = ClientPrefs.data.controlsAlpha;
		galleryPad.updateTrackedButtons();
		add(galleryPad);

		// Input yalnız handleMobileInput'tan gider.
		// onButtonDown + justPressed birlikte bilgi/favori/A'yı aynı karede iki kez toggle eder.

		updateMobileButtonVisibility();
	}

	function createGalleryButton(x:Float, y:Float, graphicName:String, color:FlxColor, ids:Array<MobileInputID>, ?logicTag:String):TouchButton {
		var button = new TouchButton(x, y, ids);
		var idStrs:Array<String> = [];
		if (ids != null) {
			for (id in ids) idStrs.push(id.toString());
		}
		button.IDs = idStrs;

		var frames:FlxGraphic;
		var path:String = MobileConfig.mobileFolderPath + 'MobilePad/Textures/$graphicName.png';
		var fallback:String = MobileConfig.mobileFolderPath + 'MobilePad/Textures/default.png';
		if (Assets.exists(path))
			frames = FlxGraphic.fromBitmapData(Assets.getBitmapData(path));
		else
			frames = FlxGraphic.fromBitmapData(Assets.getBitmapData(fallback));

		button.scale.set(0.9, 0.9);
		button.frames = FlxTileFrames.fromGraphic(frames, FlxPoint.get(Std.int(frames.width / 2), frames.height));
		button.updateHitbox();
		button.updateLabelPosition();

		button.statusBrightness = [1, 0.8, 0.4];
		button.statusIndicatorType = BRIGHTNESS;
		button.status = TouchButton.NORMAL;

		button.bounds.makeGraphic(Std.int(Math.max(8, button.width - 50)), Std.int(Math.max(8, button.height - 50)), FlxColor.TRANSPARENT);
		button.centerBounds();

		button.immovable = true;
		button.solid = false;
		button.moves = false;
		button.antialiasing = ClientPrefs.data.antialiasing;
		button.tag = (logicTag != null && logicTag.length > 0) ? logicTag : graphicName.toUpperCase();
		if (color != -1) button.color = color;
		button.parentAlpha = button.alpha;

		return button;
	}

	function createTouchButton(x:Float, y:Float, graphicName:String, color:FlxColor, ids:Array<MobileInputID>):TouchButton {
		return createGalleryButton(x, y, graphicName, color, ids);
	}

	function updateMobileButtonVisibility() {
		if (galleryPad == null) return;

		var inImageView = (viewMode == SINGLE_VIEW || viewMode == FULLSCREEN);
		var inVideoView = (viewMode == VIDEO_PLAYING);

		galleryPad.visible = !inVideoView;

		var showImageBtns = inImageView;
		if (showImageBtns && filteredItems.length > 0) {
			var item = filteredItems[curSelected];
			showImageBtns = (item.type == IMAGE || item.type == ANIMATED);
		}

		if (galleryPad.buttonQ != null) galleryPad.buttonQ.visible = showImageBtns;
		if (galleryPad.buttonE != null) galleryPad.buttonE.visible = showImageBtns;
		if (galleryPad.buttonR != null) galleryPad.buttonR.visible = showImageBtns;
		// X (kategori) yalnızca grid'de işe yarar — diğer görünümlerde gizle
		if (galleryPad.buttonX != null) galleryPad.buttonX.visible = (viewMode == GALLERY_GRID);
	}

	function onMobileButtonA():Void {
		if (filteredItems.length > 0) {
			FlxG.sound.play(Paths.sound('confirmMenu'));
			var item = filteredItems[curSelected];

			if (viewMode == GALLERY_GRID) {
				switch (item.type) {
					case VIDEO: playVideo(item);
					case SOUND_EFFECT | MUSIC: switchToSingleView(); playAudio(item);
					default: switchToSingleView();
				}
			} else if (viewMode == SINGLE_VIEW) {
				if (item.type == SOUND_EFFECT || item.type == MUSIC)
					playAudio(item);
				else if (item.type == IMAGE || item.type == ANIMATED)
					switchToFullscreen();
			} else if (viewMode == FULLSCREEN) {
				exitFullscreen();
			}
		}
	}

	function onMobileButtonB():Void {
		FlxG.sound.play(Paths.sound('cancelMenu'));
		stopAllMedia();
		if (viewMode == SINGLE_VIEW || viewMode == FULLSCREEN || viewMode == SLIDESHOW) {
			switchToGridView();
		} else {
			MenuStyleRouter.goToMainMenu();
		}
	}

	function onMobileButtonC():Void {
		if (filteredItems.length > 0) {
			filteredItems[curSelected].favorited = !filteredItems[curSelected].favorited;
			FlxG.sound.play(Paths.sound('confirmMenu'));
			updateTexts();
			if (showingInfo) updateInfoPanel();
		}
	}

	function onMobileButtonX():Void {
		// Kategori değiştirme yalnızca grid görünümünde; tek görünümde
		// boş kategoriye (ör. Favorites) geçip listeyi boşaltıyordu →
		// slideshow açılınca "Mod by 0" çökmesi.
		if (viewMode != GALLERY_GRID) { FlxG.sound.play(Paths.sound('scrollMenu')); return; }
		cycleCategory(1);
	}

	/** Boş kategorileri atlayarak kategori değiştirir. */
	function cycleCategory(dir:Int):Void {
		if (categories.length <= 1) return;
		var tries = 0;
		var idx = currentCategory;
		do {
			idx = (idx + dir + categories.length) % categories.length;
			tries++;
			var count:Int = 0;
			var cat = categories[idx];
			if (cat == "All") count = galleryItems.length;
			else if (cat == "Favorites") {
				for (i in galleryItems) if (i.favorited == true) count++;
			} else {
				for (i in galleryItems) if (i.category == cat) count++;
			}
			if (count > 0) break;
		} while (tries < categories.length);
		if (tries >= categories.length) return; // dolu kategori yok, dokunma
		currentCategory = idx;
		filterByCategory();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function onMobileButtonP():Void {
		if (viewMode == GALLERY_GRID) {
			showingInfo = !showingInfo;
			toggleInfoPanel(showingInfo);
		} else if (viewMode == SINGLE_VIEW || viewMode == FULLSCREEN) {
			var item = filteredItems.length > 0 ? filteredItems[curSelected] : null;
			if (item != null && (item.type == SOUND_EFFECT || item.type == MUSIC)) {
				toggleAudioPause();
			} else {
				toggleSlideshow();
			}
		} else if (viewMode == SLIDESHOW) {
			stopSlideshow();
			switchToSingleView();
		}
	}

	function onMobileButtonQ():Void {
		if (viewMode == SINGLE_VIEW || viewMode == FULLSCREEN) {
			imgZoom = Math.min(maxZoom, imgZoom + zoomStep);
			updateImageTransform();
		}
	}

	function onMobileButtonE():Void {
		if (viewMode == SINGLE_VIEW || viewMode == FULLSCREEN) {
			imgZoom = Math.max(minZoom, imgZoom - zoomStep);
			updateImageTransform();
		}
	}

	function onMobileButtonR():Void {
		if (viewMode == SINGLE_VIEW || viewMode == FULLSCREEN) {
			imgRotation += 90;
			updateImageTransform();
		}
	}

	function handleMobileInput(elapsed:Float) {
		if (galleryPad == null) return;

		if (galleryPad.buttonB != null && galleryPad.buttonB.justPressed) {
			onMobileButtonB();
			return;
		}

		if (galleryPad.buttonA != null && galleryPad.buttonA.justPressed) {
			onMobileButtonA();
		}

		if (galleryPad.buttonC != null && galleryPad.buttonC.justPressed) {
			onMobileButtonC();
		}

		if (galleryPad.buttonX != null && galleryPad.buttonX.justPressed) {
			onMobileButtonX();
		}

		if (galleryPad.buttonP != null && galleryPad.buttonP.justPressed) {
			onMobileButtonP();
		}

		if (galleryPad.buttonQ != null && galleryPad.buttonQ.pressed) {
			onMobileButtonQ();
		}

		if (galleryPad.buttonE != null && galleryPad.buttonE.pressed) {
			onMobileButtonE();
		}

		if (galleryPad.buttonR != null && galleryPad.buttonR.justPressed) {
			onMobileButtonR();
		}

		switch (viewMode) {
			case GALLERY_GRID:
				handleMobileGridNav();
			case SINGLE_VIEW | SLIDESHOW:
				handleMobileSingleNav(elapsed);
			case FULLSCREEN:
				handleMobileFullscreenNav(elapsed);
			case VIDEO_PLAYING:
			default:
		}

		handlePinchZoom();
	}

	function handleMobileGridNav() {
		var changed = false;
		var perPage = gridColumns * gridRows;

		if (galleryPad.buttonLeft.justPressed) { curSelected--; changed = true; }
		if (galleryPad.buttonRight.justPressed) { curSelected++; changed = true; }
		if (galleryPad.buttonUp.justPressed) { curSelected -= gridColumns; changed = true; }
		if (galleryPad.buttonDown.justPressed) { curSelected += gridColumns; changed = true; }

		if (changed) {
			curSelected = Std.int(Math.max(0, Math.min(curSelected, filteredItems.length - 1)));
			var newPage = Math.floor(curSelected / perPage);
			if (newPage != gridPage) { gridPage = newPage; buildGrid(); }
			updateGridSelection();
			updateTexts();
			if (showingInfo) updateInfoPanel();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
	}

	function handleMobileSingleNav(elapsed:Float) {
		if (galleryPad.buttonLeft.justPressed) changeItem(-1);
		if (galleryPad.buttonRight.justPressed) changeItem(1);

		if (filteredItems.length > 0) {
			var item = filteredItems[curSelected];
			if (item.type == IMAGE || item.type == ANIMATED) {
				if (galleryPad.buttonUp.pressed) { imgOffsetY -= panSpeed; updateImageTransform(); }
				if (galleryPad.buttonDown.pressed) { imgOffsetY += panSpeed; updateImageTransform(); }
			}
		}
	}

	function handleMobileFullscreenNav(elapsed:Float) {
		if (galleryPad.buttonUp.pressed) { imgOffsetY -= panSpeed; updateImageTransform(); }
		if (galleryPad.buttonDown.pressed) { imgOffsetY += panSpeed; updateImageTransform(); }
		if (galleryPad.buttonLeft.pressed) { imgOffsetX -= panSpeed; updateImageTransform(); }
		if (galleryPad.buttonRight.pressed) { imgOffsetX += panSpeed; updateImageTransform(); }
	}

	function handlePinchZoom() {
		var touches = FlxG.touches.list;

		if (touches.length >= 2 && (viewMode == SINGLE_VIEW || viewMode == FULLSCREEN)) {
			var t1 = touches[0];
			var t2 = touches[1];
			var currentDist = Math.sqrt(
				Math.pow(t1.screenX - t2.screenX, 2) + Math.pow(t1.screenY - t2.screenY, 2)
			);

			if (!isPinching) {
				pinchStartDist = currentDist;
				isPinching = true;
			} else {
				var scale = currentDist / pinchStartDist;
				imgZoom = Math.max(minZoom, Math.min(maxZoom, imgZoom * scale));
				pinchStartDist = currentDist;
				updateImageTransform();
			}
		} else {
			isPinching = false;
		}
	}
	#end

	override function update(elapsed:Float) {
		if (daSound != null && daSound.playing)
			updateAudioProgress();

		if (!disableInput) {
			handleInput(elapsed);
			#if mobile
			handleMobileInput(elapsed);
			#end
		}

		if ((viewMode == SINGLE_VIEW || viewMode == FULLSCREEN) && img.visible && smoothPan) {
			img.x = backend.FrameUtil.damp(img.x, targetX, 10, elapsed);
			img.y = backend.FrameUtil.damp(img.y, targetY, 10, elapsed);
		}

		super.update(elapsed);
	}

	function handleInput(elapsed:Float) {
		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			stopAllMedia();
			if (viewMode == SINGLE_VIEW || viewMode == FULLSCREEN || viewMode == SLIDESHOW) {
				switchToGridView();
				return;
			}
			MenuStyleRouter.goToMainMenu();
			return;
		}

		if (FlxG.keys.justPressed.X) {
			textVisible = !textVisible;
			var a:Float = textVisible ? 1 : 0;
			for (t in [instDisplay, titleG, artistText, descG, typeText, pageDisplay, categoryText])
				FlxTween.tween(t, {alpha: a}, 0.25, {ease: FlxEase.sineOut});
		}

		if (FlxG.keys.justPressed.TAB) {
			// Masaüstü TAB da aynı kural: yalnızca grid'de, boş kategorileri atla
			if (viewMode == GALLERY_GRID) cycleCategory(1);
			else FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		if (FlxG.keys.justPressed.F && filteredItems.length > 0) {
			filteredItems[curSelected].favorited = !filteredItems[curSelected].favorited;
			FlxG.sound.play(Paths.sound('confirmMenu'));
			updateTexts();
			if (showingInfo) updateInfoPanel();
		}

		if (FlxG.keys.justPressed.I) {
			showingInfo = !showingInfo;
			toggleInfoPanel(showingInfo);
		}

		if (FlxG.keys.justPressed.P && viewMode != VIDEO_PLAYING)
			toggleSlideshow();

		switch (viewMode) {
			case GALLERY_GRID: handleGridInput(elapsed);
			case SINGLE_VIEW: handleSingleViewInput(elapsed);
			case FULLSCREEN: handleFullscreenInput(elapsed);
			case VIDEO_PLAYING: handleVideoInput(elapsed);
			case SLIDESHOW: handleSlideshowInput(elapsed);
		}
	}

	function handleGridInput(elapsed:Float) {
		var changed = false;
		var perPage = gridColumns * gridRows;

		if (controls.UI_LEFT_P) { curSelected--; changed = true; }
		if (controls.UI_RIGHT_P) { curSelected++; changed = true; }
		if (controls.UI_UP_P) { curSelected -= gridColumns; changed = true; }
		if (controls.UI_DOWN_P) { curSelected += gridColumns; changed = true; }
		if (FlxG.keys.justPressed.PAGEUP) { curSelected -= perPage; changed = true; }
		if (FlxG.keys.justPressed.PAGEDOWN) { curSelected += perPage; changed = true; }
		if (FlxG.keys.justPressed.HOME) { curSelected = 0; changed = true; }
		if (FlxG.keys.justPressed.END) { curSelected = filteredItems.length - 1; changed = true; }

		if (changed) {
			curSelected = Std.int(Math.max(0, Math.min(curSelected, filteredItems.length - 1)));
			var newPage = Math.floor(curSelected / perPage);
			if (newPage != gridPage) { gridPage = newPage; buildGrid(); }
			updateGridSelection();
			updateTexts();
			if (showingInfo) updateInfoPanel();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		if (controls.ACCEPT && filteredItems.length > 0) {
			FlxG.sound.play(Paths.sound('confirmMenu'));
			var item = filteredItems[curSelected];
			switch (item.type) {
				case VIDEO: playVideo(item);
				case SOUND_EFFECT | MUSIC: switchToSingleView(); playAudio(item);
				default: switchToSingleView();
			}
		}
	}

	function switchToGridView() {
		viewMode = GALLERY_GRID;
		img.visible = false;
		graphic.visible = false;
		isPanning = false;
		hideAudioPlayer();
		stopSlideshow();
		gridThumbnails.visible = true;

		FlxTween.tween(overlayDark, {alpha: 0}, 0.25);
		restoreHUD();
		buildGrid();
		updateGridSelection();
		updateTexts();
		updateInstructions();
		refreshCategoryText();

		#if mobile
		updateMobileButtonVisibility();
		#end
	}

	function buildGrid() {
		cancelGridIntroTweens();
		gridBuildToken++;

		gridThumbnails.forEachAlive(function(spr:FlxSprite) {
			FlxTween.cancelTweensOf(spr);
			spr.kill();
		});
		gridThumbnails.clear();

		var perPage = gridColumns * gridRows;
		var startIdx = gridPage * perPage;
		var mx:Float = 50;
		var my:Float = 60;
		var gap:Float = 12;
		var tw:Float = (FlxG.width - mx * 2 - (gridColumns - 1) * gap) / gridColumns;
		var th:Float = (FlxG.height - my - 145 - (gridRows - 1) * gap) / gridRows;

		for (i in 0...perPage) {
			var idx = startIdx + i;
			if (idx >= filteredItems.length) break;

			var item = filteredItems[idx];
			var col = i % gridColumns;
			var row = Math.floor(i / gridColumns);

			var thumb = new FlxSprite();
			try {
				var imgData = getItemImagePath(item);
				if (Std.isOfType(imgData, openfl.display.BitmapData)) {
					thumb.loadGraphic(cast imgData);
				} else {
					thumb.loadGraphic(imgData);
				}
			} catch (e) {
				thumb.makeGraphic(Std.int(tw), Std.int(th), bgMedium);
			}

			var sx = tw / thumb.width;
			var sy = th / thumb.height;
			var fs = Math.min(sx, sy);
			thumb.scale.set(fs, fs);
			thumb.updateHitbox();
			thumb.x = mx + col * (tw + gap) + (tw - thumb.width) / 2;
			thumb.y = my + row * (th + gap) + (th - thumb.height) / 2;
			thumb.scrollFactor.set(0, 0);
			thumb.antialiasing = ClientPrefs.data.antialiasing;
			thumb.ID = idx;

			if (item.unlocked != null && !item.unlocked)
				thumb.color = FlxColor.fromRGB(20, 20, 25);

			thumb.alpha = 0;
			var ss = fs * 0.6;
			thumb.scale.set(ss, ss);

			var thisGridToken = gridBuildToken;
			var thumbRef = thumb;

			var introTween = FlxTween.num(0, 1, 0.35, {ease: FlxEase.quintOut, startDelay: i * 0.04}, function(v:Float) {
				if (thisGridToken != gridBuildToken) return;
				if (thumbRef == null || !thumbRef.exists) return;
				if (!gridThumbnails.members.contains(thumbRef)) return;

				var s = ss + (fs - ss) * v;
				thumbRef.scale.set(s, s);
				thumbRef.alpha = v;
				thumbRef.updateHitbox();
			});

			gridIntroTweens.push(introTween);

			gridThumbnails.add(thumb);
		}
	}

	function updateGridSelection() {
		if (filteredItems.length == 0) return;

		gridThumbnails.forEachAlive(function(spr:FlxSprite) {
			FlxTween.cancelTweensOf(spr);
			if (spr.ID == curSelected) {
				FlxTween.color(spr, 0.15, spr.color, FlxColor.WHITE);
			} else {
				var item = filteredItems[spr.ID];
				var c = (item.unlocked != null && !item.unlocked) ? FlxColor.fromRGB(20, 20, 25) : FlxColor.fromRGB(120, 120, 130);
				FlxTween.color(spr, 0.15, spr.color, c);
			}
		});
	}
	
	/* KlavyeSubState yönlendirmesi kapalı
	function openKlavyeSubState() {
		#if ACHIEVEMENTS_ALLOWED
		Achievements.load();
		if (!Achievements.isUnlocked('keyboard')) {
			Achievements.unlock('keyboard');
		}
		#end

		persistentUpdate = false;
		persistentDraw = true;
		openSubState(new KlavyeSubState());
	}
	*/

	function handleSingleViewInput(elapsed:Float) {
		// 4x R → KlavyeSubState sayacı kapalı
		if (filteredItems.length == 0) return;
		var item = filteredItems[curSelected];

		if (!isPanning) {
			if (controls.UI_LEFT_P) changeItem(-1);
			if (controls.UI_RIGHT_P) changeItem(1);
		}

		if (item.type == IMAGE || item.type == ANIMATED) {
			if (FlxG.keys.pressed.Q) imgZoom = Math.min(maxZoom, imgZoom + zoomStep);
			if (FlxG.keys.pressed.E) imgZoom = Math.max(minZoom, imgZoom - zoomStep);

			if (FlxG.keys.pressed.I || (FlxG.keys.pressed.UP && FlxG.keys.pressed.SHIFT)) {
				imgOffsetY -= panSpeed;
				isPanning = true;
			}
			if (FlxG.keys.pressed.K || (FlxG.keys.pressed.DOWN && FlxG.keys.pressed.SHIFT)) {
				imgOffsetY += panSpeed;
				isPanning = true;
			}
			if (FlxG.keys.pressed.J || (FlxG.keys.pressed.LEFT && FlxG.keys.pressed.SHIFT)) {
				imgOffsetX -= panSpeed;
				isPanning = true;
			}
			if (FlxG.keys.pressed.L || (FlxG.keys.pressed.RIGHT && FlxG.keys.pressed.SHIFT)) {
				imgOffsetX += panSpeed;
				isPanning = true;
			}

			if (!FlxG.keys.pressed.I && !FlxG.keys.pressed.K &&
				!FlxG.keys.pressed.J && !FlxG.keys.pressed.L &&
				!(FlxG.keys.pressed.SHIFT && (FlxG.keys.pressed.UP || FlxG.keys.pressed.DOWN || FlxG.keys.pressed.LEFT || FlxG.keys.pressed.RIGHT))) {
				isPanning = false;
			}

			if (FlxG.keys.justPressed.R) {
				imgRotation += 90;
				// 4x R + s1r3nmoney0 / klavye → KlavyeSubState kapalı
			}
			if (FlxG.keys.justPressed.T) imgRotation -= 90;
			if (FlxG.keys.justPressed.C) resetImageView();
			if (FlxG.keys.justPressed.SPACE) switchToFullscreen();
			updateImageTransform();
		}

		if (item.type == SOUND_EFFECT || item.type == MUSIC) {
			if (FlxG.keys.justPressed.SPACE) toggleAudioPause();
			if (controls.ACCEPT) playAudio(item);
		}
	}

	function switchToSingleView() {
		viewMode = SINGLE_VIEW;
		gridThumbnails.visible = false;
		img.visible = true;
		isPanning = false;
		resetImageView();
		loadCurrentItem();
		updateTexts();
		updateInstructions();
		refreshCategoryText();

		#if mobile
		updateMobileButtonVisibility();
		#end
	}

	function loadCurrentItem() {
		if (filteredItems.length == 0) return;
		var item = filteredItems[curSelected];

		try {
			var imgData = getItemImagePath(item);
			if (Std.isOfType(imgData, openfl.display.BitmapData)) {
				img.loadGraphic(cast imgData);
			} else {
				img.loadGraphic(imgData);
			}
		} catch (e) {
			img.makeGraphic(400, 300, bgMedium);
		}
		img.visible = true;
		img.alpha = 0;
		img.antialiasing = ClientPrefs.data.antialiasing;
		resetImageView();

		graphic.visible = false;
		switch (item.type) {
			case VIDEO:
				try { graphic.loadGraphic(Paths.image("gallery/videoGraphic")); graphic.visible = true; } catch (e) {}
			case SOUND_EFFECT | MUSIC:
				try { graphic.loadGraphic(Paths.image("gallery/audioGraphic")); graphic.visible = true; } catch (e) {}
			default:
		}
		if (graphic.visible) {
			graphic.screenCenter();
			graphic.scale.set(0.5, 0.5);
			graphic.alpha = 0.6;
		}

		FlxTween.cancelTweensOf(img);
		cancelImageIntroTween();
		imageTweenToken++;

		var thisImageToken = imageTweenToken;
		var imgRef = img;
		var sz = imgZoom * 1.08;
		img.scale.set(sz, sz);

		imageIntroTween = FlxTween.num(0, 1, 0.35, {ease: FlxEase.quintOut}, function(v:Float) {
			if (thisImageToken != imageTweenToken) return;
			if (imgRef == null || !imgRef.exists || !imgRef.visible) return;

			var s = sz + (imgZoom - sz) * v;
			imgRef.scale.set(s, s);
			imgRef.alpha = v;
			imgRef.updateHitbox();
			imgRef.screenCenter();
		});

		if (item.type == SOUND_EFFECT || item.type == MUSIC) showAudioPlayer();
		else hideAudioPlayer();
	}

	function resetImageView() {
		imgZoom = 0.8;
		imgOffsetX = 0;
		imgOffsetY = 0;
		imgRotation = 0;
		isPanning = false;
		if (img != null) {
			img.angle = 0;
			img.scale.set(imgZoom, imgZoom);
			img.updateHitbox();
			img.screenCenter();
			targetX = img.x;
			targetY = img.y;
		}
	}

	function updateImageTransform() {
		if (img == null) return;
		img.scale.set(imgZoom, imgZoom);
		img.angle = imgRotation;
		img.updateHitbox();
		targetX = (FlxG.width - img.width) / 2 + imgOffsetX;
		targetY = (FlxG.height - img.height) / 2 + imgOffsetY;
		if (!smoothPan) { img.x = targetX; img.y = targetY; }
	}

	function handleFullscreenInput(elapsed:Float) {
		if (FlxG.keys.pressed.Q) imgZoom = Math.min(maxZoom, imgZoom + zoomStep);
		if (FlxG.keys.pressed.E) imgZoom = Math.max(minZoom, imgZoom - zoomStep);

		if (FlxG.keys.pressed.I) imgOffsetY -= panSpeed;
		if (FlxG.keys.pressed.K) imgOffsetY += panSpeed;
		if (FlxG.keys.pressed.J) imgOffsetX -= panSpeed;
		if (FlxG.keys.pressed.L) imgOffsetX += panSpeed;

		if (FlxG.keys.justPressed.C) resetImageView();
		if (FlxG.keys.justPressed.R) imgRotation += 90;
		updateImageTransform();

		if (FlxG.keys.justPressed.SPACE || controls.BACK) exitFullscreen();
	}

	function switchToFullscreen() {
		viewMode = FULLSCREEN;
		FlxTween.tween(overlayDark, {alpha: 0.9}, 0.25);
		hideHUD();

		var sx = FlxG.width / img.frameWidth;
		var sy = FlxG.height / img.frameHeight;
		imgZoom = Math.min(sx, sy);
		imgOffsetX = 0;
		imgOffsetY = 0;
		img.scale.set(imgZoom, imgZoom);
		img.updateHitbox();
		img.screenCenter();
		targetX = img.x;
		targetY = img.y;
		updateInstructions();

		#if mobile
		updateMobileButtonVisibility();
		#end
	}

	function exitFullscreen() {
		viewMode = SINGLE_VIEW;
		FlxTween.tween(overlayDark, {alpha: 0}, 0.25);
		restoreHUD();
		resetImageView();
		updateInstructions();

		#if mobile
		updateMobileButtonVisibility();
		#end
	}

	function handleVideoInput(elapsed:Float) {
		#if VIDEOS_ALLOWED
		if (controls.BACK) {
			forceStopVideo();
			switchToGridView();
		}
		#end
	}

	function playVideo(item:GalleryItem) {
		#if VIDEOS_ALLOWED
		viewMode = VIDEO_PLAYING;
		isVideoPlaying = true;
		disableInput = true;

		if (FlxG.sound.music != null) FlxG.sound.music.pause();

		img.visible = false;
		graphic.visible = false;
		gridThumbnails.visible = false;
		hideAudioPlayer();
		hideHUD();
		bg.visible = false;
		bgAccent.visible = false;
		topBar.visible = false;
		bottomBar.visible = false;
		separator.visible = false;
		overlayDark.alpha = 0;

		#if mobile
		if (galleryPad != null) galleryPad.visible = false;
		#end

		if (showingInfo) toggleInfoPanel(false);

		var filepath = getItemVideoPath(item);
		videoObj = new VideoSprite(filepath, false, true, false);
		videoObj.finishCallback = function() { onVideoFinished(); };
		videoObj.onSkip = function() { onVideoFinished(); };
		add(videoObj);
		videoObj.play();

		new FlxTimer().start(0.5, function(tmr:FlxTimer) { disableInput = false; });
		#end
	}

	function onVideoFinished() {
		#if VIDEOS_ALLOWED
		isVideoPlaying = false;
		videoObj = null;
		restoreBackground();
		if (FlxG.sound.music != null) FlxG.sound.music.resume();
		switchToGridView();
		#end
	}

	function forceStopVideo() {
		#if VIDEOS_ALLOWED
		if (videoObj != null) {
			videoObj.finishCallback = null;
			videoObj.onSkip = null;
			videoObj.destroy();
			videoObj = null;
		}
		isVideoPlaying = false;
		restoreBackground();
		if (FlxG.sound.music != null) FlxG.sound.music.resume();
		#end
	}

	function restoreBackground() {
		bg.visible = true;
		bgAccent.visible = true;
		topBar.visible = true;
		bottomBar.visible = true;
		separator.visible = true;
	}

	function playAudio(item:GalleryItem) {
		stopAudio();
		if (FlxG.sound.music != null) FlxG.sound.music.pause();

		daSound = new FlxSound();
		switch (item.type) {
			case SOUND_EFFECT:
				var sndPath = getItemSoundPath(item);
				if (Std.isOfType(sndPath, String)) {
					#if sys
					daSound.loadEmbedded(sndPath, false, true);
					#end
				} else {
					daSound.loadEmbedded(sndPath, false, true);
				}
			case MUSIC:
				var musPath = getItemMusicPath(item);
				if (Std.isOfType(musPath, String)) {
					#if sys
					daSound.loadEmbedded(musPath, true, true);
					#end
				} else {
					daSound.loadEmbedded(musPath, true, true);
				}
			default: return;
		}
		daSound.onComplete = function():Void {
			audioPlaying = false;
			if (FlxG.sound.music != null) FlxG.sound.music.resume();
			hideAudioPlayer();
		};
		daSound.play(true, 0);
		audioPlaying = true;
		audioPaused = false;
		audioTitleText.text = '♫ ' + item.title + (item.artist != null ? ' — ' + item.artist : '');
		showAudioPlayer();
	}

	function stopAudio() {
		if (daSound != null) { daSound.stop(); daSound.destroy(); daSound = null; }
		audioPlaying = false;
		audioPaused = false;
		if (FlxG.sound.music != null) FlxG.sound.music.resume();
	}

	function toggleAudioPause() {
		if (daSound == null) return;
		if (audioPaused) { daSound.resume(); audioPaused = false; }
		else { daSound.pause(); audioPaused = true; }
	}

	function showAudioPlayer() {
		audioProgressBar.visible = true;
		audioProgressFill.visible = true;
		audioTimeText.visible = true;
		audioTitleText.visible = true;
	}

	function hideAudioPlayer() {
		audioProgressBar.visible = false;
		audioProgressFill.visible = false;
		audioTimeText.visible = false;
		audioTitleText.visible = false;
	}

	function updateAudioProgress() {
		if (daSound == null) return;
		var p:Float = (daSound.length > 0) ? daSound.time / daSound.length : 0;
		if (Math.isNaN(p)) p = 0;
		var bw = Std.int(360 * p);
		if (bw < 1) bw = 1;
		audioProgressFill.makeGraphic(bw, 4, accentColor);
		audioProgressFill.x = audioProgressBar.x;
		audioTimeText.text = formatTime(daSound.time / 1000) + " / " + formatTime(daSound.length / 1000)
			+ (audioPaused ? "  ||" : "  ▶");
	}

	function handleSlideshowInput(elapsed:Float) {
		if (controls.BACK || FlxG.keys.justPressed.P) { stopSlideshow(); switchToSingleView(); return; }
		if (controls.UI_RIGHT_P || controls.ACCEPT) slideshowNext();
		if (controls.UI_LEFT_P) slideshowPrev();
	}

	function toggleSlideshow() {
		if (slideshowActive) stopSlideshow();
		else startSlideshow();
	}

	function startSlideshow() {
		slideshowActive = true;
		if (viewMode != SINGLE_VIEW) switchToSingleView();
		viewMode = SLIDESHOW;
		updateInstructions();
		slideshowTimer = new FlxTimer().start(slideshowInterval, function(tmr:FlxTimer) { slideshowNext(); }, 0);
	}

	function stopSlideshow() {
		slideshowActive = false;
		if (slideshowTimer != null) { slideshowTimer.cancel(); slideshowTimer = null; }
		if (viewMode == SLIDESHOW) viewMode = SINGLE_VIEW;
		updateInstructions();
	}

	function slideshowNext() {
		// Boş listede modulo'ya bölme hatası (Mod by 0) çöküyordu
		if (filteredItems.length == 0) { stopSlideshow(); return; }
		var next = curSelected;
		var tries = 0;
		do { next = (next + 1) % filteredItems.length; tries++; }
		while (filteredItems[next].type != IMAGE && filteredItems[next].type != ANIMATED && tries < filteredItems.length);
		if (tries < filteredItems.length) { curSelected = next; loadCurrentItem(); updateTexts(); }
		if (slideshowTimer != null) {
			slideshowTimer.cancel();
			slideshowTimer = new FlxTimer().start(slideshowInterval, function(tmr:FlxTimer) { slideshowNext(); }, 0);
		}
	}

	function slideshowPrev() {
		if (filteredItems.length == 0) return;
		var prev = curSelected;
		var tries = 0;
		do { prev = (prev - 1 + filteredItems.length) % filteredItems.length; tries++; }
		while (filteredItems[prev].type != IMAGE && filteredItems[prev].type != ANIMATED && tries < filteredItems.length);
		if (tries < filteredItems.length) { curSelected = prev; loadCurrentItem(); updateTexts(); }
	}

	function buildCategories() {
		categories = ["All", "Favorites"];
		for (item in galleryItems) {
			if (item.category != null) {
				var found = false;
				for (cat in categories) if (cat == item.category) { found = true; break; }
				if (!found) categories.push(item.category);
			}
		}
	}

	function filterByCategory() {
		var cat = categories[currentCategory];
		if (cat == "All") {
			filteredItems = galleryItems.copy();
		} else if (cat == "Favorites") {
			filteredItems = [];
			for (item in galleryItems) if (item.favorited == true) filteredItems.push(item);
		} else {
			filteredItems = [];
			for (item in galleryItems) if (item.category == cat) filteredItems.push(item);
		}
		curSelected = 0;
		gridPage = 0;
		refreshCategoryText();
		if (viewMode == GALLERY_GRID) { buildGrid(); updateGridSelection(); }
		updateTexts();
	}

	function toggleInfoPanel(show:Bool) {
		showingInfo = show;
		FlxTween.tween(infoBG, {alpha: show ? 0.85 : 0}, 0.25, {ease: FlxEase.sineOut});
		for (txt in infoTextGroup)
			FlxTween.tween(txt, {alpha: show ? 1 : 0}, 0.25, {ease: FlxEase.sineOut});
		if (show) updateInfoPanel();
	}

	function updateInfoPanel() {
		if (filteredItems.length == 0) return;
		var item = filteredItems[curSelected];
		infoTitleText.text = item.title;
		infoDescText.text = item.description;
		infoArtistText.text = phrase("gallery_info_artist", "Sanatçı") + ": " + (item.artist != null ? item.artist : "—");
		infoCategoryText.text = phrase("gallery_info_category", "Kategori") + ": " + (item.category != null ? item.category : "—");
		infoTypeText.text = phrase("gallery_info_type", "Tür") + ": " + getTypeName(item.type);
		infoDateText.text = phrase("gallery_info_date", "Tarih") + ": " + (item.dateAdded != null ? item.dateAdded : "—");
		infoFavText.text = phrase("gallery_info_favorite", "Favori") + ": " + ((item.favorited != null && item.favorited) ? "★ " + phrase("general_yes", "Evet") : phrase("general_no", "Hayır"));
	}

	function hideHUD() {
		for (t in [titleG, artistText, descG, typeText, instDisplay, pageDisplay, categoryText])
			t.alpha = 0;
	}

	function restoreHUD() {
		if (!textVisible) return;
		for (t in [titleG, artistText, descG, typeText, instDisplay, pageDisplay, categoryText])
			FlxTween.tween(t, {alpha: 1}, 0.25, {ease: FlxEase.sineOut});
	}

	function changeItem(change:Int) {
		if (filteredItems.length == 0) return; // boş listeye girme (curSelected -1 oluyordu)
		cancelImageIntroTween();
		imageTweenToken++;
		curSelected += change;
		stopAudio();
		if (curSelected < 0) curSelected = filteredItems.length - 1;
		if (curSelected >= filteredItems.length) curSelected = 0;
		FlxG.sound.play(Paths.sound('scrollMenu'));
		loadCurrentItem();
		updateTexts();
		updateInstructions();
		if (showingInfo) updateInfoPanel();

		#if mobile
		updateMobileButtonVisibility();
		#end
	}

	function updateTexts() {
		if (filteredItems.length == 0) {
			titleG.text = phrase("gallery_empty_title", "Boş");
			artistText.text = "";
			descG.text = phrase("gallery_empty_desc", "Bu kategoride öğe yok.");
			typeText.text = "";
			pageDisplay.text = phrase("gallery_page_empty", "— / —");
			return;
		}
		var item = filteredItems[curSelected];
		var fav = (item.favorited != null && item.favorited) ? " ★" : "";
		var modTag = (item.modDirectory != null && item.modDirectory.length > 0) ? " [MOD]" : "";
		titleG.text = item.title + fav + modTag;
		artistText.text = item.artist != null ? phrase("gallery_by", "Yapımcı:") + " " + item.artist : "";
		descG.text = item.description;
		typeText.text = getTypeName(item.type)
			+ (item.category != null ? "  ·  " + item.category : "")
			+ (item.dateAdded != null ? "  ·  " + item.dateAdded : "")
			+ (item.modDirectory != null && item.modDirectory.length > 0 ? "  ·  " + item.modDirectory : "");
		pageDisplay.text = (curSelected + 1) + " / " + filteredItems.length;
	}

	function updateInstructions() {
		#if mobile
		switch (viewMode) {
			case GALLERY_GRID:
				instDisplay.text = phrase("gallery_inst_grid_mobile",
					"D-Pad · Gezin\nA · Aç\nB · Geri\nC · Favori\nX · Kategori\nV · Bilgi");
			case SINGLE_VIEW:
				var item = filteredItems.length > 0 ? filteredItems[curSelected] : null;
				if (item != null && (item.type == IMAGE || item.type == ANIMATED)) {
					instDisplay.text = phrase("gallery_inst_single_image_mobile",
						"←/→ · Gezin\nY/Z · Yakınlaştır\nD · Döndür\nA · Tam Ekran\nV · Slayt\nC · Favori\nB · Geri");
				} else {
					instDisplay.text = phrase("gallery_inst_single_audio_mobile",
						"←/→ · Gezin\nA · Oynat\nV · Duraklat\nC · Favori\nB · Geri");
				}
			case FULLSCREEN:
				instDisplay.text = phrase("gallery_inst_fullscreen_mobile",
					"Y/Z · Yakınlaştır\nD-Pad · Kaydır\nD · Döndür\nA/B · Çık");
			case SLIDESHOW:
				instDisplay.text = phrase("gallery_inst_slideshow_mobile",
					"Slayt Gösterisi\n←/→ · Manuel\nV/B · Durdur");
			case VIDEO_PLAYING:
				instDisplay.text = phrase("gallery_inst_video_mobile",
					"B · Durdur");
		}
		return;
		#end

		switch (viewMode) {
			case GALLERY_GRID:
				instDisplay.text = phrase("gallery_inst_grid",
					"Yön Tuşları · Gezin\nEnter · Aç\nTab · Kategori\nF · Favori\nI · Bilgi\nP · Slayt Gösterisi\nX · Arayüzü Aç/Kapat\nEsc · Geri");
			case SINGLE_VIEW:
				var item = filteredItems.length > 0 ? filteredItems[curSelected] : null;
				if (item != null && (item.type == IMAGE || item.type == ANIMATED)) {
					instDisplay.text = phrase("gallery_inst_single_image",
						"←/→ · Gezin\nQ/E · Yakınlaştır\nIJKL · Kaydır\nShift+Yön · Kaydır\nR/T · Döndür\nC · Sıfırla\nBoşluk · Tam Ekran\nF · Favori\nI · Bilgi\nP · Slayt Gösterisi\nEsc · Geri");
				} else {
					instDisplay.text = phrase("gallery_inst_single_audio",
						"←/→ · Gezin\nEnter · Oynat\nBoşluk · Duraklat\nF · Favori\nI · Bilgi\nEsc · Geri");
				}
			case FULLSCREEN:
				instDisplay.text = phrase("gallery_inst_fullscreen",
					"Q/E · Yakınlaştır\nIJKL · Kaydır\nR · Döndür\nC · Sıfırla\nBoşluk · Çık");
			case SLIDESHOW:
				instDisplay.text = phrase("gallery_inst_slideshow_label", "Slayt Gösterisi") + " (" + slideshowInterval + phrase("gallery_seconds_suffix", "sn") + ")\n"
					+ phrase("gallery_inst_slideshow_controls", "←/→ · Manuel\nP/Esc · Durdur");
			case VIDEO_PLAYING:
				instDisplay.text = phrase("gallery_inst_video",
					"Enter Basılı Tut · Atla\nEsc · Durdur");
		}
	}

	function getTypeName(type:GalleryType):String {
		return switch (type) {
			case IMAGE: phrase("gallery_type_image", "Görsel");
			case VIDEO: phrase("gallery_type_video", "Video");
			case SOUND_EFFECT: phrase("gallery_type_sfx", "Ses Efekti");
			case MUSIC: phrase("gallery_type_music", "Müzik");
			case ANIMATED: phrase("gallery_type_animation", "Animasyon");
		}
	}

	function stopAllMedia() {
		stopAudio();
		forceStopVideo();
		stopSlideshow();
	}

	function formatTime(s:Float):String {
		if (Math.isNaN(s) || s < 0) s = 0;
		var m = Std.int(s / 60);
		var sec = Std.int(s % 60);
		return m + ":" + (sec < 10 ? "0" : "") + sec;
	}

	function getCategoryDisplayName(cat:String):String {
		return switch (cat) {
			case "All": phrase("gallery_category_all", "Tümü");
			case "Favorites": phrase("gallery_category_favorites", "Favoriler");
			default: cat;
		}
	}

	function refreshCategoryText() {
		if (categoryText == null || categories.length == 0) return;
		categoryText.text = getCategoryDisplayName(categories[currentCategory]) + " (" + filteredItems.length + ")";
	}

	inline function phrase(key:String, fallback:String):String {
		return Language.getPhrase(key, fallback);
	}

	override function destroy() {
		stopAllMedia();
		#if mobile
		galleryPad = null;
		#end
		super.destroy();
	}
}

package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.util.FlxTimer;
import backend.Paths;

#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
#end

class RehberSubState extends MusicBeatSubstate {
	static inline var PANEL_WIDTH:Int = 500;
	static inline var PANEL_MARGIN_TOP:Int = 60;
	static inline var PANEL_MARGIN_BOTTOM:Int = 40;
	static inline var CONTENT_PADDING:Int = 30;
	static inline var LOGO_HEIGHT:Int = 80;
	static inline var LOGO_AREA_HEIGHT:Int = 130;
	static inline var SEPARATOR_HEIGHT:Int = 2;
	static inline var SEPARATOR_WIDTH:Int = 300;
	static inline var SECTION_GAP:Int = 30;
	static inline var IMAGE_MAX_WIDTH:Int = 380;
	static inline var IMAGE_MAX_HEIGHT:Int = 220;
	static inline var VIDEO_MAX_WIDTH:Int = 380;
	static inline var VIDEO_MAX_HEIGHT:Int = 220;
	static inline var SCROLLBAR_WIDTH:Int = 6;
	static inline var SCROLL_SPEED:Float = 60.0;
	static inline var SCROLL_LERP:Float = 0.12;
	static inline var SCROLLBAR_FADE_DELAY:Float = 0.5;

	var panelX:Float;
	var panelY:Float;
	var panelHeight:Float;
	var contentAreaY:Float;
	var contentAreaHeight:Float;

	var scrollY:Float = 0;
	var targetScrollY:Float = 0;
	var maxScrollY:Float = 0;
	var totalContentHeight:Float = 0;

	var scrollBar:FlxSprite;
	var scrollBarBg:FlxSprite;
	var scrollBarAlpha:Float = 0;
	var scrollBarTimer:Float = 0;
	var scrollBarVisible:Bool = false;
	var scrollBarFading:Bool = false;
	var scrollBarTween:FlxTween;

	var dimBg:FlxSprite;
	var panelBg:FlxSprite;
	var logoSprite:FlxSprite;

	var allContentElements:Array<ContentElement> = [];
	var videoEntries:Array<VideoEntry> = [];

	var clipTop:Float;
	var clipBottom:Float;

	override public function create():Void {
		super.create();

		if (FlxG.state != null) {
			FlxG.state.persistentUpdate = false;
			FlxG.state.persistentDraw = true;
		}

		panelHeight = FlxG.height - PANEL_MARGIN_TOP - PANEL_MARGIN_BOTTOM;
		panelX = (FlxG.width - PANEL_WIDTH) / 2;
		panelY = PANEL_MARGIN_TOP;
		contentAreaY = panelY + LOGO_AREA_HEIGHT;
		contentAreaHeight = panelHeight - LOGO_AREA_HEIGHT;
		clipTop = contentAreaY;
		clipBottom = contentAreaY + contentAreaHeight;

		// === ARKA PLAN ===
		dimBg = new FlxSprite();
		dimBg.makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(0, 0, 0, 180));
		dimBg.scrollFactor.set();
		add(dimBg);

		// Panel
		panelBg = new FlxSprite(panelX, panelY);
		panelBg.makeGraphic(PANEL_WIDTH, Std.int(panelHeight), FlxColor.fromRGB(45, 45, 50));
		panelBg.scrollFactor.set();
		add(panelBg);

		buildContent();

		// === LOGO ALANI ÜSTÜNE MASKE (içerik logonun altına girmesin) ===
		var topMask = new FlxSprite(panelX, panelY);
		topMask.makeGraphic(PANEL_WIDTH, LOGO_AREA_HEIGHT, FlxColor.fromRGB(45, 45, 50));
		topMask.scrollFactor.set();
		add(topMask);

		var bottomMask = new FlxSprite(panelX, Std.int(clipBottom));
		var bottomMaskH = Std.int(FlxG.height - clipBottom);
		if (bottomMaskH > 0) {
			bottomMask.makeGraphic(PANEL_WIDTH, bottomMaskH, FlxColor.fromRGB(45, 45, 50));
			bottomMask.scrollFactor.set();
			add(bottomMask);
		}

		// Panel alt kısmı düzeltme - panelin alt kenarı
		var panelBottom = new FlxSprite(panelX, panelY + panelHeight - 5);
		panelBottom.makeGraphic(PANEL_WIDTH, 5, FlxColor.fromRGB(45, 45, 50));
		panelBottom.scrollFactor.set();
		add(panelBottom);

		// Logo
		logoSprite = new FlxSprite();
		var logoGraphic = Paths.image('pet/petlogos/logo');
		if (logoGraphic != null) {
			logoSprite.loadGraphic(logoGraphic);
			var logoScale = Math.min((PANEL_WIDTH - 40) / logoSprite.width, LOGO_HEIGHT / logoSprite.height);
			logoSprite.scale.set(logoScale, logoScale);
			logoSprite.updateHitbox();
		} else {
			logoSprite.makeGraphic(200, 50, FlxColor.fromRGB(80, 80, 90));
		}
		logoSprite.x = panelX + (PANEL_WIDTH - logoSprite.width) / 2;
		logoSprite.y = panelY + 10;
		logoSprite.scrollFactor.set();
		add(logoSprite);

		var rehberTitle = new FlxText(panelX, logoSprite.y + logoSprite.height + 4, PANEL_WIDTH, "REHBERİ");
		rehberTitle.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.fromRGB(200, 200, 210), CENTER);
		rehberTitle.scrollFactor.set();
		rehberTitle.antialiasing = true;
		add(rehberTitle);

		var logoSep = new FlxSprite(panelX + 15, panelY + LOGO_AREA_HEIGHT - 2);
		logoSep.makeGraphic(PANEL_WIDTH - 30, 1, FlxColor.fromRGB(80, 80, 90));
		logoSep.scrollFactor.set();
		add(logoSep);

		// === SCROLLBAR ===
		scrollBarBg = new FlxSprite(panelX + PANEL_WIDTH - SCROLLBAR_WIDTH - 8, contentAreaY + 5);
		scrollBarBg.makeGraphic(SCROLLBAR_WIDTH, Std.int(contentAreaHeight - 10), FlxColor.fromRGB(60, 60, 65));
		scrollBarBg.scrollFactor.set();
		scrollBarBg.alpha = 0;
		add(scrollBarBg);

		scrollBar = new FlxSprite(panelX + PANEL_WIDTH - SCROLLBAR_WIDTH - 8, contentAreaY + 5);
		var barH = getScrollBarHeight();
		scrollBar.makeGraphic(SCROLLBAR_WIDTH, Std.int(Math.max(barH, 20)), FlxColor.fromRGB(180, 180, 190));
		scrollBar.scrollFactor.set();
		scrollBar.alpha = 0;
		add(scrollBar);
	}

	// ============================================================
	// İÇERİK TANIMLAMALARI
	// ============================================================

	function getSections():Array<SectionData> {
		return [
			{
				title: "1.0 - Giriş",
				content: "Psych Engine Türkiye'ye hoş geldiniz!\nBu rehber size engine hakkında\ntemel bilgileri verecektir.\n\nAşağı kaydırarak devam edebilirsiniz.",
				image: null,
				video: null,
				imageCaption: null
			},
			{
				title: "1.1 - Menüler",
				content: "Menüler varsayılan olarak 'Yeni' seçilir\nAyarlar -> PET -> Menü Stili\nkısmından Menüleri değiştirebilirsiniz.",
				image: "other/rehber/menu",
				video: "assets/videos/rehber/menu.mp4",
				imageCaption: "Eski Freeplay Menüsü"
			},
			{
				title: "1.2 - Mod Paketleri",
				content: "PET'nin Sahip olduğu mod paketleri\nMods -> Mod Paketleri\n\nkısmından indirilebilir",
				image: null,
				video: null,
				imageCaption: null
			},
			{
				title: "1.3 - Liderlik Sistemi",
				content: "Ana Menüden giriş yaparak PET'ye katılabilirsiniz\nOyunda kazandığınız skorlar vs. UP (Ultra Puan) dönüşür\n\nOyuna giriş yapmak zorunda değilsiniz.",
				image: null,
				video: null,
				imageCaption: null
			}
		];
	}
	function buildContent():Void {
		var sections = getSections();
		var curY:Float = 0;
		var contentStartX = panelX + CONTENT_PADDING;
		var contentWidth = PANEL_WIDTH - (CONTENT_PADDING * 2) - SCROLLBAR_WIDTH - 10;

		for (i in 0...sections.length) {
			var section = sections[i];

			var titleText = new FlxText(contentStartX, 0, contentWidth, section.title);
			titleText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, LEFT);
			titleText.scrollFactor.set();
			titleText.antialiasing = true;
			add(titleText);
			allContentElements.push({sprite: titleText, offsetY: curY, baseX: contentStartX});
			curY += titleText.height + 8;

			if (section.content != null && section.content.length > 0) {
				var bodyText = new FlxText(contentStartX, 0, contentWidth, section.content);
				bodyText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.fromRGB(200, 200, 210), LEFT);
				bodyText.scrollFactor.set();
				bodyText.antialiasing = true;
				add(bodyText);
				allContentElements.push({sprite: bodyText, offsetY: curY, baseX: contentStartX});
				curY += bodyText.height + 12;
			}

			if (section.image != null) {
				var img = new FlxSprite();
				var imgPath = Paths.image(section.image);
				if (imgPath != null) {
					img.loadGraphic(imgPath);
					var imgScale = Math.min(IMAGE_MAX_WIDTH / img.width, IMAGE_MAX_HEIGHT / img.height);
					if (imgScale < 1) {
						img.scale.set(imgScale, imgScale);
						img.updateHitbox();
					}
				} else {
					img.makeGraphic(IMAGE_MAX_WIDTH, 100, FlxColor.fromRGB(60, 60, 70));
				}
				img.scrollFactor.set();
				img.antialiasing = true;
				var imgX = panelX + (PANEL_WIDTH - img.width) / 2;
				img.x = imgX;
				add(img);
				allContentElements.push({sprite: img, offsetY: curY, baseX: imgX});
				curY += img.height + 8;
			}

			// Video
			#if VIDEOS_ALLOWED
			if (section.video != null) {
				curY = buildVideoEntry(section.video, curY);
			}
			#end

			if (section.imageCaption != null && section.imageCaption.length > 0) {
				var capText = new FlxText(contentStartX, 0, contentWidth, section.imageCaption);
				capText.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.fromRGB(160, 160, 175), CENTER);
				capText.scrollFactor.set();
				capText.antialiasing = true;
				add(capText);
				allContentElements.push({sprite: capText, offsetY: curY, baseX: contentStartX});
				curY += capText.height + 12;
			}

			if (i < sections.length - 1) {
				var sep = new FlxSprite();
				sep.makeGraphic(SEPARATOR_WIDTH, SEPARATOR_HEIGHT, FlxColor.fromRGB(80, 80, 90));
				sep.scrollFactor.set();
				var sepX = panelX + (PANEL_WIDTH - SEPARATOR_WIDTH) / 2;
				sep.x = sepX;
				add(sep);
				allContentElements.push({sprite: sep, offsetY: curY + 5, baseX: sepX});
				curY += SEPARATOR_HEIGHT + SECTION_GAP;
			}
		}

		totalContentHeight = curY;
		maxScrollY = Math.max(0, totalContentHeight - contentAreaHeight + 20);
		updateContentPositions();
	}

	#if VIDEOS_ALLOWED
	function buildVideoEntry(videoPath:String, curY:Float):Float {
		var videoThumb = new FlxSprite();
		videoThumb.makeGraphic(VIDEO_MAX_WIDTH, VIDEO_MAX_HEIGHT, FlxColor.fromRGB(30, 30, 35));
		videoThumb.scrollFactor.set();
		var thumbX = panelX + (PANEL_WIDTH - VIDEO_MAX_WIDTH) / 2;
		videoThumb.x = thumbX;
		add(videoThumb);
		allContentElements.push({sprite: videoThumb, offsetY: curY, baseX: thumbX});

		var pauseIcon = new FlxSprite();
		var pauseGraphic = Paths.image('other/pause');
		if (pauseGraphic != null) {
			pauseIcon.loadGraphic(pauseGraphic);
			var iconScale = Math.min(64 / pauseIcon.width, 64 / pauseIcon.height);
			pauseIcon.scale.set(iconScale, iconScale);
			pauseIcon.updateHitbox();
		} else {
			pauseIcon.makeGraphic(64, 64, FlxColor.fromRGB(255, 255, 255, 150));
		}
		pauseIcon.scrollFactor.set();
		var iconX = panelX + (PANEL_WIDTH - pauseIcon.width) / 2;
		pauseIcon.x = iconX;
		add(pauseIcon);
		allContentElements.push({
			sprite: pauseIcon,
			offsetY: curY + (VIDEO_MAX_HEIGHT - pauseIcon.height) / 2,
			baseX: iconX
		});

		var entry:VideoEntry = {
			videoPath: videoPath,
			thumb: videoThumb,
			pauseIcon: pauseIcon,
			videoSprite: null,
			isPlaying: false,
			isLoaded: false,
			thumbnailCaptured: false,
			offsetY: curY,
			holderWidth: VIDEO_MAX_WIDTH,
			holderHeight: VIDEO_MAX_HEIGHT
		};
		videoEntries.push(entry);

		captureFirstFrame(entry);

		return curY + VIDEO_MAX_HEIGHT + 8;
	}

	function captureFirstFrame(entry:VideoEntry):Void {
		var tempVid = new FlxVideoSprite();
		tempVid.antialiasing = true;
		tempVid.scrollFactor.set();
		tempVid.visible = false;
		add(tempVid);

		tempVid.bitmap.onFormatSetup.add(function() {
			tempVid.setGraphicSize(Std.int(entry.holderWidth));
			tempVid.updateHitbox();

			new FlxTimer().start(0.2, function(_) {
				if (tempVid != null && tempVid.pixels != null) {
					try {
						var srcPixels = tempVid.pixels.clone();
						entry.thumb.loadGraphic(srcPixels);
						entry.thumb.setGraphicSize(Std.int(entry.holderWidth));
						entry.thumb.updateHitbox();
						entry.thumb.x = panelX + (PANEL_WIDTH - entry.thumb.width) / 2;
						entry.thumbnailCaptured = true;
					} catch (e) {
						trace("Thumbnail capture failed: " + e);
					}
				}

				if (tempVid != null && tempVid.bitmap != null) {
					tempVid.bitmap.stop();
				}
				remove(tempVid);
				tempVid.destroy();
			});
		});

		tempVid.load(entry.videoPath);

		new FlxTimer().start(0.05, function(_) {
			if (tempVid != null && tempVid.bitmap != null) {
				tempVid.bitmap.play();
				tempVid.bitmap.volume = 0;
			}
		});
	}
	#end

	function updateContentPositions():Void {
		for (elem in allContentElements) {
			var newY = contentAreaY + elem.offsetY - scrollY;
			elem.sprite.y = newY;
			elem.sprite.x = elem.baseX;

			// Tamamen dışarıda mı?
			var sprH = elem.sprite.height;
			if (newY + sprH <= clipTop || newY >= clipBottom) {
				elem.sprite.visible = false;
				elem.sprite.clipRect = null;
			} else {
				elem.sprite.visible = true;
				applyClipRect(elem.sprite, newY);
			}
		}

		#if VIDEOS_ALLOWED
		updateVideoPositions();
		#end
	}

	function applyClipRect(spr:FlxSprite, screenY:Float):Void {
		var sprW = spr.frameWidth;
		var sprH = spr.frameHeight;

		if (sprW <= 0 || sprH <= 0) {
			spr.clipRect = null;
			return;
		}

		var cropTop:Float = 0;
		var cropBottom:Float = sprH;
		var needsClip = false;

		if (screenY < clipTop) {
			cropTop = (clipTop - screenY) / spr.scale.y;
			needsClip = true;
		}

		if (screenY + spr.height > clipBottom) {
			cropBottom = (clipBottom - screenY) / spr.scale.y;
			needsClip = true;
		}

		if (needsClip && cropTop < cropBottom) {
			spr.clipRect = FlxRect.get(0, cropTop, sprW, cropBottom - cropTop);
		} else if (needsClip) {
			spr.visible = false;
			spr.clipRect = null;
		} else {
			spr.clipRect = null;
		}
	}

	#if VIDEOS_ALLOWED
	function updateVideoPositions():Void {
		for (entry in videoEntries) {
			if (entry.videoSprite == null)
				continue;

			var newY = contentAreaY + entry.offsetY - scrollY;
			entry.videoSprite.y = newY;
			entry.videoSprite.x = panelX + (PANEL_WIDTH - entry.videoSprite.width) / 2;

			var videoBottom = newY + entry.holderHeight;
			var isVisible = !(videoBottom <= clipTop || newY >= clipBottom);

			if (!isVisible && entry.isPlaying) {
				entry.videoSprite.pause();
				entry.isPlaying = false;
				entry.pauseIcon.visible = true;
			}

			if (!isVisible) {
				entry.videoSprite.visible = false;
			} else {
				entry.videoSprite.visible = true;
			}
		}
	}

	function handleVideoClick():Void {
		if (!FlxG.mouse.justPressed)
			return;

		var mouseX = FlxG.mouse.screenX;
		var mouseY = FlxG.mouse.screenY;

		if (mouseY < contentAreaY || mouseY > clipBottom)
			return;
		if (mouseX < panelX || mouseX > panelX + PANEL_WIDTH)
			return;

		for (entry in videoEntries) {
			var entryScreenY = contentAreaY + entry.offsetY - scrollY;
			var entryScreenX = panelX + (PANEL_WIDTH - entry.holderWidth) / 2;

			if (entryScreenY + entry.holderHeight <= clipTop || entryScreenY >= clipBottom)
				continue;

			if (mouseX >= entryScreenX && mouseX <= entryScreenX + entry.holderWidth && mouseY >= Math.max(entryScreenY, clipTop)
				&& mouseY <= Math.min(entryScreenY + entry.holderHeight, clipBottom)) {
				toggleVideo(entry);
				break;
			}
		}
	}

	function toggleVideo(entry:VideoEntry):Void {
		if (!entry.isLoaded) {
			loadAndPlayVideo(entry);
		} else if (entry.isPlaying) {
			if (entry.videoSprite != null) {
				entry.videoSprite.pause();
				entry.isPlaying = false;
				entry.pauseIcon.visible = true;
			}
		} else {
			if (entry.videoSprite != null) {
				entry.videoSprite.resume();
				entry.isPlaying = true;
				entry.pauseIcon.visible = false;
			}
		}
	}

	function loadAndPlayVideo(entry:VideoEntry):Void {
		var vid = new FlxVideoSprite();
		vid.antialiasing = true;
		vid.scrollFactor.set();

		entry.videoSprite = vid;
		entry.isLoaded = true;
		entry.isPlaying = true;
		entry.pauseIcon.visible = false;
		entry.thumb.visible = false;

		var thumbIdx = members.indexOf(entry.thumb);
		if (thumbIdx >= 0) {
			insert(thumbIdx + 1, vid);
		} else {
			add(vid);
		}

		vid.bitmap.onFormatSetup.add(function() {
			vid.setGraphicSize(Std.int(entry.holderWidth));
			vid.updateHitbox();
			vid.x = panelX + (PANEL_WIDTH - vid.width) / 2;
			vid.y = contentAreaY + entry.offsetY - scrollY;
		});

		vid.bitmap.onEndReached.add(function() {
			// Video bitti - ilk frame'i tekrar yakala
			entry.isPlaying = false;
			entry.isLoaded = false;
			entry.pauseIcon.visible = true;
			entry.thumb.visible = true;

			if (entry.videoSprite != null) {
				remove(entry.videoSprite);
				entry.videoSprite.destroy();
				entry.videoSprite = null;
			}

			// Thumbnail'i yenile
			if (!entry.thumbnailCaptured) {
				captureFirstFrame(entry);
			}
		});

		vid.load(entry.videoPath);

		new FlxTimer().start(0.1, function(_) {
			if (vid != null && vid.bitmap != null) {
				vid.bitmap.play();
			}
		});
	}

	function cleanupAllVideos():Void {
		for (entry in videoEntries) {
			if (entry.videoSprite != null) {
				if (entry.isPlaying) {
					entry.videoSprite.pause();
				}
				remove(entry.videoSprite);
				entry.videoSprite.destroy();
				entry.videoSprite = null;
				entry.isPlaying = false;
				entry.isLoaded = false;
			}
		}
		videoEntries = [];
	}
	#end

	function getScrollBarHeight():Float {
		if (totalContentHeight <= 0)
			return contentAreaHeight - 10;
		var ratio = contentAreaHeight / totalContentHeight;
		if (ratio >= 1)
			return contentAreaHeight - 10;
		return Math.max(20, (contentAreaHeight - 10) * ratio);
	}

	function updateScrollBar():Void {
		if (maxScrollY <= 0) {
			scrollBar.alpha = 0;
			scrollBarBg.alpha = 0;
			return;
		}

		var barHeight = getScrollBarHeight();
		var trackHeight = contentAreaHeight - 10 - barHeight;
		var scrollRatio = if (maxScrollY > 0) scrollY / maxScrollY else 0;
		scrollBar.y = contentAreaY + 5 + trackHeight * scrollRatio;

		scrollBar.alpha = scrollBarAlpha;
		scrollBarBg.alpha = scrollBarAlpha * 0.3;
	}

	function showScrollBar():Void {
		if (maxScrollY <= 0)
			return;

		scrollBarVisible = true;
		scrollBarFading = false;
		scrollBarTimer = 0;
		scrollBarAlpha = 1;

		if (scrollBarTween != null) {
			scrollBarTween.cancel();
			scrollBarTween = null;
		}
	}

	function startScrollBarFade():Void {
		if (scrollBarFading)
			return;

		scrollBarFading = true;

		if (scrollBarTween != null)
			scrollBarTween.cancel();

		scrollBarTween = FlxTween.num(scrollBarAlpha, 0, 0.3, {
			ease: FlxEase.quadOut,
			onComplete: function(_) {
				scrollBarVisible = false;
				scrollBarFading = false;
				scrollBarTween = null;
			}
		}, function(v) {
			scrollBarAlpha = v;
		});
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		if (controls.BACK) {
			closeRehber();
			return;
		}

		if (FlxG.mouse.wheel != 0) {
			targetScrollY -= FlxG.mouse.wheel * SCROLL_SPEED;
			targetScrollY = FlxMath.bound(targetScrollY, 0, maxScrollY);
			showScrollBar();
		}

		if (Math.abs(scrollY - targetScrollY) > 0.5) {
			scrollY = FlxMath.lerp(scrollY, targetScrollY, SCROLL_LERP);
			updateContentPositions();
			updateScrollBar();
		} else if (scrollY != targetScrollY) {
			scrollY = targetScrollY;
			updateContentPositions();
			updateScrollBar();
		}

		if (scrollBarVisible && !scrollBarFading) {
			if (FlxG.mouse.wheel == 0) {
				scrollBarTimer += elapsed;
				if (scrollBarTimer >= SCROLLBAR_FADE_DELAY) {
					startScrollBarFade();
				}
			} else {
				scrollBarTimer = 0;
			}
		}

		updateScrollBar();

		#if VIDEOS_ALLOWED
		handleVideoClick();
		#end
	}

	function closeRehber():Void {
		if (scrollBarTween != null) {
			scrollBarTween.cancel();
			scrollBarTween = null;
		}

		for (elem in allContentElements) {
			elem.sprite.clipRect = null;
		}

		#if VIDEOS_ALLOWED
		cleanupAllVideos();
		#end

		if (FlxG.state != null) {
			FlxG.state.persistentUpdate = true;
		}

		close();
	}

	override public function close():Void {
		if (FlxG.state != null) {
			FlxG.state.persistentUpdate = true;
		}
		super.close();
	}
}

typedef SectionData = {
	var title:String;
	var content:String;
	var image:Null<String>;
	var video:Null<String>;
	var imageCaption:Null<String>;
};

typedef ContentElement = {
	var sprite:FlxSprite;
	var offsetY:Float;
	var baseX:Float;
};

typedef VideoEntry = {
	var videoPath:String;
	var thumb:FlxSprite;
	var pauseIcon:FlxSprite;
	var videoSprite:#if hxvlc FlxVideoSprite #else Dynamic #end;
	var isPlaying:Bool;
	var isLoaded:Bool;
	var thumbnailCaptured:Bool;
	var offsetY:Float;
	var holderWidth:Float;
	var holderHeight:Float;
};
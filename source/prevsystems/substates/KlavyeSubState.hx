package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import backend.Paths;

class KlavyeSubState extends MusicBeatSubstate {
	static inline var PANEL_WIDTH:Int = 600;
	static inline var PANEL_MARGIN_TOP:Int = 60;
	static inline var PANEL_MARGIN_BOTTOM:Int = 60;
	static inline var CONTENT_PADDING:Int = 35;
	static inline var TITLE_AREA_HEIGHT:Int = 60;
	static inline var SEPARATOR_HEIGHT:Int = 2;
	static inline var SEPARATOR_WIDTH:Int = 300;
	static inline var SCROLLBAR_WIDTH:Int = 5;
	static inline var SCROLL_SPEED:Float = 50.0;
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

	var allContentElements:Array<{sprite:FlxSprite, offsetY:Float, baseX:Float}> = [];

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
		contentAreaY = panelY + TITLE_AREA_HEIGHT;
		contentAreaHeight = panelHeight - TITLE_AREA_HEIGHT;
		clipTop = contentAreaY;
		clipBottom = contentAreaY + contentAreaHeight;

		var dimBg = new FlxSprite();
		dimBg.makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(0, 0, 0, 220));
		dimBg.scrollFactor.set();
		add(dimBg);

		var panelBg = new FlxSprite(panelX, panelY);
		panelBg.makeGraphic(PANEL_WIDTH, Std.int(panelHeight), FlxColor.fromRGB(25, 25, 28));
		panelBg.scrollFactor.set();
		add(panelBg);
		buildContent();

		var topMask = new FlxSprite(panelX, panelY);
		topMask.makeGraphic(PANEL_WIDTH, TITLE_AREA_HEIGHT, FlxColor.fromRGB(25, 25, 28));
		topMask.scrollFactor.set();
		add(topMask);

		var bottomMaskH = Std.int(FlxG.height - clipBottom);
		if (bottomMaskH > 0) {
			var bottomMask = new FlxSprite(panelX, Std.int(clipBottom));
			bottomMask.makeGraphic(PANEL_WIDTH, bottomMaskH + 10, FlxColor.fromRGB(25, 25, 28));
			bottomMask.scrollFactor.set();
			add(bottomMask);
		}

		var panelBot = new FlxSprite(panelX, panelY + panelHeight - 5);
		panelBot.makeGraphic(PANEL_WIDTH, 5, FlxColor.fromRGB(25, 25, 28));
		panelBot.scrollFactor.set();
		add(panelBot);

		var titleText = new FlxText(panelX, panelY + 15, PANEL_WIDTH, "Bir insan");
		titleText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.fromRGB(150, 150, 160), CENTER);
		titleText.scrollFactor.set();
		titleText.antialiasing = true;
		add(titleText);

		var titleSep = new FlxSprite(panelX + 30, panelY + TITLE_AREA_HEIGHT - 2);
		titleSep.makeGraphic(PANEL_WIDTH - 60, 1, FlxColor.fromRGB(60, 60, 70));
		titleSep.scrollFactor.set();
		add(titleSep);

		scrollBarBg = new FlxSprite(panelX + PANEL_WIDTH - SCROLLBAR_WIDTH - 6, contentAreaY + 4);
		scrollBarBg.makeGraphic(SCROLLBAR_WIDTH, Std.int(contentAreaHeight - 8), FlxColor.fromRGB(40, 40, 45));
		scrollBarBg.scrollFactor.set();
		scrollBarBg.alpha = 0;
		add(scrollBarBg);

		scrollBar = new FlxSprite(panelX + PANEL_WIDTH - SCROLLBAR_WIDTH - 6, contentAreaY + 4);
		var barH = getScrollBarHeight();
		scrollBar.makeGraphic(SCROLLBAR_WIDTH, Std.int(Math.max(barH, 20)), FlxColor.fromRGB(120, 120, 130));
		scrollBar.scrollFactor.set();
		scrollBar.alpha = 0;
		add(scrollBar);

		var escHint = new FlxText(panelX, panelY + panelHeight + 10, PANEL_WIDTH, "Geri dönmek için ESC");
		escHint.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.fromRGB(100, 100, 110), CENTER);
		escHint.scrollFactor.set();
		escHint.antialiasing = true;
		add(escHint);
	}

	function buildContent():Void {
		var curY:Float = 15;
		var contentStartX = panelX + CONTENT_PADDING;
		var contentWidth = PANEL_WIDTH - (CONTENT_PADDING * 2) - SCROLLBAR_WIDTH - 10;

		var secTitle = new FlxText(contentStartX, 0, contentWidth, "Düşünsene");
		secTitle.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.fromRGB(220, 220, 230), LEFT);
		secTitle.scrollFactor.set();
		secTitle.antialiasing = true;
		add(secTitle);
		allContentElements.push({sprite: secTitle, offsetY: curY, baseX: contentStartX});
		curY += secTitle.height + 15;

		var message = "Kendi hayatını diğer insanların hayatı ve mutluluğu için kısan bir insansın\nhayatının zorluklarını görmezden geliyorsun\nhiçbirşeyin karşılığını istemiyorsun\nsonra hayatına biri giriyor\nsana doğruları gösteriyor ve seni değiştiriyor\nSeni mutlu ediyor, destek çıkıyor\n\no insanı ne kadar seversin?\nbelkide o insan diğer insanı bu yüzden kafaya takıyodur, önemli birisidir,\n\nvermesi gereken bir karşılık vardır ama diğer insan izin vermeden gitmeyi seçmiştir\nBelkide bunların olmasını hiç istemedin\nAma ben her yaptığın ve gördüğüm şeye rağmen seni düşünmeye devam ettim\n\nO insanı iyi yönde değiştiren biri bile terk ediyorsa\nO insan nası biridir?\n\nBazı insanlar iz bırakmadan gitmeyi seçer\nartık cevap gelmez, Sessizlik oluşur,\ndiğer insan ise sessizliğin içine binlerce neden yerleştirir.\nbu sessizlik insanı yormuş ve bitirmiştir.\n\nve kendini kendi zihninin içinde boğar\ninsan bazen sessiz olduğu için mutludur\nama artık eskisi gibi bişey hissedemez\nduygularını kullanamaz, eskisi gibi değildir\n\nÇünkü bu insanın zihni boşluk bırakmayı sevmez.\nBelki de en ağır yük, terk edilmek değildir.\nSebebini öğrenememektir.\nama bu insan diğer insan gibi\nsanki o hiç yokmuş gibi davranmaz\n\nBir insan öyle bir düşünürki\nHayatına giren her insanı kendi dertleri ile boğduğunu düşünür\nve kimseye ses çıkarmaz\nsadece düşüncelerini böyle metinlerle aktarır\nSonsuz bir oyuna ve düşünce tarzına.\n\n-SametGkTe-";

		var bodyText = new FlxText(contentStartX, 0, contentWidth, message);
		// Metin özelliklerini ayarla: satır arası boşluğu hafifçe artırılmış, açık gri
		bodyText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.fromRGB(180, 180, 190), LEFT);
		bodyText.scrollFactor.set();
		bodyText.antialiasing = true;
		add(bodyText);
		allContentElements.push({sprite: bodyText, offsetY: curY, baseX: contentStartX});
		curY += bodyText.height + 25;

		totalContentHeight = curY;
		maxScrollY = Math.max(0, totalContentHeight - contentAreaHeight + 15);
		updateContentPositions();
	}

	function updateContentPositions():Void {
		for (elem in allContentElements) {
			var newY = contentAreaY + elem.offsetY - scrollY;
			elem.sprite.y = newY;
			elem.sprite.x = elem.baseX;

			var sprH = elem.sprite.height;
			if (newY + sprH <= clipTop || newY >= clipBottom) {
				elem.sprite.visible = false;
				elem.sprite.clipRect = null;
			} else {
				elem.sprite.visible = true;
				applyClipRect(elem.sprite, newY);
			}
		}
	}

	function applyClipRect(spr:FlxSprite, screenY:Float):Void {
		var sprW = spr.frameWidth;
		var sprH = spr.frameHeight;
		if (sprW <= 0 || sprH <= 0) { spr.clipRect = null; return; }

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

	function getScrollBarHeight():Float {
		if (totalContentHeight <= 0) return contentAreaHeight - 8;
		var ratio = contentAreaHeight / totalContentHeight;
		if (ratio >= 1) return contentAreaHeight - 8;
		return Math.max(20, (contentAreaHeight - 8) * ratio);
	}

	function updateScrollBar():Void {
		if (maxScrollY <= 0) { scrollBar.alpha = 0; scrollBarBg.alpha = 0; return; }
		var barHeight = getScrollBarHeight();
		var trackHeight = contentAreaHeight - 8 - barHeight;
		var scrollRatio = if (maxScrollY > 0) scrollY / maxScrollY else 0;
		scrollBar.y = contentAreaY + 4 + trackHeight * scrollRatio;
		scrollBar.alpha = scrollBarAlpha;
		scrollBarBg.alpha = scrollBarAlpha * 0.3;
	}

	function showScrollBar():Void {
		if (maxScrollY <= 0) return;
		scrollBarVisible = true;
		scrollBarFading = false;
		scrollBarTimer = 0;
		scrollBarAlpha = 1;
		if (scrollBarTween != null) { scrollBarTween.cancel(); scrollBarTween = null; }
	}

	function startScrollBarFade():Void {
		if (scrollBarFading) return;
		scrollBarFading = true;
		if (scrollBarTween != null) scrollBarTween.cancel();
		scrollBarTween = FlxTween.num(scrollBarAlpha, 0, 0.3, {
			ease: FlxEase.quadOut,
			onComplete: function(_) { scrollBarVisible = false; scrollBarFading = false; scrollBarTween = null; }
		}, function(v) { scrollBarAlpha = v; });
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		if (controls.BACK) {
			closeNote();
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
				if (scrollBarTimer >= SCROLLBAR_FADE_DELAY) startScrollBarFade();
			} else {
				scrollBarTimer = 0;
			}
		}

		updateScrollBar();
	}

	function closeNote():Void {
		if (scrollBarTween != null) { scrollBarTween.cancel(); scrollBarTween = null; }
		for (elem in allContentElements) elem.sprite.clipRect = null;
		if (FlxG.state != null) FlxG.state.persistentUpdate = true;
		close();
	}

	override public function close():Void {
		if (FlxG.state != null) FlxG.state.persistentUpdate = true;
		super.close();
	}
}
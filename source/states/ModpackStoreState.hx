package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import openfl.display.BitmapData;
import backend.update.UpdateChecker;
import backend.modpack.ModpackLinkHelper;
import backend.modpack.ModpackPaths;
import backend.modpack.ModpackInstaller;
import backend.modpack.ModpackTypes;
import backend.modpack.ModpackTier;
import backend.modpack.MediafireStats;
import backend.modpack.DownloadManager;
import substates.PickDownloadMethodSubState;

enum StoreScreenState {
	Loading;
	Browse;
	Detail;
	Downloading;
	Installing;
	Uninstalling;
	Complete;
	Error;
}

/**
 * Further Engine — Modpack Mağazası
 *
 * Ekranlar:
 *  - Browse   : 2x2 kart grid'i (görsel + paket adı + tier + toplam indirmeler)
 *  - Detail   : büyük görsel + İÇERİK listesi (scroll) + indirme linkleri
 *  - Diyalog  : [OTOMATİK] / [MANUEL] indirme yöntemi seçimi (PickDownloadMethodSubState)
 *
 * İndirme linkleri: MediaFire (mediafireUrl) ve GitHub (githubUrl).
 * Kullanıcı hangi linke basarsa OTOMATİK indirme o kaynak üzerinden yapılır;
 * MANUEL seçilirse tarayıcıda açılır.
 */
class ModpackStoreState extends MusicBeatState {
	// ─── Veri ───
	var allPacks:Array<Dynamic> = [];
	var pageIndex:Int = 0;
	var pageCount:Int = 1;
	var selectedIndex:Int = 0; // grid index (0-3)
	var currentPack:Dynamic = null; // detay ekranındaki paket
	var selectedLink:Int = 0; // 0 = MediaFire, 1 = GitHub
	var expectedBytes:Float = -1;

	// ─── Sistemler ───
	var downloader:DownloadManager;
	var installer:ModpackInstaller;

	// ─── Durum ───
	var screenState:StoreScreenState = Loading;
	var currentProgress:Float = 0.0;
	var targetProgress:Float = 0.0;
	var loadingTimer:Float = 0.0;
	var loadingDots:Int = 0;
	var includeOffset:Int = 0;
	var includeMaxVisible:Int = 10;
	var dragList:Bool = false;
	var dragStartY:Float = 0.0;
	var hoveredLink:Int = -1;

	// ─── Genel UI ───
	var bg:FlxSprite;
	var titleText:FlxText;
	var subtitleText:FlxText;
	var controlsText:FlxText;
	var loadingText:FlxText;
	var errorText:FlxText;

	// ─── Browse (kart grid) ───
	static final GRID_COLS:Int = 2;
	static final CARDS_PER_PAGE:Int = 4;
	var cardBg:Array<FlxSprite> = [];
	var cardBorder:Array<FlxSprite> = [];
	var cardName:Array<FlxText> = [];
	var cardTier:Array<FlxText> = [];
	var cardThumb:Array<FlxSprite> = [];
	var cardThumbText:Array<FlxText> = [];
	var cardDownloads:Array<FlxText> = [];
	var selector:FlxSprite;
	var pageText:FlxText;

	// ─── Detail ───
	var detailBg:FlxSprite;
	var detailImage:FlxSprite;
	var detailImageText:FlxText;
	var detailName:FlxText;
	var detailUpdated:FlxText;
	var detailMeta:FlxText;
	var includesTitle:FlxText;
	var includeTexts:Array<FlxText> = [];
	var scrollTrack:FlxSprite;
	var scrollThumb:FlxSprite;
	var linksTitle:FlxText;
	var linkRow:Array<FlxSprite> = [];
	var linkLogo:Array<FlxSprite> = [];
	var linkLogoText:Array<FlxText> = [];
	var linkText:Array<FlxText> = [];
	var linkLabel:Array<FlxText> = [];

	// ─── Progress / Durum ───
	var barBorder:FlxSprite;
	var barBg:FlxSprite;
	var barFill:FlxSprite;
	var percentText:FlxText;
	var sizeText:FlxText;
	var speedText:FlxText;
	var phaseText:FlxText;

	static final ACCENT:Int = 0xFF0D9488;
	static final INSTALLED_COLOR:Int = 0xFF22C55E;
	static final UPDATE_COLOR:Int = 0xFFF59E0B;
	static final NEW_COLOR:Int = 0xFF3B82F6;

	// ═════════════════════════════════════════════
	//  CREATE
	// ═════════════════════════════════════════════

	override function create():Void {
		super.create();

		downloader = new DownloadManager();
		installer = new ModpackInstaller();

		bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xFF0A0E12);
		add(bg);

		// ── Başlık ──
		titleText = new FlxText(0, 24, FlxG.width, "MODPACK MAĞAZASI", 34);
		titleText.setFormat("VCR OSD Mono", 34, FlxColor.WHITE, CENTER);
		add(titleText);

		subtitleText = new FlxText(0, 64, FlxG.width, "Yükleniyor...", 13);
		subtitleText.setFormat("VCR OSD Mono", 13, 0xFF666666, CENTER);
		add(subtitleText);

		controlsText = new FlxText(0, FlxG.height - 36, FlxG.width, "", 12);
		controlsText.setFormat("VCR OSD Mono", 12, 0xFF777777, CENTER);
		add(controlsText);

		loadingText = new FlxText(0, 0, FlxG.width, "Mağaza yükleniyor...", 18);
		loadingText.setFormat("VCR OSD Mono", 18, 0xFF888888, CENTER);
		loadingText.screenCenter();
		add(loadingText);

		errorText = new FlxText(60, 0, FlxG.width - 120, "", 15);
		errorText.setFormat("VCR OSD Mono", 15, 0xFFEF4444, CENTER);
		errorText.screenCenter();
		errorText.visible = false;
		add(errorText);

		// ── Progress bar ──
		var barY:Int = FlxG.height - 100;
		barBorder = new FlxSprite(30 - 1, barY - 1).makeGraphic(FlxG.width - 58 + 2, 18 + 2, 0xFF333333);
		barBorder.visible = false;
		add(barBorder);
		barBg = new FlxSprite(30, barY).makeGraphic(FlxG.width - 58, 18, 0xFF1A1A1A);
		barBg.visible = false;
		add(barBg);
		barFill = new FlxSprite(30, barY).makeGraphic(1, 18, ACCENT);
		barFill.visible = false;
		add(barFill);
		percentText = new FlxText(0, barY - 22, FlxG.width, "", 13);
		percentText.setFormat("VCR OSD Mono", 13, FlxColor.WHITE, CENTER);
		percentText.visible = false;
		add(percentText);
		sizeText = new FlxText(0, barY + 22, FlxG.width - 40, "", 11);
		sizeText.setFormat("VCR OSD Mono", 11, 0xFF666666, RIGHT);
		sizeText.visible = false;
		add(sizeText);
		speedText = new FlxText(40, barY + 22, FlxG.width / 2, "", 11);
		speedText.setFormat("VCR OSD Mono", 11, 0xFF666666, LEFT);
		speedText.visible = false;
		add(speedText);
		phaseText = new FlxText(0, 0, FlxG.width, "", 22);
		phaseText.setFormat("VCR OSD Mono", 22, FlxColor.WHITE, CENTER);
		phaseText.screenCenter();
		phaseText.y -= 40;
		phaseText.visible = false;
		add(phaseText);

		createBrowseUI();
		createDetailUI();

		FlxG.camera.fade(FlxColor.BLACK, 0.3, true);
		fetchStore();
	}

	// ═════════════════════════════════════════════
	//  BROWSE UI (2x2 kart grid)
	// ═════════════════════════════════════════════

	function createBrowseUI():Void {
		var gridW:Int = FlxG.width;
		var gridH:Int = FlxG.height - 120;
		var gap:Int = 14;
		var marginX:Int = 26;
		var marginY:Int = 86;
		var cardW:Int = Std.int((gridW - marginX * 2 - gap) / GRID_COLS);
		var cardH:Int = Std.int((gridH - marginY - gap) / 2);
		var thumbH:Int = cardH - 82;

		selector = new FlxSprite(marginX - 3, marginY - 3).makeGraphic(cardW + 6, cardH + 6, 0xFF0D9488);
		selector.alpha = 0.35;
		selector.visible = false;
		add(selector);

		for (i in 0...CARDS_PER_PAGE) {
			var col:Int = i % GRID_COLS;
			var row:Int = Std.int(i / GRID_COLS);
			var x:Int = marginX + col * (cardW + gap);
			var y:Int = marginY + row * (cardH + gap);

			var border = new FlxSprite(x - 2, y - 2).makeGraphic(cardW + 4, cardH + 4, 0xFF1E293B);
			border.visible = false;
			add(border);
			cardBorder.push(border);

			var box = new FlxSprite(x, y).makeGraphic(cardW, cardH, 0xFF111827);
			box.visible = false;
			add(box);
			cardBg.push(box);

			// Paket adı (üst)
			var name = new FlxText(x + 12, y + 8, cardW - 70, "", 16);
			name.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT);
			name.visible = false;
			add(name);
			cardName.push(name);

			// Tier rozeti (sağ üst)
			var tier = new FlxText(x + cardW - 66, y + 9, 56, "", 11);
			tier.setFormat("VCR OSD Mono", 11, FlxColor.WHITE, RIGHT);
			tier.visible = false;
			add(tier);
			cardTier.push(tier);

			// Görsel alanı
			var thumb = new FlxSprite(x + 10, y + 34);
			thumb.visible = false;
			add(thumb);
			cardThumb.push(thumb);

			var thumbText = new FlxText(x + 10, y + 34 + Std.int(thumbH / 2) - 10, cardW - 20, "", 12);
			thumbText.setFormat("VCR OSD Mono", 12, 0xFF4B5563, CENTER);
			thumbText.visible = false;
			add(thumbText);
			cardThumbText.push(thumbText);

			// Toplam indirmeler (alt)
			var dl = new FlxText(x + 12, y + cardH - 30, cardW - 24, "", 12);
			dl.setFormat("VCR OSD Mono", 12, 0xFF94A3B8, LEFT);
			dl.visible = false;
			add(dl);
			cardDownloads.push(dl);
		}

		pageText = new FlxText(0, FlxG.height - 58, FlxG.width, "", 12);
		pageText.setFormat("VCR OSD Mono", 12, 0xFF555555, CENTER);
		pageText.visible = false;
		add(pageText);
	}

	// ═════════════════════════════════════════════
	//  DETAIL UI
	// ═════════════════════════════════════════════

	function createDetailUI():Void {
		var padX:Int = 30;
		var topY:Int = 96;
		var bottomY:Int = FlxG.height - 56;

		detailBg = new FlxSprite(0, topY - 10).makeGraphic(FlxG.width, bottomY - topY + 10, 0xFF0D1117);
		detailBg.visible = false;
		add(detailBg);

		// Sol: büyük görsel
		var imgW:Int = Std.int((FlxG.width - padX * 2) * 0.42);
		var imgH:Int = bottomY - topY - 30;

		detailImage = new FlxSprite(padX, topY + 10);
		detailImage.visible = false;
		add(detailImage);

		detailImageText = new FlxText(padX, topY + 10 + Std.int(imgH / 2) - 12, imgW, "", 14);
		detailImageText.setFormat("VCR OSD Mono", 14, 0xFF4B5563, CENTER);
		detailImageText.visible = false;
		add(detailImageText);

		// Sağ panel
		var rightX:Int = padX + imgW + 34;
		var rightW:Int = FlxG.width - rightX - padX;

		detailName = new FlxText(rightX, topY + 12, rightW, "", 24);
		detailName.setFormat("VCR OSD Mono", 24, FlxColor.WHITE, LEFT);
		detailName.visible = false;
		add(detailName);

		detailUpdated = new FlxText(rightX, topY + 44, rightW, "", 12);
		detailUpdated.setFormat("VCR OSD Mono", 12, 0xFF94A3B8, LEFT);
		detailUpdated.visible = false;
		add(detailUpdated);

		detailMeta = new FlxText(rightX, topY + 62, rightW, "", 12);
		detailMeta.setFormat("VCR OSD Mono", 12, 0xFF64748B, LEFT);
		detailMeta.visible = false;
		add(detailMeta);

		includesTitle = new FlxText(rightX, topY + 92, rightW, "İÇERİK:", 14);
		includesTitle.setFormat("VCR OSD Mono", 14, ACCENT, LEFT);
		includesTitle.visible = false;
		add(includesTitle);

		var listTop:Int = topY + 116;
		var linksReserve:Int = 150;
		var listH:Int = (bottomY - listTop) - linksReserve;

		scrollTrack = new FlxSprite(rightX + rightW - 8, listTop).makeGraphic(4, listH, 0xFF1F2937);
		scrollTrack.visible = false;
		add(scrollTrack);

		scrollThumb = new FlxSprite(rightX + rightW - 8, listTop).makeGraphic(4, 30, ACCENT);
		scrollThumb.visible = false;
		add(scrollThumb);

		linksTitle = new FlxText(rightX, bottomY - 122, rightW, "İNDİRME LİNKLERİ:", 14);
		linksTitle.setFormat("VCR OSD Mono", 14, ACCENT, LEFT);
		linksTitle.visible = false;
		add(linksTitle);

		for (i in 0...2) {
			var y:Int = bottomY - 96 + i * 40;
			var row = new FlxSprite(rightX, y).makeGraphic(rightW, 34, 0xFF111827);
			row.visible = false;
			add(row);
			linkRow.push(row);

			var logo = new FlxSprite(rightX + 6, y + 5).makeGraphic(24, 24, i == 0 ? 0xFF1565C0 : 0xFF0F172A);
			logo.visible = false;
			add(logo);
			linkLogo.push(logo);

			var logoText = new FlxText(rightX + 6, y + 7, 24, i == 0 ? "MF" : "GH", 10);
			logoText.setFormat("VCR OSD Mono", 10, FlxColor.WHITE, CENTER);
			logoText.visible = false;
			add(logoText);
			linkLogoText.push(logoText);

			var label = new FlxText(rightX + 38, y + 3, 90, i == 0 ? "MediaFire" : "GitHub", 12);
			label.setFormat("VCR OSD Mono", 12, 0xFF94A3B8, LEFT);
			label.visible = false;
			add(label);
			linkLabel.push(label);

			var txt = new FlxText(rightX + 38, y + 18, rightW - 50, "", 10);
			txt.setFormat("VCR OSD Mono", 10, 0xFFCBD5E1, LEFT);
			txt.visible = false;
			add(txt);
			linkText.push(txt);
		}
	}

	// ═════════════════════════════════════════════
	//  VERİ ÇEKME
	// ═════════════════════════════════════════════

	function fetchStore():Void {
		screenState = Loading;
		loadingText.visible = true;
		errorText.visible = false;

		var checker = UpdateChecker.instance;
		checker.onError = function(err:String) {
			showError('Bağlantı hatası:\n$err');
		};

		checker.fetchStoreList(function(packs:Array<Dynamic>) {
			if (packs == null || packs.length == 0) {
				showError("Hiç modpack bulunamadı.\nKatalog boş veya erişilemiyor.");
				return;
			}

			allPacks = packs;
			pageCount = Std.int(Math.max(1, Math.ceil(allPacks.length / CARDS_PER_PAGE)));
			pageIndex = 0;
			selectedIndex = 0;

			loadingText.visible = false;
			showBrowse();
		});
	}

	// ═════════════════════════════════════════════
	//  BROWSE EKRANI
	// ═════════════════════════════════════════════

	function showBrowse():Void {
		screenState = Browse;
		hideDetail();
		hideProgress();

		titleText.visible = true;
		subtitleText.visible = true;
		pageText.visible = true;

		subtitleText.text = '${allPacks.length} modpack mevcut';
		controlsText.text = "[↑/↓/←/→] Kart Seç  |  [ENTER] Detay  |  [ESC] Geri";
		refreshCards();
	}

	function refreshCards():Void {
		var startIdx:Int = pageIndex * CARDS_PER_PAGE;

		for (i in 0...CARDS_PER_PAGE) {
			var packIdx:Int = startIdx + i;
			var hasPack:Bool = packIdx < allPacks.length;

			cardBg[i].visible = hasPack;
			cardBorder[i].visible = hasPack;
			cardName[i].visible = hasPack;
			cardTier[i].visible = hasPack;
			cardThumb[i].visible = false;
			cardThumbText[i].visible = hasPack;
			cardDownloads[i].visible = hasPack;

			if (!hasPack) continue;

			var mp:Dynamic = allPacks[packIdx];
			var tierId:String = mp.tier != null ? mp.tier : (mp.id != null ? mp.id : "");
			var tierColor:Int = ModpackTier.colorFor(tierId);

			cardBorder[i].color = tierColor;
			cardName[i].text = mp.displayName != null ? mp.displayName : mp.id;
			cardTier[i].text = '[${ModpackTier.labelFor(tierId)}]';
			cardTier[i].color = tierColor;
			cardDownloads[i].text = "TOPLAM İNDİRMELER: ...";

			// Görsel yükle (cache varsa anında, yoksa indir)
			var thumbUrl:String = mp.thumbnail != null ? mp.thumbnail : "";
			if (thumbUrl.length > 0) {
				cardThumbText[i].text = "Görsel yükleniyor...";
				loadThumbnail(Std.string(mp.id), thumbUrl, cardThumb[i], cardThumbText[i],
					Std.int(cardBg[i].width - 20), Std.int(cardBg[i].height - 82));
			} else {
				cardThumbText[i].text = "GÖRSEL YOK";
			}

			// Toplam indirmeler — MediaFire'dan (fallback: katalog)
			var mfUrl:String = ModpackLinkHelper.getMediafireUrl(mp) != null ? ModpackLinkHelper.getMediafireUrl(mp) : "";
			var catDownloads:Int = ModpackLinkHelper.getCatalogDownloads(mp);
			MediafireStats.getDownloadCount(Std.string(mp.id), mfUrl, catDownloads, function(count:Int, source:String) {
				if (screenState == Browse)
					cardDownloads[i].text = "TOPLAM İNDİRMELER: " + formatNumber(count);
			});
		}

		pageText.text = pageCount > 1 ? 'Sayfa ${pageIndex + 1} / $pageCount   [Q/E] Sayfa' : "";
		updateSelectorPos();
	}

	function updateSelectorPos():Void {
		var visibleCount:Int = Std.int(Math.min(CARDS_PER_PAGE, allPacks.length - pageIndex * CARDS_PER_PAGE));
		if (visibleCount <= 0) {
			selector.visible = false;
			return;
		}

		// selectedIndex'i bu sayfadaki geçerli aralığa kilitle
		if (selectedIndex >= visibleCount) selectedIndex = visibleCount - 1;
		if (selectedIndex < 0) selectedIndex = 0;

		selector.visible = true;

		var gap:Int = 14;
		var marginX:Int = 26;
		var marginY:Int = 86;
		var cardW:Int = Std.int((FlxG.width - marginX * 2 - gap) / GRID_COLS);
		var cardH:Int = Std.int((FlxG.height - 120 - marginY - gap) / 2);

		var col:Int = selectedIndex % GRID_COLS;
		var row:Int = Std.int(selectedIndex / GRID_COLS);
		selector.x = marginX - 3 + col * (cardW + gap);
		selector.y = marginY - 3 + row * (cardH + gap);
	}

	// ═════════════════════════════════════════════
	//  THUMBNAIL (uzaktan görsel + cache)
	// ═════════════════════════════════════════════

	function thumbCachePath(packId:String):String {
		return ModpackPaths.getDownloadDirectory() + "thumb-" + packId + ".png";
	}

	function loadThumbnail(packId:String, url:String, target:FlxSprite, placeholder:FlxText, fitW:Int, fitH:Int):Void {
		#if sys
		var cachePath:String = thumbCachePath(packId);

		if (sys.FileSystem.exists(cachePath)) {
			applyThumbnail(cachePath, target, placeholder, fitW, fitH);
			return;
		}

		// Cache yok → indir
		downloader.download(url, cachePath, {
			onComplete: function(path:String) {
				applyThumbnail(path, target, placeholder, fitW, fitH);
			},
			onError: function(_err:String) {
				if (placeholder != null) placeholder.text = "GÖRSEL İNDİRİLEMEDİ";
			},
			onProgress: null,
			onCancelled: null
		});
		#else
		if (placeholder != null) placeholder.text = "GÖRSEL YOK";
		#end
	}

	function applyThumbnail(path:String, target:FlxSprite, placeholder:FlxText, fitW:Int, fitH:Int):Void {
		#if sys
		try {
			var bytes:haxe.io.Bytes = sys.io.File.getBytes(path);
			// OpenFL 9: BitmapData.loadFromBytes bir Future döndürür (async).
			var future = BitmapData.loadFromBytes(bytes);
			future.onComplete(function(bmp:BitmapData) {
				try {
					target.loadGraphic(bmp);
					target.setGraphicSize(fitW, fitH);
					target.updateHitbox();
					target.antialiasing = true;
					target.visible = true;
					if (placeholder != null) placeholder.visible = false;
				} catch (e2:Dynamic) {
					trace('[ModpackStore] Görsel uygulanamadı: $path — ${Std.string(e2)}');
					if (placeholder != null) placeholder.text = "GÖRSEL OKUNAMADI";
				}
			});
		} catch (e:Dynamic) {
			trace('[ModpackStore] Görsel yüklenemedi: $path — ${Std.string(e)}');
			if (placeholder != null) placeholder.text = "GÖRSEL OKUNAMADI";
		}
		#end
	}

	// ═════════════════════════════════════════════
	//  DETAY EKRANI
	// ═════════════════════════════════════════════

	function openDetail(index:Int):Void {
		var packIdx:Int = pageIndex * CARDS_PER_PAGE + index;
		if (packIdx < 0 || packIdx >= allPacks.length) return;

		currentPack = allPacks[packIdx];
		screenState = Detail;
		includeOffset = 0;
		selectedLink = -1;
		hoveredLink = -1;

		titleText.visible = false;
		subtitleText.visible = false;
		pageText.visible = false;
		for (i in 0...CARDS_PER_PAGE) {
			cardBg[i].visible = false;
			cardBorder[i].visible = false;
			cardName[i].visible = false;
			cardTier[i].visible = false;
			cardThumb[i].visible = false;
			cardThumbText[i].visible = false;
			cardDownloads[i].visible = false;
		}
		selector.visible = false;

		detailBg.visible = true;
		detailName.visible = true;
		detailUpdated.visible = true;
		detailMeta.visible = true;
		includesTitle.visible = true;
		scrollTrack.visible = true;
		scrollThumb.visible = true;
		linksTitle.visible = true;

		var mp:Dynamic = currentPack;
		var tierId:String = mp.tier != null ? mp.tier : (mp.id != null ? mp.id : "");
		var tierColor:Int = ModpackTier.colorFor(tierId);

		detailName.text = mp.displayName != null ? mp.displayName : mp.id;
		detailName.color = tierColor;
		detailUpdated.text = 'SON GÜNCELLEME: ${mp.updatedAt != null ? mp.updatedAt : "bilinmiyor"}';
		var sizePart:String = mp.fileSize != null ? mp.fileSize : "?";
		var modPart:String = mp.modCount != null ? '${mp.modCount} mod' : "";
		var tierPart:String = ModpackTier.labelFor(tierId);
		detailMeta.text = '[$tierPart]  •  $sizePart  •  $modPart  •  ${mp.author != null ? mp.author : ""}';

		// Görsel
		detailImage.visible = false;
		var imgW:Int = Std.int((FlxG.width - 60) * 0.42);
		var imgH:Int = FlxG.height - 96 - 30 - 30;
		var thumbUrl:String = mp.thumbnail != null ? mp.thumbnail : "";
		if (thumbUrl.length > 0) {
			detailImageText.visible = true;
			detailImageText.text = "Görsel yükleniyor...";
			loadThumbnail(Std.string(mp.id), thumbUrl, detailImage, detailImageText, imgW, imgH);
		} else {
			detailImageText.visible = true;
			detailImageText.text = "GÖRSEL YOK";
		}

		// İçerik listesi
		includeLines = ModpackLinkHelper.getIncludes(mp);
		if (includeLines.length == 0) includeLines = ["(içerik listesi yok)"];

		var listTop:Int = 96 + 116;
		var listH:Int = (FlxG.height - 56 - listTop) - 150;
		includeMaxVisible = Std.int(Math.max(1, listH / 20));
		includeOffset = 0;
		refreshIncludeList();

		// Linkler
		var mfUrl:Null<String> = ModpackLinkHelper.getMediafireUrl(mp);
		var ghUrl:Null<String> = ModpackLinkHelper.getGithubUrl(mp);

		expectedBytes = mp.fileSizeBytes != null ? mp.fileSizeBytes : -1;

		setLinkRow(0, mfUrl, "MediaFire");
		setLinkRow(1, ghUrl, "GitHub");

		controlsText.text = "[1] MediaFire  [2] GitHub  |  [ENTER] Seçili  |  [ESC] Geri";
	}

	var includeLines:Array<String> = [];

	function setLinkRow(idx:Int, url:Null<String>, name:String):Void {
		var hasLink:Bool = url != null && url.length > 0;
		linkRow[idx].visible = hasLink;
		linkLogo[idx].visible = hasLink;
		linkLogoText[idx].visible = hasLink;
		linkLabel[idx].visible = hasLink;
		linkText[idx].visible = hasLink;

		if (!hasLink) {
			if (selectedLink == idx) selectedLink = -1;
			return;
		}

		if (selectedLink == -1) selectedLink = idx;
		linkText[idx].text = ModpackLinkHelper.shortUrl(url);
	}

	function refreshIncludeList():Void {
		// Eski satırları temizle
		for (t in includeTexts) {
			remove(t, true);
			t.destroy();
		}
		includeTexts = [];

		var rightX:Int = 30 + Std.int((FlxG.width - 60) * 0.42) + 34;
		var rightW:Int = FlxG.width - rightX - 30;
		var listTop:Int = 96 + 116;
		var maxOffset:Int = Std.int(Math.max(0, includeLines.length - includeMaxVisible));
		if (includeOffset > maxOffset) includeOffset = maxOffset;
		if (includeOffset < 0) includeOffset = 0;

		var endIdx:Int = Std.int(Math.min(includeLines.length, includeOffset + includeMaxVisible));
		for (i in includeOffset...endIdx) {
			var line:FlxText = new FlxText(rightX, listTop + (i - includeOffset) * 20, rightW - 24, "• " + includeLines[i], 12);
			line.setFormat("VCR OSD Mono", 12, 0xFFCBD5E1, LEFT);
			add(line);
			includeTexts.push(line);
		}

		// Scrollbar
		if (includeLines.length > includeMaxVisible) {
			var trackH:Int = (FlxG.height - 56 - listTop) - 150;
			var thumbH:Int = Std.int(Math.max(18, trackH * (includeMaxVisible / includeLines.length)));
			var thumbY:Float = listTop + (trackH - thumbH) * (includeOffset / maxOffset);
			scrollThumb.visible = true;
			scrollThumb.y = thumbY;
			scrollThumb.makeGraphic(4, thumbH, ACCENT);
		} else {
			scrollThumb.visible = false;
		}
	}

	function scrollIncludes(dir:Int):Void {
		var maxOffset:Int = Std.int(Math.max(0, includeLines.length - includeMaxVisible));
		var newOffset:Int = Std.int(Math.max(0, Math.min(maxOffset, includeOffset + dir)));
		if (newOffset != includeOffset) {
			includeOffset = newOffset;
			refreshIncludeList();
		}
	}

	function hideDetail():Void {
		detailBg.visible = false;
		detailImage.visible = false;
		detailImageText.visible = false;
		detailName.visible = false;
		detailUpdated.visible = false;
		detailMeta.visible = false;
		includesTitle.visible = false;
		scrollTrack.visible = false;
		scrollThumb.visible = false;
		linksTitle.visible = false;
		for (i in 0...2) {
			linkRow[i].visible = false;
			linkLogo[i].visible = false;
			linkLogoText[i].visible = false;
			linkLabel[i].visible = false;
			linkText[i].visible = false;
		}
	}

	// ═════════════════════════════════════════════
	//  İNDİRME YÖNTEMİ SEÇİMİ
	// ═════════════════════════════════════════════

	function openMethodPicker(link:String):Void {
		if (link == null || link.length == 0) {
			showError("Bu kaynaktan indirme linki yok.");
			return;
		}

		var packName:String = currentPack != null && currentPack.displayName != null ? currentPack.displayName : "Modpack";

		openSubState(new PickDownloadMethodSubState(packName, function(method:String) {
			if (method == "auto") {
				startPackDownload(link);
			} else {
				FlxG.openURL(link);
				FlxG.sound.play(Paths.sound('confirmMenu'));
				showBrowse();
			}
		}));
	}

	// ═════════════════════════════════════════════
	//  İNDİRME / KURULUM
	// ═════════════════════════════════════════════

	function startPackDownload(link:String):Void {
		if (currentPack == null) return;

		var mp:Dynamic = currentPack;
		var packId:String = mp.id != null ? mp.id : "unknown";
		var version:String = mp.version != null ? mp.version : "0";
		var displayName:String = mp.displayName != null ? mp.displayName : packId;
		var fileName:String = '$packId-v$version.zip';
		var savePath:String = ModpackPaths.getDownloadDirectory() + fileName;

		hideDetail();
		screenState = Downloading;
		showProgress();
		phaseText.text = "İndiriliyor...";
		phaseText.color = FlxColor.WHITE;
		phaseText.visible = true;
		subtitleText.visible = true;
		subtitleText.text = displayName;
		targetProgress = 0;
		currentProgress = 0;
		controlsText.text = "[ESC] İptal";

		downloader.smartDownload(link, savePath, {
			onProgress: function(progress:DownloadProgress) {
				targetProgress = progress.percent;
				var dlMB:Float = progress.downloadedBytes / (1024 * 1024);
				var totMB:Float = progress.totalBytes > 0 ? progress.totalBytes / (1024 * 1024) : 0;

				if (totMB > 0)
					sizeText.text = '${formatMB(dlMB)} / ${formatMB(totMB)} MB';
				else
					sizeText.text = '${formatMB(dlMB)} MB';

				if (progress.speed > 0) {
					if (progress.speed > 1024 * 1024)
						speedText.text = '${formatMB(progress.speed / (1024 * 1024))} MB/s';
					else
						speedText.text = '${Math.round(progress.speed / 1024)} KB/s';
				}
			},
			onComplete: function(path:String) {
				startPackInstall(path, packId, displayName);
			},
			onError: function(error:String) {
				showError('İndirme hatası:\n$error');
			},
			onCancelled: function() {
				showBrowse();
			}
		}, expectedBytes);
	}

	function startPackInstall(zipPath:String, packId:String, displayName:String):Void {
		screenState = Installing;
		phaseText.text = "Kuruluyor...";
		phaseText.color = FlxColor.WHITE;
		subtitleText.text = displayName;
		targetProgress = 0;
		currentProgress = 0;
		speedText.text = "";

		installer.install(zipPath, packId, {
			onProgress: function(progress:ModpackInstallProgress) {
				targetProgress = progress.overallProgress;
				sizeText.text = progress.message;
			},
			onComplete: function(manifest:ModpackManifest) {
				#if sys
				try {
					if (sys.FileSystem.exists(zipPath))
						sys.FileSystem.deleteFile(zipPath);
				} catch (_) {}
				#end
				showPackComplete(manifest);
			},
			onError: function(error:String) {
				showError('Kurulum hatası:\n$error');
			},
			onWarning: function(warning:String) {
				trace('[ModpackStore] Uyarı: $warning');
			},
			onCancelled: function() {
				showBrowse();
			}
		});
	}

	function startUninstall():Void {
		if (currentPack == null) return;

		var mp:Dynamic = currentPack;
		var packId:String = mp.id != null ? mp.id : "";
		if (packId.length == 0 || !installer.isInstalled(packId)) return;

		var displayName:String = mp.displayName != null ? mp.displayName : packId;

		hideDetail();
		screenState = Uninstalling;
		showProgress();
		targetProgress = 0;
		currentProgress = 0;
		phaseText.text = "Kaldırılıyor...";
		phaseText.color = FlxColor.WHITE;
		phaseText.visible = true;
		subtitleText.visible = true;
		subtitleText.text = displayName;
		sizeText.text = "Paket kaldırılıyor, lütfen bekleyin...";
		speedText.text = "";
		controlsText.text = "";

		installer.uninstall(packId, {
			onComplete: function(manifest:ModpackManifest) {
				targetProgress = 1.0;
				currentProgress = 1.0;
				phaseText.text = "Kaldırıldı!";
				phaseText.color = 0xFFEF4444;
				subtitleText.text = '${manifest.displayName} kaldırıldı';
				sizeText.text = '${manifest.modFolders.length} mod silindi';
				speedText.text = "";
				controlsText.text = "[ENTER] Listeye Dön  |  [ESC] Ana Menü";
				screenState = Complete;
			},
			onError: function(error:String) {
				showError('Kaldırma hatası:\n$error');
			},
			onWarning: function(warning:String) {
				trace('[ModpackStore] Uyarı: $warning');
			},
			onCancelled: function() {
				showBrowse();
			}
		});
	}

	function showPackComplete(manifest:ModpackManifest):Void {
		screenState = Complete;
		FlxG.sound.play(Paths.sound('confirmMenu'));

		// Güncelleme bayrağını tazele — bu paket güncellendi; hâlâ güncelleme
		// kalan paket varsa rozet ana menüde görünmeye devam eder.
		UpdateChecker.instance.fetchModpackList(function(result:backend.update.UpdateChecker.CheckResult)
		{
			UpdateChecker.instance.hasPendingModpackUpdates = (result != null && result.hasUpdates);
		});

		phaseText.text = "Tamamlandı!";
		phaseText.color = 0xFF22C55E;
		subtitleText.text = '${manifest.displayName} v${manifest.version} kuruldu';

		targetProgress = 1.0;
		currentProgress = 1.0;
		percentText.text = "100%";
		sizeText.text = '${manifest.modFolders.length} mod kuruldu';
		speedText.text = "";
		controlsText.text = "[ENTER] Listeye Dön  |  [ESC] Ana Menü";
	}

	// ═════════════════════════════════════════════
	//  PROGRESS / HATA
	// ═════════════════════════════════════════════

	function showProgress():Void {
		barBorder.visible = true;
		barBg.visible = true;
		barFill.visible = true;
		percentText.visible = true;
		sizeText.visible = true;
		speedText.visible = true;
	}

	function hideProgress():Void {
		barBorder.visible = false;
		barBg.visible = false;
		barFill.visible = false;
		percentText.visible = false;
		sizeText.visible = false;
		speedText.visible = false;
	}

	function showError(msg:String):Void {
		screenState = Error;
		loadingText.visible = false;
		hideDetail();
		hideProgress();

		titleText.visible = true;
		titleText.text = "HATA!";
		titleText.color = 0xFFEF4444;
		subtitleText.visible = false;
		pageText.visible = false;

		errorText.text = msg;
		errorText.screenCenter();
		errorText.y += 30;
		errorText.visible = true;
		controlsText.text = "[ENTER] Tekrar Dene  |  [ESC] Ana Menü";
	}

	// ═════════════════════════════════════════════
	//  UPDATE
	// ═════════════════════════════════════════════

	override function update(elapsed:Float):Void {
		super.update(elapsed);

		// Loading animasyonu
		if (screenState == Loading) {
			loadingTimer += elapsed;
			if (loadingTimer >= 0.4) {
				loadingTimer = 0;
				loadingDots = (loadingDots + 1) % 4;
				var dots:String = "";
				for (i in 0...loadingDots) dots += ".";
				loadingText.text = 'Mağaza yükleniyor$dots';
			}
		}

		// Progress bar animasyonu
		if (barFill.visible) {
			currentProgress += (targetProgress - currentProgress) * elapsed * 8;
			if (Math.abs(currentProgress - targetProgress) < 0.001)
				currentProgress = targetProgress;

			var barW:Int = FlxG.width - 58;
			var fillW:Int = Std.int(Math.max(1, barW * currentProgress));
			var barColor:Int = screenState == Installing ? 0xFF3B82F6 : ACCENT;
			barFill.makeGraphic(fillW, 18, barColor);
			percentText.text = '${Math.round(currentProgress * 100)}%';
		}

		switch (screenState) {
			case Loading:
				if (controls.BACK) goToMainMenu();

			case Browse:
				handleBrowseInput();

			case Detail:
				handleDetailInput();

			case Downloading | Installing:
				if (controls.BACK) {
					downloader.cancel();
					installer.cancel();
					showBrowse();
				}

			case Uninstalling:
				if (controls.BACK) FlxG.sound.play(Paths.sound('cancelMenu'));

			case Complete:
				if (controls.ACCEPT) {
					hideProgress();
					titleText.text = "MODPACK MAĞAZASI";
					titleText.color = FlxColor.WHITE;
					showBrowse();
				}
				if (controls.BACK) goToMainMenu();

			case Error:
				if (controls.ACCEPT) {
					errorText.visible = false;
					titleText.text = "MODPACK MAĞAZASI";
					titleText.color = FlxColor.WHITE;
					fetchStore();
				}
				if (controls.BACK) goToMainMenu();
		}
	}

	function handleBrowseInput():Void {
		if (controls.BACK) {
			goToMainMenu();
			return;
		}

		var visibleCount:Int = Std.int(Math.min(CARDS_PER_PAGE, allPacks.length - pageIndex * CARDS_PER_PAGE));
		if (visibleCount <= 0) return;

		// Sayfa değiştir (paketler 4'ten fazlaysa)
		if (pageCount > 1) {
			if (FlxG.keys.justPressed.Q) {
				pageIndex = (pageIndex - 1 + pageCount) % pageCount;
				selectedIndex = 0;
				refreshCards();
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (FlxG.keys.justPressed.E) {
				pageIndex = (pageIndex + 1) % pageCount;
				selectedIndex = 0;
				refreshCards();
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
		}

		// Grid navigasyon
		var prevIndex:Int = selectedIndex;
		if (controls.UI_UP_P) selectedIndex -= GRID_COLS;
		if (controls.UI_DOWN_P) selectedIndex += GRID_COLS;
		if (controls.UI_LEFT_P && selectedIndex % GRID_COLS > 0) selectedIndex--;
		if (controls.UI_RIGHT_P && selectedIndex % GRID_COLS < GRID_COLS - 1) selectedIndex++;

		// Sınırlara kilitle (sayfadaki görünür kart sayısına göre)
		var maxRowIndex:Int = visibleCount - 1;
		if (selectedIndex < 0) selectedIndex = 0;
		if (selectedIndex > maxRowIndex) selectedIndex = maxRowIndex;

		if (selectedIndex != prevIndex) {
			updateSelectorPos();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		// Mouse / dokunmatik
		for (i in 0...visibleCount) {
			if (cardBg[i].visible && FlxG.mouse.overlaps(cardBg[i])) {
				if (selectedIndex != i) {
					selectedIndex = i;
					updateSelectorPos();
				}
				if (FlxG.mouse.justPressed) {
					openDetail(i);
					return;
				}
			}
		}

		if (controls.ACCEPT) {
			openDetail(selectedIndex);
		}
	}

	function handleDetailInput():Void {
		if (controls.BACK) {
			showBrowse();
			return;
		}

		// İçerik listesi scroll (klavye)
		if (controls.UI_DOWN_P) scrollIncludes(1);
		if (controls.UI_UP_P) scrollIncludes(-1);

		// Mouse tekerleği
		if (FlxG.mouse.wheel != 0) {
			scrollIncludes(FlxG.mouse.wheel > 0 ? -1 : 1);
		}

		// Dokunmatik sürükleme (liste alanında)
		var listTop:Int = 96 + 116;
		var listH:Int = (FlxG.height - 56 - listTop) - 150;
		if (FlxG.mouse.justPressed) {
			dragList = FlxG.mouse.y > listTop && FlxG.mouse.y < listTop + listH;
			dragStartY = FlxG.mouse.y;
		}
		if (dragList && FlxG.mouse.pressed) {
			var delta:Float = FlxG.mouse.y - dragStartY;
			if (Math.abs(delta) > 8) {
				scrollIncludes(delta > 0 ? -1 : 1);
				dragStartY = FlxG.mouse.y;
			}
		}
		if (FlxG.mouse.justReleased) dragList = false;

		// Link satırı hover + tıklama
		for (i in 0...2) {
			if (!linkRow[i].visible) continue;
			if (FlxG.mouse.overlaps(linkRow[i])) {
				if (hoveredLink != i) {
					hoveredLink = i;
					linkRow[i].color = 0xFF1F2937;
				}
				if (FlxG.mouse.justPressed) {
					FlxG.sound.play(Paths.sound('confirmMenu'));
					var url:Null<String> = i == 0 ? ModpackLinkHelper.getMediafireUrl(currentPack) : ModpackLinkHelper.getGithubUrl(currentPack);
					openMethodPicker(url);
					return;
				}
			} else if (hoveredLink == i) {
				linkRow[i].color = 0xFF111827;
				hoveredLink = -1;
			}
		}

		// Klavye: [1] MediaFire  [2] GitHub
		if (FlxG.keys.justPressed.ONE || FlxG.keys.justPressed.NUMPADONE) {
			if (linkRow[0].visible) {
				selectedLink = 0;
				FlxG.sound.play(Paths.sound('confirmMenu'));
				openMethodPicker(ModpackLinkHelper.getMediafireUrl(currentPack));
			}
		}
		if (FlxG.keys.justPressed.TWO || FlxG.keys.justPressed.NUMPADTWO) {
			if (linkRow[1].visible) {
				selectedLink = 1;
				FlxG.sound.play(Paths.sound('confirmMenu'));
				openMethodPicker(ModpackLinkHelper.getGithubUrl(currentPack));
			}
		}

		// ENTER → seçili link
		if (controls.ACCEPT && selectedLink >= 0 && selectedLink < 2 && linkRow[selectedLink].visible) {
			var url:Null<String> = selectedLink == 0 ? ModpackLinkHelper.getMediafireUrl(currentPack) : ModpackLinkHelper.getGithubUrl(currentPack);
			openMethodPicker(url);
		}

		// [X] → kurulu paketi kaldır
		if (FlxG.keys.justPressed.X) {
			var packId:String = currentPack != null && currentPack.id != null ? currentPack.id : "";
			if (packId.length > 0 && installer.isInstalled(packId))
				startUninstall();
		}
	}

	// ═════════════════════════════════════════════
	//  YARDIMCILAR
	// ═════════════════════════════════════════════

	function goToMainMenu():Void {
		FlxG.sound.play(Paths.sound('cancelMenu'));
		FlxG.camera.fade(FlxColor.BLACK, 0.3, false, function() {
			backend.MenuStyleRouter.goToMainMenu();
		});
	}

	function formatNumber(n:Int):String {
		var s:String = Std.string(Math.max(0, n));
		var out:String = "";
		var count:Int = 0;
		for (i in (s.length - 1)...-1) {
			out = s.charAt(i) + out;
			count++;
			if (count % 3 == 0 && i > 0) out = "." + out;
		}
		return out;
	}

	function formatMB(mb:Float):String {
		if (mb >= 100) return '${Math.round(mb)}';
		else if (mb >= 10) return '${FlxMath.roundDecimal(mb, 1)}';
		else return '${FlxMath.roundDecimal(mb, 2)}';
	}
}

package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import openfl.display.BitmapData;
import openfl.events.KeyboardEvent;
import backend.update.UpdateChecker;
import backend.ClientPrefs;
import backend.modpack.ModpackPaths;
import backend.modpack.ModpackInstaller;
import backend.modpack.ModpackTypes;
import backend.modpack.ModpackTier;
import backend.modpack.MediafireStats;
import backend.modpack.ModpackLinkHelper;
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

class ModpackStoreState extends MusicBeatState {
	var allPacks:Array<Dynamic> = [];
	var displayList:Array<Dynamic> = []; // arama filtresi uygulanmış liste
	var cards:FlxTypedSpriteGroup<ModpackCard> = new FlxTypedSpriteGroup<ModpackCard>();
	var selectedIndex:Int = 0;
	var page:Int = 1;
	var totalPages:Int = 1;
	var currentPack:Dynamic = null;

	var searchString:String = "";
	var searchFocused:Bool = false;
	var searchBg:FlxSprite;
	var searchPlaceholder:FlxText;
	var searchInputText:FlxText;
	var searchCursor:FlxText;
	var cursorTimer:Float = 0;

	var downloader:DownloadManager;
	var installer:ModpackInstaller;

	var screenState:StoreScreenState = Loading;
	var currentProgress:Float = 0.0;
	var targetProgress:Float = 0.0;
	var loadingTimer:Float = 0.0;
	var loadingDots:Int = 0;

	var bg:FlxSprite;
	var titleText:FlxText;
	var pageInfo:FlxText;
	var pageTip1:FlxText;
	var pageTip2:FlxText;
	var controlsText:FlxText;
	var loadingText:FlxText;
	var errorText:FlxText;

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
	var includeLines:Array<String> = [];
	var includeOffset:Int = 0;
	var includeMaxVisible:Int = 10;
	var selectedLink:Int = 0;
	var hoveredLink:Int = -1;
	var dragList:Bool = false;
	var dragStartY:Float = 0.0;

	var barBorder:FlxSprite;
	var barBg:FlxSprite;
	var barFill:FlxSprite;
	var percentText:FlxText;
	var sizeText:FlxText;
	var speedText:FlxText;
	var phaseText:FlxText;

	static final GRID_COLS:Int = 3;
	static final CARDS_PER_PAGE:Int = 6; // 3 x 2
	static final CARD_W:Int = 300;
	static final CARD_H:Int = 220;
	static final CARD_GAP:Int = 22;
	static final GRID_TOP:Int = 150;
	static final GRID_BOTTOM_MARGIN:Int = 60;

	static final ACCENT:Int = 0xFFFFFFFF;

	override function create():Void {
		super.create();

		downloader = new DownloadManager();
		installer = new ModpackInstaller();

		// ── Arka plan (GameBanana: menuDesat renkli + coolLines) ──
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF1A1A1A;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, 0);
		add(bg);

		var lines:FlxSprite = new FlxSprite().loadGraphic(Paths.image('coolLines'));
		lines.screenCenter();
		lines.antialiasing = ClientPrefs.data.antialiasing;
		lines.scrollFactor.set(0, 0);
		lines.alpha = 0.25;
		add(lines);

		titleText = new FlxText(0, 18, FlxG.width, "MODPACK MAĞAZASI", 36);
		titleText.setFormat("VCR OSD Mono", 36, FlxColor.WHITE, CENTER);
		titleText.borderStyle = OUTLINE;
		titleText.borderColor = 0xFF000000;
		titleText.borderSize = 2;
		add(titleText);

		createSearchBar();

		add(cards);

		// ── Sayfa bilgisi + ipuçları (GameBanana tarzı) ──
		pageInfo = new FlxText(0, 0, FlxG.width);
		pageInfo.text = "< Sayfa 1 >";
		pageInfo.setFormat("VCR OSD Mono", 20, FlxColor.WHITE, CENTER);
		pageInfo.borderStyle = OUTLINE;
		pageInfo.borderColor = 0xFF000000;
		pageInfo.borderSize = 1.5;
		pageInfo.y = FlxG.height - pageInfo.height - 30;
		add(pageInfo);

		pageTip1 = new FlxText(20, 0, FlxG.width, "Q - Önceki sayfa");
		pageTip1.setFormat("VCR OSD Mono", 15, FlxColor.WHITE, LEFT);
		pageTip1.borderStyle = OUTLINE;
		pageTip1.borderColor = 0xFF000000;
		pageTip1.borderSize = 1.5;
		pageTip1.y = pageInfo.y;
		pageTip1.alpha = 0.6;
		add(pageTip1);

		pageTip2 = new FlxText(-20, 0, FlxG.width, "E - Sonraki sayfa");
		pageTip2.setFormat("VCR OSD Mono", 15, FlxColor.WHITE, RIGHT);
		pageTip2.borderStyle = OUTLINE;
		pageTip2.borderColor = 0xFF000000;
		pageTip2.borderSize = 1.5;
		pageTip2.y = pageInfo.y;
		pageTip2.alpha = 0.6;
		add(pageTip2);

		controlsText = new FlxText(0, FlxG.height - 26, FlxG.width, "", 11);
		controlsText.setFormat("VCR OSD Mono", 11, 0xFF777777, CENTER);
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

		createProgressUI();
		createDetailUI();

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onSearchKeyDown);

		FlxG.camera.fade(FlxColor.BLACK, 0.3, true);
		fetchStore();

		#if mobile
		pageTip1.text = "Y - Önceki sayfa";
		pageTip2.text = "Z - Sonraki sayfa";
		mobileManager.addMobilePad("LEFT_FULL", "A_B_C_X_Y_Z");
		mobileManager.addMobilePadCamera();
		#end
	}

	function createSearchBar():Void {
		var barW:Int = Std.int(Math.min(700, FlxG.width - 60));
		var barH:Int = 56;
		var barY:Int = 78;

		searchBg = new FlxSprite();
		searchBg.makeGraphic(barW, barH, FlxColor.BLACK);
		searchBg.screenCenter(X);
		searchBg.y = barY;
		searchBg.alpha = 0.7;
		add(searchBg);

		searchPlaceholder = new FlxText();
		searchPlaceholder.text = "Paket ara...";
		searchPlaceholder.setFormat("VCR OSD Mono", 18, FlxColor.WHITE, LEFT);
		searchPlaceholder.borderStyle = OUTLINE;
		searchPlaceholder.borderColor = 0xFF000000;
		searchPlaceholder.borderSize = 1.5;
		searchPlaceholder.alpha = 0.45;
		searchPlaceholder.x = searchBg.x + 16;
		searchPlaceholder.y = searchBg.y + searchBg.height / 2 - searchPlaceholder.height / 2;
		add(searchPlaceholder);

		searchInputText = new FlxText(searchPlaceholder.x, searchPlaceholder.y, Std.int(searchBg.width - 40), "", 18);
		searchInputText.setFormat("VCR OSD Mono", 18, FlxColor.WHITE, LEFT);
		searchInputText.borderStyle = OUTLINE;
		searchInputText.borderColor = 0xFF000000;
		searchInputText.borderSize = 1.5;
		add(searchInputText);

		searchCursor = new FlxText(searchPlaceholder.x, searchPlaceholder.y, 20, "|", 18);
		searchCursor.setFormat("VCR OSD Mono", 18, FlxColor.WHITE, LEFT);
		searchCursor.visible = false;
		add(searchCursor);
	}

	function createProgressUI():Void {
		var barY:Int = FlxG.height - 108;
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
	}

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
			loadingText.visible = false;
			showBrowse();
		});
	}

	//  BROWSE (kart grid + arama)

	function showBrowse():Void {
		screenState = Browse;
		hideDetail();
		hideProgress();

		titleText.visible = true;
		searchBg.visible = true;
		searchPlaceholder.visible = true;
		searchInputText.visible = true;
		pageInfo.visible = true;
		pageTip1.visible = true;
		pageTip2.visible = true;

		applySearchFilter(true);
	}

	function applySearchFilter(?resetPage:Bool = false):Void {
		var query:String = searchString.toLowerCase();

		if (query.length == 0)
			displayList = allPacks.copy();
		else
			displayList = allPacks.filter(function(mp:Dynamic):Bool {
				var name:String = mp.displayName != null ? Std.string(mp.displayName).toLowerCase() : "";
				var id:String = mp.id != null ? Std.string(mp.id).toLowerCase() : "";
				return name.indexOf(query) != -1 || id.indexOf(query) != -1;
			});

		totalPages = Std.int(Math.max(1, Math.ceil(displayList.length / CARDS_PER_PAGE)));
		if (resetPage || page > totalPages) page = 1;
		selectedIndex = 0;

		refreshCards();
	}

	function refreshCards():Void {
		for (card in cards.members)
		{
			if (card != null)
			{
				remove(card);
				card.destroy();
			}
		}
		cards.clear();
		cards = new FlxTypedSpriteGroup<ModpackCard>();
		add(cards);

		var startIdx:Int = (page - 1) * CARDS_PER_PAGE;
		var gridW:Int = GRID_COLS * CARD_W + (GRID_COLS - 1) * CARD_GAP;
		var startX:Float = (FlxG.width - gridW) / 2;

		var count:Int = Std.int(Math.min(CARDS_PER_PAGE, displayList.length - startIdx));
		for (i in 0...count)
		{
			var packIdx:Int = startIdx + i;
			if (packIdx >= displayList.length) break;

			var mp:Dynamic = displayList[packIdx];
			var col:Int = i % GRID_COLS;
			var row:Int = Std.int(i / GRID_COLS);
			var x:Float = startX + col * (CARD_W + CARD_GAP);
			var y:Float = GRID_TOP + row * (CARD_H + CARD_GAP);

			var card:ModpackCard = new ModpackCard(mp, packIdx, x, y, CARD_W, CARD_H);
			card.ID = packIdx;
			card.selected = (packIdx == selectedIndex);

			card.onDownloadPress = function() {
				if (currentPack == null) currentPack = mp;
				startCardDownload(mp);
			};
			card.onLinkPress = function() {
				openCardLink(mp);
			};

			cards.add(card);

			// Thumbnail (cache'ten, yoksa indir)
			var thumbUrl:String = mp.thumbnail != null ? Std.string(mp.thumbnail) : "";
			if (thumbUrl.length > 0)
				loadCardThumbnail(Std.string(mp.id), thumbUrl, card);
			else
				card.showFallback("GÖRSEL YOK");

			// İndirme sayısı (MediafireStats)
			var mfUrl:Null<String> = ModpackLinkHelper.getMediafireUrl(mp);
			var catDownloads:Int = ModpackLinkHelper.getCatalogDownloads(mp);
			MediafireStats.getDownloadCount(Std.string(mp.id), mfUrl != null ? mfUrl : "", catDownloads, function(count:Int, source:String) {
				if (card.exists)
					card.setDownloadCount(count);
			});
		}

		pageInfo.text = '< Sayfa $page / $totalPages >';
		if (displayList.length == 0)
			pageInfo.text = "Paket Bulunamadı!";

		#if mobile
		controlsText.text = "[D-Pad] Kart Seç  |  [A] Detay  |  [Y/Z] Sayfa  |  [B] Geri";
		#else
		controlsText.text = "[↑/↓/←/→] Kart Seç  |  [ENTER] Detay  |  [Q/E] Sayfa  |  [ESC] Geri";
		#end
	}

	function thumbCachePath(packId:String):String {
		return ModpackPaths.getDownloadDirectory() + "thumb-" + packId + ".png";
	}

	function loadCardThumbnail(packId:String, url:String, card:ModpackCard):Void {
		#if sys
		var cachePath:String = thumbCachePath(packId);

		if (sys.FileSystem.exists(cachePath)) {
			card.applyThumbFromFile(cachePath);
			return;
		}

		downloader.download(url, cachePath, {
			onComplete: function(path:String) {
				if (card.exists)
					card.applyThumbFromFile(path);
			},
			onError: function(_err:String) {
				if (card.exists)
					card.showFallback("GÖRSEL YOK");
			},
			onProgress: null,
			onCancelled: null
		});
		#else
		card.showFallback("GÖRSEL YOK");
		#end
	}

	function changeSelection(value:Int):Void {
		selectedIndex += value;

		if (selectedIndex >= displayList.length)
			selectedIndex = displayList.length - 1;
		else if (selectedIndex < 0)
			selectedIndex = 0;

		for (card in cards.members)
			if (card != null)
				card.selected = (card.ID == selectedIndex);

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
	}

	function changePage(value:Int):Void {
		var newPage:Int = page + value;
		if (newPage < 1 || newPage > totalPages) return;

		page = newPage;
		selectedIndex = (page - 1) * CARDS_PER_PAGE;
		refreshCards();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
	}

	// ── Kart aksiyonları ──

	function startCardDownload(mp:Dynamic):Void {
		var link:Null<String> = ModpackLinkHelper.getMediafireUrl(mp);
		if (link == null) link = ModpackLinkHelper.getGithubUrl(mp);

		if (link == null) {
			showError("İndirme linki bulunamadı.");
			return;
		}

		currentPack = mp;
		openMethodPicker(link);
	}

	function openCardLink(mp:Dynamic):Void {
		var link:Null<String> = ModpackLinkHelper.getGithubUrl(mp);
		if (link == null) link = ModpackLinkHelper.getMediafireUrl(mp);

		if (link == null) {
			showError("Link bulunamadı.");
			return;
		}

		FlxG.openURL(link);
		FlxG.sound.play(Paths.sound('confirmMenu'));
	}

	//  DETAY EKRANI (korunan)

	function createDetailUI():Void {
		var padX:Int = 30;
		var topY:Int = 96;
		var bottomY:Int = FlxG.height - 56;

		detailBg = new FlxSprite(0, topY - 10).makeGraphic(FlxG.width, bottomY - topY + 10, FlxColor.BLACK);
		detailBg.alpha = 0.7;
		detailBg.visible = false;
		add(detailBg);

		var imgW:Int = Std.int((FlxG.width - padX * 2) * 0.42);
		var imgH:Int = bottomY - topY - 30;

		detailImage = new FlxSprite(padX, topY + 10);
		detailImage.visible = false;
		add(detailImage);

		detailImageText = new FlxText(padX, topY + 10 + Std.int(imgH / 2) - 12, imgW, "", 14);
		detailImageText.setFormat("VCR OSD Mono", 14, 0xFF4B5563, CENTER);
		detailImageText.visible = false;
		add(detailImageText);

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

		scrollTrack = new FlxSprite(rightX + rightW - 8, listTop).makeGraphic(4, listH, 0xFF222222);
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
			var row = new FlxSprite(rightX, y).makeGraphic(rightW, 40, FlxColor.BLACK);
			row.alpha = 0.7;
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
			linkRow.push(label);

			var txt = new FlxText(rightX + 38, y + 18, rightW - 50, "", 10);
			txt.setFormat("VCR OSD Mono", 10, 0xFFCBD5E1, LEFT);
			txt.visible = false;
			add(txt);
			linkText.push(txt);
		}
	}

	function openDetail(index:Int):Void {
		if (index < 0 || index >= displayList.length) return;

		currentPack = displayList[index];
		screenState = Detail;
		includeOffset = 0;
		selectedLink = -1;
		hoveredLink = -1;

		titleText.visible = false;
		searchBg.visible = false;
		searchPlaceholder.visible = false;
		searchInputText.visible = false;
		pageInfo.visible = false;
		pageTip1.visible = false;
		pageTip2.visible = false;
		for (card in cards.members)
			if (card != null) card.visible = false;

		detailBg.visible = true;
		detailName.visible = true;
		detailUpdated.visible = true;
		detailMeta.visible = true;
		includesTitle.visible = true;
		scrollTrack.visible = true;
		scrollThumb.visible = true;
		linksTitle.visible = true;

		var mp:Dynamic = currentPack;
		var tierId:String = mp.tier != null ? Std.string(mp.tier) : (mp.id != null ? Std.string(mp.id) : "");
		var tierColor:Int = ModpackTier.colorFor(tierId);

		detailName.text = mp.displayName != null ? Std.string(mp.displayName) : Std.string(mp.id);
		detailName.color = tierColor;
		detailUpdated.text = 'SON GÜNCELLEME: ${mp.updatedAt != null ? Std.string(mp.updatedAt) : "bilinmiyor"}';
		var sizePart:String = mp.fileSize != null ? Std.string(mp.fileSize) : "?";
		var modPart:String = mp.modCount != null ? '${mp.modCount} mod' : "";
		var tierPart:String = ModpackTier.labelFor(tierId);
		detailMeta.text = '[$tierPart]  •  $sizePart  •  $modPart  •  ${mp.author != null ? Std.string(mp.author) : ""}';

		detailImage.visible = false;
		var imgW:Int = Std.int((FlxG.width - 60) * 0.42);
		var imgH:Int = FlxG.height - 96 - 30 - 30;
		var thumbUrl:String = mp.thumbnail != null ? Std.string(mp.thumbnail) : "";
		if (thumbUrl.length > 0) {
			detailImageText.visible = true;
			detailImageText.text = "Görsel yükleniyor...";
			loadDetailThumbnail(Std.string(mp.id), thumbUrl, imgW, imgH);
		} else {
			detailImageText.visible = true;
			detailImageText.text = "GÖRSEL YOK";
		}

		includeLines = ModpackLinkHelper.getIncludes(mp);
		if (includeLines.length == 0) includeLines = ["(içerik listesi yok)"];

		var listTop:Int = 96 + 116;
		var listH:Int = (FlxG.height - 56 - listTop) - 150;
		includeMaxVisible = Std.int(Math.max(1, listH / 20));
		includeOffset = 0;
		refreshIncludeList();

		var mfUrl:Null<String> = ModpackLinkHelper.getMediafireUrl(mp);
		var ghUrl:Null<String> = ModpackLinkHelper.getGithubUrl(mp);

		setLinkRow(0, mfUrl, "MediaFire");
		setLinkRow(1, ghUrl, "GitHub");

		#if mobile
		controlsText.text = "[A] Seçili link  |  [X] Kaldır  |  [B] Geri";
		#else
		controlsText.text = "[1] MediaFire  [2] GitHub  |  [ENTER] Seçili  |  [X] Kaldır  |  [ESC] Geri";
		#end
	}

	function loadDetailThumbnail(packId:String, url:String, fitW:Int, fitH:Int):Void {
		#if sys
		var cachePath:String = thumbCachePath(packId);

		if (sys.FileSystem.exists(cachePath)) {
			applyDetailThumb(cachePath, fitW, fitH);
			return;
		}

		downloader.download(url, cachePath, {
			onComplete: function(path:String) {
				applyDetailThumb(path, fitW, fitH);
			},
			onError: function(_err:String) {
				detailImageText.text = "GÖRSEL YOK";
			},
			onProgress: null,
			onCancelled: null
		});
		#else
		detailImageText.text = "GÖRSEL YOK";
		#end
	}

	function applyDetailThumb(path:String, fitW:Int, fitH:Int):Void {
		#if sys
		try {
			var bytes:haxe.io.Bytes = sys.io.File.getBytes(path);
			// OpenFL 9: Future döndürür (async)
			var future = BitmapData.loadFromBytes(bytes);
			future.onComplete(function(bmp:BitmapData) {
				try {
					detailImage.loadGraphic(bmp);
					detailImage.setGraphicSize(fitW, fitH);
					detailImage.updateHitbox();
					detailImage.antialiasing = true;
					detailImage.visible = true;
					detailImageText.visible = false;
				} catch (e2:Dynamic) {
					detailImageText.text = "GÖRSEL OKUNAMADI";
				}
			});
		} catch (e:Dynamic) {
			detailImageText.text = "GÖRSEL OKUNAMADI";
		}
		#end
	}

	function setLinkRow(idx:Int, url:Null<String>, name:String):Void {
		var hasLink:Bool = url != null && url.length > 0;
		linkRow[idx].visible = hasLink;
		linkLogo[idx].visible = hasLink;
		linkLogoText[idx].visible = hasLink;
		linkRow[idx + 2].visible = hasLink; // label (2. index)
		linkText[idx].visible = hasLink;

		if (!hasLink) {
			if (selectedLink == idx) selectedLink = -1;
			return;
		}

		if (selectedLink == -1) selectedLink = idx;
		linkText[idx].text = ModpackLinkHelper.shortUrl(url);
	}

	function refreshIncludeList():Void {
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
			linkRow[i + 2].visible = false;
			linkText[i].visible = false;
		}
	}

	//  İNDİRME YÖNTEMİ / KURULUM (korunan)

	function openMethodPicker(link:String):Void {
		if (link == null || link.length == 0) {
			showError("Bu kaynaktan indirme linki yok.");
			return;
		}

		var packName:String = currentPack != null && currentPack.displayName != null ? Std.string(currentPack.displayName) : "Modpack";

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

	function startPackDownload(link:String):Void {
		if (currentPack == null) return;

		var mp:Dynamic = currentPack;
		var packId:String = mp.id != null ? Std.string(mp.id) : "unknown";
		var version:String = mp.version != null ? Std.string(mp.version) : "0";
		var displayName:String = mp.displayName != null ? Std.string(mp.displayName) : packId;
		var fileName:String = '$packId-v$version.zip';
		var savePath:String = ModpackPaths.getDownloadDirectory() + fileName;

		hideDetail();
		screenState = Downloading;
		showProgress();
		phaseText.text = "İndiriliyor...";
		phaseText.color = FlxColor.WHITE;
		phaseText.visible = true;
		titleText.text = displayName;
		targetProgress = 0;
		currentProgress = 0;
		controlsText.text = "[ESC] İptal";

		var expectedBytes:Float = mp.fileSizeBytes != null ? mp.fileSizeBytes : -1;

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
		titleText.text = displayName;
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
		var packId:String = mp.id != null ? Std.string(mp.id) : "";
		if (packId.length == 0 || !installer.isInstalled(packId)) return;

		var displayName:String = mp.displayName != null ? Std.string(mp.displayName) : packId;

		hideDetail();
		screenState = Uninstalling;
		showProgress();
		targetProgress = 0;
		currentProgress = 0;
		phaseText.text = "Kaldırılıyor...";
		phaseText.color = FlxColor.WHITE;
		phaseText.visible = true;
		titleText.text = displayName;
		sizeText.text = "Paket kaldırılıyor, lütfen bekleyin...";
		speedText.text = "";
		controlsText.text = "";

		installer.uninstall(packId, {
			onComplete: function(manifest:ModpackManifest) {
				targetProgress = 1.0;
				currentProgress = 1.0;
				phaseText.text = "Kaldırıldı!";
				phaseText.color = 0xFFEF4444;
				titleText.text = '${manifest.displayName} kaldırıldı';
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

		UpdateChecker.instance.fetchModpackList(function(result:backend.update.UpdateChecker.CheckResult)
		{
			UpdateChecker.instance.hasPendingModpackUpdates = (result != null && result.hasUpdates);
		});

		phaseText.text = "Tamamlandı!";
		phaseText.color = 0xFF22C55E;
		titleText.text = '${manifest.displayName} v${manifest.version} kuruldu';

		targetProgress = 1.0;
		currentProgress = 1.0;
		percentText.text = "100%";
		sizeText.text = '${manifest.modFolders.length} mod kuruldu';
		speedText.text = "";
		controlsText.text = "[ENTER] Listeye Dön  |  [ESC] Ana Menü";
	}

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
		searchBg.visible = false;
		searchPlaceholder.visible = false;
		searchInputText.visible = false;
		pageInfo.visible = false;
		pageTip1.visible = false;
		pageTip2.visible = false;
		for (card in cards.members)
			if (card != null) card.visible = false;

		errorText.text = msg;
		errorText.screenCenter();
		errorText.y += 30;
		errorText.visible = true;
		controlsText.text = "[ENTER] Tekrar Dene  |  [ESC] Ana Menü";
	}

	//  Arama (klavye)

	function onSearchKeyDown(e:KeyboardEvent):Void {
		if (!searchFocused || screenState != Browse) return;

		var key:Int = e.keyCode;

		if (key == 27) // ESC
		{
			searchFocused = false;
			FlxG.stage.window.textInputEnabled = false;
			searchCursor.visible = false;
			return;
		}

		if (key == 13) // ENTER
		{
			searchFocused = false;
			FlxG.stage.window.textInputEnabled = false;
			searchCursor.visible = false;
			return;
		}

		if (key == 8) // BACKSPACE
		{
			if (searchString.length > 0)
			{
				searchString = searchString.substring(0, searchString.length - 1);
				updateSearchDisplay();
				applySearchFilter(true);
			}
			return;
		}

		if (key == 46) // DELETE
		{
			searchString = "";
			updateSearchDisplay();
			applySearchFilter(true);
			return;
		}

		// Ctrl+V paste desteği — charCode 0 olabilir, önce kontrol et
		if (key == 86 && e.ctrlKey)
		{
			var clipText:String = lime.system.Clipboard.text;
			if (clipText != null && clipText.length > 0)
			{
				searchString += clipText;
				updateSearchDisplay();
				applySearchFilter(true);
			}
			return;
		}

		if (e.charCode == 0) return;

		var newChar:String = String.fromCharCode(e.charCode);
		if (newChar.length > 0 && newChar != "\n" && newChar != "\r")
		{
			searchString += newChar;
			updateSearchDisplay();
			applySearchFilter(true);
		}
	}

	function updateSearchDisplay():Void {
		searchInputText.text = searchString;
		searchPlaceholder.visible = searchString.length == 0;
		searchCursor.x = searchInputText.x + searchInputText.textField.textWidth + 2;
		searchCursor.visible = searchFocused;
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);

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

		if (searchFocused) {
			cursorTimer += elapsed;
			if (cursorTimer >= 0.5) {
				cursorTimer = 0;
				searchCursor.visible = !searchCursor.visible;
			}
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
		if (controls.BACK && !searchFocused) {
			goToMainMenu();
			return;
		}

		// Arama çubuğuna tıklama → focus
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(searchBg)) {
			searchFocused = true;
			FlxG.stage.window.textInputEnabled = true;
			searchCursor.visible = true;
			updateSearchDisplay();
			return;
		}

		// Arama focus'ta: normal navigasyon kapalı
		if (searchFocused) {
			if (FlxG.mouse.justPressed && !FlxG.mouse.overlaps(searchBg)) {
				searchFocused = false;
				FlxG.stage.window.textInputEnabled = false;
				searchCursor.visible = false;
			}
			return;
		}

		if (displayList.length == 0) return;

		// Sayfalama: Q/E + Y/Z (mobil) + wheel
		if (FlxG.keys.justPressed.Q || FlxG.mouse.wheel > 0 #if mobile || mobileButtonJustPressed('Y') #end) changePage(-1);
		if (FlxG.keys.justPressed.E || FlxG.mouse.wheel < 0 #if mobile || mobileButtonJustPressed('Z') #end) changePage(1);

		// Grid navigasyonu (4 sütun)
		var prevIndex:Int = selectedIndex;
		if (controls.UI_LEFT_P) selectedIndex--;
		if (controls.UI_RIGHT_P) selectedIndex++;
		if (controls.UI_UP_P) selectedIndex -= GRID_COLS;
		if (controls.UI_DOWN_P) selectedIndex += GRID_COLS;

		if (selectedIndex < 0) selectedIndex = 0;
		if (selectedIndex >= displayList.length) selectedIndex = displayList.length - 1;

		if (selectedIndex != prevIndex) {
			for (card in cards.members)
				if (card != null)
					card.selected = (card.ID == selectedIndex);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		}

		// Mouse: kart hover → seç
		for (card in cards.members) {
			if (card == null || !card.visible) continue;
			if (FlxG.mouse.overlaps(card.bg)) {
				if (card.ID != selectedIndex) {
					selectedIndex = card.ID;
					for (c in cards.members)
						if (c != null)
							c.selected = (c.ID == selectedIndex);
				}
				// Fare ile kartın kendisine tıklama (butonlar değil) → detay
				if (FlxG.mouse.justPressed) {
					openDetail(card.ID);
					return;
				}
				break;
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

		if (controls.UI_DOWN_P) scrollIncludes(1);
		if (controls.UI_UP_P) scrollIncludes(-1);

		if (FlxG.mouse.wheel != 0)
			scrollIncludes(FlxG.mouse.wheel > 0 ? -1 : 1);

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

		if (controls.ACCEPT && selectedLink >= 0 && selectedLink < 2 && linkRow[selectedLink].visible) {
			var url:Null<String> = selectedLink == 0 ? ModpackLinkHelper.getMediafireUrl(currentPack) : ModpackLinkHelper.getGithubUrl(currentPack);
			openMethodPicker(url);
		}

		if (FlxG.keys.justPressed.X) {
			var packId:String = currentPack != null && currentPack.id != null ? Std.string(currentPack.id) : "";
			if (packId.length > 0 && installer.isInstalled(packId))
				startUninstall();
		}
	}

	function goToMainMenu():Void {
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onSearchKeyDown);
		FlxG.sound.play(Paths.sound('cancelMenu'));
		FlxG.camera.fade(FlxColor.BLACK, 0.3, false, function() {
			backend.MenuStyleRouter.goToMainMenu();
		});
	}

	function formatMB(mb:Float):String {
		if (mb >= 100) return '${Math.round(mb)}';
		else if (mb >= 10) return '${FlxMath.roundDecimal(mb, 1)}';
		else return '${FlxMath.roundDecimal(mb, 2)}';
	}
}

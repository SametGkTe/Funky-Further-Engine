package states.further;

import backend.further.DownloadHUD;
import backend.further.DownloadQueue;
import backend.further.GBClient;
import backend.further.TexturePackManager;
import backend.further.TexturePackTypes;
import backend.further.Theme;
import backend.further.ExtensionPackManager;
import backend.further.ExtensionPackManager.ECatalogEntry;

/**
 * Further Library — her şeyin ana kaynağı.
 * Tasarım: docs/design/further-library-mockup.html — "Rail + Grid + Slide-over".
 *
 * Faz 1: Texture Packs (yığın yönetimi) · Faz 2: Install Mods (GameBanana
 * tarayıcı + arka plan indirme kuyruğu) · Faz 4: Extension Packs (placeholder).
 * İNDİRİLENLER drawer'ı global DownloadHUD'dadır (her ekranda kalıcı sol buton).
 */
class FurtherLibraryState extends MusicBeatState
{
	static inline var RAIL_W:Int = 86;
	static inline var TOPBAR_H:Int = 68;
	static inline var DETAIL_W:Int = 340;
	static inline var CARD_W:Int = 228;
	static inline var CARD_H:Int = 128;
	static inline var CARD_GAP:Int = 16;
	static inline var GB_PERPAGE:Int = 12;

	static var TAB_SHORT:Array<String> = ['Packs', 'Mods', 'Ext'];
	static var FILTERS:Array<String> = ['Tümü', 'Etkin', 'Pasif'];

	var curTab:Int = 0;
	var curFilter:Int = 0;
	var curSelected:Int = 0;
	var leaving:Bool = false;

	// statik iskelet
	var tabBgs:Array<FlxSprite> = [];
	var tabTexts:Array<FlxText> = [];
	var chipBgs:Array<FlxSprite> = [];
	var chipTexts:Array<FlxText> = [];
	var fab:FlxSprite;
	var fabLabel:FlxText;
	var titleText:FlxText;
	var subText:FlxText;
	var stackLabel:FlxText;
	var gridLabel:FlxText;
	var searchInput:PsychUIInputText;
	var searchBtnBg:FlxSprite;
	var searchBtnText:FlxText;

	// dinamik katmanlar
	var stackSprites:Array<FlxSprite> = [];
	var gridSprites:Array<FlxSprite> = [];
	var detailSprites:Array<FlxSprite> = [];
	var hits:Array<LibHit> = [];
	var hoverSpr:FlxSprite;

	// Texture Packs
	var shown:Array<TexturePack> = [];

	// GameBanana (Install Mods)
	var gbItems:Array<GBModSummary> = [];
	var gbPage:Int = 1;
	var gbBusy:Bool = false;
	var gbError:String = '';
	var gbPopular:Bool = true;
	var gbSearch:String = '';
	var gbLoadedOnce:Bool = false;
	var gbPending:Bool = false;

	// Extension Packs
	var extCatalog:Array<ECatalogEntry> = null;
	var extBusy:Bool = false;
	var extError:String = '';
	var extLoadedOnce:Bool = false;

	override function create()
	{
		super.create();
		FlxG.mouse.visible = true;
		persistentUpdate = persistentDraw = true;
		DownloadQueue.addListener(onQueueMajor);

		buildSkeleton();
		refresh();
	}

	override function destroy()
	{
		DownloadQueue.removeListener(onQueueMajor);
		super.destroy();
	}

	function onQueueMajor():Void
	{
		// indirme durumu değişti (kurulum bitti/hata) — kartları tazele
		if (curTab == 1 || curTab == 2)
			refresh();
	}

	// ______________________________ İSKELET ______________________________

	function buildSkeleton():Void
	{
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('further/library_bg'));
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		// ---- Rail ----
		var rail:FlxSprite = new FlxSprite().makeGraphic(RAIL_W, FlxG.height, 0xCC0B0B10);
		rail.scrollFactor.set();
		add(rail);
		var railLine:FlxSprite = new FlxSprite(RAIL_W - 1).makeGraphic(1, FlxG.height, Theme.line);
		railLine.scrollFactor.set();
		add(railLine);

		var logo:FlxSprite = new FlxSprite(17, 14).makeGraphic(52, 52, Theme.accent);
		logo.scrollFactor.set();
		add(logo);
		var logoText:FlxText = new FlxText(17, 12, 52, "F", 34);
		logoText.setFormat(Paths.font("vcr.ttf"), 34, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		logoText.borderSize = 2;
		logoText.scrollFactor.set();
		add(logoText);

		for (i in 0...TAB_SHORT.length)
		{
			var ty:Float = 90 + i * 70;
			var tbg:FlxSprite = new FlxSprite(12, ty).makeGraphic(62, 62, (i == curTab) ? 0x24FF2E63 : Theme.card);
			tbg.scrollFactor.set();
			add(tbg);
			tabBgs.push(tbg);

			var t:FlxText = new FlxText(12, ty + 20, 62, TAB_SHORT[i], 14);
			t.setFormat(Paths.font("vcr.ttf"), 14, (i == curTab) ? Theme.accent : Theme.dim, CENTER);
			t.scrollFactor.set();
			add(t);
			tabTexts.push(t);
		}

		// ---- FAB (sol alt) → global İNDİRİLENLER drawer'ını açar ----
		fab = new FlxSprite(14, FlxG.height - 80).makeGraphic(58, 58, Theme.card);
		fab.scrollFactor.set();
		add(fab);
		var fabRing:FlxSprite = new FlxSprite(13, FlxG.height - 81).makeGraphic(60, 3, Theme.accent);
		fabRing.scrollFactor.set();
		add(fabRing);
		fabLabel = new FlxText(14, FlxG.height - 62, 58, "DL", 20);
		fabLabel.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		fabLabel.scrollFactor.set();
		add(fabLabel);

		// ---- Üst bar ----
		var topbar:FlxSprite = new FlxSprite(RAIL_W).makeGraphic(FlxG.width - RAIL_W, TOPBAR_H, 0xCC0B0B10);
		topbar.scrollFactor.set();
		add(topbar);
		var topLine:FlxSprite = new FlxSprite(RAIL_W, TOPBAR_H - 1).makeGraphic(FlxG.width - RAIL_W, 1, Theme.line);
		topLine.scrollFactor.set();
		add(topLine);

		// sag detay paneli (cam dokusu)
		var detailPanel:FlxSprite = new FlxSprite(FlxG.width - DETAIL_W, 0).loadGraphic(Paths.image('further/panel'));
		detailPanel.setGraphicSize(DETAIL_W, FlxG.height);
		detailPanel.updateHitbox();
		detailPanel.scrollFactor.set();
		add(detailPanel);

		// genel hover pariltisi (refresh sonunda en uste tasinir)
		hoverSpr = new FlxSprite().makeGraphic(1, 1, 0x2EFFFFFF);
		hoverSpr.scrollFactor.set();
		hoverSpr.visible = false;
		add(hoverSpr);

		titleText = new FlxText(RAIL_W + 22, 10, 0, "FURTHER LIBRARY", 20);
		titleText.setFormat(Paths.font("vcr.ttf"), 20, Theme.text, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set();
		add(titleText);
		subText = new FlxText(RAIL_W + 22, 38, 0, "TEXTURE PACKS", 12);
		subText.setFormat(Paths.font("vcr.ttf"), 12, Theme.dim, LEFT);
		subText.scrollFactor.set();
		add(subText);

		// ---- Sağ detay paneli ----
		var dBG:FlxSprite = new FlxSprite(FlxG.width - DETAIL_W, 0).makeGraphic(DETAIL_W, FlxG.height, Theme.panel);
		dBG.scrollFactor.set();
		add(dBG);
		var dLine:FlxSprite = new FlxSprite(FlxG.width - DETAIL_W, 0).makeGraphic(1, FlxG.height, Theme.line);
		dLine.scrollFactor.set();
		add(dLine);

		// ---- Etiketler + arama ----
		stackLabel = new FlxText(RAIL_W + 22, TOPBAR_H + 10, 0, "AKTIF YIGIN - ALTTAKI USTTEKINI EZIP GECER (DOSYA BAZLI)", 11);
		stackLabel.setFormat(Paths.font("vcr.ttf"), 11, Theme.dim, LEFT);
		stackLabel.scrollFactor.set();
		add(stackLabel);

		gridLabel = new FlxText(RAIL_W + 22, TOPBAR_H + 10, 0, "KATALOG", 11);
		gridLabel.setFormat(Paths.font("vcr.ttf"), 11, Theme.dim, LEFT);
		gridLabel.scrollFactor.set();
		add(gridLabel);
		gridLabel.visible = false;

		searchInput = new PsychUIInputText(RAIL_W + 22, TOPBAR_H + 32, 260, '', 14);
		searchInput.visible = false;
		add(searchInput);

		searchBtnBg = new FlxSprite(RAIL_W + 292, TOPBAR_H + 32).makeGraphic(64, 28, Theme.accent);
		searchBtnBg.scrollFactor.set();
		add(searchBtnBg);
		searchBtnText = new FlxText(RAIL_W + 292, TOPBAR_H + 38, 64, "ARA", 13);
		searchBtnText.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		searchBtnText.scrollFactor.set();
		add(searchBtnText);
		searchBtnBg.visible = searchBtnText.visible = false;
	}

	// ______________________________ YENİDEN İNŞA ______________________________

	function refresh():Void
	{
		hits = [];
		rebuildShown();
		rebuildChips();
		rebuildStackStrip();
		rebuildGrid();
		rebuildDetail();
		refreshChrome();
		// hover katmani her zaman en ustte
		if (hoverSpr != null)
		{
			remove(hoverSpr);
			add(hoverSpr);
		}
	}

	function chipLabels():Array<String>
	{
		return switch (curTab)
		{
			case 0: FILTERS;
			case 1: ['Populer', 'Yeni'];
			case 2: ['Kurulu', 'Katalog'];
			default: [];
		}
	}

	function rebuildChips():Void
	{
		while (chipBgs.length > 0)
		{
			var s:FlxSprite = chipBgs.pop();
			remove(s, true);
			s.destroy();
		}
		while (chipTexts.length > 0)
		{
			var t:FlxText = chipTexts.pop();
			remove(t, true);
			t.destroy();
		}

		var labels:Array<String> = chipLabels();
		var totalChipW:Float = 0;
		for (f in labels)
			totalChipW += f.length * 9 + 28;
		if (labels.length > 1)
			totalChipW += (labels.length - 1) * 8;

		var chipX:Float = FlxG.width - DETAIL_W - 14 - totalChipW;
		for (i in 0...labels.length)
		{
			var cw:Float = labels[i].length * 9 + 28;
			var active:Bool = (curTab == 1) ? (i == (gbPopular ? 0 : 1)) : (i == curFilter);
			var cbg:FlxSprite = new FlxSprite(chipX, 20).makeGraphic(Std.int(cw), 30, active ? Theme.text : Theme.card);
			cbg.scrollFactor.set();
			add(cbg);
			chipBgs.push(cbg);
			var ct:FlxText = new FlxText(chipX, 26, cw, labels[i], 13);
			ct.setFormat(Paths.font("vcr.ttf"), 13, active ? Theme.background : Theme.dim, CENTER);
			ct.scrollFactor.set();
			add(ct);
			chipTexts.push(ct);
			chipX += cw + 8;
		}
	}

	/** UI sırası: yığının tepesinden aşağı, sonra pasifler. */
	function rebuildShown():Void
	{
		shown = [];
		var order:Array<TexturePack> = [];
		var stackNow = TexturePackManager.getStackOrder();
		var i:Int = stackNow.length - 1;
		while (i >= 0)
		{
			var p:TexturePack = TexturePackManager.findPack(stackNow[i].id);
			if (p != null)
				order.push(p);
			i--;
		}
		for (p in order)
		{
			var on:Bool = TexturePackManager.isEnabled(p.id);
			if (curFilter == 0 || (curFilter == 1 && on) || (curFilter == 2 && !on))
				shown.push(p);
		}
		if (curSelected >= shown.length)
			curSelected = shown.length - 1;
		if (curSelected < 0)
			curSelected = 0;
	}

	function rebuildStackStrip():Void
	{
		wipe(stackSprites);
		var visible:Bool = (curTab == 0);
		stackLabel.visible = visible;
		if (!visible)
			return;

		var x:Float = RAIL_W + 22;
		var y:Float = TOPBAR_H + 30;
		var stackNow = TexturePackManager.getStackOrder();
		var placed:Int = 0;
		var i:Int = stackNow.length - 1;
		while (i >= 0)
		{
			var e = stackNow[i];
			var p:TexturePack = TexturePackManager.findPack(e.id);
			if (p != null)
			{
				var w:Int = 210;
				var c:FlxColor = (placed == 0) ? Theme.accent : Theme.card;
				if (e.enabled == false)
					c = 0xFF2A2A33;
				var cardBG:FlxSprite = new FlxSprite(x, y).makeGraphic(w, 54, c);
				cardBG.scrollFactor.set();
				addSprite(stackSprites, cardBG);

				var nm:FlxText = new FlxText(x + 10, y + 6, w - 60, p.displayName, 14);
				nm.setFormat(Paths.font("vcr.ttf"), 14, (e.enabled == false) ? Theme.dim : Theme.text, LEFT);
				nm.scrollFactor.set();
				addSprite(stackSprites, nm);

				var pos:FlxText = new FlxText(x + 10, y + 28, w - 60, (e.enabled == false) ? "PASIF" : ((placed == 0) ? "USTTE - KAZANAN" : "alt katman"), 11);
				pos.setFormat(Paths.font("vcr.ttf"), 11, (placed == 0 && e.enabled != false) ? FlxColor.WHITE : Theme.dim, LEFT);
				pos.scrollFactor.set();
				addSprite(stackSprites, pos);

				var upBG:FlxSprite = new FlxSprite(x + w - 42, y + 6).makeGraphic(30, 20, Theme.panel);
				upBG.scrollFactor.set();
				addSprite(stackSprites, upBG);
				var upT:FlxText = new FlxText(x + w - 42, y + 9, 30, "A", 12);
				upT.setFormat(Paths.font("vcr.ttf"), 12, Theme.text, CENTER);
				upT.scrollFactor.set();
				addSprite(stackSprites, upT);
				var dnBG:FlxSprite = new FlxSprite(x + w - 42, y + 28).makeGraphic(30, 20, Theme.panel);
				dnBG.scrollFactor.set();
				addSprite(stackSprites, dnBG);
				var dnT:FlxText = new FlxText(x + w - 42, y + 31, 30, "Z", 12);
				dnT.setFormat(Paths.font("vcr.ttf"), 12, Theme.text, CENTER);
				dnT.scrollFactor.set();
				addSprite(stackSprites, dnT);

				var eid:String = e.id;
				hits.push({x: x + w - 42, y: y + 6, w: 30, h: 20, cb: function() {
					TexturePackManager.moveUp(eid);
					refresh();
				}});
				hits.push({x: x + w - 42, y: y + 28, w: 30, h: 20, cb: function() {
					TexturePackManager.moveDown(eid);
					refresh();
				}});
				var pRef:TexturePack = p;
				hits.push({x: x, y: y, w: w - 44, h: 54, cb: function() {
					selectPack(pRef);
				}});

				x += w + 12;
				placed++;
			}
			i--;
		}
		if (placed == 0)
		{
			var empty:FlxText = new FlxText(x, y + 12, 500, "Henuz texture pack yok. further/texturepacks/ klasorune paket at veya asagidan kur.", 13);
			empty.setFormat(Paths.font("vcr.ttf"), 13, Theme.dim, LEFT);
			empty.scrollFactor.set();
			addSprite(stackSprites, empty);
		}
	}

	function shownGb():Array<GBModSummary>
	{
		if (gbSearch.length == 0)
			return gbItems;
		var needle:String = gbSearch.toLowerCase();
		var out:Array<GBModSummary> = [];
		for (s in gbItems)
			if (s.name.toLowerCase().indexOf(needle) != -1 || s.author.toLowerCase().indexOf(needle) != -1)
				out.push(s);
		return out;
	}

	function rebuildGrid():Void
	{
		wipe(gridSprites);

		// arama kutusu görünürlüğü
		searchInput.visible = (curTab == 1);
		searchBtnBg.visible = searchBtnText.visible = (curTab == 1);

		if (curTab == 2)
		{
			rebuildExtList();
			return;
		}

		if (curTab == 1)
		{
			rebuildGbGrid();
			return;
		}

		gridLabel.visible = true;
		gridLabel.text = "KURULU PAKETLER - further/texturepacks/ (yerel)";

		var areaX:Float = RAIL_W + 22;
		var areaW:Float = FlxG.width - RAIL_W - DETAIL_W - 44;
		var cols:Int = Std.int(areaW / (CARD_W + CARD_GAP));
		if (cols < 1)
			cols = 1;
		var startY:Float = TOPBAR_H + 170;

		for (i in 0...shown.length)
		{
			var p:TexturePack = shown[i];
			var col:Int = i % cols;
			var row:Int = Std.int(i / cols);
			var x:Float = areaX + col * (CARD_W + CARD_GAP);
			var y:Float = startY + row * (CARD_H + CARD_GAP);
			var on:Bool = TexturePackManager.isEnabled(p.id);
			var selected:Bool = (i == curSelected);

			var c:FlxColor = (i == 0) ? 0xFF1A1A21 : Theme.card;
			var cardBG:FlxSprite = new FlxSprite(x, y).loadGraphic(Paths.image(selected ? 'further/card_hover' : 'further/card'));
			cardBG.setGraphicSize(CARD_W, CARD_H);
			cardBG.updateHitbox();
			cardBG.scrollFactor.set();
			addSprite(gridSprites, cardBG);
			if (selected)
			{
				var sel:FlxSprite = new FlxSprite(x, y).makeGraphic(CARD_W, 3, Theme.accent);
				sel.scrollFactor.set();
				addSprite(gridSprites, sel);
			}

			var thumbCol:FlxColor = TexturePackManager.parseColor(p.manifest.accentColor) ?? 0xFF2A2A3A;
			var thumb:FlxSprite = new FlxSprite(x + 12, y + 12).makeGraphic(72, 72, thumbCol);
			thumb.scrollFactor.set();
			addSprite(gridSprites, thumb);
			var letter:FlxText = new FlxText(x + 12, y + 28, 72, p.displayName.substr(0, 1).toUpperCase(), 30);
			letter.setFormat(Paths.font("vcr.ttf"), 30, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			letter.scrollFactor.set();
			addSprite(gridSprites, letter);

			var nm:FlxText = new FlxText(x + 94, y + 14, CARD_W - 106, p.displayName, 15);
			nm.setFormat(Paths.font("vcr.ttf"), 15, Theme.text, LEFT);
			nm.scrollFactor.set();
			addSprite(gridSprites, nm);

			var meta:FlxText = new FlxText(x + 94, y + 38, CARD_W - 106, p.author + "  v" + p.version, 11);
			meta.setFormat(Paths.font("vcr.ttf"), 11, Theme.dim, LEFT);
			meta.scrollFactor.set();
			addSprite(gridSprites, meta);

			var pillBG:FlxSprite = new FlxSprite(x + 94, y + 60).makeGraphic(64, 22, on ? 0xFF1F3D2E : 0xFF2A2A33);
			pillBG.scrollFactor.set();
			addSprite(gridSprites, pillBG);
			var pillT:FlxText = new FlxText(x + 94, y + 64, 64, on ? "ETKIN" : "PASIF", 11);
			pillT.setFormat(Paths.font("vcr.ttf"), 11, on ? 0xFF3ED598 : Theme.dim, CENTER);
			pillT.scrollFactor.set();
			addSprite(gridSprites, pillT);

			var btnBG:FlxSprite = new FlxSprite(x + CARD_W - 92, y + CARD_H - 40).makeGraphic(80, 28, Theme.accent);
			btnBG.scrollFactor.set();
			addSprite(gridSprites, btnBG);
			var btnT:FlxText = new FlxText(x + CARD_W - 92, y + CARD_H - 36, 80, on ? "KAPAT" : "AC", 13);
			btnT.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			btnT.scrollFactor.set();
			addSprite(gridSprites, btnT);

			var pid:String = p.id;
			hits.push({x: x, y: y, w: CARD_W, h: CARD_H, cb: function() {
				selectGb(null);
				selectPack(TexturePackManager.findPack(pid));
			}});
			hits.push({x: x + CARD_W - 92, y: y + CARD_H - 40, w: 80, h: 28, cb: function() {
				TexturePackManager.setEnabled(pid, !TexturePackManager.isEnabled(pid));
				refresh();
			}});
		}

		if (shown.length == 0)
		{
			var empty:FlxText = new FlxText(areaX, startY + 20, areaW, "Paket bulunamadi.\n\nfurther/texturepacks/<paket>/ altina texturepack.json olan\nklasorler burada gorunur. Bkz: docs/TEXTUREPACK_TR.md", 15);
			empty.setFormat(Paths.font("vcr.ttf"), 15, Theme.dim, LEFT);
			empty.scrollFactor.set();
			addSprite(gridSprites, empty);
		}
	}

	function rebuildGbGrid():Void
	{
		gridLabel.visible = true;
		gridLabel.text = gbBusy ? "GAMABANA - YUKLENIYOR..." : ("GAMABANA - FNF MODLARI  (sayfa " + gbPage + ")");

		var areaX:Float = RAIL_W + 22;
		var areaW:Float = FlxG.width - RAIL_W - DETAIL_W - 44;
		var cols:Int = Std.int(areaW / (CARD_W + CARD_GAP));
		if (cols < 1)
			cols = 1;
		var startY:Float = TOPBAR_H + 80;

		if (gbError.length > 0)
		{
			var err:FlxText = new FlxText(areaX, startY, areaW, "HATA: " + gbError + "\n\nInternet baglantini kontrol et.", 14);
			err.setFormat(Paths.font("vcr.ttf"), 14, 0xFFFF5A5A, LEFT);
			err.scrollFactor.set();
			addSprite(gridSprites, err);
		}

		var list:Array<GBModSummary> = shownGb();
		if (curSelected >= list.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = 0;

		for (i in 0...list.length)
		{
			var s:GBModSummary = list[i];
			var col:Int = i % cols;
			var row:Int = Std.int(i / cols);
			var x:Float = areaX + col * (CARD_W + CARD_GAP);
			var y:Float = startY + row * (CARD_H + CARD_GAP);
			if (y > FlxG.height - CARD_H)
				continue;

			var c:FlxColor = (i == curSelected) ? 0xFF1A1A21 : Theme.card;
			var cardBG:FlxSprite = new FlxSprite(x, y).loadGraphic(Paths.image('further/card'));
			cardBG.setGraphicSize(CARD_W, CARD_H);
			cardBG.updateHitbox();
			cardBG.scrollFactor.set();
			addSprite(gridSprites, cardBG);
			if (i == curSelected)
			{
				var sel:FlxSprite = new FlxSprite(x, y).makeGraphic(CARD_W, 3, Theme.accent);
				sel.scrollFactor.set();
				addSprite(gridSprites, sel);
			}

			var thumb:FlxSprite = new FlxSprite(x + 12, y + 12).makeGraphic(72, 72, 0xFF2A2A3A);
			thumb.scrollFactor.set();
			addSprite(gridSprites, thumb);
			var letter:FlxText = new FlxText(x + 12, y + 28, 72, s.name.substr(0, 1).toUpperCase(), 30);
			letter.setFormat(Paths.font("vcr.ttf"), 30, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			letter.scrollFactor.set();
			addSprite(gridSprites, letter);

			var nm:FlxText = new FlxText(x + 94, y + 14, CARD_W - 106, s.name, 15);
			nm.setFormat(Paths.font("vcr.ttf"), 15, Theme.text, LEFT);
			nm.scrollFactor.set();
			addSprite(gridSprites, nm);

			var meta:FlxText = new FlxText(x + 94, y + 38, CARD_W - 106, s.author + "  " + (s.likes > 0 ? (Std.int(s.likes) + " begeni") : ""), 11);
			meta.setFormat(Paths.font("vcr.ttf"), 11, Theme.dim, LEFT);
			meta.scrollFactor.set();
			addSprite(gridSprites, meta);

			var cat:FlxText = new FlxText(x + 94, y + 58, CARD_W - 106, s.category, 11);
			cat.setFormat(Paths.font("vcr.ttf"), 11, Theme.dim, LEFT);
			cat.scrollFactor.set();
			addSprite(gridSprites, cat);

			var btnBG:FlxSprite = new FlxSprite(x + CARD_W - 92, y + CARD_H - 40).makeGraphic(80, 28, Theme.accent);
			btnBG.scrollFactor.set();
			addSprite(gridSprites, btnBG);
			var btnT:FlxText = new FlxText(x + CARD_W - 92, y + CARD_H - 36, 80, "INDIR", 13);
			btnT.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			btnT.scrollFactor.set();
			addSprite(gridSprites, btnT);

			var sRef:GBModSummary = s;
			hits.push({x: x, y: y, w: CARD_W, h: CARD_H, cb: function() {
				selectGb(sRef);
			}});
			hits.push({x: x + CARD_W - 92, y: y + CARD_H - 40, w: 80, h: 28, cb: function() {
				downloadGb(sRef);
			}});
		}

		if (list.length == 0 && !gbBusy && gbError.length == 0)
		{
			var empty:FlxText = new FlxText(areaX, startY + 20, areaW,
				gbLoadedOnce ? "Sonuc yok." : "GameBanana listeleniyor...", 15);
			empty.setFormat(Paths.font("vcr.ttf"), 15, Theme.dim, LEFT);
			empty.scrollFactor.set();
			addSprite(gridSprites, empty);
		}

		// sayfalama
		var py:Float = FlxG.height - 60;
		var px:Float = areaX;
		if (gbPage > 1)
		{
			var b1:FlxSprite = new FlxSprite(px, py).makeGraphic(110, 34, Theme.card);
			b1.scrollFactor.set();
			addSprite(gridSprites, b1);
			var b1t:FlxText = new FlxText(px, py + 9, 110, "ONCEKI", 14);
			b1t.setFormat(Paths.font("vcr.ttf"), 14, Theme.text, CENTER);
			b1t.scrollFactor.set();
			addSprite(gridSprites, b1t);
			hits.push({x: px, y: py, w: 110, h: 34, cb: function() {
				gbPage--;
				gbSearch = '';
				if (searchInput != null) searchInput.text = '';
				loadGb();
			}});
			px += 122;
		}
		var pg:FlxText = new FlxText(px, py + 9, 140, "SAYFA " + gbPage, 14);
		pg.setFormat(Paths.font("vcr.ttf"), 14, Theme.dim, CENTER);
		pg.scrollFactor.set();
		addSprite(gridSprites, pg);
		px += 150;

		var b2:FlxSprite = new FlxSprite(px, py).makeGraphic(110, 34, Theme.card);
		b2.scrollFactor.set();
		addSprite(gridSprites, b2);
		var b2t:FlxText = new FlxText(px, py + 9, 110, "SONRAKI", 14);
		b2t.setFormat(Paths.font("vcr.ttf"), 14, Theme.text, CENTER);
		b2t.scrollFactor.set();
		addSprite(gridSprites, b2t);
		hits.push({x: px, y: py, w: 110, h: 34, cb: function() {
			gbPage++;
			gbSearch = '';
			if (searchInput != null) searchInput.text = '';
			loadGb();
		}});

		// arama butonu
		hits.push({x: searchBtnBg.x, y: searchBtnBg.y, w: 64, h: 28, cb: function() {
			gbSearch = StringTools.trim(searchInput.text);
			curSelected = 0;
			refresh();
		}});
	}

	function rebuildDetail():Void
	{
		wipe(detailSprites);
		if (curTab == 1)
		{
			rebuildGbDetail();
			return;
		}
		if (curTab == 2)
		{
			rebuildExtDetail();
			return;
		}
		if (curTab != 0 || shown.length == 0)
			return;

		var p:TexturePack = shown[curSelected];
		var px:Float = FlxG.width - DETAIL_W + 20;

		var thumbCol:FlxColor = TexturePackManager.parseColor(p.manifest.accentColor) ?? 0xFF2A2A3A;
		var hero:FlxSprite = new FlxSprite(px, 24).makeGraphic(DETAIL_W - 40, 130, thumbCol);
		hero.scrollFactor.set();
		addSprite(detailSprites, hero);
		var heroL:FlxText = new FlxText(px, 58, DETAIL_W - 40, p.displayName.substr(0, 1).toUpperCase(), 48);
		heroL.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		heroL.scrollFactor.set();
		addSprite(detailSprites, heroL);

		var nm:FlxText = new FlxText(px, 170, DETAIL_W - 40, p.displayName, 22);
		nm.setFormat(Paths.font("vcr.ttf"), 22, Theme.text, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		nm.scrollFactor.set();
		addSprite(detailSprites, nm);

		var meta:FlxText = new FlxText(px, 202, DETAIL_W - 40, p.author + "  ·  v" + p.version, 13);
		meta.setFormat(Paths.font("vcr.ttf"), 13, Theme.dim, LEFT);
		meta.scrollFactor.set();
		addSprite(detailSprites, meta);

		var desc:String = p.description;
		if (desc == null || desc.length == 0)
			desc = "Aciklama yok.";
		var d:FlxText = new FlxText(px, 236, DETAIL_W - 40, desc, 14);
		d.setFormat(Paths.font("vcr.ttf"), 14, Theme.dim, LEFT);
		d.scrollFactor.set();
		addSprite(detailSprites, d);

		var on:Bool = TexturePackManager.isEnabled(p.id);
		var posText:String = stackPositionText(p.id);
		var pos:FlxText = new FlxText(px, 380, DETAIL_W - 40, "YIGIN: " + posText, 13);
		pos.setFormat(Paths.font("vcr.ttf"), 13, Theme.text, LEFT);
		pos.scrollFactor.set();
		addSprite(detailSprites, pos);

		var note:FlxText = new FlxText(px, 404, DETAIL_W - 40,
			"Kural: cakisan DOSYALAR yigin sirasiyla,\nTEMA (renk/font/muzik) her zaman yiginin\nen ustundeki paketten gelir.\nTam deneyim modlari pack.json'a\n\"ignoreTexturePacks\": true yazarak yigini\noturum boyunca askiya alabilir.", 12);
		note.setFormat(Paths.font("vcr.ttf"), 12, Theme.dim, LEFT);
		note.scrollFactor.set();
		addSprite(detailSprites, note);

		var b1:FlxSprite = new FlxSprite(px, FlxG.height - 150).makeGraphic(DETAIL_W - 40, 40, Theme.accent);
		b1.scrollFactor.set();
		addSprite(detailSprites, b1);
		var b1t:FlxText = new FlxText(px, FlxG.height - 140, DETAIL_W - 40, on ? "DEVRE DISI BIRAK" : "ETKINLESTIR", 16);
		b1t.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		b1t.scrollFactor.set();
		addSprite(detailSprites, b1t);
		var pid:String = p.id;
		hits.push({x: px, y: FlxG.height - 150, w: DETAIL_W - 40, h: 40, cb: function() {
			TexturePackManager.setEnabled(pid, !TexturePackManager.isEnabled(pid));
			refresh();
		}});

		var b2:FlxSprite = new FlxSprite(px, FlxG.height - 100).makeGraphic(Std.int((DETAIL_W - 52) / 2), 34, Theme.card);
		b2.scrollFactor.set();
		addSprite(detailSprites, b2);
		var b2t:FlxText = new FlxText(px, FlxG.height - 91, b2.width, "ONCELIK +", 14);
		b2t.setFormat(Paths.font("vcr.ttf"), 14, Theme.text, CENTER);
		b2t.scrollFactor.set();
		addSprite(detailSprites, b2t);
		hits.push({x: px, y: FlxG.height - 100, w: b2.width, h: 34, cb: function() {
			TexturePackManager.moveUp(pid);
			refresh();
		}});

		var b3:FlxSprite = new FlxSprite(px + b2.width + 12, FlxG.height - 100).makeGraphic(Std.int((DETAIL_W - 52) / 2), 34, Theme.card);
		b3.scrollFactor.set();
		addSprite(detailSprites, b3);
		var b3t:FlxText = new FlxText(b3.x, FlxG.height - 91, b3.width, "ONCELIK -", 14);
		b3t.setFormat(Paths.font("vcr.ttf"), 14, Theme.text, CENTER);
		b3t.scrollFactor.set();
		addSprite(detailSprites, b3t);
		hits.push({x: b3.x, y: FlxG.height - 100, w: b3.width, h: 34, cb: function() {
			TexturePackManager.moveDown(pid);
			refresh();
		}});
	}

	function rebuildGbDetail():Void
	{
		var list:Array<GBModSummary> = shownGb();
		if (list.length == 0)
			return;
		var s:GBModSummary = list[curSelected];
		if (s == null)
			return;
		var px:Float = FlxG.width - DETAIL_W + 20;

		var hero:FlxSprite = new FlxSprite(px, 24).makeGraphic(DETAIL_W - 40, 130, 0xFF2A2A3A);
		hero.scrollFactor.set();
		addSprite(detailSprites, hero);
		var heroL:FlxText = new FlxText(px, 58, DETAIL_W - 40, s.name.substr(0, 1).toUpperCase(), 48);
		heroL.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		heroL.scrollFactor.set();
		addSprite(detailSprites, heroL);

		var nm:FlxText = new FlxText(px, 170, DETAIL_W - 40, s.name, 22);
		nm.setFormat(Paths.font("vcr.ttf"), 22, Theme.text, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		nm.scrollFactor.set();
		addSprite(detailSprites, nm);

		var meta:FlxText = new FlxText(px, 202, DETAIL_W - 40, s.author + "  ·  " + s.category, 13);
		meta.setFormat(Paths.font("vcr.ttf"), 13, Theme.dim, LEFT);
		meta.scrollFactor.set();
		addSprite(detailSprites, meta);

		var d:FlxText = new FlxText(px, 236, DETAIL_W - 40,
			"GameBanana uzerinden indirilir.\n\n- Arka planda iner (oyun oynanabilir)\n- Zip otomatik kurulur: mods/<ad>/\n- MD5 dogrulamasi yapilir (varsa)\n- 7z/rar yalniz indirilir (kurulmaz)\n\nSag ustteki butonla GB sayfasini acabilirsin.", 14);
		d.setFormat(Paths.font("vcr.ttf"), 14, Theme.dim, LEFT);
		d.scrollFactor.set();
		addSprite(detailSprites, d);

		var b1:FlxSprite = new FlxSprite(px, FlxG.height - 150).makeGraphic(DETAIL_W - 40, 40, Theme.accent);
		b1.scrollFactor.set();
		addSprite(detailSprites, b1);
		var b1t:FlxText = new FlxText(px, FlxG.height - 140, DETAIL_W - 40, gbPending ? "HAZIRLANIYOR..." : "INDIR VE KUR", 16);
		b1t.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		b1t.scrollFactor.set();
		addSprite(detailSprites, b1t);
		var sRef:GBModSummary = s;
		hits.push({x: px, y: FlxG.height - 150, w: DETAIL_W - 40, h: 40, cb: function() {
			downloadGb(sRef);
		}});

		var b2:FlxSprite = new FlxSprite(px, FlxG.height - 100).makeGraphic(DETAIL_W - 40, 34, Theme.card);
		b2.scrollFactor.set();
		addSprite(detailSprites, b2);
		var b2t:FlxText = new FlxText(px, FlxG.height - 91, b2.width, "GAMABANA SAYFASINI AC", 14);
		b2t.setFormat(Paths.font("vcr.ttf"), 14, Theme.text, CENTER);
		b2t.scrollFactor.set();
		addSprite(detailSprites, b2t);
		hits.push({x: px, y: FlxG.height - 100, w: b2.width, h: 34, cb: function() {
			if (sRef.profileUrl != null && sRef.profileUrl.length > 0)
				CoolUtil.browserLoad(sRef.profileUrl);
		}});
	}

	function refreshChrome():Void
	{
		for (i in 0...tabBgs.length)
		{
			tabBgs[i].color = (i == curTab) ? 0x24FF2E63 : Theme.card;
			tabTexts[i].color = (i == curTab) ? Theme.accent : Theme.dim;
		}
		subText.text = (curTab == 0) ? "TEXTURE PACKS" : (curTab == 1) ? "INSTALL MODS" : "EXTENSION PACKS";
	}

	// ______________________________ VERİ AKIŞI ______________________________

	function loadGb():Void
	{
		if (gbBusy)
			return;
		gbBusy = true;
		gbError = '';
		refresh();
		GBClient.listMods(gbPage, GB_PERPAGE, gbPopular, function(list:Array<GBModSummary>)
		{
			DownloadQueue.pushMain(function()
			{
				gbBusy = false;
				gbItems = list;
				gbLoadedOnce = true;
				curSelected = 0;
				refresh();
			}, true);
		}, function(err:String)
		{
			DownloadQueue.pushMain(function()
			{
				gbBusy = false;
				gbError = err;
				gbLoadedOnce = true;
				refresh();
			}, true);
		});
	}

	function downloadGb(s:GBModSummary):Void
	{
		if (gbPending || s == null)
			return;
		gbPending = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		refresh();
		GBClient.getProfile(s.id, function(profile:GBModProfile)
		{
			DownloadQueue.pushMain(function()
			{
				gbPending = false;
				var f:GBFile = GBClient.pickFile(profile);
				if (f == null)
				{
					gbError = 'Bu modun indirilebilir dosyasi yok.';
					refresh();
					return;
				}
				var sizeText:String = (f.size > 0) ? (Math.round(f.size / (1024 * 1024) * 10) / 10) + ' MB' : '';
				var item:DLItem = DownloadQueue.enqueue(profile.summary != null ? profile.summary.name : s.name, f.url, f.name, 'mod', sizeText);
				Reflect.setField(item, 'md5', f.md5);
				if (DownloadHUD.instance != null)
					DownloadHUD.instance.openDrawer();
				refresh();
			}, true);
		}, function(err:String)
		{
			DownloadQueue.pushMain(function()
			{
				gbPending = false;
				gbError = err;
				refresh();
			}, true);
		});
	}

	// ______________________________ EXTENSION PACKS ______________________________

	function extRows():Array<{name:String, type:String, meta:String, desc:String, id:String, url:String, installed:Bool}>
	{
		if (curFilter == 0)
		{
			return [
				for (p in ExtensionPackManager.list())
					{
						name: p.name,
						type: p.type,
						meta: p.author + "  ·  v" + p.version,
						desc: p.description,
						id: p.id,
						url: '',
						installed: true
					}
			];
		}
		var out:Array<{name:String, type:String, meta:String, desc:String, id:String, url:String, installed:Bool}> = [];
		if (extCatalog != null)
			for (e in extCatalog)
			{
				out.push({
					name: (e.name != null && e.name.length > 0) ? e.name : e.id,
					type: e.type,
					meta: e.author + "  ·  v" + e.version,
					desc: e.description,
					id: e.id,
					url: e.url,
					installed: ExtensionPackManager.find(e.id) != null
				});
			}
		return out;
	}

	function rebuildExtList():Void
	{
		gridLabel.visible = true;
		gridLabel.text = (curFilter == 0) ? "KURULU PAKETLER" : "KATALOG (extensions.json)";

		var gx:Float = RAIL_W + 22;
		var gw:Float = FlxG.width - RAIL_W - DETAIL_W - 44;

		inline function card(y:Float, h:Float, text:String, col:FlxColor):Void
		{
			var big:FlxSprite = new FlxSprite(gx, y).makeGraphic(Std.int(gw), Std.int(h), Theme.card);
			big.scrollFactor.set();
			addSprite(gridSprites, big);
			var t:FlxText = new FlxText(gx + 24, y + 22, gw - 48, text, 15);
			t.setFormat(Paths.font("vcr.ttf"), 15, col, LEFT);
			t.scrollFactor.set();
			addSprite(gridSprites, t);
		}

		// Katalog ilk giriste yuklenir
		if (curFilter == 1 && extCatalog == null && !extBusy && extError == '')
			loadExtCatalog();

		if (curFilter == 1 && extBusy)
		{
			card(TOPBAR_H + 60, 90, "KATALOG YUKLENIYOR...", Theme.dim);
			return;
		}
		if (curFilter == 1 && extError != '')
		{
			card(TOPBAR_H + 60, 120, "HATA: " + extError + "\nTIKLA: TEKRAR DENE", Theme.accent);
			hits.push({
				x: gx, y: TOPBAR_H + 60, w: gw, h: 120, cb: function()
				{
					extError = '';
					loadExtCatalog();
				}
			});
			return;
		}

		var rows = extRows();
		if (rows.length == 0)
		{
			card(TOPBAR_H + 60, 90, (curFilter == 0) ? "Paket yok. KATALOG sekmesinden indir." : "Katalog bos ya da erisilemedi.", Theme.dim);
			return;
		}

		if (curSelected >= rows.length)
			curSelected = rows.length - 1;

		var y:Float = TOPBAR_H + 60;
		var rowH:Float = 64;
		for (i in 0...rows.length)
		{
			var r = rows[i];
			var sel:Bool = (i == curSelected);
			var rowBg:FlxSprite = new FlxSprite(gx, y).makeGraphic(Std.int(gw), Std.int(rowH), sel ? 0xFF242438 : Theme.card);
			rowBg.scrollFactor.set();
			addSprite(gridSprites, rowBg);
			var bar:FlxSprite = new FlxSprite(gx, y).makeGraphic(4, Std.int(rowH), extTypeColor(r.type));
			bar.scrollFactor.set();
			addSprite(gridSprites, bar);

			var nm:FlxText = new FlxText(gx + 16, y + 10, gw - 160, r.name, 16);
			nm.setFormat(Paths.font("vcr.ttf"), 16, sel ? Theme.text : Theme.dim, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			nm.scrollFactor.set();
			addSprite(gridSprites, nm);

			var tag:FlxText = new FlxText(gx + 16, y + 36, gw - 160, extTypeTag(r.type) + "   " + r.meta + (r.installed ? "   [KURULU]" : ""), 12);
			tag.setFormat(Paths.font("vcr.ttf"), 12, Theme.dim, LEFT);
			tag.scrollFactor.set();
			addSprite(gridSprites, tag);

			var act:String = (curFilter == 0) ? "DETAY" : (r.installed ? "KURULU" : (r.url.length > 0 ? "INDIR" : "YOK"));
			var ab:FlxSprite = new FlxSprite(gx + gw - 92, y + 17).makeGraphic(80, 30, (act == "INDIR") ? Theme.accent : Theme.card);
			ab.scrollFactor.set();
			addSprite(gridSprites, ab);
			var at:FlxText = new FlxText(ab.x, y + 24, 80, act, 13);
			at.setFormat(Paths.font("vcr.ttf"), 13, (act == "INDIR") ? FlxColor.WHITE : Theme.dim, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			at.scrollFactor.set();
			addSprite(gridSprites, at);

			var idx:Int = i;
			hits.push({
				x: gx, y: y, w: gw - 100, h: rowH, cb: function()
				{
					curSelected = idx;
					refresh();
				}
			});
			if (curFilter == 1 && !r.installed && r.url.length > 0)
			{
				var rr = r;
				hits.push({
					x: ab.x, y: y + 17, w: 80, h: 30, cb: function()
					{
						extDownload(rr.id, rr.name, rr.url);
					}
				});
			}
			y += rowH + 10;
		}
	}

	function rebuildExtDetail():Void
	{
		var rows = extRows();
		if (rows.length == 0 || curSelected >= rows.length)
			return;
		var r = rows[curSelected];
		var px:Float = FlxG.width - DETAIL_W + 20;

		var hero:FlxSprite = new FlxSprite(px, 24).makeGraphic(DETAIL_W - 40, 130, extTypeColor(r.type));
		hero.scrollFactor.set();
		addSprite(detailSprites, hero);
		var heroL:FlxText = new FlxText(px, 58, DETAIL_W - 40, r.name.substr(0, 1).toUpperCase(), 48);
		heroL.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		heroL.scrollFactor.set();
		addSprite(detailSprites, heroL);

		var nm:FlxText = new FlxText(px, 170, DETAIL_W - 40, r.name, 20);
		nm.setFormat(Paths.font("vcr.ttf"), 20, Theme.text, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		nm.scrollFactor.set();
		addSprite(detailSprites, nm);

		var meta:FlxText = new FlxText(px, 202, DETAIL_W - 40, extTypeTag(r.type) + "  ·  " + r.meta, 13);
		meta.setFormat(Paths.font("vcr.ttf"), 13, Theme.dim, LEFT);
		meta.scrollFactor.set();
		addSprite(detailSprites, meta);

		var desc:String = (r.desc != null && r.desc.length > 0) ? r.desc : "Aciklama yok.";
		var d:FlxText = new FlxText(px, 236, DETAIL_W - 40, desc, 14);
		d.setFormat(Paths.font("vcr.ttf"), 14, Theme.dim, LEFT);
		d.scrollFactor.set();
		addSprite(detailSprites, d);

		if (r.installed && curFilter == 0)
		{
			var note:FlxText = new FlxText(px, 420, DETAIL_W - 40,
				"KALDIR: further/extensionpacks altindaki\npaket klasorunu siler. Character Packs\nkarakter secimden, Menu Packs ana\nmenuden kaybolur.", 12);
			note.setFormat(Paths.font("vcr.ttf"), 12, Theme.dim, LEFT);
			note.scrollFactor.set();
			addSprite(detailSprites, note);

			var b:FlxSprite = new FlxSprite(px, FlxG.height - 150).makeGraphic(DETAIL_W - 40, 40, 0xFF8B1E3F);
			b.scrollFactor.set();
			addSprite(detailSprites, b);
			var bt:FlxText = new FlxText(px, FlxG.height - 140, DETAIL_W - 40, "PAKETI KALDIR", 16);
			bt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			bt.scrollFactor.set();
			addSprite(detailSprites, bt);
			var rid:String = r.id;
			hits.push({
				x: px, y: FlxG.height - 150, w: DETAIL_W - 40, h: 40, cb: function()
				{
					FlxG.sound.play(Paths.sound('cancelMenu'));
					ExtensionPackManager.remove(rid);
					if (curSelected > 0)
						curSelected--;
					refresh();
				}
			});
		}
		else if (!r.installed)
		{
			if (r.url.length > 0)
			{
				var b:FlxSprite = new FlxSprite(px, FlxG.height - 150).makeGraphic(DETAIL_W - 40, 40, Theme.accent);
				b.scrollFactor.set();
				addSprite(detailSprites, b);
				var bt:FlxText = new FlxText(px, FlxG.height - 140, DETAIL_W - 40, "INDIR", 16);
				bt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				bt.scrollFactor.set();
				addSprite(detailSprites, bt);
				var rid:String = r.id;
				var rname:String = r.name;
				var rurl:String = r.url;
				hits.push({
					x: px, y: FlxG.height - 150, w: DETAIL_W - 40, h: 40, cb: function()
					{
						extDownload(rid, rname, rurl);
					}
				});
			}
			else
			{
				var nb:FlxText = new FlxText(px, FlxG.height - 150, DETAIL_W - 40, "INDIRME ADRESI YOK", 14);
				nb.setFormat(Paths.font("vcr.ttf"), 14, Theme.dim, CENTER);
				nb.scrollFactor.set();
				addSprite(detailSprites, nb);
			}
		}
		else
		{
			var ok:FlxText = new FlxText(px, FlxG.height - 150, DETAIL_W - 40, "ZATEN KURULU", 14);
			ok.setFormat(Paths.font("vcr.ttf"), 14, Theme.dim, CENTER);
			ok.scrollFactor.set();
			addSprite(detailSprites, ok);
		}
	}

	function extTypeColor(type:String):FlxColor
	{
		return switch (type)
		{
			case 'character': 0xFF2E63FF;
			case 'menu': 0xFFFF2E63;
			default: 0xFF3A3A52;
		}
	}

	function extTypeTag(type:String):String
	{
		return switch (type)
		{
			case 'character': '[KARAKTER]';
			case 'menu': '[MENU]';
			default: '[MISC]';
		}
	}

	function extDownload(id:String, name:String, url:String):Void
	{
		FlxG.sound.play(Paths.sound('confirmMenu'));
		var item:DLItem = DownloadQueue.enqueue(name, url, id + '.zip', 'extensionpack', '');
		if (DownloadHUD.instance != null)
			DownloadHUD.instance.openDrawer();
		refresh();
	}

	function loadExtCatalog():Void
	{
		if (extBusy)
			return;
		extBusy = true;
		extError = '';
		ExtensionPackManager.loadCatalog(function(list:Array<ECatalogEntry>)
		{
			DownloadQueue.pushMain(function()
			{
				extBusy = false;
				extLoadedOnce = true;
				extCatalog = list;
				if (extCatalog.length == 0)
					extError = 'Katalog bos ya da erisilemedi.';
				refresh();
			}, true);
		});
	}

	// ______________________________ GİRDİ ______________________________

	override function update(elapsed:Float)
	{
		var typing:Bool = (PsychUIInputText.focusOn != null);

		if (!leaving)
		{
			// sekmeler
			for (i in 0...tabBgs.length)
				if (justClicked(tabBgs[i].x, tabBgs[i].y, 62, 62))
				{
					curTab = i;
					curSelected = 0;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					if (curTab == 1 && !gbLoadedOnce)
						loadGb();
					else
						refresh();
				}
			for (i in 0...chipBgs.length)
				if (justClicked(chipBgs[i].x, chipBgs[i].y, chipBgs[i].width, chipBgs[i].height))
				{
					if (curTab == 0 || curTab == 2)
						curFilter = i;
					else if (curTab == 1)
					{
						gbPopular = (i == 0);
						gbPage = 1;
						loadGb();
						continue;
					}
					curSelected = 0;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					refresh();
				}

			// FAB → global İNDİRİLENLER drawer
			if (justClicked(fab.x, fab.y, 58, 58))
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				if (DownloadHUD.instance != null)
					DownloadHUD.instance.toggleDrawer();
			}

			// genel hover pariltisi
			var hv:LibHit = null;
			var hoverHits:Array<LibHit> = hits.copy();
			hoverHits.reverse(); // son eklenen (kucuk butonlar) once
			for (h in hoverHits)
				if (pointIn(h))
				{
					hv = h;
					break;
				}
			if (hv != null)
			{
				hoverSpr.visible = true;
				hoverSpr.setGraphicSize(Std.int(hv.w + 4), Std.int(hv.h + 4));
				hoverSpr.updateHitbox();
				hoverSpr.x = hv.x - 2;
				hoverSpr.y = hv.y - 2;
			}
			else
				hoverSpr.visible = false;

			// dinamik hit'ler
			if (FlxG.mouse.justPressed)
			{
				var clickHits:Array<LibHit> = hits.copy();
				clickHits.reverse(); // son eklenen (kucuk butonlar) once
				for (h in clickHits)
					if (pointIn(h))
					{
						h.cb();
						break;
					}
			}

			// klavye (arama yazarken değil)
			if (!typing)
			{
				if (controls.UI_LEFT_P)
				{
					curTab = FlxMath.wrap(curTab - 1, 0, 2);
					curSelected = 0;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					if (curTab == 1 && !gbLoadedOnce)
						loadGb();
					else
						refresh();
				}
				if (controls.UI_RIGHT_P)
				{
					curTab = FlxMath.wrap(curTab + 1, 0, 2);
					curSelected = 0;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					if (curTab == 1 && !gbLoadedOnce)
						loadGb();
					else
						refresh();
				}
				if (controls.UI_UP_P || controls.UI_DOWN_P)
				{
					var count:Int = (curTab == 0) ? shown.length : (curTab == 1 ? shownGb().length : 0);
					var maxIdx:Int = count - 1;
					if (maxIdx < 0) maxIdx = 0;
					curSelected = FlxMath.wrap(curSelected + (controls.UI_DOWN_P ? 1 : -1), 0, maxIdx);
					FlxG.sound.play(Paths.sound('scrollMenu'));
					refresh();
				}
				if (controls.ACCEPT)
				{
					if (curTab == 0 && shown.length > 0)
					{
						var pid:String = shown[curSelected].id;
						FlxG.sound.play(Paths.sound('confirmMenu'));
						TexturePackManager.setEnabled(pid, !TexturePackManager.isEnabled(pid));
						refresh();
					}
					else if (curTab == 1)
					{
						var list:Array<GBModSummary> = shownGb();
						if (list.length > 0 && curSelected < list.length)
							downloadGb(list[curSelected]);
					}
				}
				if (controls.BACK)
					leave();
			}
		}
		super.update(elapsed);
	}

	function leave():Void
	{
		if (leaving)
			return;
		leaving = true;
		FlxG.mouse.visible = false;
		FlxG.sound.play(Paths.sound('cancelMenu'));
		MenuStyleRouter.goToMainMenu();
	}

	// ______________________________ YARDIMCILAR ______________________________

	function selectPack(p:TexturePack):Void
	{
		if (p == null)
			return;
		for (i in 0...shown.length)
			if (shown[i].id == p.id)
			{
				curSelected = i;
				break;
			}
		rebuildGrid();
		rebuildDetail();
	}

	function selectGb(s:GBModSummary):Void
	{
		if (s == null)
			return;
		var list:Array<GBModSummary> = shownGb();
		for (i in 0...list.length)
			if (list[i].id == s.id)
			{
				curSelected = i;
				break;
			}
		rebuildGrid();
		rebuildDetail();
	}

	function stackPositionText(id:String):String
	{
		var stackNow = TexturePackManager.getStackOrder();
		var idx:Int = -1;
		for (i in 0...stackNow.length)
			if (stackNow[i].id == id)
				idx = i;
		if (idx < 0)
			return "-";
		return (stackNow.length - idx) + ". sira (en ust = kazanan)";
	}

	function addSprite(list:Array<FlxSprite>, spr:FlxSprite):Void
	{
		spr.scrollFactor.set();
		add(spr);
		list.push(spr);
	}

	function wipe(list:Array<FlxSprite>):Void
	{
		for (s in list)
		{
			if (s == null)
				continue;
			remove(s, true);
			s.destroy();
		}
		while (list.length > 0)
			list.pop();
	}

	function pointIn(h:LibHit):Bool
	{
		return FlxG.mouse.justPressed
			&& FlxG.mouse.screenX >= h.x && FlxG.mouse.screenX <= h.x + h.w
			&& FlxG.mouse.screenY >= h.y && FlxG.mouse.screenY <= h.y + h.h;
	}

	function justClicked(x:Float, y:Float, w:Float, h:Float):Bool
	{
		return FlxG.mouse.justPressed
			&& FlxG.mouse.screenX >= x && FlxG.mouse.screenX <= x + w
			&& FlxG.mouse.screenY >= y && FlxG.mouse.screenY <= y + h;
	}
}

private typedef LibHit =
{
	var x:Float;
	var y:Float;
	var w:Float;
	var h:Float;
	var cb:Void->Void;
}

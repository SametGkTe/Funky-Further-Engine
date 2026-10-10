package backend.further;

import backend.further.DownloadQueue;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * Kalıcı indirme HUD'u — solda indirme butonu + İNDİRİLENLER drawer'ı.
 * FlxG.stage ÖTESİNDE, Main.addChild ile yaşar: state geçişlerinde, oyunda,
 * ayarlarda... her yerde ekranda kalır (istenen davranış).
 * DownloadQueue.poll() her kare buradan çağrılır (ana iş parçacığı).
 */
class DownloadHUD extends Sprite
{
	public static var instance:DownloadHUD = null;

	static inline var FAB_W:Float = 58;
	static inline var FAB_H:Float = 58;
	static inline var DRAWER_W:Float = 340;
	static inline var ROW_H:Float = 84;
	static inline var MAX_ROWS:Int = 6;

	var fab:Sprite;
	var fabLabel:TextField;
	var badgeBg:Shape;
	var badgeText:TextField;
	var fabBarBg:Shape;
	var fabBarFill:Shape;

	var drawer:Sprite;
	var drawerBg:Shape;
	var drawerLine:Shape;
	var titleField:TextField;
	var closeBtn:TextField;
	var clearBtn:TextField;
	var emptyField:TextField;
	var rowLayer:Sprite;
	var rowsBuilt:Int = -1;

	var open:Bool = false;
	var slide:Float = 0;
	var lastW:Float = -1;
	var lastH:Float = -1;

	public function new()
	{
		super();
		instance = this;
		mouseEnabled = false;
		buildFab();
		buildDrawer();
		addEventListener(Event.ENTER_FRAME, onFrame);
		DownloadQueue.addListener(onQueueMajor);
	}

	function get_scale():Float
	{
		var s:Float = Lib.current.stage.stageWidth / 1280;
		if (s < 0.55)
			s = 0.55;
		return s;
	}

	// ______________________________ İNŞA ______________________________

	function makeField(size:Int, color:Int, width:Float, ?align:String = 'left'):TextField
	{
		var tf:TextField = new TextField();
		var fontName:String = Assets.getFont('assets/fonts/vcr.ttf').fontName;
		var fmt:TextFormat = new TextFormat(fontName, Std.int(size * get_scale()), color, true);
		fmt.align = align;
		tf.defaultTextFormat = fmt;
		tf.selectable = false;
		tf.mouseEnabled = false;
		tf.width = width;
		tf.text = '';
		return tf;
	}

	function buildFab():Void
	{
		var s:Float = get_scale();
		fab = new Sprite();
		fab.graphics.beginFill(0xFF141419, 0.96);
		fab.graphics.drawRoundRect(0, 0, FAB_W * s, FAB_H * s, 16 * s, 16 * s);
		fab.graphics.endFill();
		// üst vurgu çizgisi (accent)
		fab.graphics.beginFill(0xFFFF2E63);
		fab.graphics.drawRoundRect(0, 0, FAB_W * s, 4 * s, 2 * s, 2 * s);
		fab.graphics.endFill();

		fabLabel = makeField(20, 0xFFFFFFFF, FAB_W * s, 'center');
		fabLabel.text = 'DL';
		fabLabel.y = (FAB_H * s - fabLabel.textHeight) * 0.5 - 4 * s;
		fab.addChild(fabLabel);

		badgeBg = new Shape();
		fab.addChild(badgeBg);
		badgeText = makeField(11, 0xFFFFFFFF, 24 * s, 'center');
		badgeText.y = -6 * s;
		badgeText.x = FAB_W * s - 14 * s;
		fab.addChild(badgeText);

		fabBarBg = new Shape();
		fabBarBg.graphics.beginFill(0xFF232330);
		fabBarBg.graphics.drawRoundRect(8 * s, FAB_H * s - 10 * s, (FAB_W - 16) * s, 4 * s, 2 * s, 2 * s);
		fabBarBg.graphics.endFill();
		fab.addChild(fabBarBg);

		fabBarFill = new Shape();
		fab.addChild(fabBarFill);

		fab.buttonMode = true;
		fab.useHandCursor = true;
		fab.addEventListener(MouseEvent.CLICK, onFabClick);
		addChild(fab);
	}

	function buildDrawer():Void
	{
		var s:Float = get_scale();
		drawer = new Sprite();
		drawerBg = new Shape();
		drawer.addChild(drawerBg);
		drawerLine = new Shape();
		drawer.addChild(drawerLine);

		titleField = makeField(18, 0xFFF2F2F5, 220 * s);
		titleField.text = 'INDIRILENLER';
		titleField.x = 20 * s;
		titleField.y = 18 * s;
		drawer.addChild(titleField);

		closeBtn = makeField(16, 0xFF9A9AAB, 30 * s, 'center');
		closeBtn.text = 'X';
		closeBtn.mouseEnabled = true;
		closeBtn.addEventListener(MouseEvent.CLICK, function(_) toggleDrawer());
		drawer.addChild(closeBtn);

		clearBtn = makeField(12, 0xFF9A9AAB, 140 * s);
		clearBtn.text = 'BITENLERI TEMIZLE';
		clearBtn.mouseEnabled = true;
		clearBtn.addEventListener(MouseEvent.CLICK, function(_)
		{
			DownloadQueue.clearFinished();
		});
		drawer.addChild(clearBtn);

		emptyField = makeField(14, 0xFF9A9AAB, DRAWER_W * s - 40 * s);
		emptyField.text = 'Kuyruk bos.\n\nMod Downloader\'dan bir sey\nindirdiginde burada gorunur.\n\nIndirme arka planda surer:\noyun oynanabilir, ayar yapilabilir.';
		emptyField.x = 20 * s;
		emptyField.y = 90 * s;
		drawer.addChild(emptyField);

		rowLayer = new Sprite();
		drawer.addChild(rowLayer);

		drawer.x = -DRAWER_W * s;
		addChild(drawer);
		layout();
	}

	function layout():Void
	{
		var s:Float = get_scale();
		var stageW:Float = Lib.current.stage.stageWidth;
		var stageH:Float = Lib.current.stage.stageHeight;

		fab.x = 12 * s;
		fab.y = (stageH - FAB_H * s) * 0.5;

		drawerBg.graphics.clear();
		drawerBg.graphics.beginFill(0xFF0E0E12, 0.98);
		drawerBg.graphics.drawRect(0, 0, DRAWER_W * s, stageH);
		drawerBg.graphics.endFill();
		drawerLine.graphics.clear();
		drawerLine.graphics.beginFill(0xFF232330);
		drawerLine.graphics.drawRect(DRAWER_W * s - 1, 0, 1, stageH);
		drawerLine.graphics.endFill();

		closeBtn.x = DRAWER_W * s - 40 * s;
		closeBtn.y = 16 * s;
		clearBtn.x = 20 * s;
		clearBtn.y = stageH - 34 * s;

		drawer.x = open ? 0 : -DRAWER_W * s;
		rowsBuilt = -1; // yeniden çiz
	}

	// ______________________________ GÜNCELLEME ______________________________

	function onQueueMajor():Void
	{
		rowsBuilt = -1;
	}

	function onFrame(_):Void
	{
		DownloadQueue.poll();

		var stageW:Float = Lib.current.stage.stageWidth;
		var stageH:Float = Lib.current.stage.stageHeight;
		if (stageW != lastW || stageH != lastH)
		{
			lastW = stageW;
			lastH = stageH;
			layout();
		}

		// drawer kaydırma animasyonu
		var target:Float = open ? 1 : 0;
		slide += (target - slide) * 0.28;
		if (Math.abs(target - slide) < 0.01)
			slide = target;
		var s:Float = get_scale();
		drawer.x = -DRAWER_W * s * (1 - slide);
		drawer.visible = slide > 0.01;

		updateFab();
		updateRows();
	}

	function updateFab():Void
	{
		var n:Int = DownloadQueue.activeTotal();
		var s:Float = get_scale();

		badgeBg.graphics.clear();
		if (n > 0)
		{
			badgeBg.graphics.beginFill(0xFFFF2E63);
			badgeBg.graphics.drawCircle(FAB_W * s - 4 * s, 8 * s, 11 * s);
			badgeBg.graphics.endFill();
			badgeText.text = Std.string(n);
			badgeText.visible = true;
		}
		else
			badgeText.visible = false;

		// aktif ilerleme: ilk indiren öğenin yüzdesi
		var pct:Float = -1;
		for (it in DownloadQueue.items)
			if (it.state == 'downloading')
			{
				pct = it.percent;
				break;
			}
			else if (it.state == 'installing')
			{
				pct = 100;
				break;
			}

		fabBarFill.graphics.clear();
		if (pct >= 0)
		{
			var w:Float = (FAB_W - 16) * s * (pct / 100);
			if (w < 2)
				w = 2;
			fabBarFill.graphics.beginFill(0xFFFF2E63);
			fabBarFill.graphics.drawRoundRect(8 * s, FAB_H * s - 10 * s, w, 4 * s, 2 * s, 2 * s);
			fabBarFill.graphics.endFill();
		}
	}

	function updateRows():Void
	{
		// hızlı yol: aynı yapıysa sadece barları tazele
		var sig:Int = 0;
		for (it in DownloadQueue.items)
			sig = sig * 31 + it.state.charCodeAt(0) + Std.int(it.percent) + it.id;
		if (sig == rowsBuilt)
		{
			refreshBars();
			return;
		}
		rowsBuilt = sig;

		while (rowLayer.numChildren > 0)
			rowLayer.removeChildAt(0);

		emptyField.visible = (DownloadQueue.items.length == 0);

		var s:Float = get_scale();
		var order:Array<DLItem> = orderedItems();
		var y:Float = 60 * s;
		var shown:Int = 0;
		for (it in order)
		{
			if (shown >= MAX_ROWS)
				break;
			rowLayer.addChild(buildRow(it, 10 * s, y, DRAWER_W * s - 20 * s, ROW_H * s));
			y += (ROW_H + 8) * s;
			shown++;
		}
	}

	function orderedItems():Array<DLItem>
	{
		var weight:Map<String, Int> = [
			'downloading' => 0,
			'installing' => 1,
			'queued' => 2,
			'error' => 3,
			'cancelled' => 4,
			'done' => 5
		];
		var out:Array<DLItem> = DownloadQueue.items.copy();
		out.sort(function(a:DLItem, b:DLItem)
		{
			var wa:Int = weight.exists(a.state) ? weight.get(a.state) : 9;
			var wb:Int = weight.exists(b.state) ? weight.get(b.state) : 9;
			return wa - wb;
		});
		return out;
	}

	var barFills:Map<Int, Shape> = new Map();
	var statusFields:Map<Int, TextField> = new Map();

	function buildRow(it:DLItem, x:Float, y:Float, w:Float, h:Float):Sprite
	{
		var s:Float = get_scale();
		var row:Sprite = new Sprite();
		row.graphics.beginFill(0xFF141419);
		row.graphics.drawRoundRect(0, 0, w, h, 12 * s, 12 * s);
		row.graphics.endFill();
		row.x = x;
		row.y = y;

		var title:TextField = makeField(13, 0xFFF2F2F5, w - 20 * s);
		title.text = it.title;
		title.x = 12 * s;
		title.y = 8 * s;
		row.addChild(title);

		var status:TextField = makeField(11, 0xFF9A9AAB, w - 20 * s);
		status.text = statusLine(it);
		status.x = 12 * s;
		status.y = 30 * s;
		row.addChild(status);
		statusFields.set(it.id, status);

		var barBg:Shape = new Shape();
		barBg.graphics.beginFill(0xFF232330);
		barBg.graphics.drawRoundRect(12 * s, 52 * s, w - 24 * s, 6 * s, 3 * s, 3 * s);
		barBg.graphics.endFill();
		row.addChild(barBg);

		var fill:Shape = new Shape();
		row.addChild(fill);
		barFills.set(it.id, fill);
		drawBarFill(it, fill, w);

		// eylem düğmeleri
		var bx:Float = 12 * s;
		if (it.state == 'downloading' || it.state == 'queued')
			bx = addBtn(row, 'IPTAL', bx, 62 * s, 0xFF232330, 0xFFF2F2F5, function() DownloadQueue.cancel(it.id));
		else if (it.state == 'error' || it.state == 'cancelled')
		{
			bx = addBtn(row, 'YENIDEN', bx, 62 * s, 0xFFFF2E63, 0xFFFFFFFF, function() DownloadQueue.retry(it.id));
			bx = addBtn(row, 'KALDIR', bx, 62 * s, 0xFF232330, 0xFFF2F2F5, function() DownloadQueue.remove(it.id));
		}
		else if (it.state == 'done')
			bx = addBtn(row, 'KALDIR', bx, 62 * s, 0xFF232330, 0xFFF2F2F5, function() DownloadQueue.remove(it.id));

		return row;
	}

	function drawBarFill(it:DLItem, fill:Shape, w:Float):Void
	{
		var s:Float = get_scale();
		fill.graphics.clear();
		var pct:Float = it.percent;
		if (it.state == 'installing')
			pct = 100;
		if (it.state != 'downloading' && it.state != 'installing' && it.state != 'done')
			return;
		var color:Int = (it.state == 'done') ? 0xFF3ED598 : 0xFFFF2E63;
		var bw:Float = (w - 24 * s) * (pct / 100);
		if (bw < 2)
			bw = 2;
		fill.graphics.beginFill(color);
		fill.graphics.drawRoundRect(12 * s, 52 * s, bw, 6 * s, 3 * s, 3 * s);
		fill.graphics.endFill();
	}

	function refreshBars():Void
	{
		for (it in DownloadQueue.items)
		{
			var fill:Shape = barFills.get(it.id);
			var st:TextField = statusFields.get(it.id);
			if (fill != null)
				drawBarFill(it, fill, DRAWER_W * get_scale() - 20 * get_scale());
			if (st != null)
				st.text = statusLine(it);
		}
	}

	function statusLine(it:DLItem):String
	{
		return switch (it.state)
		{
			case 'queued': 'SIRADA';
			case 'downloading': '%' + Std.int(it.percent) + ((it.speed > 0) ? '  ' + fmtSpeed(it.speed) : '') + ((it.sizeText.length > 0) ? '  ' + it.sizeText : '');
			case 'installing': it.status;
			case 'done': it.status;
			case 'error': 'HATA: ' + it.error;
			case 'cancelled': 'DURDURULDU';
			default: it.status;
		}
	}

	function addBtn(parent:Sprite, label:String, x:Float, y:Float, bg:Int, fg:Int, cb:Void->Void):Float
	{
		var s:Float = get_scale();
		var w:Float = (label.length * 8 + 22) * s;
		var btn:Sprite = new Sprite();
		btn.graphics.beginFill(bg);
		btn.graphics.drawRoundRect(0, 0, w, 18 * s, 6 * s, 6 * s);
		btn.graphics.endFill();
		btn.x = x;
		btn.y = y;
		btn.buttonMode = true;
		btn.useHandCursor = true;

		var tf:TextField = makeField(10, fg, w, 'center');
		tf.text = label;
		tf.y = 2 * s;
		btn.addChild(tf);
		btn.addEventListener(MouseEvent.CLICK, function(_) cb());
		parent.addChild(btn);
		return x + w + 8 * s;
	}

	function fmtSpeed(bps:Float):String
	{
		if (bps >= 1024 * 1024)
			return (Math.round(bps / (1024 * 1024) * 10) / 10) + ' MB/s';
		if (bps >= 1024)
			return Math.round(bps / 1024) + ' KB/s';
		return Math.round(bps) + ' B/s';
	}

	// ______________________________ DIŞ API ______________________________

	public function toggleDrawer():Void
	{
		open = !open;
	}

	public function openDrawer():Void
	{
		open = true;
	}

	public function isDrawerOpen():Bool
	{
		return open;
	}

	function onFabClick(_):Void
	{
		toggleDrawer();
	}
}

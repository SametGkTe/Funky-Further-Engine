package mobile.substates;

import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxSpriteGroup;
import flixel.input.touch.FlxTouch;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import mobile.backend.VSliceControlPreset;
import objects.Note;

/** Dört V-Slice dokunma alanı için mobil öncelikli, normalize düzen editörü. */
class VSliceControlEditorSubState extends MusicBeatSubstate
{
	/** OptionsState ve PET mouse hit-test'ini editör boyunca tamamen kilitler. */
	public static var blocksOptionsInput(default, null):Bool = false;
	static inline var HEADER_H:Float = 92;
	// Siyah-beyaz tema renkleri
	static inline var THEME_BG:Int = 0xFF0A0A0C;
	static inline var THEME_PANEL:Int = 0xFF141418;
	static inline var THEME_BTN:Int = 0xFF14141A;
	static inline var THEME_BORDER:Int = 0xFF8A8A93;
	/** KAYDET vurgusu: parlak beyaz çerçeve (zemin yine siyah, yazı beyaz). */
	static inline var THEME_BORDER_PRIMARY:Int = 0xFFFFFFFF;
	static inline var THEME_TEXT_MUTED:Int = 0xFFBDBDBD;
	static inline var BOTTOM_PANEL_H:Float = 132;
	static inline var LANE_W:Float = 150;
	var lanes:Array<FlxSprite> = [];
	var arrows:Array<FlxSprite> = [];
	var labels:Array<FlxText> = [];
	var handles:Array<FlxSprite> = [];
	var leftHandles:Array<FlxSprite> = [];
	var rightHandles:Array<FlxSprite> = [];
	var selected:Int = 0;
	var dragging:Bool = false;
	// 0=taşı, 1=alt/yükseklik, 2=sol kenar, 3=sağ kenar
	var resizeMode:Int = 0;
	var dragOffsetX:Float = 0;
	var dragOffsetY:Float = 0;
	var dragStartX:Float = 0;
	var dragStartY:Float = 0;
	var ui:FlxCamera;
	var status:FlxText;
	var xChanged:Bool = false;
	var zonesChanged:Bool = false;
	var widthChanged:Bool = false;
	var actionButtons:Array<EditorActionButton> = [];
	/** Sürüklemeyi başlatan parmağın kendisi (ilk parmak değil!). */
	var dragTouch:FlxTouch;
	var _tap:FlxPoint = FlxPoint.get();

	inline function editBottom():Float return FlxG.height - BOTTOM_PANEL_H;

	public function new()
	{
		super();
		blocksOptionsInput = true;
		ui = new FlxCamera();
		ui.bgColor = THEME_BG;
		FlxG.cameras.add(ui, false);

		var header = new FlxSprite().makeGraphic(FlxG.width, Std.int(HEADER_H), THEME_PANEL);
		header.cameras = [ui]; add(header);
		var title = new FlxText(0, 11, FlxG.width, 'V-SLICE KONTROL DÜZENİ', 25);
		title.setFormat(Paths.font('vcr.ttf'), 25, FlxColor.WHITE, CENTER);
		title.cameras = [ui]; add(title);

		status = new FlxText(0, 50, FlxG.width, 'Ortayı sürükle: taşı • Alt: boy • Sol/sağ kenar: genişlik', 15);
		status.setFormat(Paths.font('vcr.ttf'), 15, THEME_TEXT_MUTED, CENTER);
		status.cameras = [ui]; add(status);

		// Üst-sol: her zaman erişilebilir ikinci çıkış. Mobilde İPTAL'e
		// ulaşılamayan bir durumda kullanıcıyı kilitlenmekten kurtarır.
		var exitTop = new EditorActionButton(12, 11, 118, 36, 'X ÇIKIŞ', closeEditor, THEME_BTN, null, THEME_BORDER);
		exitTop.cameras = [ui]; add(exitTop); actionButtons.push(exitTop);

		// Görsel preset işlemleri sağ üstte, büyük dokunma alanlarıyla.
		makeIconButton(FlxG.width - 166, 11, 'noteColorMenu/copy', 'Kopyala', function()
		{
			saveValues(); VSliceControlPreset.copyToClipboard(); setStatus('Preset panoya kopyalandı.');
		});
		makeIconButton(FlxG.width - 84, 11, 'noteColorMenu/paste', 'Yapıştır', pastePreset);

		var colors = [0xFFC24B99, 0xFF00D9FF, 0xFF22D65F, 0xFFFF4655];
		var names = ['SOL', 'AŞAĞI', 'YUKARI', 'SAĞ'];
		var prefixes = ['arrowLEFT', 'arrowDOWN', 'arrowUP', 'arrowRIGHT'];
		var noteAtlas = getCurrentNoteAtlas();
		for (i in 0...4)
		{
			var lane = new FlxSprite();
			lane.makeGraphic(Std.int(LANE_W), 100, colors[i]);
			lane.alpha = 0.28;
			lane.cameras = [ui]; add(lane); lanes.push(lane);

			var arrow = new FlxSprite();
			arrow.frames = noteAtlas;
			arrow.animation.addByPrefix('idle', prefixes[i], 24, false);
			arrow.animation.play('idle');
			arrow.setGraphicSize(88, 88);
			arrow.updateHitbox();
			arrow.antialiasing = ClientPrefs.data.antialiasing;
			arrow.cameras = [ui]; add(arrow); arrows.push(arrow);

			var label = new FlxText(0, 0, Std.int(LANE_W), names[i], 16);
			label.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER);
			label.cameras = [ui]; add(label); labels.push(label);

			var handle = new FlxSprite().makeGraphic(Std.int(LANE_W), 14, FlxColor.WHITE);
			handle.cameras = [ui]; add(handle); handles.push(handle);
			var leftHandle = new FlxSprite().makeGraphic(14, 100, FlxColor.WHITE);
			leftHandle.cameras = [ui]; add(leftHandle); leftHandles.push(leftHandle);
			var rightHandle = new FlxSprite().makeGraphic(14, 100, FlxColor.WHITE);
			rightHandle.cameras = [ui]; add(rightHandle); rightHandles.push(rightHandle);
		}

		buildBottomPanel();
		loadValues();
		FlxG.mouse.visible = !FlxG.onMobile;
	}

	function getCurrentNoteAtlas():flixel.graphics.frames.FlxAtlasFrames
	{
		var skin = Note.defaultNoteSkin + Note.getNoteSkinPostfix();
		if (!Paths.fileExists('images/$skin.png', IMAGE)) skin = Note.defaultNoteSkin;
		return Paths.getSparrowAtlas(skin);
	}

	function buildBottomPanel():Void
	{
		var y = editBottom();
		var panel = new FlxSprite(0, y).makeGraphic(FlxG.width, Std.int(BOTTOM_PANEL_H), THEME_PANEL);
		panel.cameras = [ui]; add(panel);
		var names = ['KAYDET', "Y'Yİ EŞİTLE", 'BOYU EŞİTLE', "X'İ EŞİTLE", 'SIFIRLA', 'İPTAL'];
		var actions:Array<Void->Void> = [saveAndClose, alignY, equalHeight, equalSpacing, resetPreset, closeEditor];
		var gap:Float = 12;
		var margin:Float = 18;
		var w:Float = (FlxG.width - margin * 2 - gap * 5) / 6;
		for (i in 0...names.length)
		{
			var isPrimary = (i == 0);
			var button = new EditorActionButton(margin + i * (w + gap), y + 25, w, 76, names[i], actions[i],
				THEME_BTN, null, isPrimary ? THEME_BORDER_PRIMARY : THEME_BORDER);
			button.cameras = [ui]; add(button); actionButtons.push(button);
		}
	}

	function makeIconButton(x:Float, y:Float, image:String, hint:String, action:Void->Void):Void
	{
		var button = new EditorActionButton(x, y, 70, 70, '', action, THEME_BTN, image, THEME_BORDER);
		button.cameras = [ui]; add(button); actionButtons.push(button);
	}

	override function update(elapsed:Float):Void
	{
		// GİRİŞ DÜZELTMESİ: TouchUtil.touch listedeki İLK parmağı döndürür;
		// basılan parmak başka bir parmak olabilir (çoklu dokunuşta koordinat
		// yanlış ölçülüyordu). Artık basılan parmak bizzat bulunur ve konumu
		// HER ZAMAN 'ui' kamerasının uzayında okunur (getScreenPosition),
		// böylece ana kameranın scroll/zoom'u hit-test'i kaydıramaz.
		for (touch in FlxG.touches.list)
		{
			if (touch == null || !touch.justPressed) continue;
			var pos = touch.getScreenPosition(ui, _tap);
			if (pos.y >= HEADER_H && pos.y < editBottom())
			{
				for (i in 0...lanes.length)
				{
					var lane = lanes[i];
					if (pos.x >= lane.x && pos.x <= lane.x + lane.width && pos.y >= lane.y && pos.y <= lane.y + lane.height)
					{
						selected = i; dragging = true; dragTouch = touch;
						resizeMode = 0;
						if (pos.y >= lane.y + lane.height - 38) resizeMode = 1;
						else if (pos.x <= lane.x + 28) resizeMode = 2;
						else if (pos.x >= lane.x + lane.width - 28) resizeMode = 3;
						dragOffsetX = pos.x - lane.x; dragOffsetY = pos.y - lane.y;
						dragStartX = lane.x; dragStartY = lane.y;
						refreshVisuals(); break;
					}
				}
			}
		}
		// Sürüklerken takip edilen parmağın konumu kullanılır (ilk parmağın değil).
		if (dragging && dragTouch != null && dragTouch.pressed)
		{
			var pos = dragTouch.getScreenPosition(ui, _tap);
			var lane = lanes[selected];
			switch (resizeMode)
			{
				case 1:
					lane.setGraphicSize(Std.int(lane.width), Std.int(Math.max(54, Math.min(editBottom() - lane.y, pos.y - lane.y))));
					lane.updateHitbox(); zonesChanged = true;
				case 2:
					var oldRight = lane.x + lane.width;
					var newLeft = Math.max(0, Math.min(oldRight - 70, pos.x));
					lane.x = newLeft;
					lane.setGraphicSize(Std.int(oldRight - newLeft), Std.int(lane.height));
					lane.updateHitbox(); xChanged = true; zonesChanged = true; widthChanged = true;
				case 3:
					var newRight = Math.max(lane.x + 70, Math.min(FlxG.width, pos.x));
					lane.setGraphicSize(Std.int(newRight - lane.x), Std.int(lane.height));
					lane.updateHitbox(); xChanged = true; zonesChanged = true; widthChanged = true;
				default:
					lane.x = Math.max(0, Math.min(FlxG.width - lane.width, pos.x - dragOffsetX));
					lane.y = Math.max(HEADER_H, Math.min(editBottom() - lane.height, pos.y - dragOffsetY));
					xChanged = true; zonesChanged = true;
			}
			refreshVisuals();
		}
		if (dragging && (dragTouch == null || !dragTouch.pressed))
		{
			if (resizeMode == 0 && dragTouch != null) resolveLaneOverlap();
			dragging = false; dragTouch = null;
			refreshVisuals();
		}
		if (controls.BACK) closeEditor();
		super.update(elapsed);
	}

	/**
	 * İki lane aynı yere bırakılırsa ikisi de aynı dokunmayı tüketir. Kullanıcı
	 * özellikle AŞAĞI/YUKARI yerini değiştirmek istediğinde sürüklenen lane'i
	 * hedef lane ile otomatik takas et.
	 */
	function resolveLaneOverlap():Void
	{
		var moved = lanes[selected];
		var movedCenter = moved.x + moved.width * 0.5;
		var closest:Int = -1;
		var closestDistance:Float = Math.POSITIVE_INFINITY;
		for (i in 0...lanes.length)
		{
			if (i == selected) continue;
			var otherCenter = lanes[i].x + lanes[i].width * 0.5;
			var distance = Math.abs(movedCenter - otherCenter);
			if (distance < moved.width * 0.65 && distance < closestDistance)
			{
				closest = i;
				closestDistance = distance;
			}
		}
		if (closest >= 0)
		{
			lanes[closest].x = dragStartX;
			xChanged = true;
			setStatus('${labels[selected].text} ile ${labels[closest].text} konumu takas edildi.');
		}
	}

	function loadValues():Void
	{
		var canvasH = editBottom() - HEADER_H;
		for (i in 0...4)
		{
			var normalizedH = Math.max(0.05, Math.min(1, ClientPrefs.data.vSliceButtonHeight[i]));
			var normalizedY = Math.max(0, Math.min(1 - normalizedH, ClientPrefs.data.vSliceButtonY[i]));
			var visualY = ClientPrefs.data.downScroll ? 1 - normalizedY - normalizedH : normalizedY;
			var h = Math.max(54, normalizedH * canvasH);
			var y = HEADER_H + visualY * canvasH;
			h = Math.min(h, editBottom() - y);
			var normalizedW = (ClientPrefs.data.vSliceButtonWidth != null && ClientPrefs.data.vSliceButtonWidth.length >= 4)
				? ClientPrefs.data.vSliceButtonWidth[i] : LANE_W / FlxG.width;
			var laneW = Math.max(70, Math.min(FlxG.width, normalizedW * FlxG.width));
			lanes[i].setGraphicSize(Std.int(laneW), Std.int(h)); lanes[i].updateHitbox();
			lanes[i].x = Math.max(0, Math.min(FlxG.width - laneW, ClientPrefs.data.vSliceButtonX[i] * FlxG.width - laneW * 0.5));
			lanes[i].y = y;
		}
		refreshVisuals();
		setStatus(ClientPrefs.data.downScroll
			? 'Downscroll önizlemesi • Kontrol alanları oynanışta dikey aynalanır.'
			: 'Upscroll önizlemesi • Parlak alt kenarı sürükleyerek yüksekliği değiştir.');
	}

	function saveValues():Void
	{
		var xs:Array<Float> = [], ys:Array<Float> = [], ws:Array<Float> = [], hs:Array<Float> = [];
		var canvasH = editBottom() - HEADER_H;
		for (lane in lanes)
		{
			var normalizedH = Math.max(0.05, Math.min(1, lane.height / canvasH));
			var visualY = Math.max(0, Math.min(1 - normalizedH, (lane.y - HEADER_H) / canvasH));
			var canonicalY = ClientPrefs.data.downScroll ? 1 - visualY - normalizedH : visualY;
			xs.push((lane.x + lane.width * 0.5) / FlxG.width);
			ys.push(Math.max(0, Math.min(1 - normalizedH, canonicalY)));
			ws.push(Math.max(0.055, Math.min(1, lane.width / FlxG.width)));
			hs.push(normalizedH);
		}
		ClientPrefs.data.vSliceButtonX = xs; ClientPrefs.data.vSliceButtonY = ys;
		ClientPrefs.data.vSliceButtonWidth = ws; ClientPrefs.data.vSliceButtonHeight = hs;
		if (xChanged) ClientPrefs.data.vSliceCustomX = true;
		if (zonesChanged) ClientPrefs.data.vSliceCustomZones = true;
		if (widthChanged) ClientPrefs.data.vSliceCustomWidth = true;
			ClientPrefs.data.ogGameControls = true;
			// V-Slice açılınca Sabitlenmiş Notalar otomatik açılır (oyuncu istersen kapatabilir)
			ClientPrefs.data.pinnedNotes = true;
			ClientPrefs.data.ogAutoPinDone = true;
			ClientPrefs.saveSettings();
	}

	function saveAndClose():Void { saveValues(); closeEditor(); }
	function closeEditor():Void {
		FlxG.mouse.visible = false;
		// MobileControlSelectSubState'e dönüyoruz; OptionsState'e değil.
		controls.isInSubstate = true;
		close();
	}
	function alignY():Void { var y = lanes[selected].y; for (lane in lanes) lane.y = Math.min(y, editBottom() - lane.height); zonesChanged = true; refreshVisuals(); setStatus("Y konumları eşitlendi."); }
	function equalHeight():Void { var h = lanes[selected].height; for (lane in lanes) { lane.setGraphicSize(Std.int(lane.width), Std.int(Math.min(h, editBottom() - lane.y))); lane.updateHitbox(); } zonesChanged = true; refreshVisuals(); setStatus('Yükseklikler eşitlendi.'); }
	function equalSpacing():Void
	{
		var ordered = lanes.copy(); ordered.sort(function(a, b) return a.x < b.x ? -1 : (a.x > b.x ? 1 : 0));
		var step = (ordered[3].x - ordered[0].x) / 3; for (i in 0...4) ordered[i].x = ordered[0].x + step * i;
		xChanged = true; refreshVisuals(); setStatus("X aralıkları eşitlendi; Kontrol Aralığı artık kullanılmayacak.");
	}
	function pastePreset():Void { var error = VSliceControlPreset.pasteFromClipboard(); if (error != null) { setStatus(error, true); return; } xChanged = ClientPrefs.data.vSliceCustomX; zonesChanged = ClientPrefs.data.vSliceCustomZones; widthChanged = ClientPrefs.data.vSliceCustomWidth; loadValues(); setStatus('Preset panodan yüklendi.'); }
	function resetPreset():Void { VSliceControlPreset.reset(); xChanged = false; zonesChanged = false; widthChanged = false; loadValues(); setStatus('Varsayılan düzen geri yüklendi; Kontrol Aralığı yeniden etkin.'); }

	function refreshVisuals():Void
	{
		for (i in 0...lanes.length)
		{
			var lane = lanes[i]; lane.alpha = i == selected ? 0.48 : 0.25;
			arrows[i].x = lane.x + (lane.width - arrows[i].width) * 0.5;
			arrows[i].y = lane.y + (lane.height - arrows[i].height) * 0.5;
			labels[i].x = lane.x; labels[i].y = Math.max(lane.y + 8, arrows[i].y - 25);
			handles[i].setGraphicSize(Std.int(lane.width), 14); handles[i].updateHitbox();
			handles[i].x = lane.x; handles[i].y = lane.y + lane.height - handles[i].height;
			handles[i].alpha = i == selected ? 1 : 0.6;
			leftHandles[i].setGraphicSize(14, Std.int(lane.height)); leftHandles[i].updateHitbox();
			leftHandles[i].x = lane.x; leftHandles[i].y = lane.y; leftHandles[i].alpha = i == selected ? 0.95 : 0.45;
			rightHandles[i].setGraphicSize(14, Std.int(lane.height)); rightHandles[i].updateHitbox();
			rightHandles[i].x = lane.x + lane.width - rightHandles[i].width; rightHandles[i].y = lane.y; rightHandles[i].alpha = i == selected ? 0.95 : 0.45;
		}
	}
	function setStatus(message:String, error:Bool = false):Void { status.text = message; status.color = error ? 0xFFFF6374 : 0xFFADB2C8; }
	override function destroy():Void
	{
		blocksOptionsInput = false;
		FlxG.cameras.remove(ui);
		if (_tap != null) { _tap.put(); _tap = null; }
		super.destroy();
	}
}

/** FlxButton yerine büyük dokunma alanı, modern kart ve okunaklı metin sunar. */
private class EditorActionButton extends FlxSpriteGroup
{
	var bg:FlxSprite;
	var callback:Void->Void;
	var areaW:Float;
	var areaH:Float;
	var _tap:FlxPoint = FlxPoint.get();

	public function new(x:Float, y:Float, width:Float, height:Float, text:String, callback:Void->Void, color:Int, ?iconPath:String, ?borderColor:Int)
	{
		super(x, y); this.callback = callback; areaW = width; areaH = height;
		if (borderColor == null) borderColor = 0xFF8A8A93; // THEME_BORDER ile aynı değer
		bg = new FlxSprite().makeGraphic(Std.int(width), Std.int(height), FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(bg, 0, 0, width, height, 16, 16, color, {thickness: 2, color: borderColor}); add(bg);
		if (iconPath != null)
		{
			var icon = new FlxSprite().loadGraphic(Paths.image(iconPath)); icon.setGraphicSize(42, 50); icon.updateHitbox();
			icon.x = (width - icon.width) * 0.5; icon.y = (height - icon.height) * 0.5; add(icon);
		}
		else
		{
			var label = new FlxText(8, 0, Std.int(width - 16), text, 17);
			label.setFormat(Paths.font('vcr.ttf'), 17, FlxColor.WHITE, CENTER); label.y = (height - label.height) * 0.5; add(label);
		}
	}

	function overlapsLocal(px:Float, py:Float):Bool
	{
		return px >= x && px <= x + areaW && py >= y && py <= y + areaH;
	}

	override function update(elapsed:Float):Void
	{
		// GİRİŞ DÜZELTMESİ (butonların "basılmıyor" + kilitlenme bug'ı):
		// 1) TouchUtil.touch listedeki İLK parmağı döndürür; basılan parmak
		//    başka olabilir -> her parmak tek tek kontrol edilir.
		// 2) touch.x/y ANA kameranın uzayındadır; bu butonlar 'ui' kamerasında
		//    çizilir -> konum getScreenPosition(kamera) ile butonun uzayında
		//    okunur, ana kamera kaysa bile hit-test doğru kalır.
		// 3) Fare yalnızca masaüstünde: mobilde emüle edilen fare takılı
		//    kalıp callback'in her karede tetiklenmesine yol açabiliyordu.
		var cam = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
		var pressed:Bool = false;
		var hit:Bool = false;
		for (touch in FlxG.touches.list)
		{
			if (touch == null) continue;
			var pos = touch.getScreenPosition(cam, _tap);
			if (!overlapsLocal(pos.x, pos.y)) continue;
			if (touch.pressed) pressed = true;
			if (touch.justPressed) hit = true;
		}
		#if !mobile
		var mpos = FlxG.mouse.getScreenPosition(cam, _tap);
		if (overlapsLocal(mpos.x, mpos.y))
		{
			if (FlxG.mouse.pressed) pressed = true;
			if (FlxG.mouse.justPressed) hit = true;
		}
		#end
		bg.alpha = pressed ? 0.72 : 1;
		if (hit)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
			callback();
		}
		super.update(elapsed);
	}

	override public function destroy():Void
	{
		if (_tap != null) { _tap.put(); _tap = null; }
		super.destroy();
	}
}

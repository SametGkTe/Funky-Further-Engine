package mobile.substates;

import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import mobile.backend.TouchUtil;
import mobile.backend.VSliceControlPreset;
import objects.Note;

/** Dört V-Slice dokunma alanı için mobil öncelikli, normalize düzen editörü. */
class VSliceControlEditorSubState extends MusicBeatSubstate
{
	/** OptionsState ve PET mouse hit-test'ini editör boyunca tamamen kilitler. */
	public static var blocksOptionsInput(default, null):Bool = false;
	static inline var HEADER_H:Float = 92;
	static inline var BOTTOM_PANEL_H:Float = 132;
	static inline var LANE_W:Float = 150;
	var lanes:Array<FlxSprite> = [];
	var arrows:Array<FlxSprite> = [];
	var labels:Array<FlxText> = [];
	var handles:Array<FlxSprite> = [];
	var selected:Int = 0;
	var dragging:Bool = false;
	var resizing:Bool = false;
	var dragOffsetX:Float = 0;
	var dragOffsetY:Float = 0;
	var dragStartX:Float = 0;
	var dragStartY:Float = 0;
	var ui:FlxCamera;
	var status:FlxText;
	var xChanged:Bool = false;
	var zonesChanged:Bool = false;
	var actionButtons:Array<EditorActionButton> = [];

	inline function editBottom():Float return FlxG.height - BOTTOM_PANEL_H;

	public function new()
	{
		super();
		blocksOptionsInput = true;
		ui = new FlxCamera();
		ui.bgColor = 0xFF0C0D16;
		FlxG.cameras.add(ui, false);

		var header = new FlxSprite().makeGraphic(FlxG.width, Std.int(HEADER_H), 0xFF171925);
		header.cameras = [ui]; add(header);
		var title = new FlxText(24, 13, 650, 'V-SLICE KONTROL DÜZENİ', 25);
		title.setFormat(Paths.font('vcr.ttf'), 25, FlxColor.WHITE, LEFT);
		title.cameras = [ui]; add(title);

		status = new FlxText(24, 51, FlxG.width - 210,
			'Alanı sürükle • Parlak alt kenarı sürükleyerek yüksekliği değiştir', 15);
		status.setFormat(Paths.font('vcr.ttf'), 15, 0xFFADB2C8, LEFT);
		status.cameras = [ui]; add(status);

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
		var panel = new FlxSprite(0, y).makeGraphic(FlxG.width, Std.int(BOTTOM_PANEL_H), 0xFF171925);
		panel.cameras = [ui]; add(panel);
		var names = ['KAYDET', "Y'Yİ EŞİTLE", 'BOYU EŞİTLE', "X'İ EŞİTLE", 'SIFIRLA', 'İPTAL'];
		var actions:Array<Void->Void> = [saveAndClose, alignY, equalHeight, equalSpacing, resetPreset, closeEditor];
		var gap:Float = 12;
		var margin:Float = 18;
		var w:Float = (FlxG.width - margin * 2 - gap * 5) / 6;
		for (i in 0...names.length)
		{
			var color = i == 0 ? 0xFF276B4A : (i == 5 ? 0xFF6A3038 : 0xFF2B3045);
			var button = new EditorActionButton(margin + i * (w + gap), y + 25, w, 76, names[i], actions[i], color);
			button.cameras = [ui]; add(button); actionButtons.push(button);
		}
	}

	function makeIconButton(x:Float, y:Float, image:String, hint:String, action:Void->Void):Void
	{
		var button = new EditorActionButton(x, y, 70, 70, '', action, 0xFF2B3045, image);
		button.cameras = [ui]; add(button); actionButtons.push(button);
	}

	override function update(elapsed:Float):Void
	{
		var touch = TouchUtil.touch;
		if (TouchUtil.justPressed && touch != null && touch.y >= HEADER_H && touch.y < editBottom())
		{
			for (i in 0...lanes.length)
			{
				var lane = lanes[i];
				if (touch.x >= lane.x && touch.x <= lane.x + lane.width && touch.y >= lane.y && touch.y <= lane.y + lane.height)
				{
					selected = i; dragging = true;
					resizing = touch.y >= lane.y + lane.height - 38;
					dragOffsetX = touch.x - lane.x; dragOffsetY = touch.y - lane.y;
					dragStartX = lane.x; dragStartY = lane.y;
					refreshVisuals(); break;
				}
			}
		}
		if (dragging && touch != null && TouchUtil.pressed)
		{
			var lane = lanes[selected];
			if (resizing)
			{
				lane.setGraphicSize(Std.int(LANE_W), Std.int(Math.max(54, Math.min(editBottom() - lane.y, touch.y - lane.y))));
				lane.updateHitbox(); zonesChanged = true;
			}
			else
			{
				lane.x = Math.max(0, Math.min(FlxG.width - lane.width, touch.x - dragOffsetX));
				lane.y = Math.max(HEADER_H, Math.min(editBottom() - lane.height, touch.y - dragOffsetY));
				xChanged = true; zonesChanged = true;
			}
			refreshVisuals();
		}
		if (dragging && TouchUtil.justReleased)
		{
			if (!resizing) resolveLaneOverlap();
			dragging = false;
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
			lanes[i].setGraphicSize(Std.int(LANE_W), Std.int(h)); lanes[i].updateHitbox();
			lanes[i].x = Math.max(0, Math.min(FlxG.width - LANE_W, ClientPrefs.data.vSliceButtonX[i] * FlxG.width - LANE_W * 0.5));
			lanes[i].y = y;
		}
		refreshVisuals();
		setStatus(ClientPrefs.data.downScroll
			? 'Downscroll önizlemesi • Kontrol alanları oynanışta dikey aynalanır.'
			: 'Upscroll önizlemesi • Parlak alt kenarı sürükleyerek yüksekliği değiştir.');
	}

	function saveValues():Void
	{
		var xs:Array<Float> = [], ys:Array<Float> = [], hs:Array<Float> = [];
		var canvasH = editBottom() - HEADER_H;
		for (lane in lanes)
		{
			var normalizedH = Math.max(0.05, Math.min(1, lane.height / canvasH));
			var visualY = Math.max(0, Math.min(1 - normalizedH, (lane.y - HEADER_H) / canvasH));
			var canonicalY = ClientPrefs.data.downScroll ? 1 - visualY - normalizedH : visualY;
			xs.push((lane.x + lane.width * 0.5) / FlxG.width);
			ys.push(Math.max(0, Math.min(1 - normalizedH, canonicalY)));
			hs.push(normalizedH);
		}
		ClientPrefs.data.vSliceButtonX = xs; ClientPrefs.data.vSliceButtonY = ys; ClientPrefs.data.vSliceButtonHeight = hs;
		if (xChanged) ClientPrefs.data.vSliceCustomX = true;
		if (zonesChanged) ClientPrefs.data.vSliceCustomZones = true;
		ClientPrefs.data.ogGameControls = true; ClientPrefs.saveSettings();
	}

	function saveAndClose():Void { saveValues(); closeEditor(); }
	function closeEditor():Void {
		FlxG.mouse.visible = false;
		// MobileControlSelectSubState'e dönüyoruz; OptionsState'e değil.
		controls.isInSubstate = true;
		close();
	}
	function alignY():Void { var y = lanes[selected].y; for (lane in lanes) lane.y = Math.min(y, editBottom() - lane.height); zonesChanged = true; refreshVisuals(); setStatus("Y konumları eşitlendi."); }
	function equalHeight():Void { var h = lanes[selected].height; for (lane in lanes) { lane.setGraphicSize(Std.int(LANE_W), Std.int(Math.min(h, editBottom() - lane.y))); lane.updateHitbox(); } zonesChanged = true; refreshVisuals(); setStatus('Yükseklikler eşitlendi.'); }
	function equalSpacing():Void
	{
		var ordered = lanes.copy(); ordered.sort(function(a, b) return a.x < b.x ? -1 : (a.x > b.x ? 1 : 0));
		var step = (ordered[3].x - ordered[0].x) / 3; for (i in 0...4) ordered[i].x = ordered[0].x + step * i;
		xChanged = true; refreshVisuals(); setStatus("X aralıkları eşitlendi; Kontrol Aralığı artık kullanılmayacak.");
	}
	function pastePreset():Void { var error = VSliceControlPreset.pasteFromClipboard(); if (error != null) { setStatus(error, true); return; } xChanged = ClientPrefs.data.vSliceCustomX; zonesChanged = ClientPrefs.data.vSliceCustomZones; loadValues(); setStatus('Preset panodan yüklendi.'); }
	function resetPreset():Void { VSliceControlPreset.reset(); xChanged = false; zonesChanged = false; loadValues(); setStatus('Varsayılan düzen geri yüklendi; Kontrol Aralığı yeniden etkin.'); }

	function refreshVisuals():Void
	{
		for (i in 0...lanes.length)
		{
			var lane = lanes[i]; lane.alpha = i == selected ? 0.48 : 0.25;
			arrows[i].x = lane.x + (lane.width - arrows[i].width) * 0.5;
			arrows[i].y = lane.y + (lane.height - arrows[i].height) * 0.5;
			labels[i].x = lane.x; labels[i].y = Math.max(lane.y + 8, arrows[i].y - 25);
			handles[i].x = lane.x; handles[i].y = lane.y + lane.height - handles[i].height;
			handles[i].alpha = i == selected ? 1 : 0.6;
		}
	}
	function setStatus(message:String, error:Bool = false):Void { status.text = message; status.color = error ? 0xFFFF6374 : 0xFFADB2C8; }
	override function destroy():Void
	{
		blocksOptionsInput = false;
		FlxG.cameras.remove(ui);
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

	public function new(x:Float, y:Float, width:Float, height:Float, text:String, callback:Void->Void, color:Int, ?iconPath:String)
	{
		super(x, y); this.callback = callback; areaW = width; areaH = height;
		bg = new FlxSprite().makeGraphic(Std.int(width), Std.int(height), FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(bg, 0, 0, width, height, 16, 16, color, {thickness: 2, color: 0xFF596078}); add(bg);
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

	override function update(elapsed:Float):Void
	{
		var touch = TouchUtil.touch;
		var overTouch = touch != null && touch.x >= x && touch.x <= x + areaW && touch.y >= y && touch.y <= y + areaH;
		var overMouse = FlxG.mouse.x >= x && FlxG.mouse.x <= x + areaW && FlxG.mouse.y >= y && FlxG.mouse.y <= y + areaH;
		bg.alpha = (overTouch && TouchUtil.pressed) || (overMouse && FlxG.mouse.pressed) ? 0.72 : 1;
		if ((TouchUtil.justPressed && overTouch) || (FlxG.mouse.justPressed && overMouse)) { FlxG.sound.play(Paths.sound('scrollMenu')); callback(); }
		super.update(elapsed);
	}
}

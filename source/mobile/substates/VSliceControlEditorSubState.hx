package mobile.substates;

import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import mobile.backend.TouchUtil;
import mobile.backend.VSliceControlPreset;

/** Dört V-Slice dokunma alanı için normalize edilmiş düzen editörü. */
class VSliceControlEditorSubState extends MusicBeatSubstate
{
	static inline var TOOLBAR_H:Float = 96;
	static inline var LANE_W:Float = 150;
	var lanes:Array<FlxSprite> = [];
	var labels:Array<FlxText> = [];
	var handles:Array<FlxSprite> = [];
	var selected:Int = 0;
	var dragging:Bool = false;
	var resizing:Bool = false;
	var dragOffsetX:Float = 0;
	var dragOffsetY:Float = 0;
	var ui:FlxCamera;
	var status:FlxText;
	var xChanged:Bool = false;
	var zonesChanged:Bool = false;

	public function new()
	{
		super();
		ui = new FlxCamera();
		ui.bgColor = 0xFF101018;
		FlxG.cameras.add(ui, false);

		var colors = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
		var names = ['SOL', 'AŞAĞI', 'YUKARI', 'SAĞ'];
		for (i in 0...4)
		{
			var lane = new FlxSprite();
			lane.makeGraphic(Std.int(LANE_W), 100, colors[i]);
			lane.alpha = 0.32;
			lane.cameras = [ui];
			add(lane);
			lanes.push(lane);

			var label = new FlxText(0, 0, Std.int(LANE_W), names[i] + '\nSÜRÜKLE', 16);
			label.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER);
			label.cameras = [ui];
			add(label);
			labels.push(label);

			var handle = new FlxSprite().makeGraphic(Std.int(LANE_W), 10, FlxColor.WHITE);
			handle.alpha = 0.9;
			handle.cameras = [ui];
			add(handle);
			handles.push(handle);
		}

		makeButton(12, 10, 'KAYDET', saveAndClose);
		makeButton(152, 10, 'KOPYALA', function() { saveValues(); VSliceControlPreset.copyToClipboard(); setStatus('Preset panoya kopyalandı.'); });
		makeButton(292, 10, 'YAPIŞTIR', pastePreset);
		makeButton(432, 10, "Y'Yİ EŞİTLE", alignY);
		makeButton(572, 10, 'BOYU EŞİTLE', equalHeight);
		makeButton(712, 10, "X'İ EŞİTLE", equalSpacing);
		makeButton(852, 10, 'SIFIRLA', resetPreset);
		makeButton(992, 10, 'İPTAL', closeEditor);

		status = new FlxText(12, 59, FlxG.width - 24,
			'Bir alanı sürükleyin. Alt kenardaki parlak bölümü sürükleyerek yüksekliği değiştirin.', 15);
		status.setFormat(Paths.font('vcr.ttf'), 15, 0xFFDDDDDD, CENTER);
		status.cameras = [ui];
		add(status);

		loadValues();
		FlxG.mouse.visible = !FlxG.onMobile;
	}

	function makeButton(x:Float, y:Float, text:String, action:Void->Void):Void
	{
		var button = new FlxButton(x, y, text, action);
		button.setGraphicSize(126, 38);
		button.updateHitbox();
		button.label.setFormat(Paths.font('vcr.ttf'), 12, FlxColor.WHITE, CENTER);
		button.cameras = [ui];
		add(button);
	}

	override function update(elapsed:Float):Void
	{
		var touch = TouchUtil.touch;
		if (TouchUtil.justPressed && touch != null && touch.y >= TOOLBAR_H)
		{
			for (i in 0...lanes.length)
			{
				var lane = lanes[i];
				if (touch.x >= lane.x && touch.x <= lane.x + lane.width && touch.y >= lane.y && touch.y <= lane.y + lane.height)
				{
					selected = i;
					dragging = true;
					resizing = touch.y >= lane.y + lane.height - 34;
					dragOffsetX = touch.x - lane.x;
					dragOffsetY = touch.y - lane.y;
					refreshVisuals();
					break;
				}
			}
		}
		if (dragging && touch != null && TouchUtil.pressed)
		{
			var lane = lanes[selected];
			if (resizing)
			{
				lane.scale.y = 1;
				lane.setGraphicSize(Std.int(LANE_W), Std.int(Math.max(50, Math.min(FlxG.height - lane.y, touch.y - lane.y))));
				lane.updateHitbox();
				zonesChanged = true;
			}
			else
			{
				lane.x = Math.max(0, Math.min(FlxG.width - lane.width, touch.x - dragOffsetX));
				lane.y = Math.max(TOOLBAR_H, Math.min(FlxG.height - lane.height, touch.y - dragOffsetY));
				xChanged = true;
				zonesChanged = true;
			}
			refreshVisuals();
		}
		if (dragging && TouchUtil.justReleased) dragging = false;
		if (controls.BACK) closeEditor();
		super.update(elapsed);
	}

	function loadValues():Void
	{
		for (i in 0...4)
		{
			var h = Math.max(0.05, ClientPrefs.data.vSliceButtonHeight[i]) * FlxG.height;
			lanes[i].setGraphicSize(Std.int(LANE_W), Std.int(h));
			lanes[i].updateHitbox();
			lanes[i].x = ClientPrefs.data.vSliceButtonX[i] * FlxG.width - lanes[i].width * 0.5;
			lanes[i].y = ClientPrefs.data.vSliceButtonY[i] * FlxG.height;
		}
		refreshVisuals();
	}

	function saveValues():Void
	{
		var xs:Array<Float> = [], ys:Array<Float> = [], hs:Array<Float> = [];
		for (lane in lanes)
		{
			xs.push((lane.x + lane.width * 0.5) / FlxG.width);
			ys.push(lane.y / FlxG.height);
			hs.push(lane.height / FlxG.height);
		}
		ClientPrefs.data.vSliceButtonX = xs;
		ClientPrefs.data.vSliceButtonY = ys;
		ClientPrefs.data.vSliceButtonHeight = hs;
		if (xChanged) ClientPrefs.data.vSliceCustomX = true;
		if (zonesChanged) ClientPrefs.data.vSliceCustomZones = true;
		ClientPrefs.data.ogGameControls = true;
		ClientPrefs.saveSettings();
	}

	function saveAndClose():Void { saveValues(); closeEditor(); }
	function closeEditor():Void { FlxG.mouse.visible = false; controls.isInSubstate = false; close(); }

	function alignY():Void
	{
		var y = lanes[selected].y;
		for (lane in lanes) lane.y = Math.min(y, FlxG.height - lane.height);
		zonesChanged = true; refreshVisuals(); setStatus("Y konumları eşitlendi.");
	}

	function equalHeight():Void
	{
		var h = lanes[selected].height;
		for (lane in lanes) { lane.setGraphicSize(Std.int(LANE_W), Std.int(Math.min(h, FlxG.height - lane.y))); lane.updateHitbox(); }
		zonesChanged = true; refreshVisuals(); setStatus('Yükseklikler eşitlendi.');
	}

	function equalSpacing():Void
	{
		var ordered = lanes.copy();
		ordered.sort(function(a, b) return a.x < b.x ? -1 : (a.x > b.x ? 1 : 0));
		var left = ordered[0].x;
		var right = ordered[3].x;
		var step = (right - left) / 3;
		for (i in 0...4) ordered[i].x = left + step * i;
		xChanged = true; refreshVisuals(); setStatus("X aralıkları eşitlendi; Kontrol Aralığı ayarı artık kullanılmayacak.");
	}

	function pastePreset():Void
	{
		var error = VSliceControlPreset.pasteFromClipboard();
		if (error != null) { setStatus(error, true); return; }
		xChanged = ClientPrefs.data.vSliceCustomX;
		zonesChanged = ClientPrefs.data.vSliceCustomZones;
		loadValues(); setStatus('Preset panodan yüklendi.');
	}

	function resetPreset():Void
	{
		VSliceControlPreset.reset(); xChanged = false; zonesChanged = false; loadValues();
		setStatus('V-Slice düzeni varsayılana döndürüldü; Kontrol Aralığı yeniden etkin.');
	}

	function refreshVisuals():Void
	{
		for (i in 0...lanes.length)
		{
			lanes[i].alpha = i == selected ? 0.55 : 0.30;
			labels[i].x = lanes[i].x;
			labels[i].y = lanes[i].y + 12;
			handles[i].x = lanes[i].x;
			handles[i].y = lanes[i].y + lanes[i].height - handles[i].height;
			handles[i].alpha = i == selected ? 1 : 0.65;
			// Parlak alt kenar, yüksekliği değiştiren sürükleme tutamacıdır.
			labels[i].text = labels[i].text.split('\n')[0] + '\n' + (i == selected ? 'SEÇİLİ • ALT KENAR: BOY' : 'SÜRÜKLE');
		}
	}

	function setStatus(message:String, error:Bool = false):Void
	{
		status.text = message;
		status.color = error ? 0xFFFF5252 : 0xFFDDDDDD;
	}

	override function destroy():Void
	{
		FlxG.cameras.remove(ui);
		super.destroy();
	}
}

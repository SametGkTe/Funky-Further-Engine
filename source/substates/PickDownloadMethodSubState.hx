package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.MusicBeatSubstate;

class PickDownloadMethodSubState extends MusicBeatSubstate {
	var packName:String;
	var onPick:String->Void;
	var selected:Int = 0;

	var box:FlxSprite;
	var titleText:FlxText;
	var packText:FlxText;
	var btnAuto:FlxSprite;
	var btnManual:FlxSprite;
	var btnAutoLabel:FlxText;
	var btnManualLabel:FlxText;
	var hintText:FlxText;
	var closed:Bool = false;

	public function new(packName:String, onPick:String->Void) {
		super();
		this.packName = packName;
		this.onPick = onPick;
	}

	override function create():Void {
		super.create();

		var bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		add(bg);

		var boxW:Int = Std.int(Math.min(520, FlxG.width - 60));
		var boxH:Int = 250;
		var boxX:Int = Std.int((FlxG.width - boxW) / 2);
		var boxY:Int = Std.int((FlxG.height - boxH) / 2);

		box = new FlxSprite(boxX, boxY).makeGraphic(boxW, boxH, 0xFF0D1117);
		box.alpha = 0;
		add(box);

		var border = new FlxSprite(boxX - 2, boxY - 2).makeGraphic(boxW + 4, boxH + 4, 0xFF0D9488);
		border.alpha = 0;
		add(border);

		titleText = new FlxText(0, boxY + 26, FlxG.width, "İNDİRME YÖNTEMİ SEÇİN", 20);
		titleText.setFormat("VCR OSD Mono", 20, FlxColor.WHITE, CENTER);
		titleText.alpha = 0;
		add(titleText);

		packText = new FlxText(0, boxY + 58, FlxG.width, packName, 13);
		packText.setFormat("VCR OSD Mono", 13, 0xFF94A3B8, CENTER);
		packText.alpha = 0;
		add(packText);

		var btnW:Int = Std.int(boxW * 0.42);
		var btnH:Int = 74;
		var gap:Int = 16;
		var btnsY:Int = boxY + 104;
		var autoX:Int = boxX + Std.int((boxW - btnW * 2 - gap) / 2);

		btnAuto = new FlxSprite(autoX, btnsY).makeGraphic(btnW, btnH, 0xFF0D9488);
		btnAuto.alpha = 0;
		add(btnAuto);

		btnAutoLabel = new FlxText(autoX, btnsY + 16, btnW, "OTOMATİK", 16);
		btnAutoLabel.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, CENTER);
		btnAutoLabel.alpha = 0;
		add(btnAutoLabel);

		var autoSub = new FlxText(autoX, btnsY + 40, btnW, "(Önerilir)", 10);
		autoSub.setFormat("VCR OSD Mono", 10, 0xFFD1FAE5, CENTER);
		autoSub.alpha = 0;
		add(autoSub);

		var manualX:Int = autoX + btnW + gap;
		btnManual = new FlxSprite(manualX, btnsY).makeGraphic(btnW, btnH, 0xFF1F2937);
		btnManual.alpha = 0;
		add(btnManual);

		btnManualLabel = new FlxText(manualX, btnsY + 24, btnW, "MANUEL", 16);
		btnManualLabel.setFormat("VCR OSD Mono", 16, 0xFFCBD5E1, CENTER);
		btnManualLabel.alpha = 0;
		add(btnManualLabel);

		hintText = new FlxText(0, boxY + boxH - 40, FlxG.width, "[←/→] Seç  |  [ENTER] Onayla  |  [ESC] İptal", 11);
		hintText.setFormat("VCR OSD Mono", 11, 0xFF666666, CENTER);
		hintText.alpha = 0;
		add(hintText);

		box.alpha = 0.95;
		border.alpha = 1;
		FlxTween.tween(titleText, {alpha: 1}, 0.15);
		FlxTween.tween(packText, {alpha: 1}, 0.15);
		FlxTween.tween(btnAuto, {alpha: 1}, 0.15);
		FlxTween.tween(btnManual, {alpha: 1}, 0.15);
		FlxTween.tween(btnAutoLabel, {alpha: 1}, 0.15);
		FlxTween.tween(btnManualLabel, {alpha: 1}, 0.15);
		FlxTween.tween(autoSub, {alpha: 1}, 0.15);
		FlxTween.tween(hintText, {alpha: 1}, 0.15);

		updateSelection();
	}

	function updateSelection():Void {
		btnAuto.color = selected == 0 ? 0xFF0D9488 : 0xFF16222E;
		btnManual.color = selected == 1 ? 0xFF0D9488 : 0xFF16222E;
		btnAutoLabel.color = selected == 0 ? FlxColor.WHITE : 0xFF64748B;
		btnManualLabel.color = selected == 1 ? FlxColor.WHITE : 0xFF64748B;
	}

	function confirm():Void {
		if (closed) return;
		closed = true;

		FlxG.sound.play(Paths.sound('confirmMenu'));

		var picked:String = selected == 0 ? "auto" : "manual";

		FlxTween.tween(box, {alpha: 0}, 0.15, {
			onComplete: function(_) {
				close();
				if (onPick != null) onPick(picked);
			}
		});
		FlxTween.tween(titleText, {alpha: 0}, 0.12);
		FlxTween.tween(packText, {alpha: 0}, 0.12);
		FlxTween.tween(btnAuto, {alpha: 0}, 0.12);
		FlxTween.tween(btnManual, {alpha: 0}, 0.12);
		FlxTween.tween(btnAutoLabel, {alpha: 0}, 0.12);
		FlxTween.tween(btnManualLabel, {alpha: 0}, 0.12);
		FlxTween.tween(hintText, {alpha: 0}, 0.12);
	}

	function cancelOut():Void {
		if (closed) return;
		closed = true;

		FlxG.sound.play(Paths.sound('cancelMenu'));
		close();
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);

		if (closed) return;

		if (controls.UI_LEFT_P || controls.UI_RIGHT_P) {
			selected = selected == 0 ? 1 : 0;
			updateSelection();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		if (controls.ACCEPT) {
			confirm();
			return;
		}
		if (controls.BACK) {
			cancelOut();
			return;
		}

		if (FlxG.mouse.overlaps(btnAuto)) {
			if (selected != 0) {
				selected = 0;
				updateSelection();
			}
			if (FlxG.mouse.justPressed) {
				confirm();
				return;
			}
		}
		if (FlxG.mouse.overlaps(btnManual)) {
			if (selected != 1) {
				selected = 1;
				updateSelection();
			}
			if (FlxG.mouse.justPressed) {
				confirm();
				return;
			}
		}
	}
}

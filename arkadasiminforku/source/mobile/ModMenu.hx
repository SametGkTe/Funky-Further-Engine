package mobile;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.events.MouseEvent;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldType;
import openfl.text.TextFormatAlign;
import openfl.geom.Rectangle;
import openfl.geom.ColorTransform;
import openfl.Lib;
import haxe.Timer;

class ModMenu extends Sprite {
	public static var menuScale:Float = 1.5;

	private var container:Sprite;
	private var icon:Sprite;
	private var scrollContainer:Sprite;
	private var contentLayer:Sprite;
	
	private var menuWidth:Int = 360;
	private var menuHeight:Int = 550;
	private var headerHeight:Int = 60;
	private var currentY:Float = 15;

	private var isDragging:Bool = false;
	private var isSliderDragging:Bool = false;
	private var lastY:Float = 0;
	private var scrollDist:Float = 0;

	private var startX:Float;
	private var startY:Float;

	public function new(?floatText:String, startX:Float = 50, startY:Float = 50) {
		super();
		this.startX = startX;
		this.startY = startY;
		if (stage != null) init(floatText);
		else addEventListener(Event.ADDED_TO_STAGE, function(_) init());
	}

	private function init(?floatText:String) {
		icon = new Sprite();
		icon.x = startX; icon.y = startY;
		icon.graphics.beginFill(0xFF0000, 0.7);
		icon.graphics.drawRoundRect(0, 0, 80, 80, 20, 20);
		icon.addChild(createText(0, 28, floatText, 16, 80, true));
		icon.addEventListener(MouseEvent.MOUSE_DOWN, function(_) icon.startDrag());
		icon.addEventListener(MouseEvent.MOUSE_UP, function(_) { icon.stopDrag(); toggleMenu(true); });
		addChild(icon);

		container = new Sprite();
		container.visible = false;
		container.alpha = 0;
		container.x = startX; container.y = startY;
		addChild(container);

		var bg = new Shape();
		bg.graphics.beginFill(0x000000, 0.95);
		bg.graphics.drawRoundRect(0, 0, menuWidth, menuHeight, 15, 15);
		container.addChild(bg);

		var dragBar = new Sprite();
		dragBar.graphics.beginFill(0xFFFFFF, 0.1);
		dragBar.graphics.drawRoundRect(0, 0, menuWidth, headerHeight, 15, 15);
		dragBar.addChild(createText(0, 15, "ONLINE HACKS", 22, menuWidth, true));
		dragBar.addEventListener(MouseEvent.MOUSE_DOWN, function(_) container.startDrag());
		dragBar.addEventListener(MouseEvent.MOUSE_UP, function(_) container.stopDrag());
		container.addChild(dragBar);

		scrollContainer = new Sprite();
		scrollContainer.x = 0; scrollContainer.y = headerHeight + 5;
		scrollContainer.scrollRect = new Rectangle(0, 0, menuWidth, 400); 
		container.addChild(scrollContainer);

		contentLayer = new Sprite();
		scrollContainer.addChild(contentLayer);

		scrollContainer.addEventListener(MouseEvent.MOUSE_DOWN, onDown);
		Lib.current.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMove);
		Lib.current.stage.addEventListener(MouseEvent.MOUSE_UP, onUp);

		addOptions();

		var minBtn = new Sprite();
		minBtn.graphics.beginFill(0xCC0000);
		minBtn.graphics.drawRoundRect(0, 0, 310, 50, 10, 10);
		minBtn.x = (menuWidth - 310) / 2; minBtn.y = menuHeight - 65;
		minBtn.addChild(createText(0, 12, "MINIMIZE", 18, 310, true));
		minBtn.addEventListener(MouseEvent.CLICK, function(_) toggleMenu(false));
		container.addChild(minBtn);

		updateScale();
	}

	private function addOptions() {
		addValueChanger("Menu Scale", Std.string(menuScale), function(val) {
			var ns = Std.parseFloat(val);
			if (!Math.isNaN(ns) && ns >= 0.5 && ns <= 2.0) {
				menuScale = ns;
				updateScale();
			}
		});

		/*
		addSlider("Game Speed", 0.5, 3.0, gameSpeed, function(val) { gameSpeed = val; });
		addInput("Nickname", "Player1", function(t) { trace(t); });
		*/
	}

	private function addInput(label:String, defaultText:String, onEnter:String->Void) {
		var group = new Sprite();
		group.x = 25; group.y = currentY;
		var bg = new Shape();
		bg.graphics.beginFill(0x222222);
		bg.graphics.drawRoundRect(0, 0, 310, 75, 10, 10);
		group.addChild(bg);
		group.addChild(createText(12, 5, label, 13, 200));

		var input = new TextField();
		var fmt = new TextFormat("_sans", 16, 0xFFFFFF, false, null, null, null, null, TextFormatAlign.CENTER);
		input.defaultTextFormat = fmt;
		input.type = TextFieldType.INPUT;
		input.background = true;
		input.backgroundColor = 0x333333;
		input.text = defaultText;
		input.x = 15; 
		input.y = 32;
		input.width = 280; input.height = 32;
		
		input.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent) {
			if (e.keyCode == Keyboard.ENTER) { onEnter(input.text); stage.focus = null; }
		});
		input.addEventListener(MouseEvent.MOUSE_UP, function(_) { if(!isDragging) stage.focus = input; });
		group.addChild(input);
		contentLayer.addChild(group);
		currentY += 85;
	}

	private function addValueChanger(label:String, defaultVal:String, onApply:String->Void) {
		var group = new Sprite();
		group.x = 25; group.y = currentY;
		var bg = new Shape();
		bg.graphics.beginFill(0x222222);
		bg.graphics.drawRoundRect(0, 0, 310, 80, 10, 10);
		group.addChild(bg);
		group.addChild(createText(12, 5, label, 13, 200));

		var input = new TextField();
		input.defaultTextFormat = new TextFormat("_sans", 16, 0xFFFFFF, false, null, null, null, null, TextFormatAlign.CENTER);
		input.type = TextFieldType.INPUT;
		input.background = true;
		input.backgroundColor = 0x333333;
		input.text = defaultVal;
		input.x = 15; input.y = 32;
		input.width = 180; input.height = 32;
		input.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent) {
			if (e.keyCode == Keyboard.ENTER) { onApply(input.text); stage.focus = null; }
		});
		input.addEventListener(MouseEvent.MOUSE_UP, function(_) { if(!isDragging) stage.focus = input; });
		group.addChild(input);

		var applyBtn = new Sprite();
		applyBtn.graphics.beginFill(0x444444);
		applyBtn.graphics.drawRoundRect(0, 0, 90, 32, 8, 8);
		applyBtn.x = 205; applyBtn.y = 32;
		applyBtn.addChild(createText(0, 6, "SET", 14, 90, true));
		applyBtn.addEventListener(MouseEvent.CLICK, function(_) { onApply(input.text); applyFlashEffect(applyBtn); });
		group.addChild(applyBtn);

		contentLayer.addChild(group);
		currentY += 90;
	}

	private function toggleMenu(show:Bool) {
		if (show) {
			container.visible = true;
			container.alpha = 0;
			container.x = icon.x; container.y = icon.y;
			icon.visible = false;
			var frames = 0;
			var timer = new Timer(16);
			timer.run = function() {
				container.alpha += 0.1;
				frames++;
				if (frames >= 10) { container.alpha = 1; timer.stop(); }
			};
		} else {
			icon.visible = true;
			icon.x = container.x; icon.y = container.y;
			container.visible = false;
		}
	}

	private function addSlider(label:String, min:Float, max:Float, start:Float, onUpdate:Float->Void) {
		var group = new Sprite();
		group.x = 25; group.y = currentY;
		var bg = new Shape();
		bg.graphics.beginFill(0x222222);
		bg.graphics.drawRoundRect(0, 0, 310, 85, 10, 10);
		group.addChild(bg);
		var title = createText(0, 8, label + ": " + start, 15, 310, true);
		group.addChild(title);
		var track = new Shape();
		track.graphics.beginFill(0x555555);
		track.graphics.drawRoundRect(15, 52, 280, 4, 2, 2);
		group.addChild(track);
		var handle = new Sprite();
		handle.graphics.beginFill(0xFF0000);
		handle.graphics.drawCircle(0, 0, 15);
		handle.x = 15 + ((start - min) / (max - min)) * 280;
		handle.y = 54;
		var moveFunc = function(e:MouseEvent) {
			var p = (handle.x - 15) / 280;
			var val = Math.round((min + (p * (max - min))) * 10) / 10;
			title.text = label + ": " + val;
			onUpdate(val);
		};
		handle.addEventListener(MouseEvent.MOUSE_DOWN, function(e) {
			isSliderDragging = true;
			handle.startDrag(false, new Rectangle(15, 54, 280, 0));
			stage.addEventListener(MouseEvent.MOUSE_MOVE, moveFunc);
		});
		stage.addEventListener(MouseEvent.MOUSE_UP, function(_) {
			if (isSliderDragging) {
				handle.stopDrag();
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, moveFunc);
				Timer.delay(function() { isSliderDragging = false; }, 100);
			}
		});
		group.addChild(handle);
		contentLayer.addChild(group);
		currentY += 95;
	}

	private function addToggleButton(label:String, onClick:TextField->Void) {
		var btn = new Sprite();
		btn.graphics.beginFill(0x222222);
		btn.graphics.drawRoundRect(0, 0, 310, 55, 10, 10);
		btn.x = 25; btn.y = currentY;
		var tf = createText(0, 12, label, 18, 310, true);
		tf.name = "label";
		btn.addChild(tf);
		btn.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent) {
			if (!isDragging && !isSliderDragging && scrollDist < 10) { onClick(tf); applyFlashEffect(btn); }
		});
		contentLayer.addChild(btn);
		currentY += 65;
	}

	private function createText(x:Float, y:Float, str:String, size:Int, w:Float, center:Bool = false):TextField {
		var tf = new TextField();
		var fmt = new TextFormat("_sans", size, 0xFFFFFF, true);
		if (center) fmt.align = TextFormatAlign.CENTER;
		tf.defaultTextFormat = fmt;
		tf.text = str; tf.x = x; tf.y = y; tf.width = w;
		tf.selectable = false; tf.mouseEnabled = false;
		return tf;
	}

	private function onDown(e:MouseEvent) {
		if (!container.visible || isSliderDragging) return;
		isDragging = false; scrollDist = 0; lastY = e.stageY;
	}

	private function onMove(e:MouseEvent) {
		if (!container.visible || !e.buttonDown || isSliderDragging) return;
		if (isDragging || scrollContainer.hitTestPoint(e.stageX, e.stageY)) {
			var deltaY = e.stageY - lastY;
			lastY = e.stageY;
			scrollDist += Math.abs(deltaY);
			if (scrollDist > 10) { isDragging = true; contentLayer.y += deltaY; checkBounds(); }
		}
	}

	private function onUp(e:MouseEvent) { Timer.delay(function() { isDragging = false; }, 50); }

	private function checkBounds() {
		if (contentLayer.y > 0) contentLayer.y = 0;
		var limit = -(currentY - 400 + 20);
		if (limit < 0 && contentLayer.y < limit) contentLayer.y = limit;
		if (limit >= 0) contentLayer.y = 0;
	}

	private function applyFlashEffect(s:Sprite) {
		s.transform.colorTransform = new ColorTransform(1,1,1,1,150,150,150,0);
		Timer.delay(function() { s.transform.colorTransform = new ColorTransform(); }, 100);
	}

	public function updateScale() { this.scaleX = this.scaleY = menuScale; }
}

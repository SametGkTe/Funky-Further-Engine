package online.gui.sidebar.obj;

import online.gui.sidebar.obj.TabSprite.ITabInteractable;

class TabButton extends Sprite implements ITabInteractable {

	public var onClick:Void->Void;

	public var icon:Bitmap;
	public var underlay:Bitmap;
	public var border:Bitmap;

	public function new(daIcon:String, onClick:Void->Void) {
		super();

		this.onClick = onClick;

		var s:Float = SideUI.uiScale;

		border = new Bitmap(GAssets.image('sidebar/button_border'));
		border.smoothing = true; // Mobilde daha yumuşak görünmesi için
		border.width = Std.int(56 * s); // 56 yerine ölçekli değer
		border.height = Std.int(56 * s);

		icon = new Bitmap(GAssets.image('sidebar/' + daIcon));
		icon.smoothing = true;
		icon.x = 3 * s;
		icon.y = 3 * s;
		icon.width = Std.int(50 * s); // 50 yerine ölçekli değer
		icon.height = Std.int(50 * s);

		underlay = new Bitmap(new BitmapData(Std.int(50 * s), Std.int(50 * s), true, FlxColor.fromRGB(100, 100, 100)));
		underlay.x = icon.x;
		underlay.y = icon.y;

		addChild(underlay);
		addChild(icon);
		addChild(border);

		updateVisual();
	}
	private function mouseDown(event:MouseEvent) {
		if (this.overlapsMouse()) {
			onClick();
		}
    }
	private function mouseMove(event:MouseEvent) {
		updateVisual();
    }

    function updateVisual() {
		underlay.alpha = 0.4;
		border.alpha = 0.4;
		if (this.overlapsMouse()) {
			underlay.alpha = 1;
			border.alpha = 1;
		}
    }

	private function keyDown(event:KeyboardEvent) {};
	private function mouseWheel(event:MouseEvent) {};
}
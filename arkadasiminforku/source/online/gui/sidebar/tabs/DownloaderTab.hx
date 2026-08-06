package online.gui.sidebar.tabs;

import online.gui.sidebar.obj.TabSprite.ITabInteractable;

class DownloaderTab extends TabSprite {
    public function new() {
        super('Downloads', 'downloads');
    }

    override function create() {
        super.create();

		var title = this.createText(0, 0, Std.int(20 * S), FlxColor.WHITE);
		title.setText('Downloader Test');
		addChild(title);

		for (dow in ModDownloader.downloaders) {
            
        }
    }
}

class DownloadItem extends Sprite implements ITabInteractable {
	public var underlay:Bitmap;
	public var nameTxt:TextField;
	public var status:TextField;
	public var cancel:TabButton;
	public var bar:Bitmap;

    public function new() {
        super();

		// Arka plan yüksekliğini 80'den 100 * S'ye çıkardık (dokunması kolay olsun)
        underlay = new Bitmap(new BitmapData(Std.int(SideUI.DEFAULT_TAB_WIDTH * S), Std.int(100 * S), true, FlxColor.fromRGB(20, 20, 20)));
        addChild(underlay);

        // Yazıları ve boşlukları (20, 30 gibi) S ile çarparak büyüttük
        nameTxt = this.createText(20 * S, 15 * S, Std.int(22 * S));
        addChild(nameTxt);

        status = this.createText(nameTxt.x, nameTxt.y + (35 * S), Std.int(18 * S));
        addChild(status);

        cancel = new TabButton('cancel', () -> {});
        // Butonu sağa yaslarken kenar payını (20) ölçeklendirdik
        cancel.x = underlay.width - cancel.width - (20 * S);
        cancel.y = underlay.height / 2 - cancel.height / 2;
        addChild(cancel);

        updateVisual();
    }

    public function create(trackId:String) {
        // Buradaki BitmapData boyutunu da new fonksiyonuyla aynı yapıyoruz
        underlay.bitmapData = new BitmapData(Std.int(SideUI.DEFAULT_TAB_WIDTH * S), Std.int(100 * S), true, FlxColor.fromRGB(20, 20, 20));

        nameTxt.setText(trackId);
        status.setText('Initializing...');

        cancel.onClick = () -> {
        // İptal işlemleri

		}
	}

	override function __enterFrame(delta) {
		super.__enterFrame(delta);

	}

	private function mouseDown(event:MouseEvent) {}
	private function mouseMove(event:MouseEvent) {
		updateVisual();
    }

    function updateVisual() {
		underlay.alpha = 0.3;
		if (this.overlapsMouse()) {
			underlay.alpha = 0.6;
		}
    }

	private function keyDown(event:KeyboardEvent) {};
	private function mouseWheel(event:MouseEvent) {};
}
package online.gui.sidebar.tabs;

class ReportTab extends TabSprite {
    public function new() {
        super('Rapor Et', 'report');
    }

    override function create() {
        super.create();

		var title = this.createText(0, 0, 20, FlxColor.WHITE);
        title.setText('Rapor Testi');
		addChild(title);
    }
}
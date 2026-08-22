package states;

class DebugErrState extends MusicBeatState
{
	final details:String;

	public function new(details:String)
	{
		this.details = details;
		super();
	}

	override function create():Void
	{
		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.scrollFactor.set();
		add(bg);

		var text = new FlxText(24, 20, FlxG.width - 48, details, 24);
		text.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, LEFT);
		text.scrollFactor.set();
		text.autoSize = false;
		add(text);

		var footer = new FlxText(24, FlxG.height - 42, FlxG.width - 48,
			'ENTER / A: Ana menü     ESC / B: Geri', 18);
		footer.setFormat(Paths.font('vcr.ttf'), 18, 0xFFAAAAAA, LEFT);
		footer.scrollFactor.set();
		add(footer);

		super.create();
		addTouchPad('NONE', 'A_B');
		addTouchPadCamera();
	}

	override function update(elapsed:Float):Void
	{
		if (controls.ACCEPT)
			MenuStyleRouter.goToMainMenu();
		else if (controls.BACK)
			FlxG.switchState(new TitleState());

		super.update(elapsed);
	}
}

package states;

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var warnText:FlxText;
	override function create()
	{
		super.create();

		leftState = false;

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		warnText = new FlxText(0, 0, FlxG.width,
			"Üzgünüz, Ama Bu Versiyon Artık Güncel Değil,
			Sizin Versiyonunuz '" + Main.PSYCH_ONLINE_VERSION + "' Son
			Versiyon '" + Main.updateVersion + "'\n
			A - İndirme Sayfasına Git!
			B - Güncellemeden Devam Et.
			P.E.T ONLINE'IN GÜNCELLENMESINI BEKLEYIN",
			32);
		warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		add(warnText);
		
		mobileManager.addMobilePad('NONE', 'A_B');
	}

	override function update(elapsed:Float)
	{
		if(!leftState) {
			if (controls.ACCEPT) {
				CoolUtil.browserLoad(Main.updatePageURL);
				online.network.Auth.saveClose();
				Sys.exit(1);
			}
			else if(controls.BACK) {
				leftState = true;
			}

			if(leftState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(warnText, {alpha: 0}, 1, {
					onComplete: function (twn:FlxTween) {
						FlxG.switchState(() -> new MainMenuState());
					}
				});
			}
		}
		super.update(elapsed);
	}
}

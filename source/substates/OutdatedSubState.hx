package substates;

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

import states.MainMenuState;
import states.TitleState;

class OutdatedSubState extends MusicBeatSubstate
{
	// Further Engine: sürüm artık ReleaseChecker'dan gelir (GitHub Releases API)
	public static var updateVersion:String = backend.update.ReleaseChecker.latestVersion;
	var leftState:Bool = false;

	var bg:FlxSprite;
	var warnText:FlxText;

	override function create()
	{
		controls.isInSubstate = true;
		final enter:String = (controls.mobileC) ? 'A' : 'ENTER';
		final back:String = (controls.mobileC) ? 'B' : 'BACK';

		super.create();

		// ReleaseChecker henüz sonuçlanmadıysa son değeri tazele
		if (updateVersion == null || updateVersion.length == 0)
			updateVersion = backend.update.ReleaseChecker.latestVersion;
		if (updateVersion == null || updateVersion.length == 0)
			updateVersion = "?";

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.scrollFactor.set();
		bg.alpha = 0.0;
		add(bg);

		warnText = new FlxText(0, 0, FlxG.width,
			'Further Engine için yeni bir sürüm mevcut!\n\n			Mevcut sürüm: ${MainMenuState.psychEngineVersion}\n			En son sürüm: ${updateVersion}\n\n			-----------------------------------------------\n\n			$enter — Güncelleme sayfasını aç\n			$back — Yine de devam et\n\n			Bu uyarıyı Ayarlar → "Güncellemeleri Kontrol Et" seçeneğinden kapatabilirsin.\n\n			-----------------------------------------------\n\n			İyi oyunlar!',
			32);
		warnText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		warnText.scrollFactor.set();
		warnText.screenCenter(Y);
		warnText.alpha = 0.0;
		add(warnText);

		addTouchPad("NONE", "A_B");
		touchPad.alpha = 0;

		FlxTween.tween(bg, { alpha: 0.8 }, 0.6, { ease: FlxEase.sineIn });
		FlxTween.tween(warnText, { alpha: 1.0 }, 0.6, { ease: FlxEase.sineIn });
		FlxTween.tween(touchPad, { alpha: 1.0 }, 0.6, { ease: FlxEase.sineIn });
	}

	override function update(elapsed:Float)
	{
		if(!leftState) {
			if (controls.ACCEPT) {
				leftState = true;
				// Further Engine: kendi repo'nun releases sayfası (API'den gelen URL öncelikli)
				var url:String = backend.update.ReleaseChecker.releaseUrl;
				if (url == null || url.length == 0)
					url = 'https://github.com/${backend.update.UpdateConfig.GITHUB_REPO_OWNER}/${backend.update.UpdateConfig.GITHUB_REPO_NAME}/releases';
				CoolUtil.browserLoad(url);
			}
			else if(controls.BACK) {
				leftState = true;
			}
			if(leftState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(bg, { alpha: 0.0 }, 0.9, { ease: FlxEase.sineOut });
				FlxTween.tween(touchPad, { alpha: 0.0 }, 1, { ease: FlxEase.sineOut });
				FlxTween.tween(warnText, {alpha: 0}, 1, {
					ease: FlxEase.sineOut,
					onComplete: function (twn:FlxTween) {
						FlxG.state.persistentUpdate = true;
						controls.isInSubstate = false;
						close();
					}
				});
			}
		}
		super.update(elapsed);
	}
}
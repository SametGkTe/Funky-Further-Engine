package states;

import flixel.FlxSubState;

import flixel.effects.FlxFlicker;
import lime.app.Application;
import flixel.addons.transition.FlxTransitionableState;

class FlashingState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var warnText:FlxText;
	override function create()
	{
		super.create();

		final enter:String = (controls.mobileControls) ? 'A' : 'ENTER';
		final back:String = (controls.mobileControls) ? 'B' : 'BACK';

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		warnText = new FlxText(0, 0, FlxG.width,
			"Hey, dikkatli olun!\n
			Bu Oyun yanıp sönen ışıklar içeriyor!\n
			Hemen şimdi devre dışı bırakmak için A Tuşuna basın veya Ayarlar'a gidin.\n
			Bu mesajı görmezden gelmek için B tuşuna basın.\n
			Uyarıldınız!
			Psych Engine Türkiye - Online V1",
			32);
		warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		add(warnText);
		mobileManager.addMobilePad('NONE', 'A_B');
	}

	override function update(elapsed:Float)
	{
		if(!leftState) {
			var back:Bool = controls.BACK;
			if (controls.ACCEPT || back) {
				leftState = true;
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				if(!back) {
					ClientPrefs.data.flashing = false;
					ClientPrefs.saveSettings();
					FlxG.sound.play(Paths.sound('confirmMenu'));
					FlxFlicker.flicker(warnText, 1, 0.1, false, true, function(flk:FlxFlicker) {
						new FlxTimer().start(0.5, function (tmr:FlxTimer) {
							FlxG.switchState(() -> new TitleState());
						});
					});
				} else {
					FlxG.sound.play(Paths.sound('cancelMenu'));
					FlxTween.tween(warnText, {alpha: 0}, 1, {
						onComplete: function (twn:FlxTween) {
							FlxG.switchState(() -> new TitleState());
						}
					});
				}
			}
		}
		super.update(elapsed);
	}
}

package online.substates;

import openfl.filters.BlurFilter;

class VerifyCodeSubstate extends MusicBeatSubstate {
    public function new(onEnter:String->Void) {
        super();

        this.onEnter = onEnter;
    }

    var onEnter:String->Void;
	var blurFilter:BlurFilter;
	var blackSprite:FlxSprite;
	var coolCam:FlxCamera;

    override function create() {
        super.create();

		if (!ClientPrefs.data.disableOnlineShaders) {
			blurFilter = new BlurFilter();
			for (cam in FlxG.cameras.list) {
				if (cam.filters == null)
					cam.filters = [];
				cam.filters.push(blurFilter);
			}
		} else {
			blackSprite = new FlxSprite();
			blackSprite.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
			blackSprite.alpha = 0.75;
			add(blackSprite);
		}

		coolCam = new FlxCamera();
		coolCam.bgColor.alpha = 0;
		FlxG.cameras.add(coolCam, false);

		cameras = [coolCam];

		var bg = new FlxSprite();
		bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.7;
		bg.scrollFactor.set(0, 0);
		add(bg);

		var title = new FlxText(0, 0, FlxG.width,
			'Bu e-posta adresine bir Doğrulama Kodu gönderildi!\n' +
			'Lütfen sunucunun bu e-postanın kayıtlı olup olmadığını size söylemeyeceğini unutmayın!\n' +
			'Eğer kodu bulamıyorsanız, spam (istenmeyen) kutunuzu kontrol edin.\n' +
			'Kodu aldıysanız, lütfen buraya girin!' +
			' Eğer Kod gelmediyse Sunucu Bakımda / Dinlenmede Olabilir'
		);
		title.setFormat("VCR OSD Mono", 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.y = FlxG.height / 2 - title.height / 2 - 225;
		title.scrollFactor.set();
		add(title);

		input = new InputText(0, 0, FlxG.width, text -> {
			onEnter(text.trim().toUpperCase());
			close();
		});
		input.setFormat("VCR OSD Mono", 30, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		input.y = FlxG.height / 2 - input.height / 2;
		input.scrollFactor.set();
		add(input);
    }

	override function destroy() {
		super.destroy();

		if (!ClientPrefs.data.disableOnlineShaders) {
			for (cam in FlxG.cameras.list) {
				if (cam?.filters != null)
					cam.filters.remove(blurFilter);
			}
		} else
			blackSprite.destroy();
		FlxG.cameras.remove(coolCam);
	}

	var input:InputText;

    var confirmBack = false;
    override function update(elapsed) {
        super.update(elapsed);

		input.hasFocus = true;

        if (input.text.length <= 0 && controls.BACK) {
            if (!confirmBack) {
				confirmBack = true;
                return;
            }
            close();
        }
		else if (input.text.length > 0) {
			confirmBack = false;
        }
    }
}
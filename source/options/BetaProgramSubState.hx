package options;

import backend.update.BetaChecker;

class BetaProgramSubState extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var titleText:Alphabet;
	var infoText:FlxText;
	var statusText:FlxText;
	var hintText:FlxText;
	var items:Array<Alphabet> = [];
	var curSelected:Int = 0;
	var checking:Bool = false;

	static inline var ITEM_TOGGLE:Int = 0;
	static inline var ITEM_CHECK:Int = 1;
	static inline var ITEM_DOWNLOAD:Int = 2;

	override function create()
	{
		controls.isInSubstate = true;
		super.create();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF101033;
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		titleText = new Alphabet(70, 40, Language.getPhrase('beta_program_title', 'Beta Programı'), true);
		titleText.setScale(0.75);
		titleText.scrollFactor.set();
		add(titleText);

		infoText = new FlxText(50, 110, FlxG.width - 100, '', 20);
		infoText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoText.borderSize = 1.8;
		infoText.scrollFactor.set();
		add(infoText);

		statusText = new FlxText(50, 250, FlxG.width - 100, '', 18);
		statusText.setFormat(Paths.font('vcr.ttf'), 18, 0xFFFFD94D, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		statusText.borderSize = 1.8;
		statusText.scrollFactor.set();
		add(statusText);

		var labels:Array<String> = ['', 'Beta Güncellemelerini Denetle', 'Yeni Beta İndirme Sayfasını Aç'];
		for (i in 0...3)
		{
			var item:Alphabet = new Alphabet(90, 380, labels[i], false);
			item.isMenuItem = true;
			item.targetY = i;
			item.scrollFactor.set();
			add(item);
			items.push(item);
		}

		hintText = new FlxText(0, FlxG.height - 40, FlxG.width, 'A: Seç    B: Geri', 16);
		hintText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hintText.borderSize = 1.5;
		hintText.scrollFactor.set();
		add(hintText);

		addTouchPad('UP_DOWN', 'A_B');

		refreshJoinLabel();
		refreshInfo();
		refreshItems();
		changeSelection(0, false);
	}

	function isJoined():Bool
		return ClientPrefs.data.betaProgram == true;

	function refreshJoinLabel():Void
	{
		items[ITEM_TOGGLE].text = isJoined() ? 'Beta Programı: KATILDI  (Ayrılmak için seç)' : 'Beta Programı: KATILMADI  (Katılmak için seç)';
	}

	function refreshInfo():Void
	{
		infoText.text = 'Beta sürümleri yeni özellikleri herkesten önce dener; kararsız olabilir.\n'
			+ 'Programa katılırsan oyun içi güncelleme denetimi beta (pre-release) kanalına geçer.\n\n'
			+ 'Kurulu sürüm: v' + UpdateConfig.CURRENT_ENGINE_VERSION + '\n'
			+ 'Güncelleme kanalı: ' + (isJoined() ? 'BETA (pre-release)' : 'Kararlı (stable)');
	}

	function refreshItems():Void
	{
		items[ITEM_DOWNLOAD].visible = BetaChecker.hasUpdate;
		if (!items[curSelected].visible)
			curSelected = ITEM_TOGGLE;
		for (i in 0...items.length)
			items[i].alpha = items[i].visible ? 0.6 : 0;
		items[curSelected].alpha = 1;
	}

	function setStatus(msg:String):Void
		statusText.text = msg;

	function toggleJoin():Void
	{
		ClientPrefs.data.betaProgram = !isJoined();
		ClientPrefs.saveSettings();
		refreshJoinLabel();
		refreshInfo();
		setStatus(isJoined()
			? 'Beta Programına katıldın! Beta sürümleri hata içerebilir; kayıtlarını yedeklemeni öneririz.'
			: 'Beta Programından ayrıldın. Güncelleme denetimleri kararlı kanaldan yapılacak.');
		FlxG.sound.play(Paths.sound('confirmMenu'));
		refreshItems();
	}

	function startCheck():Void
	{
		if (checking) return;
		if (!isJoined())
		{
			setStatus('Önce Beta Programına katılmalısın.');
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}
		checking = true;
		setStatus('Beta sürümleri denetleniyor...');
		BetaChecker.check(function()
		{
			checking = false;
			if (BetaChecker.lastError != '' && BetaChecker.latestVersion == '')
			{
				setStatus('Denetim başarısız: ' + BetaChecker.lastError + '  -  İnternet bağlantını kontrol et.');
			}
			else if (BetaChecker.hasUpdate)
			{
				setStatus('Yeni beta bulundu: v' + BetaChecker.latestVersion + '  (kurulu: v' + UpdateConfig.CURRENT_ENGINE_VERSION + ')');
			}
			else if (BetaChecker.latestVersion != '')
			{
				setStatus('En güncel betadasın. Son beta: v' + BetaChecker.latestVersion);
			}
			else
			{
				setStatus('Şu anda yayınlanmış bir beta sürümü yok.');
			}
			refreshItems();
			FlxG.sound.play(Paths.sound(BetaChecker.hasUpdate ? 'confirmMenu' : 'scrollMenu'));
		});
	}

	function openDownload():Void
	{
		if (BetaChecker.releaseUrl == '') return;
		FlxG.openURL(BetaChecker.releaseUrl);
		FlxG.sound.play(Paths.sound('confirmMenu'));
	}

	function activateSelected():Void
	{
		switch (curSelected)
		{
			case ITEM_TOGGLE:
				toggleJoin();
			case ITEM_CHECK:
				startCheck();
			case ITEM_DOWNLOAD:
				openDownload();
		}
	}

	function changeSelection(change:Int = 0, playSound:Bool = true):Void
	{
		var next:Int = curSelected;
		for (_ in 0...items.length)
		{
			next = FlxMath.wrap(next + change, 0, items.length - 1);
			if (items[next].visible) break;
		}
		curSelected = next;
		for (i in 0...items.length)
			items[i].alpha = items[i].visible ? 0.6 : 0;
		items[curSelected].alpha = 1;
		if (playSound && change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.UI_UP_P)
			changeSelection(-1);
		if (controls.UI_DOWN_P)
			changeSelection(1);

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
			return;
		}

		if (controls.ACCEPT)
			activateSelected();
	}

	override function destroy()
	{
		ClientPrefs.saveSettings();
		super.destroy();
	}
}

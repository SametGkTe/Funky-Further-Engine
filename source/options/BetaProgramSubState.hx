package options;

import backend.TesterProgram;
import backend.update.BetaChecker;

/**
 * TESTER PROGRAMI ekranı.
 *
 * Eskiden "Beta Programı" adındaki bu ekran sadece yerel bir bool'u açıp
 * kapatıyordu (kayıt dosyası elle düzenlenerek tester olunabiliyordu).
 * Artık karar SUNUCUDA: Supabase'deki tester_program kaydı.
 *
 * Buradaki ekran sadece:
 *   - sunucudan gelen durumu gösterir,
 *   - katıl / ayrıl çağrısını yapar,
 *   - onaylı tester'a beta güncelleme araçlarını açar.
 */
class BetaProgramSubState extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var titleText:Alphabet;
	var infoText:FlxText;
	var statusText:FlxText;
	var items:Array<Alphabet> = [];
	var curSelected:Int = 0;
	var checking:Bool = false;

	static inline var ITEM_JOIN:Int = 0;
	static inline var ITEM_REFRESH:Int = 1;
	static inline var ITEM_CHECK:Int = 2;
	static inline var ITEM_DOWNLOAD:Int = 3;

	override function create()
	{
		controls.isInSubstate = true;
		super.create();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF101033;
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		titleText = new Alphabet(70, 40, Language.getPhrase('tester_program_title', 'Tester Programı'), true);
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

		for (i in 0...4)
		{
			var item:Alphabet = new Alphabet(90, 380, '', true);
			item.isMenuItem = true;
			item.targetY = i;
			item.scrollFactor.set();
			add(item);
			items.push(item);
		}

		addTouchPad('UP_DOWN', 'A_B');

		refreshAll();
		changeSelection(0, false);

		// Durumu sunucudan tazele; cevap gelince ekran kendini günceller.
		TesterProgram.refresh(function(_) {
			refreshAll();
		});
	}

	// ------------------------------------------------------------------ GÖRÜNÜM

	function refreshAll():Void
	{
		refreshInfo();
		refreshItems();
	}

	function refreshInfo():Void
	{
		var logged:Bool = TesterProgram.isLoggedIn();
		var lines:Array<String> = [];

		lines.push('Tester Programı, Oyunun test sürümlerini (CİDDİ SEVİYEDE BUG BULUNDURUR) test edebilmenize yarar.');
		lines.push('Katılmak için bir further hesabına giriş yapman gerekir; kararı yapımcılar verilir.');
		lines.push('Onaylanan tester\'lar Credits bölümünde "Testers" bölümünde listelenir.');
		lines.push('');

		if (!logged)
		{
			lines.push('Durum: Giriş yapılmadı');
			lines.push('Katılmak için önce hesabına giriş yap.');
		}
		else
		{
			lines.push('Durum: ' + TesterProgram.statusLabel());
			var why:String = TesterProgram.reasonLabel();
			if (why.length > 0) lines.push('Not: ' + why);
			if (TesterProgram.maxTesters > 0)
				lines.push('Kontenjan: ' + TesterProgram.approvedCount + ' / ' + TesterProgram.maxTesters);
		}

		if (!TesterProgram.programOpen)
			lines.push('Yeni katılım şu an kapalı.');

		infoText.text = lines.join('\n');
	}

	function refreshItems():Void
	{
		var logged:Bool = TesterProgram.isLoggedIn();
		var tester:Bool = TesterProgram.isTester();

		// 0: Katıl / Ayrıl / Giriş yap
		if (!logged)
			items[ITEM_JOIN].text = 'Hesaba Giriş Yap';
		else if (tester)
			items[ITEM_JOIN].text = 'Tester Programından Ayrıl';
		else
			items[ITEM_JOIN].text = 'Tester Programına Katıl';

		items[ITEM_REFRESH].text = 'Durumu Yenile';
		items[ITEM_CHECK].text = 'Beta Güncellemelerini Denetle';
		items[ITEM_DOWNLOAD].text = 'Yeni Beta İndirme Sayfasını Aç';

		// Beta araçları yalnızca onaylı tester için
		items[ITEM_CHECK].visible = tester;
		items[ITEM_DOWNLOAD].visible = tester && BetaChecker.hasUpdate;

		if (!items[curSelected].visible)
			curSelected = ITEM_JOIN;

		for (i in 0...items.length)
			items[i].alpha = items[i].visible ? 0.6 : 0;
		items[curSelected].alpha = 1;
	}

	function setStatus(msg:String):Void
		statusText.text = msg;

	// ------------------------------------------------------------------ EYLEMLER

	function toggleJoin():Void
	{
		if (!TesterProgram.isLoggedIn())
		{
			// Giriş yapılmamış → giriş ekranına gönder
			FlxG.sound.play(Paths.sound('confirmMenu'));
			MusicBeatState.switchState(new states.LoginState());
			return;
		}

		if (TesterProgram.isBusy)
		{
			setStatus('İşlem sürüyor, bekle...');
			return;
		}

		if (TesterProgram.isTester())
		{
			setStatus('Ayrılma isteği gönderiliyor...');
			TesterProgram.leaveProgram(function(ok:Bool, result:String)
			{
				if (ok)
				{
					setStatus('Programdan ayrıldın. Credits listesinden de kaldırıldın.');
					FlxG.sound.play(Paths.sound('cancelMenu'));
				}
				else
				{
					setStatus('Ayrılma başarısız: ' + result);
					FlxG.sound.play(Paths.sound('cancelMenu'));
				}
				refreshAll();
			});
		}
		else
		{
			setStatus('Katılım isteği gönderiliyor...');
			TesterProgram.joinProgram(function(ok:Bool, result:String)
			{
				if (ok)
				{
					if (TesterProgram.isTester())
						setStatus('Tester Programına katıldın! Credits ekranında görüneceksin.');
					else
						setStatus('Başvurun alındı. Onaylandığında Credits listesinde görüneceksin.');
					FlxG.sound.play(Paths.sound('confirmMenu'));
				}
				else
				{
					setStatus('Katılım başarısız: ' + TesterProgram.reasonLabel());
					FlxG.sound.play(Paths.sound('cancelMenu'));
				}
				refreshAll();
			});
		}
	}

	function refresh():Void
	{
		if (TesterProgram.isBusy)
		{
			setStatus('Durum sorgulanıyor...');
			return;
		}
		setStatus('Durum sunucudan alınıyor...');
		TesterProgram.refresh(function(ok:Bool)
		{
			setStatus(ok
				? 'Durum: ' + TesterProgram.statusLabel()
				: 'Sunucuya ulaşılamadı. İnternetini kontrol edip tekrar dene.');
			refreshAll();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}, true);
	}

	function startCheck():Void
	{
		if (checking) return;
		if (!TesterProgram.isTester())
		{
			setStatus('Beta güncellemeleri için onaylı tester olmalısın.');
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
		if (!TesterProgram.isTester()) return;
		if (BetaChecker.releaseUrl == '') return;
		FlxG.openURL(BetaChecker.releaseUrl);
		FlxG.sound.play(Paths.sound('confirmMenu'));
	}

	function activateSelected():Void
	{
		switch (curSelected)
		{
			case ITEM_JOIN:
				toggleJoin();
			case ITEM_REFRESH:
				refresh();
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
}

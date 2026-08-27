package options;

import backend.AudioMixer;
import backend.AudioChannel;
import flixel.sound.FlxSound;

/**
 * Ses ayarları ekranı.
 *
 * AudioMixer'ın yedi kanalını (master/music/inst/voices/hit/ui/sfx) slider ile ayarlar.
 * Periyodik olarak ufak bir test sesi çalarak ayarı anında duymanı sağlar.
 */
class AudioSubState extends BaseOptionsMenu
{
	/** Her kanal için Option eşlemesi (slider değişince anında mixer'a yansıtmak için) */
	var channelOptions:Map<String, Option> = [];

	/** Değişiklik yapıldıktan sonra çalınacak test sesi */
	var previewSound:FlxSound = null;
	var previewTimer:Float = 0;
	var lastPreviewChannel:AudioChannel = MASTER;

	public function new()
	{
		title = Language.getPhrase('audio_menu', 'Ses Ayarları');
		rpcTitle = 'Audio Settings';

		// ── Her kanal için bir PERCENT slider oluştur ─────────────────
		var channels:Array<AudioChannel> = [
			MASTER, MUSIC, INST, VOICES, HIT, UI, SFX
		];

		for (ch in channels)
		{
			var varName:String = 'volume_${ch}';
			var label:String = AudioMixer.channelLabel(ch);

			var opt = new Option(label, channelDescription(ch), varName, FLOAT);
			opt.minValue = 0;
			opt.maxValue = 2;
			opt.changeValue = 0.05;
			opt.decimals = 2;
			opt.scrollSpeed = 1.0;
			opt.displayFormat = (ch == MASTER) ? '%v  (toplam)' : '%v';
			opt.onChange = function() {
				// Değişen kanalın hacmini anında mixer'a yansıt
				AudioMixer.setVolume(ch, opt.getValue());
				schedulePreview(ch);
			};
			channelOptions.set(cast ch, opt);
			addOption(opt);
		}

		// ── Tümünü sustur ──────────────────────────────────────────────
		var muteOpt = new Option('Tüm Sesleri Kapat',
			'İşaretlendiğinde tüm sesler anında kesilir. Ayarlarınız kaybolmaz.',
			'volumeMuted', BOOL);
		muteOpt.onChange = function() {
			AudioMixer.muted = muteOpt.getValue();
		};
		addOption(muteOpt);

		super();
	}

	function channelDescription(ch:AudioChannel):String
	{
		switch (ch)
		{
			case MASTER: return 'Tüm seslerin toplam şiddeti. Diğer kanallar bununla çarpılır.';
			case MUSIC:  return 'Ana menüde ve yükleme ekranında çalan müzik.';
			case INST:   return 'Şarkıdaki enstrüman (beat) parçasının sesi.';
			case VOICES: return 'Şarkıdaki vokal parçalarının (BF, rakip) sesi.';
			case HIT:    return 'Notaya vurma ve ıskalama sesleri.';
			case UI:     return 'Menü gezinme, tıklama ve bildirim sesleri.';
			case SFX:    return 'Oyun içi ses efektleri (tezahürat, ölüm, oyun bitişi vb.).';
			default:     return '';
		}
	}

	/** Belirli bir kanal için kısa bir test sesi planlar (0.2 sn gecikmeyle). */
	function schedulePreview(ch:AudioChannel):Void
	{
		lastPreviewChannel = ch;
		previewTimer = 0.2;
	}

	function playPreviewSound():Void
	{
		if (previewSound != null)
		{
			previewSound.stop();
			previewSound.destroy();
			previewSound = null;
		}
		// Mevcut bir ses efektini kanalda çal (confirmMenu güvenli, kısa)
		try
		{
			previewSound = FlxG.sound.play(Paths.sound('confirmMenu'), AudioMixer.getVolume(lastPreviewChannel));
			AudioMixer.track(previewSound, lastPreviewChannel);
		}
		catch (e:Dynamic)
		{
			// Ses dosyası yoksa sessizce geç
		}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (previewTimer > 0)
		{
			previewTimer -= elapsed;
			if (previewTimer <= 0) playPreviewSound();
		}
	}

	override function closeSubState()
	{
		// Alt menü kapanırken ses çalıyorsa durdur
		if (previewSound != null)
		{
			previewSound.stop();
			previewSound.destroy();
			previewSound = null;
		}
		super.closeSubState();
	}

	override function destroy():Void
	{
		// Çıkarken ayarları diske yaz
		ClientPrefs.saveSettings();
		super.destroy();
	}
}

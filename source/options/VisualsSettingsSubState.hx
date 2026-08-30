package options;

import objects.Note;
import objects.StrumNote;
import objects.NoteSplash;
import objects.Alphabet;

class VisualsSettingsSubState extends BaseOptionsMenu
{
	var noteOptionID:Int = -1;
	var notes:FlxTypedGroup<StrumNote>;
	var splashes:FlxTypedGroup<NoteSplash>;
	var noteY:Float = 90;

	public function new()
	{
		title = Language.getPhrase('visuals_menu', 'Görünüş Ayarları');
		rpcTitle = 'Görsel Ayarlar Menüsü'; //for Discord Rich Presence

		// for note skins and splash skins
		notes = new FlxTypedGroup<StrumNote>();
		splashes = new FlxTypedGroup<NoteSplash>();
		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			changeNoteSkin(note);
			notes.add(note);

			var splash:NoteSplash = new NoteSplash(0, 0, NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix());
			splash.inEditor = true;
			splash.babyArrow = note;
			splash.ID = i;
			splash.kill();
			splashes.add(splash);
		}

		// options
		var noteSkins:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
		if(noteSkins.length > 0)
		{
			if(!noteSkins.contains(ClientPrefs.data.noteSkin))
				ClientPrefs.data.noteSkin = ClientPrefs.defaultData.noteSkin; //Reset to default if saved noteskin couldnt be found
			noteSkins.insert(0, ClientPrefs.defaultData.noteSkin); //Default skin always comes first
			var option:Option = new Option(Language.getPhrase('setting_note_skins', 'Nota Görünümleri:'),
				Language.getPhrase('description_note_skins', "Tercih ettiğiniz Nota görünümünü seçin."),
				'noteSkin',
				STRING,
				noteSkins,
				'note_skins');
			addOption(option);
			option.onChange = onChangeNoteSkin;
			noteOptionID = optionsArray.length - 1;
		}

		var noteSplashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt');
		if(noteSplashes.length > 0)
		{
			if(!noteSplashes.contains(ClientPrefs.data.splashSkin))
				ClientPrefs.data.splashSkin = ClientPrefs.defaultData.splashSkin; //Reset to default if saved splashskin couldnt be found
			noteSplashes.insert(0, ClientPrefs.defaultData.splashSkin); //Default skin always comes first
			var option:Option = new Option(Language.getPhrase('setting_note_splashes', 'Nota Efektleri:'),
				Language.getPhrase('description_note_splashes', "Tercih ettiğiniz Nota Efekti varyasyonunu seçin."),
				'splashSkin',
				STRING,
				noteSplashes,
				'note_splashes');
			addOption(option);
			option.onChange = onChangeSplashSkin;
		}

		var option:Option = new Option(Language.getPhrase('setting_note_splash_opacity', 'Nota Efekti Opaklığı'),
			Language.getPhrase('description_note_splash_opacity', 'Nota Efektleri ne kadar saydam olmalı.'),
			'splashAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		option.onChange = playNoteSplashes;

		var holdCovers:Array<String> = Mods.mergeAllTextsNamed('images/holdCovers/list.txt');
		if(holdCovers.length > 0)
		{
			if(!holdCovers.contains(ClientPrefs.data.holdSkin))
				ClientPrefs.data.holdSkin = ClientPrefs.defaultData.holdSkin; //Kayıtlı skin bulunamazsa varsayılana dön
			holdCovers.insert(0, ClientPrefs.defaultData.holdSkin); //Varsayılan her zaman başta
			var option:Option = new Option(Language.getPhrase('setting_hold_skins', 'Hold Efekti Görünümü:'),
				Language.getPhrase('description_hold_skins', "Hold notalarında strumline'da oynayan efektin görünümünü seçin."),
				'holdSkin',
				STRING,
				holdCovers,
				'note_splashes');
			addOption(option);
		}

		var option:Option = new Option(Language.getPhrase('setting_hold_splash_opacity', 'Hold Efekti Opaklığı'),
			Language.getPhrase('description_hold_splash_opacity', 'Hold efektleri ne kadar saydam olmalı. 0 ise tamamen kapalı.'),
			'holdSplashAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option(Language.getPhrase('setting_hide_hud', 'Arayüzü Gizle'),
			Language.getPhrase('description_hide_hud', 'İşaretlenirse, çoğu arayüz öğesini gizler.'),
			'hideHud',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.getPhrase('setting_time_bar', 'Zaman Çubuğu:'),
			Language.getPhrase('description_time_bar', "Zaman Çubuğu ne göstersin?"),
			'timeBarType',
			STRING,
			['Time Left', 'Time Elapsed', 'Song Name', 'Disabled'],
			'time_bar');
		option.displayOptions = ['Kalan Süre', 'Geçen Süre', 'Şarkı Adı', 'Devre Dışı'];
		addOption(option);

		var option:Option = new Option(Language.getPhrase('setting_flashing_lights', 'Yanıp Sönen Işıklar'),
			Language.getPhrase('description_flashing_lights', "Yanıp sönen ışıklara karşı hassassanız\nbunu işaretlemeyin!"),
			'flashing',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.getPhrase('setting_camera_zooms', 'Kamera Yakınlaştırması'),
			Language.getPhrase('description_camera_zooms', "İşaretlenmezse, kamera ritme göre\nyakınlaşmaz."),
			'camZooms',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.getPhrase('setting_camera_movement', 'Kamera Hareketi'),
			Language.getPhrase('description_camera_movement', "İşaretlenmezse, kamera şarkı söyleyen\nkaraktere doğru hareket etmez."),
			'camMovement',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.getPhrase('setting_score_text_grow', 'Vuruşta Skor Yazısı Büyümesi'),
			Language.getPhrase('description_score_text_grow', "İşaretlenmezse, her nota vuruşunda\nSkor yazısının büyümesini devre dışı bırakır."),
			'scoreZoom',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.getPhrase('setting_health_bar_opacity', 'Sağlık Çubuğu Opaklığı'),
			Language.getPhrase('description_health_bar_opacity', 'Sağlık çubuğu ve simgeler ne kadar saydam olmalı.'),
			'healthBarAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		#if native
		var option:Option = new Option(Language.getPhrase('setting_vsync', 'Dikey Senkronizasyon'),
			Language.getPhrase('description_vsync', "İşaretlenirse, Dikey Senkronizasyonu etkinleştirir ve ekran yırtılmasını düzeltir,\nancak FPS'yi ekran yenileme hızıyla sınırlar.\n(Etkili olması için oyunun yeniden başlatılması gerekir)"),
			'vsync',
			BOOL);
		option.onChange = onChangeVSync;
		addOption(option);
		#end

		var option:Option = new Option(Language.getPhrase('setting_pause_music', 'Duraklatma Müziği:'),
			Language.getPhrase('description_pause_music', "Duraklatma Ekranı için hangi şarkıyı tercih edersiniz?"),
			'pauseMusic',
			STRING,
			['None', 'Tea Time', 'Breakfast', 'Breakfast (Pico)'],
			'pause_music');
		option.displayOptions = ['Yok', 'Çay Vakti', 'Kahvaltı', 'Kahvaltı (Pico)'];
		addOption(option);
		option.onChange = onChangePauseMusic;

		#if CHECK_FOR_UPDATES
		var option:Option = new Option(Language.getPhrase('setting_check_for_updates', 'Güncellemeleri Kontrol Et'),
			Language.getPhrase('description_check_for_updates', 'Yayın sürümlerinde, oyunu başlattığınızda güncellemeleri\nkontrol etmek için bunu açın.'),
			'checkForUpdates',
			BOOL);
		addOption(option);
		#end

		#if DISCORD_ALLOWED
		var option:Option = new Option(Language.getPhrase('setting_discord_rpc', 'Discord Durum Bilgisi'),
			Language.getPhrase('description_discord_rpc', "Kazara sızıntıları önlemek için bunu işaretlemeyin,\nDiscord'daki \"Oynuyor\" kutusundan Uygulamayı gizler."),
			'discordRPC',
			BOOL);
		addOption(option);
		#end

		var option:Option = new Option(Language.getPhrase('setting_combo_stacking', 'Kombo Yığılması'),
			Language.getPhrase('description_combo_stacking', "İşaretlenmezse, Dereceler ve Kombo yığılmaz,\nSistem Belleğinden tasarruf sağlar ve okunmalarını kolaylaştırır."),
			'comboStacking',
			BOOL);
		addOption(option);

		super();
		add(notes);
		add(splashes);
	}

	var notesShown:Bool = false;
	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);

		switch(curOption.variable)
		{
			case 'noteSkin', 'splashSkin', 'splashAlpha':
				if(!notesShown)
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: noteY}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = true;
				if(curOption.variable.startsWith('splash') && Math.abs(notes.members[0].y - noteY) < 25) playNoteSplashes();
			default:
				if(notesShown)
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: -200}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = false;
		}
	}

	var changedMusic:Bool = false;
	function onChangePauseMusic()
	{
		if(ClientPrefs.data.pauseMusic == 'None')
			FlxG.sound.music.volume = 0;
		else
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)));
		changedMusic = true;
	}
	function onChangeNoteSkin()
	{
		notes.forEachAlive(function(note:StrumNote) {
			changeNoteSkin(note);
			note.centerOffsets();
			note.centerOrigin();
		});
	}
	function changeNoteSkin(note:StrumNote)
	{
		var skin:String = Note.defaultNoteSkin;
		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if(Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;
		note.texture = skin; //Load texture and anims
		note.reloadNote();
		note.playAnim('static');
	}
	function onChangeSplashSkin()
	{
		var skin:String = NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix();
		for (splash in splashes)
			splash.loadSplash(skin);
		playNoteSplashes();
	}
	function playNoteSplashes()
	{
		var rand:Int = 0;
		if (splashes.members[0] != null && splashes.members[0].maxAnims > 1)
			rand = FlxG.random.int(0, splashes.members[0].maxAnims - 1); // For playing the same random animation on all 4 splashes
		for (splash in splashes)
		{
			splash.revive();
			splash.spawnSplashNote(0, 0, splash.ID, null, false);
			if (splash.maxAnims > 1)
				splash.noteData = splash.noteData % Note.colArray.length + (rand * Note.colArray.length);
			var anim:String = splash.playDefaultAnim();
			var conf = splash.config.animations.get(anim);
			var offsets:Array<Float> = [0, 0];
			var minFps:Int = 22;
			var maxFps:Int = 26;
			if (conf != null)
			{
				offsets = conf.offsets;
				minFps = conf.fps[0];
				if (minFps < 0) minFps = 0;
				maxFps = conf.fps[1];
				if (maxFps < 0) maxFps = 0;
			}
			splash.offset.set(10, 10);
			if (offsets != null)
			{
				splash.offset.x += offsets[0];
				splash.offset.y += offsets[1];
			}
			if (splash.animation.curAnim != null)
				splash.animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);
		}
	}

	override function destroy()
	{
		if(changedMusic && !OptionsState.onPlayState) FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
		Note.globalRgbShaders = [];
		super.destroy();
	}
	function onChangeFPSCounter()
	{
		if(Main.fpsVar != null)
			Main.fpsVar.visible = ClientPrefs.data.showFPS;
	}
	#if native
	function onChangeVSync()
	{
		// iOS: resmî lime'da window.vsync alanı yok; iOS vsync'i zaten zorunlu tutar.
		#if !ios
		lime.app.Application.current.window.vsync = ClientPrefs.data.vsync;
		#end
	}
	#end
}

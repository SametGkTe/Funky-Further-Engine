package options;

import states.FreeplayState;
import backend.NoteSkinData;
import online.GameClient;
import objects.Note;
import objects.StrumNote;
import objects.Alphabet;

class VisualsUISubState extends BaseOptionsMenu
{
	public static var isOpened:Bool = false;

	var noteOptionID:Int = -1;
	var notes:FlxTypedGroup<StrumNote>;
	var notesTween:Array<FlxTween> = [];
	var noteY:Float = 90;
	public function new()
	{
		ClientPrefs.reloadKeyColors();
		title = 'Görünüs & Arayüz';
		rpcTitle = 'Görünüş & Arayüz Ayarları'; //for Discord Rich Presence

		NoteSkinData.reloadNoteSkins();

		isOpened = true;

		// for note skins
		notes = new FlxTypedGroup<StrumNote>();
		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			note.centerOffsets();
			note.centerOrigin();
			note.playAnim('static');
			notes.add(note);
		}

		// options

		if(NoteSkinData.noteSkins.length > 0)
		{
			if(!NoteSkinData.noteSkinArray.contains(ClientPrefs.data.noteSkin))
				ClientPrefs.data.noteSkin = ClientPrefs.defaultData.noteSkin; //Reset to default if saved noteskin couldnt be found

			var option:Option = new Option('Nota Kostümü:',
				"Tercih Ettiğiniz Nota Kostümünü Seçin.",
				'noteSkin',
				'string',
				NoteSkinData.noteSkinArray);
			addOption(option);
			option.onChange = onChangeNoteSkin;
			noteOptionID = optionsArray.length - 1;
		}
		
		var noteSplashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt', 'shared');
		if(noteSplashes.length > 0)
		{
			if(!noteSplashes.contains(ClientPrefs.data.splashSkin))
				ClientPrefs.data.splashSkin = ClientPrefs.defaultData.splashSkin; //Reset to default if saved splashskin couldnt be found

			noteSplashes.insert(0, ClientPrefs.defaultData.splashSkin); //Default skin always comes first
			var option:Option = new Option('Nota Efektleri:',
				"Tercih ettiğiniz Not Efekti varyasyonunu seçin veya kapatın.",
				'splashSkin',
				'string',
				noteSplashes);
			addOption(option);
		}

		var option:Option = new Option('Nota Efekt Seffafligi',
			'Nota Sıçramaları Efektleri ne kadar şeffaf (saydam) olmalıdır?\n%0 ayarı bunu devre dışı bırakır.',
			'splashAlpha',
			'percent');
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Nota Tutus Efekt Seffafligi',
			'Uzun Nota Sıçramaları ne kadar şeffaf olmalıdır?\n%0 ayarı bunu devre dışı bırakır.',
			'holdSplashAlpha',
			'percent');
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Nota Kuyrugu Seffafligi',
			'Nota Kuyruğunun ne kadar şeffaf olması gerekir?.',
			'holdAlpha',
			'percent');
		option.scrollSpeed = 1.3;
		option.minValue = 0.5;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('HUD yi Gizle',
			'Aktif edilirse, ekran göstergelerinin (HUD) çoğunu gizler.',
			'hideHud',
			'bool');
		addOption(option);
		
		var option:Option = new Option('Zaman Bari:',
			"Zaman Çubuğu neyi göstermelidir?",
			'timeBarType',
			'string',
			['Kalan Süre', 'Geçen Süre', 'Sarki Adi', 'Kapali']);
		addOption(option);

		var option:Option = new Option('Yanip / Sönen Isıklar',
			"Yanıp sönen ışıklara karşı hassassanız bu seçeneğin işaretini kaldırın!",
			'flashing',
			'bool');
		addOption(option);

		var option:Option = new Option('Kamera Zoomlari',
			"Aktif Edilmezse, kamera vuruşta yakınlaştırma yapmaz..",
			'camZooms',
			'bool');
		addOption(option);

		var option:Option = new Option('Skor Yakinlastirmasi',
			"Aktif Edilmezse, her nota vuruşunda skor metninin\nyakınlaşmasını devre dışı bırakır.",
			'scoreZoom',
			'bool');
		addOption(option);

		var option:Option = new Option('Can Bar Opakligi',
			'Can Çubuğu ve Simgeler Ne Kadar Şeffaf Olmalı.',
			'healthBarAlpha',
			'percent');
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		
		var option:Option = new Option('FPS Sayaci',
			'Aktif Edilmezse, FPS Sayacını gizler.',
			'showFPS',
			'bool');
		addOption(option);
		option.onChange = onChangeFPSCounter;

		var option:Option = new Option('Çevrimiçi Gölgelendiricileri Kapat',
			'Aktif Edildiğinde, çevrimiçi menülerde kullanılan gölgelendiricileri devre dışı bırakır.',
			'disableOnlineShaders',
			'bool');
		addOption(option);

		var option:Option = new Option('Durdurma Ekrani Müziği:',
			"Duraklama Ekranı için hangi şarkıyı tercih edersiniz?",
			'pauseMusic',
			'string',
			['Hiçbiri', 'Breakfast', 'Tea Time']);
		addOption(option);
		option.onChange = onChangePauseMusic;
		
		#if CHECK_FOR_UPDATES
		var option:Option = new Option('Güncellemeleri Kontrol Et',
			'Resmi sürümlerde, oyunu başlattığınızda güncellemeleri kontrol etmek için bunu etkinleştirin.',
			'checkForUpdates',
			'bool');
		addOption(option);
		#end

		#if DISCORD_ALLOWED
		var option:Option = new Option('Discord Durumu',
			"Yanlışlıkla sızıntıları önlemek için bu seçeneğin işaretini kaldırın, bu işlem Discord'daki Oynuyor kutunuzdan Uygulamayı gizleyecektir.",
			'discordRPC',
			'bool');
		addOption(option);
		#end

		var option:Option = new Option('Hata Ayiklama',
			"Aktif Edildiğinde, hata ayıklama uyarıları vb. etkinleştirilir.",
			'debugMode',
			'bool');
		addOption(option);

		var option:Option = new Option('Nota Zamanlamasini Göster',
			'Aktif Edildiğinde, vurulan notanın zamanlaması ekranda gösterilir (milisaniye cinsinden).',
			'showNoteTiming',
			'bool');
		addOption(option);

		var option:Option = new Option('Otomatik Indirmeleri Kapat',
			'Rakibin Mod ve Skin lerini otomatik olarak indirmeyi devre dışı bırakır.',
			'disableAutoDownloads',
			'bool');
		addOption(option);

		var option:Option = new Option('Sarki Yorumlarini Kapat',
			'Yeniden oynatma görüntüleyicisinde şarkı yorumlarını devre dışı bırakır ve (görünürse, oynatma sırasında)',
			'disableSongComments',
			'bool');
		addOption(option);
		
		var option:Option = new Option('Sarki Yorum Opakligi',
			'Bir şarkıyı çalarken şarkı yorumları ne kadar görünür olmalı?',
			'midSongCommentsOpacity',
			'percent');
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('FP Sayacini Göster',
			'Aktif Edildiğinde, mevcut FP sayısı puan metninde gösterilir, oyun içinde F7 tuşuyla değiştirilebilir.',
			'showFP',
			'bool');
		addOption(option);

		var option:Option = new Option('Grup Sarkilari:',
			"Freeplay menüsündeki şarkılar nasıl gruplandırılmalıdır?",
			'groupSongsBy',
			'string',
			FreeplayState.GROUPS);
		addOption(option);

		var option:Option = new Option('Derecelendirme Rengi',
			'İşaretlendiğinde, Derecelendirme metni mevcut... şey... Derecelendirmenize göre renklendirilir, Combo ile aynı şekilde.',
			'colorRating',
			'bool');
		addOption(option);

		var option:Option = new Option('Favori Sarkilar Menü Temasi',
			'Aktif edilirse, oyun ana menü teması olarak rastgele seçtiğiniz favori şarkınızı seçecektir!',
			'favsAsMenuTheme',
			'bool');
		option.onChange = () -> {
			states.TitleState.playFreakyMusic();
		};
		addOption(option);

		var option:Option = new Option('Kombolari Göster',
			'Aktif edilirse, kombo (rating: Müq, İyi vs.) artık görünmeyecektir.',
			'disableComboRating',
			'bool');
		addOption(option);

		var option:Option = new Option('Kombo Sayaci',
			'Aktif edilirse, kombo sayacı artık görünmeyecektir.',
			'disableComboCounter',
			'bool');
		addOption(option);

		var option:Option = new Option('Ad Plakasi Solma Süresi',
			'Oyuncu isim plakaları kaç saniye sonra gizlenmelidir? Anında gizlemek için 0 olarak ayarlayın. Asla gizlememek için -1 olarak ayarlayın.',
			'nameplateFadeTime',
			'int');
		option.displayFormat = '%vs';
		option.scrollSpeed = 20;
		option.minValue = -1;
		option.maxValue = 60;
		option.changeValue = 1;
		option.decimals = 0;
		addOption(option);

		super();
		add(notes);
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		
		if(noteOptionID < 0) return;

		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = notes.members[i];
			if(notesTween[i] != null) notesTween[i].cancel();
			if(curSelected == noteOptionID)
				notesTween[i] = FlxTween.tween(note, {y: noteY}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
			else
				notesTween[i] = FlxTween.tween(note, {y: -200}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
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
		var data:NoteSkinStructure = NoteSkinData.getCurrent();
		Mods.currentModDirectory = data.folder;

		var skin:String = Note.defaultNoteSkin;
		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if(Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;

		note.texture = skin; //Load texture and anims
		note.reloadNote();
		note.playAnim('static');
	}

	override function destroy()
	{
		if(changedMusic && !OptionsState.onPlayState) states.TitleState.playFreakyMusic();
		isOpened = false;
		if (GameClient.isConnected()) {
			var data:NoteSkinStructure = NoteSkinData.getCurrent(-1);
			GameClient.send('updateNoteSkinData', [data.skin, data.folder, data.url]);
		}
		Mods.currentModDirectory = '';
		super.destroy();
	}

	function onChangeFPSCounter()
	{
		if(Main.fpsVar != null)
			Main.fpsVar.visible = ClientPrefs.data.showFPS;
	}
}

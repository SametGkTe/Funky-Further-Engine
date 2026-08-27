package options;

import states.MainMenuState;
import backend.StageData;

typedef OptionEntry = {
	label:String,
	desc:String,
	langKey:String,
}

class OptionsState extends MusicBeatState
{
	var entries:Array<OptionEntry> = [
		{ label: 'Nota Renkleri',     desc: 'Nota oklarının renklerini özelleştirin ve ayarlayın!',  langKey: 'note_colors'     },
		{ label: 'Kontroller',        desc: 'Klavye ve oyun kumandası tuşlarını yeniden atayın.',    langKey: 'controls'        },
		{ label: 'Gecikme & Kombo',   desc: 'Nota ofsetini ve gecikmeyi ayarlayın.',                langKey: 'delay_combo'     },
		{ label: 'Grafikler',         desc: 'Performans ve işleme ayarları.',                       langKey: 'graphics'        },
		{ label: 'Sesler',            desc: 'Ana ses, müzik, enstrüman, vokal ve efekt kanallarını ayarlayın.', langKey: 'audio'        },
		{ label: 'Görünüş',           desc: 'HUD, efektler ve görsel tercihler.',                   langKey: 'visuals'         },
		{ label: 'Oynanış',           desc: 'Ok Stili, Görsel efektleri ayarlayın.',                langKey: 'gameplay'        },
		#if TRANSLATIONS_ALLOWED
		{ label: 'Dil',              desc: 'Dilinizi seçin!',                                      langKey: 'language'        },
		#end
		#if mobile
		{ label: 'Mobil Ayarlar',    desc: 'Dokunmatik Kontrol Ayarları.',                          langKey: 'mobile_settings' },
		{ label: 'Mobil Ekstra Tuşlar', desc: 'Ekstra tuş atamaları.',                              langKey: 'mobile_extra_control' },
		#end
	];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private static var curSelected:Int = 0;
	public static var onPlayState:Bool = false;

	// Boşluklar arttırıldı ve itemler yukarı çekildi
	static inline var ITEM_SPACING:Float = 140;
	static inline var TOP_MARGIN:Float = 40;
	static inline var BOTTOM_MARGIN:Float = 60;

	var menuSpacing:Float = 140;

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;
	var descText:FlxText;
	var descBg:FlxSprite;
	var exiting:Bool = false;

	var petButton:FlxSprite;
	var petHovered:Bool = false;

	var petHoverX:Float = 0;
	var petHoverY:Float = 0;
	var petHoverW:Float = 211;
	var petHoverH:Float = 226;

	function openSelectedSubstate(langKey:String)
	{
		#if mobile
		FlxG.mouse.visible = false;
		#end
		FlxG.camera.scroll.set(0, 0);

		if (langKey != 'delay_combo') {
			removeTouchPad();
			if (mobileManager != null) mobileManager.removeMobilePad();
			persistentUpdate = false;
			controls.isInSubstate = true;
		}

		switch (langKey) {
			case 'note_colors':
				openSubState(new options.NotesColorSubState());

			case 'controls':
				openSubState(new options.ControlsSubState());

			case 'audio':
				openSubState(new options.AudioSubState());

			case 'graphics':
				openSubState(new options.GraphicsSettingsSubState());

			case 'visuals':
				openSubState(new options.VisualsSettingsSubState());

			case 'gameplay':
				openSubState(new options.GameplaySettingsSubState());

			case 'delay_combo':
				removeTouchPad();
				if (mobileManager != null) mobileManager.removeMobilePad();
				MusicBeatState.switchState(new options.NoteOffsetState());

			case 'mobile_settings':
				openSubState(new mobile.options.MobileOptionsSubState());

			case 'mobile_extra_control':
				removeTouchPad();
				if (mobileManager != null) mobileManager.removeMobilePad();
				persistentUpdate = false;
				controls.isInSubstate = true;
				openSubState(new mobile.substates.MobileExtraControl());

			#if TRANSLATIONS_ALLOWED
			case 'language':
				openSubState(new options.LanguageSubState());
			#end
		}
	}

	function createPetButton(x:Float, y:Float):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite(x, y);
		spr.frames = Paths.getSparrowAtlas('optionsmenu/option_pet');
		spr.animation.addByPrefix('idle', 'pet idle', 24, true);
		spr.animation.addByPrefix('selected', 'pet selected', 24, true);
		spr.animation.play('idle');
		spr.antialiasing = ClientPrefs.data.antialiasing;
		spr.scrollFactor.set();
		spr.updateHitbox();
		add(spr);
		return spr;
	}

	function isMouseOverPet():Bool
	{
		var mouseX:Float = FlxG.mouse.x;
		var mouseY:Float = FlxG.mouse.y;

		return mouseX >= petHoverX && mouseX <= petHoverX + petHoverW
			&& mouseY >= petHoverY && mouseY <= petHoverY + petHoverH;
	}

	function updatePetButton():Bool
	{
		if (petButton == null) return false;

		var overPet:Bool = isMouseOverPet();

		if (overPet && !petHovered)
		{
			petHovered = true;
			petButton.animation.play('selected', true);
		}
		else if (!overPet && petHovered)
		{
			petHovered = false;
			petButton.animation.play('idle', true);
		}

		if (overPet && FlxG.mouse.justPressed)
		{
			openPetSettings();
			return true;
		}

		return false;
	}

	function openPetSettings()
	{
		if (exiting) return;

		#if mobile
		FlxG.mouse.visible = false;
		#end
		FlxG.camera.scroll.set(0, 0);
		FlxG.sound.play(Paths.sound('confirmMenu'));

		removeTouchPad();
		if (mobileManager != null) mobileManager.removeMobilePad();
		persistentUpdate = false;
		controls.isInSubstate = true;

		openSubState(new options.PetSettingsState());
	}

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Options Menu', null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);
		
		// Fak yu Cursor
		FlxG.mouse.visible = #if mobile false #else true #end;

		// Pet Sprite'ı en aşağıya (Açıklama barının üstüne) yerleştirildi
		petButton = createPetButton(20, FlxG.height - 226 - 50);
		petHoverX = petButton.x - 6;
		petHoverY = petButton.y - 30;
		petHoverW = 211;
		petHoverH = 226;

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (entry in entries) {
			var displayLabel:String = Language.getPhrase('options_${entry.langKey}', entry.label);
			var optionText:Alphabet = new Alphabet(0, 0, displayLabel, true);
			grpOptions.add(optionText);
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		add(selectorLeft);

		selectorRight = new Alphabet(0, 0, '<', true);
		add(selectorRight);

		descBg = new FlxSprite(0, FlxG.height - 36).makeGraphic(FlxG.width, 36, 0xDD0A0414);
		descBg.scrollFactor.set();
		add(descBg);

		descText = new FlxText(0, FlxG.height - 28, FlxG.width, '', 14);
		descText.setFormat('assets/fonts/vcr.ttf', 14, 0xFFea71fd, CENTER, FlxTextBorderStyle.NONE);
		descText.scrollFactor.set();
		descText.antialiasing = ClientPrefs.data.antialiasing;
		add(descText);

		if (controls.mobileC) {
			var tipText:FlxText = new FlxText(150, FlxG.height - 60, 0,
				'Press ' + (FlxG.onMobile ? 'C' : 'CTRL or C') + ' for Mobile Controls', 12);
			tipText.setFormat('assets/fonts/vcr.ttf', 12, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			tipText.borderSize = 1.25;
			tipText.scrollFactor.set();
			tipText.antialiasing = ClientPrefs.data.antialiasing;
			add(tipText);
		}

		layoutOptions();
		changeSelection(0, false);

		ClientPrefs.saveSettings();
		#if mobile
		mobileManager.addMobilePad('UP_DOWN', 'A_B_C');
		mobileManager.addMobilePadCamera();
		#else
		addTouchPad('UP_DOWN', 'A_B_C');
		#end

		super.create();
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Options Menu', null);
		#end

		controls.isInSubstate = false;
		removeTouchPad();
		if (mobileManager != null) mobileManager.removeMobilePad();
		#if mobile
		mobileManager.addMobilePad('UP_DOWN', 'A_B_C');
		mobileManager.addMobilePadCamera();
		#else
		addTouchPad('UP_DOWN', 'A_B_C');
		#end
		persistentUpdate = true;

		FlxG.camera.scroll.set(0, 0);
		layoutOptions();
		changeSelection(0, false);

		petHovered = false;
		if (petButton != null) petButton.animation.play('idle', true);

		#if mobile
		FlxG.mouse.visible = false;
		#end
	}

	override function update(elapsed:Float)
	{
		// Android dokunması mouse click olarak da raporlanır. V-Slice editörü
		// açıkken PET ve arkadaki bütün Options inputlarını update etme.
		if (mobile.substates.VSliceControlEditorSubState.blocksOptionsInput) return;
		super.update(elapsed);

		if (exiting) return;

		if (updatePetButton()) return;

		// Yön tuşlarının hareket algoritması (Yukarı/Aşağı için -2/+2 atlıyor)
		if (controls.UI_LEFT_P) changeSelection(-1);
		if (controls.UI_RIGHT_P) changeSelection(1);
		if (controls.UI_UP_P) changeSelection(-2);
		if (controls.UI_DOWN_P) changeSelection(2);

		var mobileControlPressed:Bool = false;

		if (touchPad != null && touchPad.buttonC != null && touchPad.buttonC.justPressed) {
			mobileControlPressed = true;
		}

		// Fiziksel C/CTRL, mobil kontrol opaklığından bağımsız çalışmalıdır.
		if (FlxG.keys.justPressed.CONTROL || FlxG.keys.justPressed.C) {
			mobileControlPressed = true;
		}

		// Yeni FurtherPad sistemi legacy touchPad alanını kullanmaz.
		if (mobileManager != null && mobileManager.mobilePad != null && mobileManager.mobilePad.buttonJustPressed('C')) {
			mobileControlPressed = true;
		}

		if (mobileControlPressed) {
			FlxG.camera.scroll.set(0, 0);
			controls.isInSubstate = true;
			persistentUpdate = false;
			removeTouchPad();
			if (mobileManager != null) mobileManager.removeMobilePad();
			openSubState(new mobile.substates.MobileControlSelectSubState());
			return;
		}

		if (controls.BACK) {
			exiting = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));

			if (onPlayState) {
				StageData.loadDirectory(PlayState.SONG);
				LoadingState.loadAndSwitchState(new PlayState());
				FlxG.sound.music.volume = 0;
			} else {
				MenuStyleRouter.goToMainMenu();
			}
		}
		else if (controls.ACCEPT) {
			openSelectedSubstate(entries[curSelected].langKey);
		}

		refreshSelectors();
	}

	function layoutOptions()
	{
		if (grpOptions == null || grpOptions.members == null || grpOptions.members.length == 0) return;

		var visibleTop:Float = TOP_MARGIN;
		var visibleBottom:Float = FlxG.height - BOTTOM_MARGIN;
		var visibleHeight:Float = visibleBottom - visibleTop;

		// 2 sütunlu görünüm için toplam satır sayısını hesapla
		var rows:Int = Std.int((entries.length + 1) / 2);

		menuSpacing = ITEM_SPACING;
		if (rows > 1) {
			var maxSpacing:Float = visibleHeight / (rows - 1);
			if (menuSpacing > maxSpacing) menuSpacing = maxSpacing;
		}

		// İtemleri yukarı almak için centering offsetini iptal ettik, direkt TOP_MARGIN hizasından başlıyor
		var startY:Float = visibleTop;

		for (num => item in grpOptions.members) {
			if (item == null) continue;
			
			// 0 ise sol taraf, 1 ise sağ taraf
			var col:Int = num % 2;
			var row:Int = Std.int(num / 2);
			
			// Ekranı yarıya bölüp %25 ve %75 alanlarına ortala
			if (col == 0) {
				item.x = (FlxG.width * 0.25) - (item.width * 0.5);
			} else {
				item.x = (FlxG.width * 0.75) - (item.width * 0.5);
			}
			
			item.y = startY + (row * menuSpacing);
		}

		refreshSelectors();
	}

	function refreshSelectors()
	{
		if (grpOptions == null || grpOptions.members == null) return;
		if (curSelected < 0 || curSelected >= grpOptions.members.length) return;

		var item = grpOptions.members[curSelected];
		if (item == null) return;

		selectorLeft.x = item.x - 63;
		selectorLeft.y = item.y;

		selectorRight.x = item.x + item.width + 15;
		selectorRight.y = item.y;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, entries.length - 1);

		for (num => item in grpOptions.members) {
			if (item == null) continue;
			item.alpha = (num == curSelected) ? 1 : 0.45;
		}

		if (descText != null) {
			descText.text = Language.getPhrase('options_desc_${entries[curSelected].langKey}', entries[curSelected].desc).toUpperCase();
		}

		refreshSelectors();

		if (playSound && change != 0) {
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}
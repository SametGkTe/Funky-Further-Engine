package options;

import states.MainMenuState;
import backend.StageData;
import flixel.FlxObject;

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

	static inline var ITEM_SPACING:Float = 120;
	static inline var TOP_MARGIN:Float = 200;

	var menuSpacing:Float = 120;

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

	var camFollow:FlxObject;

	function openSelectedSubstate(langKey:String)
	{
		#if mobile
		FlxG.mouse.visible = false;
		#end
		
		if (langKey != 'delay_combo') {
			removeTouchPad();
			if (mobileManager != null) mobileManager.removeMobilePad();
			persistentUpdate = false;
			controls.isInSubstate = true;
		}

		switch (langKey) {
			case 'note_colors':
				FlxG.camera.follow(null);
			FlxG.camera.scroll.set(0, 0);
			openSubState(new options.NotesColorSubState());
			case 'controls':
				FlxG.camera.follow(null);
			FlxG.camera.scroll.set(0, 0);
			openSubState(new options.ControlsSubState());
			case 'audio':
				FlxG.camera.follow(null);
			FlxG.camera.scroll.set(0, 0);
			openSubState(new options.AudioSubState());
			case 'graphics':
				FlxG.camera.follow(null);
			FlxG.camera.scroll.set(0, 0);
			openSubState(new options.GraphicsSettingsSubState());
			case 'visuals':
				FlxG.camera.follow(null);
			FlxG.camera.scroll.set(0, 0);
			openSubState(new options.VisualsSettingsSubState());
			case 'gameplay':
				FlxG.camera.follow(null);
			FlxG.camera.scroll.set(0, 0);
			openSubState(new options.GameplaySettingsSubState());
			case 'delay_combo':
				removeTouchPad();
				if (mobileManager != null) mobileManager.removeMobilePad();
				MusicBeatState.switchState(new options.NoteOffsetState());
			case 'mobile_settings':
				FlxG.camera.follow(null);
			FlxG.camera.scroll.set(0, 0);
			openSubState(new mobile.options.MobileOptionsSubState());
			case 'mobile_extra_control':
				removeTouchPad();
				if (mobileManager != null) mobileManager.removeMobilePad();
				persistentUpdate = false;
				controls.isInSubstate = true;
				FlxG.camera.follow(null);
			FlxG.camera.scroll.set(0, 0);
			openSubState(new mobile.substates.MobileExtraControl());
			#if TRANSLATIONS_ALLOWED
			case 'language':
				FlxG.camera.follow(null);
			FlxG.camera.scroll.set(0, 0);
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
		// Scroll factor 0 olan objeler için ekran koordinatı (screenX/Y) kullanılmalıdır.
		var mouseX:Float = FlxG.mouse.screenX;
		var mouseY:Float = FlxG.mouse.screenY;

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
		FlxG.sound.play(Paths.sound('confirmMenu'));

		removeTouchPad();
		if (mobileManager != null) mobileManager.removeMobilePad();
		persistentUpdate = false;
		controls.isInSubstate = true;

		FlxG.camera.follow(null);
			FlxG.camera.scroll.set(0, 0);
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
		
		camFollow = new FlxObject(FlxG.width / 2, 0, 1, 1);
		add(camFollow);
		FlxG.camera.follow(camFollow, null, 0.15);
		
		FlxG.mouse.visible = #if mobile false #else true #end;

		// Pet Sprite'ı tekrar orta-sol hizaya alındı (Mobil kontroller sol altı kapladığı için)
		petButton = createPetButton(20, (FlxG.height - 226) * 0.5);
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

		FlxG.camera.follow(camFollow, null, 0.15);
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
		if (mobile.substates.VSliceControlEditorSubState.blocksOptionsInput) return;
		super.update(elapsed);

		if (exiting) return;

		if (updatePetButton()) return;

		// Sadece dikey kaydırma mantığı, sağ-sol tuşlarını da dahil ettik
		if (controls.UI_UP_P || controls.UI_LEFT_P) changeSelection(-1);
		if (controls.UI_DOWN_P || controls.UI_RIGHT_P) changeSelection(1);

		var mobileControlPressed:Bool = false;

		if (touchPad != null && touchPad.buttonC != null && touchPad.buttonC.justPressed) {
			mobileControlPressed = true;
		}

		if (FlxG.keys.justPressed.CONTROL || FlxG.keys.justPressed.C) {
			mobileControlPressed = true;
		}

		if (mobileManager != null && mobileManager.mobilePad != null && mobileManager.mobilePad.buttonJustPressed('C')) {
			mobileControlPressed = true;
		}

		if (mobileControlPressed) {
			controls.isInSubstate = true;
			persistentUpdate = false;
			removeTouchPad();
			if (mobileManager != null) mobileManager.removeMobilePad();
			FlxG.camera.follow(null);
			FlxG.camera.scroll.set(0, 0);
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

		var startY:Float = TOP_MARGIN;

		for (num => item in grpOptions.members) {
			if (item == null) continue;
			
			// Tamamen dikey görünüm
			item.x = (FlxG.width - item.width) * 0.5;
			item.y = startY + (num * ITEM_SPACING);
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
		curSelected = flixel.math.FlxMath.wrap(curSelected + change, 0, entries.length - 1);

		for (num => item in grpOptions.members) {
			if (item == null) continue;
			item.alpha = (num == curSelected) ? 1 : 0.45;
		}

		if (descText != null) {
			descText.text = Language.getPhrase('options_desc_${entries[curSelected].langKey}', entries[curSelected].desc).toUpperCase();
		}

		refreshSelectors();

		// Kamera kaydırma
		var selectedItem = grpOptions.members[curSelected];
		if (selectedItem != null && camFollow != null) {
			camFollow.y = selectedItem.getGraphicMidpoint().y;
		}

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

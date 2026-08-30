package options;

import states.MainMenuState;
import backend.StageData;
import flixel.FlxObject;

typedef OptionEntry = {
	label:String,
	desc:String,
	langKey:String,
	icon:String
}

class OptionsState extends MusicBeatState
{
	var entries:Array<OptionEntry> = [
		{ label: 'Nota Renkleri',     desc: 'Nota oklarının renklerini özelleştirin ve ayarlayın!',  langKey: 'note_colors',     icon: 'note_colors' },
		{ label: 'Kontroller',        desc: 'Klavye ve oyun kumandası tuşlarını yeniden atayın.',    langKey: 'controls',        icon: 'controls' },
		{ label: 'Gecikme & Kombo',   desc: 'Nota ofsetini ve gecikmeyi ayarlayın.',                langKey: 'delay_combo',     icon: 'delay_and_combo' },
		{ label: 'Grafik ve Performans',         desc: 'Performans ve işleme ayarları.',                       langKey: 'graphics',        icon: 'graphics_and_performance' },
		{ label: 'Sesler',            desc: 'Ana ses, müzik, enstrüman, vokal ve efekt kanallarını ayarlayın.', langKey: 'audio', icon: 'music' },
		{ label: 'Arayüz & Görünüş',           desc: 'HUD, efektler ve görsel tercihler.',                   langKey: 'visuals',         icon: 'interface_and_visuals' },
		{ label: 'Oynanış',           desc: 'Ok Stili, Görsel efektleri ayarlayın.',                langKey: 'gameplay',        icon: 'gameplay' },
		{ label: 'Ekstra Ayarlar',    desc: 'Diğer menülerde bulunmayan ek ayarlar.',      langKey: 'extra_settings',  icon: 'extra_settings' },
		#if TRANSLATIONS_ALLOWED
		{ label: 'Dil',              desc: 'Dilinizi seçin!',                                      langKey: 'language',        icon: 'language' },
		#end
		#if mobile
		{ label: 'Mobil Ayarlar',    desc: 'Dokunmatik Kontrol Ayarları.',                          langKey: 'mobile_settings', icon: 'mobilecontrols' },
		{ label: 'Mobil Ekstra Tuşlar', desc: 'Ekstra tuş atamaları.',                              langKey: 'mobile_extra_control', icon: 'mobileextracontrols' },
		#end
		{ label: 'PET Ayarları',     desc: 'PET karakteri ve görünüm ayarlarını yapılandırın.',     langKey: 'pet_settings',    icon: 'pet' }
	];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var optionIcons:Array<FlxSprite> = [];
	
	private static var curSelected:Int = 0;
	public static var onPlayState:Bool = false;

	static inline var ITEM_SPACING:Float = 120;
	static inline var TOP_MARGIN:Float = 200;

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;
	var descText:FlxText;
	var descBg:FlxSprite;
	var exiting:Bool = false;
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

		FlxG.camera.follow(null);
		FlxG.camera.scroll.set(0, 0);

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
			case 'extra_settings':
				openSubState(new options.ExtraSettingsState());
			case 'delay_combo':
				removeTouchPad();
				if (mobileManager != null) mobileManager.removeMobilePad();
				MusicBeatState.switchState(new options.NoteOffsetState());
			case 'mobile_settings':
				openSubState(new mobile.options.MobileOptionsSubState());
			case 'mobile_extra_control':
				openSubState(new mobile.substates.MobileExtraControl());
			case 'pet_settings':
				openSubState(new options.PetSettingsState());
			#if TRANSLATIONS_ALLOWED
			case 'language':
				openSubState(new options.LanguageSubState());
			#end
		}
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

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (i in 0...entries.length) {
			var entry = entries[i];
			var displayLabel:String = Language.getPhrase('options_${entry.langKey}', entry.label);
			
			var optionText:Alphabet = new Alphabet(0, 0, displayLabel, true);
			grpOptions.add(optionText);

			var iconStr = 'further/options/' + entry.icon;
			var icon:FlxSprite = new FlxSprite(0, 0);
			
			// Eger resim bulunamazsa oyun cokmesin diye beyaz kutu (placeholder) ekliyoruz
			if (Paths.fileExists('images/' + iconStr + '.png', IMAGE)) {
				icon.loadGraphic(Paths.image(iconStr));
			} else {
				icon.makeGraphic(80, 80, flixel.util.FlxColor.WHITE);
			}
			icon.antialiasing = ClientPrefs.data.antialiasing;
			add(icon);
			optionIcons.push(icon);
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		add(selectorLeft);

		selectorRight = new Alphabet(0, 0, '<', true);
		add(selectorRight);

		descBg = new FlxSprite(0, FlxG.height - 36).makeGraphic(FlxG.width, 36, 0xDD0A0414);
		descBg.scrollFactor.set();
		add(descBg);

		descText = new FlxText(0, FlxG.height - 28, FlxG.width, '', 14);
		descText.setFormat('assets/fonts/vcr.ttf', 14, 0xFFea71fd, CENTER, flixel.text.FlxText.FlxTextBorderStyle.NONE);
		descText.scrollFactor.set();
		descText.antialiasing = ClientPrefs.data.antialiasing;
		add(descText);

		if (controls.mobileC) {
			var tipText:FlxText = new FlxText(150, FlxG.height - 60, 0,
				'Press ' + (FlxG.onMobile ? 'C' : 'CTRL or C') + ' for Mobile Controls', 12);
			tipText.setFormat('assets/fonts/vcr.ttf', 12, flixel.util.FlxColor.WHITE, LEFT, flixel.text.FlxText.FlxTextBorderStyle.OUTLINE, flixel.util.FlxColor.BLACK);
			tipText.borderSize = 1.25;
			tipText.scrollFactor.set();
			tipText.antialiasing = ClientPrefs.data.antialiasing;
			add(tipText);
		}

		layoutOptions();
		changeSelection(0, false);

		ClientPrefs.saveSettings();
		#if mobile
		if (ClientPrefs.data.mobileControlType == 'Touch')
		{
			addTouchPad('UP_DOWN', 'A_B_C');
			addTouchPadCamera();
		}
		else
		{
			mobileManager.addMobilePad('UP_DOWN', 'A_B_C');
			mobileManager.addMobilePadCamera();
		}
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
		if (ClientPrefs.data.mobileControlType == 'Touch')
		{
			addTouchPad('UP_DOWN', 'A_B_C');
			addTouchPadCamera();
		}
		else
		{
			mobileManager.addMobilePad('UP_DOWN', 'A_B_C');
			mobileManager.addMobilePadCamera();
		}
		#else
		addTouchPad('UP_DOWN', 'A_B_C');
		#end
		persistentUpdate = true;

		FlxG.camera.follow(camFollow, null, 0.15);
		layoutOptions();
		changeSelection(0, false);

		#if mobile
		FlxG.mouse.visible = false;
		#end
	}

	override function update(elapsed:Float)
	{
		if (mobile.substates.VSliceControlEditorSubState.blocksOptionsInput) return;
		super.update(elapsed);

		if (exiting) return;

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
			var icon = optionIcons[num];
			
			var totalWidth:Float = item.width;
			if (icon != null) {
			    totalWidth += icon.width + 20; // 20px ikon ve yazi arasi bosluk
			}
			
			var startX:Float = (FlxG.width - totalWidth) * 0.5;

            if (icon != null) {
                icon.x = startX;
                icon.y = startY + (num * ITEM_SPACING) + (item.height - icon.height) * 0.5;
                item.x = icon.x + icon.width + 20;
            } else {
                item.x = startX;
            }
            
			item.y = startY + (num * ITEM_SPACING);
		}

		refreshSelectors();
	}

	function refreshSelectors()
	{
		if (grpOptions == null || grpOptions.members == null) return;
		if (curSelected < 0 || curSelected >= grpOptions.members.length) return;

		var item = grpOptions.members[curSelected];
		var icon = optionIcons[curSelected];
		if (item == null) return;

        var leftTarget = (icon != null) ? icon : item;

		selectorLeft.x = leftTarget.x - 63;
		selectorLeft.y = item.y;

		selectorRight.x = item.x + item.width + 15;
		selectorRight.y = item.y;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		curSelected = flixel.math.FlxMath.wrap(curSelected + change, 0, entries.length - 1);

		for (num => item in grpOptions.members) {
			if (item == null) continue;
			var isSel = (num == curSelected);
			
			item.alpha = isSel ? 1 : 0.45;
			if (optionIcons[num] != null) {
			    optionIcons[num].alpha = isSel ? 1 : 0.45;
			}
		}

		if (descText != null) {
			descText.text = Language.getPhrase('options_desc_${entries[curSelected].langKey}', entries[curSelected].desc).toUpperCase();
		}

		refreshSelectors();

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

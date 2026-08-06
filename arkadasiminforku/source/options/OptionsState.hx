package options;

import flixel.FlxObject;
import online.states.RoomState;
import states.MainMenuState;
import backend.StageData;

class OptionsState extends MusicBeatState
{
	var options:Array<String> = ['Nota Renkleri', 'Kontroller', 'Gecikme & Kombo', 'Grafik Ve Performans', 'Arayüz & Efektler', 'Oynanis', 'Mobil Ayarlar', 'P.E.T Ayarlari'];
	private var grpOptions:FlxTypedGroup<Alphabet>;
	private static var curSelected:Int = 0;
	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;
	public static var onOnlineRoom:Bool = false;
	public static var hadMouseVisible:Bool = false;
	public static var loadedMod:String = '';

	// CoolCam değişkenleri
	private var camFollowY:Float = 0;

	function openSelectedSubstate(label:String) {
		if (label != "Adjust Delay and Combo"){
			mobileManager.removeMobilePad();
			persistentUpdate = false;
		}
		
		// Ana menü öğelerini gizle
		grpOptions.visible = false;
		selectorLeft.visible = false;
		selectorRight.visible = false;
		
		// Kamera pozisyonunu sıfırla
		FlxG.camera.scroll.y = 0;
		camFollowY = 0;
		
		switch(label) {
			case 'Nota Renkleri':
				openSubState(new options.NotesSubState());
			case 'Kontroller':
				openSubState(new options.ControlsSubState());
			case 'Grafik Ve Performans':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Arayüz & Efektler':
				openSubState(new options.VisualsUISubState());
			case 'Oynanis':
				openSubState(new options.GameplaySettingsSubState());
			case 'Mobil Ayarlar':
				openSubState(new mobile.options.MobileOptionsSubState());
			case 'Mobile Ekstra Kontroller':
				controls.isInSubstate = true;
				openSubState(new mobile.substates.MobileExtraControl());
			case 'Gecikme & Kombo':
				FlxG.switchState(() -> new options.NoteOffsetState());
			case 'P.E.T Ayarlari':
				openSubState(new options.PETSettingsState());
		}
	}

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;

	override function create() {
		hadMouseVisible = FlxG.mouse.visible;
		FlxG.mouse.visible = true;

		OptionsState.loadedMod = Mods.currentModDirectory;
		
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", "Options");
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFea71fd;
		bg.scale.set(1.1, 1.1);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (i in 0...options.length)
		{
			var optionText:Alphabet = new Alphabet(0, 0, options[i], true);
			optionText.screenCenter();
			optionText.y += (100 * (i - (options.length / 2))) + 50;
			optionText.ID = i;
			grpOptions.add(optionText);
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		add(selectorLeft);
		selectorRight = new Alphabet(0, 0, '<', true);
		add(selectorRight);

		changeSelection();
		ClientPrefs.saveSettings();

		super.create();

		mobileManager.addMobilePad("UP_DOWN", "A_B_E");

		online.GameClient.send("status", "Oyun Ayarları");
	}

	override function closeSubState() {
		super.closeSubState();
		FlxG.mouse.visible = true;
		ClientPrefs.saveSettings();
		controls.isInSubstate = false;
		mobileManager.removeMobilePad();
		mobileManager.addMobilePad('UP_DOWN', 'A_B_E');
		persistentUpdate = true;
		
		// Ana menü öğelerini tekrar göster
		grpOptions.visible = true;
		selectorLeft.visible = true;
		selectorRight.visible = true;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		// CoolCam sadece Y ekseninde yumuşak hareket
		FlxG.camera.scroll.y = FlxMath.lerp(camFollowY, FlxG.camera.scroll.y, Math.exp(-elapsed * 6));

		if (controls.UI_UP_P) {
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P) {
			changeSelection(1);
		}
		
		if (FlxG.mouse.deltaScreenY != 0) {
			for (i => spr in grpOptions) {
				if (FlxG.mouse.overlaps(spr, spr.camera) && i - curSelected != 0) {
					changeSelection(i - curSelected);
				}
			}
		}

		if (FlxG.mouse.wheel != 0) {
			changeSelection(-FlxG.mouse.wheel);
		}

		if (controls.BACK) {
			FlxG.mouse.visible = hadMouseVisible;
			Mods.currentModDirectory = OptionsState.loadedMod;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			if(onPlayState)
			{
				StageData.loadDirectory(PlayState.SONG);
				LoadingState.loadAndSwitchState(new PlayState());
				FlxG.sound.music.volume = 0;
			}
			else if (onOnlineRoom) {
				LoadingState.loadAndSwitchState(new RoomState());
			}
			else FlxG.switchState(() -> new MainMenuState());
		}
		else if (controls.ACCEPT #if desktop || FlxG.mouse.justPressed #end) openSelectedSubstate(options[curSelected]);
		else if (mobileButtonJustPressed('E')) openSelectedSubstate('Mobil Ekstra Kontroller');
	}
	
	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			if (item.targetY == 0) {
				item.alpha = 1;
				selectorLeft.x = item.x - 63;
				selectorLeft.y = item.y;
				selectorRight.x = item.x + item.width + 15;
				selectorRight.y = item.y;

				// Kamerayı seçilen öğenin Y pozisyonuna hafifçe kaydır
				camFollowY = (item.y - FlxG.height / 2) * 0.15;
			}
		}

		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}
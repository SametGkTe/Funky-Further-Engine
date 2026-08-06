package online.substates;

import openfl.filters.BlurFilter;
import substates.GameplayChangersSubstate;
import options.OptionsState;
import flixel.util.FlxSpriteUtil;
import states.ModsMenuState;

class RoomSettingsSubstate extends MusicBeatSubstate {
	var bg:FlxSprite;
	var prevMouseVisibility:Bool = false;
	var items:FlxTypedSpriteGroup<Option>;
	var curSelectedID:Int = 0;
	var lastSelectedID:Int = -1;

	var blurFilter:BlurFilter;
	var blackSprite:FlxSprite;
	var coolCam:FlxCamera;

	//options
	var skinSelect:Option;
	var gameOptions:Option;
	var stageSelect:Option;
	var publicRoom:Option;
	var anarchyMode:Option;
	var swapSides:Option;
	var teamMode:Option;

	override function create() {
		super.create();

		var bgCam:FlxCamera = new FlxCamera();
		bgCam.bgColor.alpha = 0;
		FlxG.cameras.add(bgCam, false);

		// Mobil/Shader desteği
		#if !mobile
		if (!ClientPrefs.data.disableOnlineShaders) {
			blurFilter = new BlurFilter();
			for (cam in FlxG.cameras.list) {
				if (cam.filters == null)
					cam.filters = [];
				cam.filters.push(blurFilter);
			}
		} else 
		#end
		{
			blackSprite = new FlxSprite();
			blackSprite.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
			blackSprite.alpha = 0.75;
			add(blackSprite);
			blackSprite.cameras = [bgCam];
		}

		coolCam = new FlxCamera();
		coolCam.bgColor.alpha = 0;
		FlxG.cameras.add(coolCam, false);

		cameras = [coolCam];

		prevMouseVisibility = FlxG.mouse.visible;
		FlxG.mouse.visible = true;

		bg = new FlxSprite();
		bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.7;
		bg.scrollFactor.set(0, 0);
		add(bg);

		items = new FlxTypedSpriteGroup<Option>(40, 40);

		var i = 0;

		items.add(publicRoom = new Option("Açık Oda", "Etkinleştirilirse, bu ODA BUL sekmesinde herkese açık olarak listelenecektir.", () -> {
			GameClient.send("togglePrivate");
		}, (elapsed) -> {
			publicRoom.alpha = GameClient.hasPerms() ? 1 : 0.8;
			publicRoom.checked = !GameClient.room.state.isPrivate;
		}, 0, 80 * i, !GameClient.room.state.isPrivate));
		publicRoom.ID = i++;

		items.add(anarchyMode = new Option("Anarşi Modu", "Bu seçenek diğer oyunculara sunucu sahibi izinleri verir.", () -> {
			GameClient.send("anarchyMode");
		}, (elapsed) -> {
			anarchyMode.alpha = GameClient.hasPerms() ? 1 : 0.8;
			anarchyMode.checked = GameClient.room.state.anarchyMode;
		}, 0, 80 * i, GameClient.room.state.anarchyMode));
		anarchyMode.ID = i++;

		items.add(swapSides = new Option("Karşı Taraf", "Karşı Tarafta Oyna.", () -> {
			GameClient.send("swapSides");
		}, (elapsed) -> {
			swapSides.alpha = GameClient.hasPerms() ? 1 : 0.8;
			swapSides.checked = GameClient.getPlayerSelf().bfSide;
		}, 0, 80 * i, GameClient.getPlayerSelf().bfSide));
		swapSides.ID = i++;

		items.add(teamMode = new Option("Takım Modu", "Bireysel olarak değil, takımlar halinde yarışın! Performansınız takım arkadaşınızla ortalaması alınacaktır.", () -> {
			GameClient.send("teamMode");
		}, (elapsed) -> {
			teamMode.alpha = GameClient.hasPerms() ? 1 : 0.8;
			teamMode.checked = GameClient.room.state.teamMode;
		}, 0, 80 * i, GameClient.room.state.teamMode));
		teamMode.ID = i++;

		var hideGF:Option;
		items.add(hideGF = new Option("Girlfriend'i Gizle", "GF'yi sahneden gizler.", () -> {
			GameClient.send("toggleGF");
		}, (elapsed) -> {
			hideGF.alpha = GameClient.hasPerms() ? 1 : 0.8;
			hideGF.checked = GameClient.room.state.hideGF;
		}, 0, 80 * i, GameClient.room.state.hideGF));
		hideGF.ID = i++;

		var disableSkins:Option;
		items.add(disableSkins = new Option("Kostümleri Kapat", "Oyuncuların skin kullanmasını yasaklar.", () -> {
			GameClient.send("toggleSkins");
		}, (elapsed) -> {
			disableSkins.alpha = GameClient.hasPerms() ? 1 : 0.8;
			disableSkins.checked = GameClient.room.state.disableSkins;
		}, 0, 80 * i, GameClient.room.state.disableSkins));
		disableSkins.ID = i++;

		var prevCond:Int = -1;
		var winCondition:Option;
		items.add(winCondition = new Option("Kazanma Koşulu", "...", () -> {
			GameClient.send("nextWinCondition");
		}, (elapsed) -> {
			if (GameClient.room.state.winCondition != prevCond) {
				switch (GameClient.room.state.winCondition) {
					case 0:
						winCondition.descText.text = 'En yüksek Doğruluk oranına sahip taraf kazanır!';
					case 1:
						winCondition.descText.text = 'En yüksek Skoru olan taraf kazanır!';
					case 2:
						winCondition.descText.text = 'En az Iskası olan taraf kazanır!';
					case 3:
						winCondition.descText.text = 'En fazla FP kazanan taraf kazanır!';
					case 4:
						winCondition.descText.text = 'En yüksek Kombo ya sahip taraf kazanır!';
				}
				winCondition.descText.text += ' (Değiştirmek için tıklayın!)';
				winCondition.box.makeGraphic(Std.int(winCondition.descText.x - winCondition.x + winCondition.descText.width) + 10, Std.int(winCondition.height), 0x81000000);
			}
			prevCond = GameClient.room.state.winCondition;
		}, 0, 80 * i, false, true));
		winCondition.ID = i++;

		var modifers:Option;
		items.add(modifers = new Option("Oyun Değiştiriciler", "Oyun Değiştiricilerini buradan ayarlayın!", () -> {
			close();
			FlxG.state.openSubState(new GameplayChangersSubstate());
		}, null, 0, 80 * i, false, true));
		modifers.ID = i++;

		items.add(stageSelect = new Option("Arkaplan Seç", "Seçili Olan: " + (GameClient.room.state.stageName == "" ? '(default)' : GameClient.room.state.stageName), () -> {
			if (GameClient.hasPerms()) {
				close();
				FlxG.state.openSubState(new SelectStageSubstate());
			}
		}, (elapsed) -> {
			stageSelect.alpha = GameClient.hasPerms() ? 1 : 0.8;
		}, 0, 80 * i, false, true));
		stageSelect.ID = i++;

		items.add(skinSelect = new Option("Kostüm Seç", "Burada Kostümünüzü seçin!", () -> {
			if (!GameClient.room.state.disableSkins) {
				controls.isInSubstate = false;
				LoadingState.loadAndSwitchState(new SkinsState());
			}
			else {
				Alert.alert('Kostümler devre-dışı bırakıldı!');
			}
		}, null, 0, 80 * i, false, true));
		skinSelect.ID = i++;

		items.add(gameOptions = new Option("Oyun Ayarları", "Oyun Ayarlarınızı buradan açın!", () -> {
			controls.isInSubstate = false;
			LoadingState.loadAndSwitchState(new OptionsState());
			OptionsState.onPlayState = false;
			OptionsState.onOnlineRoom = true;
		}, null, 0, 80 * i, false, true));
		gameOptions.ID = i++;

		var mods:Option;
		items.add(mods = new Option("Modlar", "Yüklediğiniz Modları buradan kontrol edin!", () -> {
			controls.isInSubstate = false;
			LoadingState.loadAndSwitchState(new ModsMenuState());
			ModsMenuState.onOnlineRoom = true;
		}, null, 0, 80 * i, false, true));
		mods.ID = i++;

		add(items);

		var lastItem = items.members[items.length - 1];
		coolCam.setScrollBounds(FlxG.width, FlxG.width, 0, lastItem.y + lastItem.height + 40 > FlxG.height ? lastItem.y + lastItem.height + 40 : FlxG.height);

		GameClient.send("status", "Oda Ayarlarında");

		mobileManager.addMobilePad('NONE', 'B');
		mobileManager.addMobilePadCamera();
		controls.isInSubstate = true;
	}

	override function closeSubState() {
		super.closeSubState();
		controls.isInSubstate = true;

		GameClient.send("status", "Oda Ayarlarında");
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

    override function update(elapsed) {
        if (controls.BACK) {
			controls.isInSubstate = false;
            close();
			FlxG.mouse.visible = prevMouseVisibility;
        }

		if (!GameClient.isConnected()) {
			return;
		}

		super.update(elapsed);

		if (controls.UI_UP_P)
			curSelectedID--;
		else if (controls.UI_DOWN_P)
			curSelectedID++;

		if (curSelectedID >= items.length) {
			curSelectedID = 0;
		}
		else if (curSelectedID < 0) {
			curSelectedID = items.length - 1;
		}

        items.forEach((option) -> {
			if (GameClient.room == null)
				return;
			
			if (FlxG.mouse.justMoved && FlxG.mouse.overlaps(option, camera)) {
				curSelectedID = option.ID;
            }

			if (FlxG.mouse.overlaps(option, camera) && FlxG.mouse.justReleased) {
				option.onClick();
			}

			if (option.ID == curSelectedID) {
				coolCam.follow(option, null, 0.1);
				option.text.alpha = 1;

                if (controls.ACCEPT) {
                    option.onClick();
                }
            }
            else {
				option.text.alpha = 0.7;
            }
        });
    }
}

class Option extends FlxSpriteGroup {
	public var box:FlxSprite;
	public var checkbox:FlxSprite;
	var check:FlxSprite;
	public var text:FlxText;
	public var descText:FlxText;
	public var onClick:Void->Void;
	var onUpdate:Float->Void;
	
	public var checked(default, set):Bool;
	function set_checked(value:Bool):Bool {
		if (value == checked)
			return value;

		if (value && check != null) {
			check.angle = 0;
			check.alpha = 1;
			check.scale.set(1.2, 1.2);
		}
		return checked = value;
	}

	var noCheckbox:Bool = false;

	public function new(title:String, description:String, onClick:Void->Void, onUpdate:Float->Void, x:Int, y:Int, isChecked:Bool, ?noCheckbox:Bool = false) {
        super(x, y);

		this.onClick = onClick;
		this.onUpdate = onUpdate;
		this.noCheckbox = noCheckbox;

		box = new FlxSprite();
        box.setPosition(-5, -5);
        add(box);

		if (!noCheckbox) {
			checkbox = new FlxSprite();
			checkbox.makeGraphic(50, 50, 0x50000000);
			FlxSpriteUtil.drawRect(checkbox, 0, 0, checkbox.width, checkbox.height, FlxColor.TRANSPARENT, {thickness: 5, color: FlxColor.WHITE});
			checkbox.updateHitbox();
			add(checkbox);

			check = new FlxSprite();
			check.loadGraphic(Paths.image('check'));
			check.alpha = isChecked ? 1 : 0;
			add(check);

			checked = isChecked;
			if (checked) {
				check.scale.set(1, 1);
			}
			else {
				check.alpha = 0;
				check.scale.set(0.01, 0.01);
			}
		}

		text = new FlxText(0, 0, 0, title);
		text.setFormat("VCR OSD Mono", 22, FlxColor.WHITE);
		text.x = checkbox != null ? checkbox.width + 10 : 10;
        //text.y = checkbox.height / 2 - text.height / 2;
        add(text);

		descText = new FlxText(0, 0, 0, description);
		descText.setFormat("VCR OSD Mono", 18, FlxColor.WHITE);
		descText.x = text.x;
		descText.y = text.height + 2;
		add(descText);

		box.makeGraphic(Std.int(width) + 10, Std.int(height) + 10, 0x81000000);
    }

    override function update(elapsed) {
        super.update(elapsed);

		if (!noCheckbox) {
			if (checked) {
				if (check.scale.x != 1 || check.scale.y != 1)
					check.scale.set(FlxMath.lerp(check.scale.x, 1, elapsed * 10), FlxMath.lerp(check.scale.y, 1, elapsed * 10));
			}
			else {
				if (check.alpha != 0) {
					check.alpha = FlxMath.lerp(check.alpha, 0, elapsed * 15);
					check.angle += elapsed * 800;
				}
				if (check.scale.x != 0.01 || check.scale.y != 0.01)
					check.scale.set(FlxMath.lerp(check.scale.x, 0.01, elapsed * 15), FlxMath.lerp(check.scale.y, 0.01, elapsed * 15));
			}
		}

		if (onUpdate != null)
			onUpdate(elapsed);

		descText.alpha = text.alpha;
		if (!noCheckbox)
			checkbox.alpha = text.alpha;
    }
}
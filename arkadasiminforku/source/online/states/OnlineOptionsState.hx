package online.states;

import flixel.input.keyboard.FlxKey;
import backend.InputFormatter;
import online.network.Auth;
import lime.ui.FileDialog;
import flixel.util.FlxSpriteUtil;
import online.network.FunkinNetwork;
import flixel.FlxObject;
import lime.system.Clipboard;
import flixel.group.FlxGroup;
import openfl.events.KeyboardEvent;

class OnlineOptionsState extends MusicBeatState {
	var items:FlxTypedGroup<InputOption> = new FlxTypedGroup<InputOption>();
    static var curSelected:Int = 0;

	var camFollow:FlxObject;

	var scrollToRegister:Bool = false;
	
	public function new(?scrollToRegister:Bool = false) {
		super();

		this.scrollToRegister = scrollToRegister;
	}

    override function create() {
        super.create();

		camera.follow(camFollow = new FlxObject(), 0.1);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Menüde", "Online Ayarlar"); 
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xff2b2b2b;
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, 0);
		add(bg);

		var i = 0;

		var section = new FlxText(0, 0, FlxG.width, "Genel");
		section.setFormat("VCR OSD Mono", 25, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(section);

		var nicknameOption:InputOption;
		items.add(nicknameOption = new InputOption("Kullanıcı İsmi", "Adını Buraya Yaz!", ["Boyfriend"], (text, _) -> {
			curOption.inputs[0].text = curOption.inputs[0].text.trim().substr(0, 14);
			ClientPrefs.setNickname(curOption.inputs[0].text);
			ClientPrefs.saveSettings();
		}));
		nicknameOption.inputs[0].text = ClientPrefs.getNickname();
		nicknameOption.y = 100;
		nicknameOption.screenCenter(X);
		nicknameOption.ID = i++;

		// var titleOption:InputOption;
		// items.add(titleOption = new InputOption("Title", "Bu isminizin altında gözükecektir! (Maksimum 20 karakter)", ClientPrefs.data.playerTitle, text -> {
		// 	curOption.input.text = curOption.input.text.trim().substr(0, 20);
		// 	ClientPrefs.data.playerTitle = curOption.input.text;
		// 	ClientPrefs.saveSettings();
		// }));
		// titleOption.input.text = ClientPrefs.data.playerTitle;
		// titleOption.y = serverOption.y + serverOption.height + 50;
		// titleOption.screenCenter(X);
		// titleOption.ID = i++;

		var skinsOption:InputOption;
		items.add(skinsOption = new InputOption("Skin", "Kostümünüzü Seçin!", null, () -> {
			LoadingState.loadAndSwitchState(new SkinsState());
		}));
		skinsOption.y = nicknameOption.y + nicknameOption.height + 50;
		skinsOption.screenCenter(X);
		skinsOption.ID = i++;

		var modsOption:InputOption;
		items.add(modsOption = new InputOption("Mod Ayarlama", "Modların URL ve Linkini buradan ayarla!", null, () -> {
			FlxG.switchState(() -> new SetupModsState(Mods.getModDirectories(), true));
		}));
		modsOption.y = skinsOption.y + skinsOption.height + 50;
		modsOption.screenCenter(X);
		modsOption.ID = i++;

		function prepareAddress(address:String) {
			address = address.trim();

			if (address == "2567" || address == "0" || address == "local") {
				address = "localhost";
			}

			if (address.length > 0
				&& !(address.startsWith('wss://') || address.startsWith('ws://')))
				address = 'ws://' + address;

			if (address == "ws://localhost") {
				address += ":2567";
			}

			if (address == "ws://funkin.sniro.boo") {
				address = "wss://funkin.sniro.boo";
			}

			if (address == "ws://gettinfreaky.onrender.com") {
				address = "wss://gettinfreaky.onrender.com";
			}

			return address;
		}

		var serverOption:InputOption;
		var appendText = "";
		if (GameClient.serverAddresses.length > 0) {
			appendText += "Resmi Sunucular:";
			for (address in GameClient.serverAddresses) {
				if (address != "ws://localhost:2567")
					appendText += "\n" + address;
			}
		}
		items.add(serverOption = new InputOption("Sunucu Adresi", "Oyun Odalarını barındıran sunucu.\nVarsayılan sunucuyu kullanmak için boş bırakın.\n\nLokal Adres: 'localhost'" + appendText, [GameClient.getDefaultServer()], (text, _) -> {
			curOption.inputs[0].text = prepareAddress(curOption.inputs[0].text);
			GameClient.serverAddress = curOption.inputs[0].text;
		}));
		serverOption.inputs[0].text = GameClient.serverAddress;
		serverOption.y = modsOption.y + modsOption.height + 50;
		serverOption.screenCenter(X);
		serverOption.ID = i++;

		var networkServerOption:InputOption;
		items.add(networkServerOption = new InputOption("Ağ Sunucu Adresi", "Sosyal bilgiler için ağ sunucusu.\nVarsayılan sunucuyu kullanmak için boş bırakın.\n\nVarsayılan Sunucu: " + GameClient.getDefaultServer()
		, [GameClient.getDefaultServer()], (text, _) -> {
			curOption.inputs[0].text = prepareAddress(curOption.inputs[0].text);
			GameClient.networkServerAddress = curOption.inputs[0].text;
			try {
				online.network.FunkinNetwork.ping();
			}
			catch (exc) {
				trace(exc);
			}
		}));
		networkServerOption.inputs[0].text = GameClient.networkServerAddress;
		networkServerOption.y = serverOption.y + serverOption.height + 50;
		networkServerOption.screenCenter(X);
		networkServerOption.ID = i++;

		var trustedOption:InputOption;
		items.add(trustedOption = new InputOption("Güvenilir Alanları Sıfırla", "Güvenilir alan adlarının listesini sıfırlayın!", null, () -> {
			ClientPrefs.data.trustedSources = ["https://gamebanana.com/"];
			ClientPrefs.saveSettings();
			Alert.alert("Güvenilir alanlar sıfırlandı!", "");
		}));
		trustedOption.y = networkServerOption.y + networkServerOption.height + 50;
		trustedOption.screenCenter(X);
		trustedOption.ID = i++;

		var lastOption:InputOption;
		var recentOption:InputOption;
		items.add(recentOption = new InputOption("SSL Doğrulamasını Etkinleştir", "Aktif Edildiğinde, oyun geçerli SSL Sertifikalarını kontrol eder ve bu da indirmeler veya odalarla daha güvenli bağlantılar sağlar.\n(Ancak Haxe nin hatalı soket uygulaması nedeniyle bu önerilmez.)",
		ClientPrefs.data.verifySSL,
		() -> {
			recentOption.checked = !recentOption.checked;
			ClientPrefs.data.verifySSL = recentOption.checked;
			ClientPrefs.saveSettings();
			sys.ssl.Socket.DEFAULT_VERIFY_CERT = ClientPrefs.data.verifySSL;
		}));
		recentOption.y = trustedOption.y + trustedOption.height + 50;
		recentOption.screenCenter(X);
		recentOption.ID = i++;

		if (Auth.authID == null && Auth.authToken == null) {
			var section = new FlxText(0, recentOption.y + recentOption.height + 100, FlxG.width, "Hesap");
			section.setFormat("VCR OSD Mono", 25, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(section);

			var registerOption:InputOption;
			items.add(registerOption = new InputOption("Ağa Katılın",
					"Psych Online Network'e katılın ve şarkı tekrarlarınızı\nliderlik tablolarına gönderin!" + (!Main.UNOFFICIAL_BUILD ? '\n(UYARI: Resmi olmayan bir sürümde oynuyorsunuz.)' : ''), ["Kullanıcı", "E-posta"], (text, input) -> {
					if (input == 0) {
						registerOption.inputs[0].hasFocus = false;
						registerOption.inputs[1].hasFocus = true;
						inputWait = true;
						return;
					}

					registerOption.inputs[0].text = registerOption.inputs[0].text.trim();
					registerOption.inputs[1].text = registerOption.inputs[1].text.trim();

					if (registerOption.inputs[0].text.length <= 0) {
						Alert.alert('Kullanıcı adı ayarlanmadı!');
						return;
					}

					if (registerOption.inputs[1].text.length <= 0) {
						registerOption.inputs[0].hasFocus = false;
						registerOption.inputs[1].hasFocus = true;
						inputWait = true;
						return;
					}

					if (FunkinNetwork.requestRegister(registerOption.inputs[0].text, registerOption.inputs[1].text)) {
						openSubState(new VerifyCodeSubstate(code -> {
							if (FunkinNetwork.requestRegister(registerOption.inputs[0].text, registerOption.inputs[1].text, code)) {
								Alert.alert("Başarıyla kayıt olundu!");
								FlxG.resetState();
							}
						}));
					}
				}));
			registerOption.y = section.y + 100;
			registerOption.screenCenter(X);
			registerOption.ID = i++;
			if (scrollToRegister) {
				curSelected = registerOption.ID;
			}

			var loginOption:InputOption;
			items.add(loginOption = new InputOption("Ağa Giriş Yapın",
				"E-posta adresinizi buraya girin ve Tek Kullanımlık Giriş Kodunuzu bekleyin!" + (!Main.UNOFFICIAL_BUILD ? '' : ''), ["ben@örnek.com"], (mail, _) -> {
					if (FunkinNetwork.requestLogin(mail)) {
						openSubState(new VerifyCodeSubstate(code -> {
							if (FunkinNetwork.requestLogin(mail, code)) {
								Alert.alert("Başarıyla giriş yapıldı!");
								FlxG.resetState();
							}
						}));
					}
				}));
			loginOption.y = registerOption.y + registerOption.height + 50;
			loginOption.screenCenter(X);
			loginOption.ID = i++;
		}
		else {
			lastOption = recentOption;
			var recentOption:InputOption;
			items.add(recentOption = new InputOption("Ağ Sohbeti Bildirimleri",
			'Aktif Edildiğinde, Ağ Sohbetinden gelen tüm mesajlar size bildirilir.\n /notify komutuyla değiştirilebilir.',
			ClientPrefs.data.notifyOnChatMsg,
			() -> {
				recentOption.checked = !recentOption.checked;
				ClientPrefs.data.notifyOnChatMsg = recentOption.checked;
				ClientPrefs.saveSettings();
			}));
			recentOption.y = lastOption.y + lastOption.height + 50;
			recentOption.screenCenter(X);
			recentOption.ID = i++;

			lastOption = recentOption;
			var recentOption:InputOption;
			items.add(recentOption = new InputOption("ÖM Bildirimlerini Sessize Al",
				'Aktif Edildiğinde, Özel Mesaj bildirimleri sessize alınır.\n /notify pm Ağ komutuyla değiştirilebilir.',
				ClientPrefs.data.disablePMs, () -> {
					recentOption.checked = !recentOption.checked;
					ClientPrefs.data.disablePMs = recentOption.checked;
					ClientPrefs.saveSettings();
				}));
			recentOption.y = lastOption.y + lastOption.height + 50;
			recentOption.screenCenter(X);
			recentOption.ID = i++;

			lastOption = recentOption;
			var recentOption:InputOption;
			items.add(recentOption = new InputOption("Oda Davetlerini Sessize Al",
				'Aktif Edildiğinde, oda davetleri sessize alınır.\n /notify roominvite ağ komutuyla değiştirilebilir.',
				ClientPrefs.data.disableRoomInvites, () -> {
					recentOption.checked = !recentOption.checked;
					ClientPrefs.data.disableRoomInvites = recentOption.checked;
					ClientPrefs.saveSettings();
				}));
			recentOption.y = lastOption.y + lastOption.height + 50;
			recentOption.screenCenter(X);
			recentOption.ID = i++;

			lastOption = recentOption;
			var recentOption:InputOption;
			items.add(recentOption = new InputOption("Arkadaş Çevrimiçi Bildirimi",
				'Aktif Edildiğinde, arkadaşınız çevrimiçi olduğunda bir bildirim alırsınız.\n /notify friend ağ komutuyla etkinleştirilebilir.',
				ClientPrefs.data.friendOnlineNotification, () -> {
					recentOption.checked = !recentOption.checked;
					ClientPrefs.data.friendOnlineNotification = recentOption.checked;
					ClientPrefs.saveSettings();
				}));
			recentOption.y = lastOption.y + lastOption.height + 50;
			recentOption.screenCenter(X);
			recentOption.ID = i++;

			var sezOption:InputOption;
			items.add(sezOption = new InputOption("Global Mesaj Yaz", "Başkalarına sizin çevrimiçi hesabınızda görebileceği bir mesaj yazın!\n(Lütfen İngilizce yaz.)", ["Mesaj"],
				(message, _) -> {
					if (FunkinNetwork.postFrontMessage(message))
						FlxG.switchState(() -> new OnlineState());
				}));
			sezOption.y = recentOption.y + recentOption.height + 50;
			sezOption.screenCenter(X);
			sezOption.ID = i++;

			var sidebarOption:InputOption;
			items.add(sidebarOption = new InputOption("Yan Barı Aç", "Ağ yan barını aç, eğer yapamıyorsanız.\n(Yan barı istediğiniz zaman açmak için " + InputFormatter.getKeyName(cast(ClientPrefs.keyBinds.get('sidebar')[0], FlxKey)) + " tuşuna basın!)", null, () -> {
				online.gui.sidebar.SideUI.instance.active = true;
			}));
			sidebarOption.y = sezOption.y + sezOption.height + 50;
			sidebarOption.screenCenter(X);
			sidebarOption.ID = i++;

			var section = new FlxText(0, sidebarOption.y + sidebarOption.height + 100, FlxG.width, "Hesap");
			section.setFormat("VCR OSD Mono", 25, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(section);

			var loginBrowserOption:InputOption;
			items.add(loginBrowserOption = new InputOption("Tarayıcıda Giriş Yap", "Varsayılan web tarayıcınızda ağa kimliğinizi doğrular.", null, () -> {
				FlxG.openURL(FunkinNetwork.client.getURL("/api/auth/cookie?id=" + Auth.authID + "&token=" + Auth.authToken));
			}));
			loginBrowserOption.y = section.y + 100;
			loginBrowserOption.screenCenter(X);
			loginBrowserOption.ID = i++;

			var emailOption:InputOption;
			items.add(emailOption = new InputOption("E-posta Adresini Değiştir",
				"Use the following format:\n<new_mail> from <old_mail>", ["new@example.org from old@example.org"], (mail, _) -> {
					if (FunkinNetwork.setEmail(mail)) {
						openSubState(new VerifyCodeSubstate(code -> {
							if (FunkinNetwork.setEmail(mail, code)) {
								Alert.alert("Email Başarıyla Eklendi!");
							}
						}));
					}
				}));
			emailOption.y = loginBrowserOption.y + loginBrowserOption.height + 50;
			emailOption.screenCenter(X);
			emailOption.ID = i++;
			
			var deleteOption:InputOption;
			items.add(deleteOption = new InputOption("Hesabınızı Silin", "Psych Online Hesabınızı SİLİN, (UYARI: BU İŞLEM GERİ ALINAMAZ)!", null, () -> {
				RequestSubstate.request('Hesabınızı silmek istediğinizden emin misiniz?\n(Bu işlem geri alınamaz!)', '', _ -> {
					if (FunkinNetwork.deleteAccount()) {
						openSubState(new VerifyCodeSubstate(code -> {
							if (FunkinNetwork.deleteAccount(code)) {
								Alert.alert("Hesap Silindi!");
							}
						}));
					}
				}, null, true);
			}));
			deleteOption.y = emailOption.y + emailOption.height + 50;
			deleteOption.screenCenter(X);
			deleteOption.ID = i++;

			var logoutOption:InputOption;
			items.add(logoutOption = new InputOption("Hesaptan Çık", "Pysch Online Ağından Çıkın, hesabınıza tekrar girebilirsiniz.", null, () -> {
				RequestSubstate.request('Çıkış yapmak istediğinizden emin misiniz?', '', _ -> {
					FunkinNetwork.logout();
					FlxG.resetState();
				}, null, true);
			}));
			logoutOption.y = deleteOption.y + deleteOption.height + 50;
			logoutOption.screenCenter(X);
			logoutOption.ID = i++;
			if (scrollToRegister) {
				curSelected = logoutOption.ID;
			}
		}

		add(items);

		changeSelection(0);

		mobileManager.addMobilePad('UP_DOWN', 'A_B');
	}

	override function update(elapsed) {
		if (curOption != null) {
			camFollow.setPosition(curOption.getMidpoint().x, curOption.getMidpoint().y);
		}

		if (!inputWait) {
			if (controls.BACK) {
				FlxG.sound.music.volume = 1;
				FlxG.switchState(() -> new OnlineState());
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}

			if (controls.UI_UP_P || FlxG.mouse.wheel == 1)
				changeSelection(-1);
			else if (controls.UI_DOWN_P || FlxG.mouse.wheel == -1)
				changeSelection(1);

			if (!controls.mobileControls && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0 || FlxG.mouse.justPressed)) {
                curSelected = -1;
                var i = 0;
                for (item in items) {
                    if (!controls.mobileControls && FlxG.mouse.overlaps(item, camera)) {
                        curSelected = i;
                        break;
                    }
                    i++;
                }
                updateOptions();
            }
        }

		super.update(elapsed);

		if (!inputWait) {
			if ((controls.ACCEPT || (!controls.mobileControls && FlxG.mouse.justPressed)) && curOption != null) {
				if (curOption.isInput) {
					if (FlxG.mouse.justPressed)
						for (i => input in curOption.inputs)
							input.hasFocus = FlxG.mouse.overlaps(curOption.inputBgs[i], camera);
					else
						for (i => input in curOption.inputs)
							input.hasFocus = i == 0;
				}
				else if (curOption.onClick != null) {
					curOption.onClick();
				}
			}
		}

		inputWait = false;
		for (item in items) {
			if (item?.inputs == null)
				continue;

			for (input in item.inputs) {
				if (input.hasFocus) {
					curSelected = item.ID;
					inputWait = true;
					return;
				}
			}
		}
    }

    var curOption:InputOption;
    function changeSelection(diffe:Int) {
		curSelected += diffe;

		if (curSelected >= items.length) {
			curSelected = 0;
		}
		else if (curSelected < 0) {
			curSelected = items.length - 1;
		}

        updateOptions();
    }

    function updateOptions() {
        if (curSelected < 0 || curSelected >= items.length)
            curOption = null;
        else
            curOption = items.members[curSelected];

        for (item in items) {
			item.borderline.visible = item == curOption;
			item.alpha = inputWait ? 0.5 : 0.6;
			if (item.isInput)
				for (input in item.inputs)
					input.alpha = 0.5;
        }
        if (curOption != null) {
			curOption.alpha = 1;
			if (curOption.isInput)
				for (input in curOption.inputs)
					input.alpha = inputWait ? 1 : 0.7;
		}
    }

    var inputWait(default, set):Bool = false;
	function set_inputWait(value:Bool) {
		if (inputWait == value) return inputWait;
		inputWait = value;
		updateOptions();
		return inputWait;
	}
}

class InputOption extends FlxSpriteGroup {
	var box:FlxSprite;
	var checkbox:FlxSprite;
	var check:FlxSprite;
	public var checked(default, set):Bool = false;
	function set_checked(value:Bool):Bool {
		if (value == checked)
			return value;

		if (value && check != null) {
			check.alpha = 1;
			check.angle = 0;
			check.scale.set(1.2, 1.2);
		}
		return checked = value;
	}
	public var borderline:FlxSprite;
	public var text:FlxText;
	public var descText:FlxText;

	public var inputBgs:Array<FlxSprite> = [];
	var inputPhs:Array<FlxText> = [];
	public var inputs:Array<InputText> = [];

	public var id:String;
	public var isInput:Bool;
	public var isCheck:Bool;
	public var onEnter:(text:String, input:Int) -> Void;
	public var onClick:Void -> Void;

	public function new(title:String, description:String, input:Dynamic, ?onClick:Void->Void, ?onEnter:(text:String, input:Int)->Void) {
        super();

		id = title.toLowerCase();
		this.isInput = input is Array;
		this.isCheck = input is Bool;
		checked = isCheck && input;
		this.onClick = onClick;

		box = new FlxSprite();
		box.setPosition(-5, -10);
		add(box);

		text = new FlxText(0, 0, 0, title);
		text.setFormat("VCR OSD Mono", 22, FlxColor.WHITE);
		text.x = 10;
		add(text);

		descText = new FlxText(0, 0, 0, description);
		descText.setFormat("VCR OSD Mono", 18, FlxColor.WHITE);
		descText.fieldWidth = Math.min(700, descText.fieldWidth);
		descText.x = text.x;
		descText.y = text.height + 5;
		add(descText);

		if (isInput) {
			for (i => placeholder in cast (input, Array<Dynamic>)) {
				var inputBg = new FlxSprite();
				inputBg.makeGraphic(700, 50, FlxColor.BLACK);
				inputBg.x = text.x;
				inputBg.y = descText.y + descText.textField.textHeight + 10;
				inputBg.alpha = 0.6;
				add(inputBg);

				var inputPlaceholder = new FlxText();
				inputPlaceholder.text = placeholder;
				inputPlaceholder.setFormat("VCR OSD Mono", 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				inputPlaceholder.alpha = 0.5;
				inputPlaceholder.x = inputBg.x + 20;
				inputPlaceholder.y = inputBg.y + inputBg.height / 2 - inputPlaceholder.height / 2;
				add(inputPlaceholder);

				var input = new InputText(0, 0, inputBg.width - 20, (text) -> onEnter(text, i));
				input.setFormat("VCR OSD Mono", 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				input.setPosition(inputPlaceholder.x, inputPlaceholder.y);
				add(input);

				inputBg.y += i * 50;
				inputPlaceholder.y += i * 50;
				input.y += i * 50;

				inputBgs.push(inputBg);
				inputPhs.push(inputPlaceholder);
				inputs.push(input);
			}
		}

		var width = Std.int(width) + 10;
		if (width < 600) {
			width = 600;
		}

		if (isCheck) {
			checkbox = new FlxSprite(0, 5);
			checkbox.makeGraphic(50, 50, 0x50000000);
			FlxSpriteUtil.drawRect(checkbox, 0, 0, checkbox.width, checkbox.height, FlxColor.TRANSPARENT, {thickness: 5, color: FlxColor.WHITE});
			checkbox.updateHitbox();
			checkbox.x = width - checkbox.width - 10;
			add(checkbox);

			check = new FlxSprite(checkbox.x, checkbox.y);
			check.loadGraphic(Paths.image('check'));
			check.alpha = checked ? 1 : 0;
			add(check);

			descText.fieldWidth = checkbox.x - 30;

			if (checked) {
				check.scale.set(1, 1);
			}
			else {
				check.alpha = 0;
				check.scale.set(0.01, 0.01);
			}
		}

		box.makeGraphic(Std.int(width) + 10, Std.int(height) + 20, 0x81000000);

		borderline = new FlxSprite(box.x, box.y);
		borderline.makeGraphic(Std.int(box.width), Std.int(box.height), FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRect(borderline, 0, 0, borderline.width, borderline.height, FlxColor.TRANSPARENT, {thickness: 6, color: 0x34FFFFFF});
		borderline.visible = false;
		add(borderline);
    }

	override function update(elapsed) {
		super.update(elapsed);

		if (isInput)
			for (i => input in inputs)
				inputPhs[i].visible = input.text == "";

		if (check != null) {
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
		//targetScale = alpha == 1 ? 1.02 : 1;
		//scale.set(FlxMath.lerp(scale.x, targetScale, elapsed * 10), FlxMath.lerp(scale.y, targetScale, elapsed * 10));
	}
}
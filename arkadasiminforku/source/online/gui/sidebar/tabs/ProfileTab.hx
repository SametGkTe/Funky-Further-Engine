package online.gui.sidebar.tabs;

import openfl.display.Shape;
import openfl.display.InterpolationMethod;
import openfl.display.SpreadMethod;
import openfl.display.GradientType;
import openfl.geom.Matrix;
import com.yagp.GifPlayerWrapper;
import com.yagp.GifPlayer;
import com.yagp.GifDecoder;
import com.yagp.Gif;
import online.http.HTTPHandler;

class ProfileTab extends TabSprite {
	static var flagCDN:HTTPHandler;
	static var flagsAPI:HTTPHandler;

	var nextUsername:String = null;
	var username(default, set):String;
	var user:UserDetailsData;

	var loading(default, set):Bool = false;

	var avatar:Bitmap;
	var flag:Bitmap;
	var usernameTxt:TextField;
	var role:TextField;
	var seen:TextField;
	var stats:TextField;
	var loadingTxt:TextField;
	var desc:TextField;
	var line1:Bitmap;
	var line2:Bitmap;
	var statsTitle:TextField;

	var addFriend:TabButton;
	var removeFriend:TabButton;
	var invitePlay:TabButton;
	var settings:TabButton;
	var web:TabButton;

    public function new() {
        super('Profil', 'profile');
    }

    public static function view(username:String) {
		SideUI.instance.active = true;
		cast(SideUI.instance.tabs[SideUI.instance.initTabs.indexOf(ProfileTab)], ProfileTab).nextUsername = username;
		SideUI.instance.curTabIndex = SideUI.instance.initTabs.indexOf(ProfileTab);
    }

override function create() {
    super.create();

    flagCDN = new HTTPHandler('https://flagcdn.com');
    flagsAPI = new HTTPHandler('https://flagsapi.com');
    
    // Yükleniyor metni
    loadingTxt = this.createText(20 * S, 20 * S, Std.int(40 * S));
    loadingTxt.setText('Bilgi Alınıyor...');
    loadingTxt.visible = false;
    addChild(loadingTxt);

    // Avatar ve Temel Bilgiler
    avatar = new Bitmap(new BitmapData(Std.int(110 * S), Std.int(110 * S), true, FlxColor.GRAY));
    avatar.x = 20 * S;
    avatar.y = 20 * S;
    addChild(avatar);

    usernameTxt = this.createText(avatar.x + avatar.width + (15 * S), avatar.y + (5 * S), Std.int(35 * S));
    addChild(usernameTxt);

    flag = new Bitmap(new BitmapData(1, 1, true, 0)); 
    addChild(flag);

    role = this.createText(usernameTxt.x, usernameTxt.y + (45 * S), Std.int(20 * S));
    addChild(role);

    seen = this.createText(role.x, role.y + (30 * S), Std.int(18 * S), 0xFF7C7C7C);
    addChild(seen);

    desc = this.createText(avatar.x, avatar.y + avatar.height + (15 * S), Std.int(16 * S));
    desc.setText("");
    addChild(desc);

    // Ayırıcı Çizgiler ve İstatistikler
    line1 = new Bitmap(new BitmapData(1, 2, true, 0xFFFFFFFF));
    line1.x = 20 * S;
    line1.scaleX = (tabWidth * S) - (40 * S);
    addChild(line1);

    statsTitle = this.createText(0, 0, Std.int(28 * S));
    statsTitle.setText("Statistics");
    addChild(statsTitle);

    line2 = new Bitmap(new BitmapData(1, 2, true, 0xFFFFFFFF));
    line2.x = line1.x;
    line2.scaleX = line1.scaleX;
    addChild(line2);

    stats = this.createText(40 * S, 0, Std.int(20 * S));
    addChild(stats);

    // Alt Butonlar
    web = new TabButton('internet', () -> {
        FlxG.openURL(FunkinNetwork.client.getURL("/user/" + StringTools.urlEncode(username)));
    });
    web.x = (tabWidth * S) - web.width - (20 * S);
    web.y = heightSpace - web.height - (20 * S);
    addChild(web);

    settings = new TabButton('wheel', () -> {
        FlxG.openURL(FunkinNetwork.client.getURL("/api/auth/cookie?id=" + Auth.authID + "&token=" + Auth.authToken));
    });
    settings.x = web.x;
    settings.y = web.y;
    addChild(settings);

    addFriend = new TabButton('add_friend', () -> inviteToFriends());
    addFriend.x = avatar.x;
    addFriend.y = seen.y + (40 * S);
    addChild(addFriend);

    removeFriend = new TabButton('remove_friend', () -> removeFromFriends());
    removeFriend.x = addFriend.x;
    removeFriend.y = addFriend.y;
    addChild(removeFriend);

    invitePlay = new TabButton('invite', () -> Util.inviteToPlay(username));
    invitePlay.x = addFriend.x + addFriend.width + (10 * S);
    invitePlay.y = addFriend.y;
    addChild(invitePlay);
}

	function renderData() {
		loading = false;
		var loadingUser = username;
    
		// Arka plan rengini ayarla
		tabBg.visible = true;
		tabBg.bitmapData = new BitmapData(Std.int(tabWidth * S), heightSpace, true, FlxColor.fromHSL(user.profileHue, 0.35, 0.2));

		// Avatar Yükleme Kısmı (Genişlik ve Yüksekliği S ile çarpmayı unutma)
		avatar.width = 110 * S;
		avatar.height = 110 * S;

		Thread.run(() -> {
			var avatarData = FunkinNetwork.getUserAvatar(loadingUser);
			Waiter.putPersist(() -> {
				if (loadingUser == username) {
					var prevAvatar = avatar;
					if (avatarData == null)
						avatar = new Bitmap(FunkinNetwork.getDefaultAvatar());
					else if (!ShitUtil.isGIF(avatarData))
						avatar = new Bitmap(BitmapData.fromBytes(avatarData));
					else
						avatar = new GifPlayerWrapper(new GifPlayer(GifDecoder.parseBytes(avatarData)));

					addChildAt(avatar, getChildIndex(prevAvatar));
					removeChild(prevAvatar);

					avatar.x = 20 * S;
					avatar.y = 20 * S;
					avatar.width = 110 * S;
					avatar.height = 110 * S;
				}
			});
			loadFlag(loadingUser, user.country);
		});

		updateUsernameText();
    
		// ... Metinleri güncelle ...
		role.setText((user.club != null ? '[${user.club}] | ' : '') + (user.role != null ? user.role : 'Üye'));
    
		// Pozisyonları dinamik olarak güncelle
		line1.y = desc.y + desc.height + (15 * S);
		statsTitle.x = (tabWidth * S) / 2 - statsTitle.textWidth / 2;
		statsTitle.y = line1.y + (20 * S);
		line2.y = statsTitle.y + (45 * S);
		stats.y = line2.y + (20 * S);
    
		// Buton görünürlükleri
		removeFriend.visible = user.friends.contains(FunkinNetwork.nickname);
		addFriend.visible = !removeFriend.visible && user.canFriend;
		invitePlay.visible = removeFriend.visible;
		settings.visible = (username == FunkinNetwork.nickname);
		web.visible = !settings.visible;
	}

	override function onShow() {
        super.onShow();

		if (nextUsername == null)
            username = FunkinNetwork.nickname;
		else
			username = nextUsername;
    }

	override function onHide() {
		super.onHide();

		if (!SideUI.instance.active)
			nextUsername = null;
	}

	function set_username(v:String) {
		username = v;

		loading = true;
		Thread.run(() -> {
			var response = FunkinNetwork.requestAPI('/api/user/details?name=' + StringTools.urlEncode(username));

			if (response != null && !response.isFailed()) {
				Waiter.putPersist(() -> {
					if (v == username) {
						user = Json.parse(response.getString());
						renderData();
                    }
				});
			}
		});

        return username;
	}

	function set_loading(v:Bool) {
		for (child in __children) {
			child.visible = !v;
		}
		tabBg.visible = true;
		loadingTxt.visible = v;
		if (v)
			tabBg.bitmapData = new BitmapData(tabBg.bitmapData.width, tabBg.bitmapData.height, true, FlxColor.fromRGB(10, 10, 10));
		return loading = v;
	}

	function removeFromFriends() {
		LoadingScreen.toggle(true);

		var daUsername = username;
		Thread.run(() -> {
			var response = FunkinNetwork.requestAPI('/api/user/friends/remove?name=' + StringTools.urlEncode(daUsername));

			LoadingScreen.toggle(false);

			if (response != null && !response.isFailed()) {
				Waiter.putPersist(() -> {
					Alert.alert('Kullanıcı ' + daUsername + " arkadaş listesinden çıkarıldı");
					if (username == daUsername)
						username = username;
				});
			}
		});
	}

	function inviteToFriends() {
		LoadingScreen.toggle(true);

		var daUsername = username;
		Thread.run(() -> {
			var response = FunkinNetwork.requestAPI('/api/user/friends/request?name=' + StringTools.urlEncode(daUsername));

			LoadingScreen.toggle(false);

			if (response != null && !response.isFailed()) {
				Waiter.putPersist(() -> {
					Alert.alert('Arkadaşlık isteği ' + daUsername + " adlı kullanıcıya gönderildi!");
					if (username == daUsername)
						username = username;
				});
			}
		});
	}

	function updateUsernameText() {
		usernameTxt.setText(username, Std.int((150 * S) + (!flag.visible ? (65 * S) : 0)));
		flag.x = usernameTxt.x + usernameTxt.width + (20 * S);
		flag.y = avatar.y + (15 * S);
		usernameTxt.y = avatar.y + (10 * S) + ((40 * S) / 2) - ((40 * S) * usernameTxt.scaleY) / 2;
	}

	override function __enterFrame(delta) {
		super.__enterFrame(delta);

		invitePlay.alpha = GameClient.isConnected() ? 1.0 : 0.5;
	}

	function loadFlag(loadingUser:String, country:String, ?retry:Bool = false) {
		var flagResponse = !retry ? flagCDN.request({
			path: "h24/" + country.toLowerCase() + ".png",
		}) : flagsAPI.request({
			path: country + "/flat/24.png",
		});

		if (!flagResponse.isFailed()) {
			Waiter.putPersist(() -> {
				if (flag != null && loadingUser == username) {
					flag.visible = true;
					flag.bitmapData = BitmapData.fromBytes(flagResponse.getBytes());
					updateUsernameText();
				}
			});
		}
		else if (!retry) {
			loadFlag(loadingUser, country, true);
		}
	}
}

typedef UserDetailsData = {
	var role:String;
	var joined:String;
	var lastActive:String;
	var points:Float;
	var isSelf:Bool;
	var bio:String;
	var friends:Array<String>;
	var canFriend:Bool;
	var profileHue:Int;
	var profileHue2:Null<Int>;
	var avgAccuracy:Float;
	var rank:Float;
	var country:String;
	var club:String;
}
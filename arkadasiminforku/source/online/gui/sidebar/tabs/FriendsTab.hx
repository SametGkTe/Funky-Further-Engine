package online.gui.sidebar.tabs;

import haxe.ds.Either;
import haxe.Json;
import sys.thread.Thread;
import com.yagp.GifDecoder;
import com.yagp.GifPlayer;
import com.yagp.GifPlayerWrapper;
import openfl.geom.Rectangle;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.events.MouseEvent;
import openfl.events.KeyboardEvent;
import flixel.util.FlxColor;
import online.gui.sidebar.SideUI;
import online.gui.sidebar.SideUI.uiScale as S;
import online.gui.sidebar.obj.TabSprite.ITabInteractable;

using StringTools;

class FriendsTab extends TabSprite {
	var data:FriendsResponseData;

	var loading(default, set):Bool = false;
	var loadingTxt:TextField;

	var friendsTxt:TextField;
	var requestsTxt:TextField;
	var pendingTxt:TextField;

	var trashedProfiles:Array<SmolProfile> = [];
	var friendsList:Array<SmolProfile> = [];

	var realHeight:Float = 0;

    public function new() {
        super('Arkadaşlar', 'friends');
    }

    override function create() {
        super.create();

		scrollRect = new Rectangle(0, 0, tabWidth * S, heightSpace);

		loadingTxt = this.createText(20 * S, 20 * S, Std.int(40 * S));
		loadingTxt.setText('Bilgi Alınıyor...');
		loadingTxt.visible = false;
		addChild(loadingTxt);
	
		friendsTxt = this.createText(10 * S, 10 * S, Std.int(25 * S), FlxColor.WHITE);
		friendsTxt.setText('Arkadaşlarım');
		addChild(friendsTxt);

		requestsTxt = this.createText(10 * S, 0, Std.int(25 * S), FlxColor.WHITE);
		requestsTxt.setText('Arkadaşlık İstekleri');
		requestsTxt.visible = false;
		addChild(requestsTxt);

		pendingTxt = this.createText(10 * S, 0, Std.int(25 * S), FlxColor.WHITE);
		pendingTxt.setText('Bekleyen İstekler');
		pendingTxt.visible = false;
		addChild(pendingTxt);
	}

	function renderData() {
		for (profile in friendsList) {
			profile.isAction = false;
			trashedProfiles.push(profile);
			if (contains(profile)) removeChild(profile);
		}
		friendsList = [];

		if (data == null) return;

		data.friends.sort((a, b) -> {
			if (a.status == b.status) return 0;
			return a.status.toLowerCase() != 'offline' ? -1 : 1;
		});

		var nextY:Float = friendsTxt.y + friendsTxt.height + (10 * S);

		// Arkadaşlar Listesi
		for (friend in data.friends) {
			var profile = trashedProfiles.length > 0 ? trashedProfiles.pop() : new SmolProfile();
			profile.create(friend);
			profile.y = nextY;
			nextY += profile.underlay.height + (5 * S);
			friendsList.push(profile);
			addChild(profile);
		}

		// İstekler Listesi
		requestsTxt.visible = data.requests.length > 0;
		if (requestsTxt.visible) {
			requestsTxt.y = nextY + (20 * S);
			nextY = requestsTxt.y + requestsTxt.height + (10 * S);
			for (name in data.requests) {
				var profile = trashedProfiles.length > 0 ? trashedProfiles.pop() : new SmolProfile();
				profile.create({name: name, isNotFriend: true, canFriend: true});
				profile.y = nextY;
				nextY += profile.underlay.height + (5 * S);
				friendsList.push(profile);
				addChild(profile);
			}
		}

		// Bekleyenler Listesi
		pendingTxt.visible = data.pending.length > 0;
		if (pendingTxt.visible) {
			pendingTxt.y = nextY + (20 * S);
			nextY = pendingTxt.y + pendingTxt.height + (10 * S);
			for (name in data.pending) {
				var profile = trashedProfiles.length > 0 ? trashedProfiles.pop() : new SmolProfile();
				profile.create({name: name, isNotFriend: true});
				profile.y = nextY;
				nextY += profile.underlay.height + (5 * S);
				friendsList.push(profile);
				addChild(profile);
			}
		}

		realHeight = nextY;
	}

	override function onShow() {
		super.onShow();
		loadData();
	}

    function loadData() {
        loading = true;
		Thread.run(() -> {
			var response = FunkinNetwork.requestAPI('/api/account/friends');
			if (response != null && !response.isFailed()) {
				var raw = response.getString();
				Waiter.putPersist(() -> {
					loading = false;
					data = Json.parse(raw);
					renderData();
				});
			}
		});
    }

	function set_loading(v:Bool) {
		for (i in 0...numChildren) {
			var child = getChildAt(i);
			if (child != tabBg && child != loadingTxt) child.visible = !v;
		}
		loadingTxt.visible = v;
		return loading = v;
	}

	override function mouseWheel(e:MouseEvent):Void {
		super.mouseWheel(e);
		autoScroll(e.delta);
	}

	function autoScroll(?scrollDelta:Float = 0) {
		var rect = scrollRect;
		rect.y -= scrollDelta * 40;
		if (rect.y <= 0) rect.y = 0;
		if (realHeight > rect.height) {
			if (rect.y > realHeight - rect.height)
				rect.y = realHeight - rect.height;
		} else {
			rect.y = 0;
		}
		scrollRect = rect;
	}
}

// createText kullanabilmesi için WSprite olmalı
class SmolProfile extends WSprite implements ITabInteractable {
	public var icon:Bitmap;
	public var nick:TextField;
	public var status:TextField;
	public var invitePlay:TabButton;
	public var addFriend:TabButton;
	public var viewProfile:TabButton;
	public var underlay:Bitmap;
	public var isAction:Bool = false;

    public function new() {
        super();
		
		underlay = new Bitmap(new BitmapData(Std.int(SideUI.DEFAULT_TAB_WIDTH * S), Std.int(100 * S), true, FlxColor.fromRGB(30, 30, 30)));
        addChild(underlay);

		icon = new Bitmap(new BitmapData(1, 1, true, 0));
		icon.x = 10 * S;
		icon.y = 10 * S;
		addChild(icon);

		nick = this.createText(100 * S, 15 * S, Std.int(22 * S));
		addChild(nick);

		status = this.createText(nick.x, nick.y + (30 * S), Std.int(17 * S));
		addChild(status);

		invitePlay = new TabButton('invite', () -> {});
		invitePlay.x = underlay.width - invitePlay.width - (15 * S);
		invitePlay.y = underlay.height / 2 - invitePlay.height / 2;
		addChild(invitePlay);

		addFriend = new TabButton('add_friend', () -> {});
		addFriend.x = invitePlay.x;
		addFriend.y = invitePlay.y;
		addChild(addFriend);

		viewProfile = new TabButton('profile', () -> {});
		viewProfile.x = invitePlay.x - viewProfile.width - (10 * S);
		viewProfile.y = invitePlay.y;
		addChild(viewProfile);
    }

	public function create(data:FriendData) {
		var hue = data.hue != null ? data.hue : 0;
		underlay.bitmapData = new BitmapData(Std.int(SideUI.DEFAULT_TAB_WIDTH * S), Std.int(100 * S), true, FlxColor.fromHSL(hue, 0.2, 0.15));

		status.visible = !data.isNotFriend;
		invitePlay.visible = !data.isNotFriend;
		addFriend.visible = (data.isNotFriend == true && data.canFriend == true);

		nick.text = data.name;
		status.text = (data.status != null) ? data.status : "";

		if (data.status != null && data.status.toLowerCase() != "offline") {
			status.textColor = FlxColor.LIME;
		} else {
			status.textColor = FlxColor.GRAY;
		}

		invitePlay.onClick = () -> Util.inviteToPlay(data.name);
		viewProfile.onClick = () -> ProfileTab.view(data.name);
		addFriend.onClick = () -> {
			var daUsername = data.name;
			Thread.run(() -> {
				FunkinNetwork.requestAPI('/api/user/friends/request?name=' + daUsername.urlEncode());
				SideUI.instance.curTabIndex = SideUI.instance.curTabIndex; // Refresh
			});
		}

		// Avatar Yükleme
		Thread.run(() -> {
			var avatarData = FunkinNetwork.getUserAvatar(data.name);
			Waiter.putPersist(() -> {
				var prevIcon = icon;
				var iconData:Either<BitmapData, com.yagp.Gif>;

				if (avatarData == null)
					iconData = Left(FunkinNetwork.getDefaultAvatar());
				else if (!ShitUtil.isGIF(avatarData))
					iconData = Left(BitmapData.fromBytes(avatarData));
				else
					iconData = Right(GifDecoder.parseBytes(avatarData));

				switch (iconData) {
					case Left(v): icon = new Bitmap(v);
					case Right(v): icon = new GifPlayerWrapper(new GifPlayer(v));
					default:
				}

				icon.smoothing = true;
				icon.x = 10 * S;
				icon.y = 10 * S;
				icon.width = icon.height = 80 * S;

				addChildAt(icon, getChildIndex(prevIcon));
				if (prevIcon != null && contains(prevIcon)) removeChild(prevIcon);
			});
		});
	}

	override function __enterFrame(delta) {
		super.__enterFrame(delta);
		invitePlay.alpha = GameClient.isConnected() ? 1.0 : 0.5;
	}

	public function mouseDown(event:MouseEvent) {}
	public function mouseMove(event:MouseEvent) {
		underlay.alpha = this.overlapsMouse() ? 0.6 : 0.3;
    }
	public function keyDown(event:KeyboardEvent) {}
	public function mouseWheel(event:MouseEvent) {}
}

typedef FriendsResponseData = {
	var friends:Array<FriendData>;
	var pending:Array<String>;
	var requests:Array<String>;
}

typedef FriendData = {
	var name:String;
	@:optional var status:String;
	@:optional var hue:Int;
	@:optional var isNotFriend:Bool;
	@:optional var canFriend:Bool;
}
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
import flixel.FlxG;
import online.gui.sidebar.SideUI;
import online.gui.sidebar.SideUI.uiScale as S;
import online.gui.sidebar.obj.TabSprite.ITabInteractable;

using StringTools;

class NotificationsTab extends TabSprite {
	var data:Array<NotificationData> = [];

	var loading(default, set):Bool = false;
	var loadingTxt:TextField;

	var trashedNotifs:Array<Notification> = [];
	var notifsList:Array<Notification> = [];

	var realHeight:Float = 0;

    public function new() {
        super('Bildirimler', 'notif');
    }

    override function create() {
        super.create();

		scrollRect = new Rectangle(0, 0, tabWidth * S, heightSpace);

		loadingTxt = this.createText(20 * S, 20 * S, Std.int(40 * S));
		loadingTxt.setText('Bilgi Alınıyor...');
		loadingTxt.visible = false;
		addChild(loadingTxt);
    }

	function renderData() {
		for (notif in notifsList) {
			notif.isAction = false;
			trashedNotifs.push(notif);
			if (contains(notif)) removeChild(notif);
		}
		notifsList = [];

		if (data == null || data.length == 0) {
			loadingTxt.setText('Bildirim yok...');
			loadingTxt.visible = true;
			return;
		}

		var nextY = 0.0;
		for (i => notifData in data) {
			var notif:Notification;
			if (trashedNotifs.length > 0) {
				notif = trashedNotifs.pop();
			} else {
				notif = new Notification(notifData);
			}
			
			notif.create(notifData);
			notif.y = nextY;
			nextY += notif.underlay.height + (5 * S);
			notifsList.push(notif);
			addChild(notif);
		}

		realHeight = nextY;
		autoScroll(0); // Scroll sınırlarını güncelle
	}

	override function onShow() {
		super.onShow();
		loadData();
	}

    function loadData() {
        loading = true;
		Thread.run(() -> {
			try {
				var response = FunkinNetwork.requestAPI('/api/account/notifications');
				if (response != null && !response.isFailed()) {
					var rawData = response.getString();
					Waiter.putPersist(() -> {
						loading = false;
						data = Json.parse(rawData);
						renderData();
					});
				}
			} catch(e:Dynamic) {
				loading = false;
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

// createText kullanabilmesi için WSprite'dan türetildi
class Notification extends WSprite implements ITabInteractable {
	public var icon:Bitmap;
	public var title:TextField;
	public var desc:TextField;
	public var underlay:Bitmap;
	var remove:TabButton;
	var view:TabButton;
	var profile:TabButton;
	var data:NotificationData;
	
	public var isAction(default, set):Bool = false;
	var _actionTime:Float = 0;

	function set_isAction(v) {
		_actionTime = 0;
		title.visible = !v;
		desc.visible = !v;
		remove.visible = v;
		
		var hasHref = (data != null && data.href != null);
		profile.visible = v && hasHref && data.href.startsWith('/user/');
		view.visible = v && hasHref && !profile.visible;
		
		return isAction = v;
	}

	public function new(data:NotificationData) {
		super();
		this.data = data;

		underlay = new Bitmap(new BitmapData(Std.int(SideUI.DEFAULT_TAB_WIDTH * S), Std.int(110 * S), true, FlxColor.fromRGB(40, 40, 45)));
		addChild(underlay);

		icon = new Bitmap(new BitmapData(1, 1, true, 0));
		icon.smoothing = true;
		icon.x = 15 * S;
		icon.y = 15 * S;
		addChild(icon);

		title = this.createText(110 * S, 15 * S, Std.int(20 * S));
		title.wordWrap = true;
		title.multiline = true;
		title.width = (SideUI.DEFAULT_TAB_WIDTH * S) - title.x - (15 * S);
		addChild(title);

		desc = this.createText(title.x, title.y + (30 * S), Std.int(16 * S));
		desc.wordWrap = true;
		desc.multiline = true;
		desc.width = title.width;
		addChild(desc);

		remove = new TabButton('cancel', () -> {
			if (_actionTime < 0.1) return;
			FunkinNetwork.requestAPI('/api/account/notifications/delete/' + this.data.id);
			// Refresh tab
			SideUI.instance.curTabIndex = SideUI.instance.curTabIndex;
		});
		remove.x = underlay.width - remove.width - (15 * S);
		remove.y = underlay.height / 2 - remove.height / 2;
		addChild(remove);

		view = new TabButton('internet', () -> {
			if (_actionTime < 0.1) return;
			var url = this.data.href.startsWith('/') ? FunkinNetwork.client.getURL(this.data.href) : this.data.href;
			FlxG.openURL(url);
		});
		view.x = remove.x - view.width - (15 * S);
		view.y = remove.y;
		addChild(view);

		profile = new TabButton('profile', () -> {
			if (_actionTime < 0.1) return;
			var userName = this.data.href.substr('/user/'.length).urlDecode();
			ProfileTab.view(userName);
		});
		profile.x = view.x;
		profile.y = view.y;
		addChild(profile);

		set_isAction(false);
	}

	public function create(data:NotificationData) {
		this.data = data;
		title.text = data.title;
		desc.text = data.content;
		
		// Metin yüksekliklerini ayarla
		title.height = title.textHeight + 10;
		desc.y = title.y + title.height;
		desc.height = desc.textHeight + 10;

		// Resim yükleme
		if (data.image != null && data.image.length > 0) {
			Thread.run(() -> {
				var url = data.image.startsWith('/') ? FunkinNetwork.client.getURL(data.image) : data.image;
				var imgBytes = ShitUtil.fetchBitmapBytesfromURL(url);
				if (imgBytes != null) {
					Waiter.putPersist(() -> {
						var iconData:Either<BitmapData, com.yagp.Gif>;
						if (!ShitUtil.isGIF(imgBytes))
							iconData = Left(BitmapData.fromBytes(imgBytes));
						else
							iconData = Right(GifDecoder.parseBytes(imgBytes));

						var prevIcon = icon;
						switch (iconData) {
							case Left(v): icon = new Bitmap(v);
							case Right(v): icon = new GifPlayerWrapper(new GifPlayer(v));
							default:
						}
						
						icon.smoothing = true;
						icon.x = 15 * S;
						icon.y = 15 * S;
						icon.width = icon.height = 80 * S;
						
						addChildAt(icon, getChildIndex(prevIcon));
						removeChild(prevIcon);
					});
				}
			});
		}
	}

	override function __enterFrame(delta) {
		super.__enterFrame(delta);
		if (isAction) _actionTime += delta / 1000;
	}

	public function mouseDown(event:MouseEvent) {
		if (this.overlapsMouse() && !remove.overlapsMouse() && !view.overlapsMouse() && !profile.overlapsMouse()) {
			isAction = !isAction;
		}
	}
	public function mouseMove(event:MouseEvent) {
		underlay.alpha = this.overlapsMouse() ? 0.8 : 0.3;
		if (isAction && !this.overlapsMouse()) isAction = false;
	}
	public function keyDown(event:KeyboardEvent) {}
	public function mouseWheel(event:MouseEvent) {}
}

typedef NotificationData = {
	var id:String;
	var date:String;
	var title:String;
	var content:String;
	var image:String;
	var href:String;
}
package online.gui.sidebar.tabs;

import openfl.geom.Rectangle;

class ChatTab extends TabSprite {
	var input:TextField;
	var messages:Array<TextField> = [];
	var messageGroup:Sprite;

	public function new() {
		super('Sohbet', 'chat');
	}

	override function create() {
		super.create();

		var placeholderInput = this.createText(0, 0, 16, FlxColor.WHITE);
		placeholderInput.text = '(Buraya tıklayın veya Chat tuşuna basarak sohbet edin)';
		placeholderInput.width = tabWidth;
		placeholderInput.height = placeholderInput.textHeight;
		placeholderInput.alpha = 0.5;

		input = this.createText(0, 0, Std.int(18 * S), FlxColor.WHITE); // Font boyutu 16 -> 18 * S yapıldı
		input.text = ''; // \n\n mobilde garip durabilir, boş bıraktık
		input.width = (tabWidth * S) - (10 * S); // Genişlik ölçeklendi ve kenarlardan boşluk bırakıldı
		input.height = Std.int(45 * S); // Yükseklik 16'dan 45 * S'ye çıkarıldı (Dokunması kolay olsun diye)
		input.type = INPUT;
		input.multiline = false;

		input.x = 5 * S; 
		input.y = heightSpace - input.height - (5 * S); 

		input.addEventListener(Event.CHANGE, _ -> {
			placeholderInput.visible = input.text.length <= 0;
		});
		placeholderInput.y = input.y;

		addChild(input);
		addChild(placeholderInput);

		messageGroup = new Sprite();
		messageGroup.scrollRect = new Rectangle(0, 0, tabWidth, heightSpace - 20);
		addChild(messageGroup);

		for (preMsg in _nullInstanceMsgs) {
			addMessage(preMsg);
		}
		_nullInstanceMsgs = [];

		updateData();
	}

	override function onShow() {
		super.onShow();

		input.selectable = true;
	}
	
	override function onHide() {
		super.onHide();

		input.selectable = false;
		if (stage.focus == input)
			stage.focus = null;
	}

	override function onRemove() {
		super.onRemove();

		if (Lib.current.stage != null && Lib.current.stage.focus == input)
			Lib.current.stage.focus = null;
	}

	function updateData() {
		var lastMessage:TextField = null;
		for (message in messages) {
			if (lastMessage != null)
				message.y = lastMessage.y + lastMessage.textHeight + 5;
			lastMessage = message;
		}
	}
	
	override function keyDown(event:KeyboardEvent):Void {
		super.keyDown(event);

		if (stage.focus == input && event.keyCode == 13) {
			if (input.text.trim() == '/notify pm') {
				ClientPrefs.data.disablePMs = !ClientPrefs.data.disablePMs;
				ClientPrefs.saveSettings();
				addMessage('ÖM Bildirimleri şu an ${ClientPrefs.data.disablePMs ? 'KAPALI' : 'AÇIK'}!');
			}
			else if (input.text.trim() == '/notify roominvite') {
				ClientPrefs.data.disableRoomInvites = !ClientPrefs.data.disableRoomInvites;
				ClientPrefs.saveSettings();
				addMessage('Oda Daveti Bildirimleri şu an ${ClientPrefs.data.disableRoomInvites ? 'KAPALI' : 'AÇIK'}!');
			}
			else if (input.text.trim() == '/notify') {
				ClientPrefs.data.notifyOnChatMsg = !ClientPrefs.data.notifyOnChatMsg;
				ClientPrefs.saveSettings();
				addMessage('Sohbet Bildirimleri şu an ${ClientPrefs.data.notifyOnChatMsg ? 'AÇIK' : 'KAPALI'}!');
			}
			else if (input.text.trim().startsWith('/profile')) {
				online.gui.sidebar.tabs.ProfileTab.view(input.text.substr('/profile'.length).trim());
			}
			else {
				if (NetworkClient.room != null) {
					NetworkClient.room.send('chat', input.text);
				}
				else {
					addMessage("Sunucuya bağlı değil! Bağlanılmaya çalışılıyor!");
					NetworkClient.connect();
				}
			}
			
			input.text = '';
			input.dispatchEvent(new Event(Event.CHANGE, true));
		}
	}

	override function mouseDown(e:MouseEvent):Void {
		if (input.overlapsMouse()) {
			stage.focus = input;
		}
	}

	override function mouseWheel(e:MouseEvent):Void {
		super.mouseWheel(e);

		autoScroll(e.delta);
	}

	function autoScroll(?scrollDelta:Float = 0) {
		var rect = messageGroup.scrollRect;
		rect.y -= scrollDelta * 30;
		if (rect.y <= 0)
			rect.y = 0;
		if (rect.y + rect.height >= messageGroup.height)
			rect.y = messageGroup.height - rect.height;
		messageGroup.scrollRect = rect;
	}

	public static var lastLogDate:Float = 0;
	static var _nullInstanceMsgs:Array<Dynamic> = [];
	public static function addMessage(raw:Dynamic, ?isNew:Bool = false) {
		var data = ShitUtil.parseLog(raw);
		
		var instance:ChatTab = cast(SideUI.instance.tabs[SideUI.instance.initTabs.indexOf(ChatTab)]);
		if (instance == null || !instance.initialized) {
			_nullInstanceMsgs.push(raw);
			return;
		}
		if (instance.messages.length > 100)
			instance.removeChild(instance.messages.shift());

		var doScrollDown = instance.messageGroup.scrollRect.y + instance.messageGroup.scrollRect.height + 10 >= instance.messageGroup.height;

		var message = instance.createText(0, 0, 15, FlxColor.WHITE);
		var format = message.defaultTextFormat;
		format.size = Std.int(18 * S);
		if (data.color != null)
			format.color = data.color;
		else
			format.color = data.hue != null ? FlxColor.fromHSL(data.hue, 1.0, 0.8) : FlxColor.WHITE;
		if (data.center == true) {
			format.align = CENTER;
			//message.x = tabWidth / 2 - message.width / 2;
		}
		message.defaultTextFormat = format;
		message.wordWrap = true;
		message.selectable = true;

		var prefix = '';
		if (data.date != null) {
			var lastDate = Date.fromTime(lastLogDate);
			var date = Date.fromTime(data.date);
			if (data.hue != null) {
				prefix = ShitUtil.toBiDigitString(date.getHours()) + ":" + ShitUtil.toBiDigitString(date.getMinutes()) + " ";
				if (!SideUI.instance.active && ((data.isPM && !ClientPrefs.data.disablePMs) || (isNew && ClientPrefs.data.notifyOnChatMsg))) {
					Alert.alert('New Chat Message!', data.content);
				}
			}

			lastLogDate = data.date;

			if (date.getDate() != lastDate.getDate()
				|| date.getMonth() != lastDate.getMonth()
				|| date.getFullYear() != lastDate.getFullYear()) 
			{
				addMessage({
					content: date.getDate() + ' ' + ShitUtil.getMonthName(date) + ' ' + date.getFullYear(), 
					color: 0x888888,
					center: true
				});
			}
			
		}
		message.text = prefix + data.content;
		message.width = instance.tabWidth;
		message.height = message.textHeight + 1;
		instance.messageGroup.addChild(message);
		instance.messages.push(message);
		instance.updateData();

		if (doScrollDown) {
			var rect = instance.messageGroup.scrollRect;
			rect.y = instance.messageGroup.height - rect.height;
			instance.messageGroup.scrollRect = rect;
		}
		instance.autoScroll();
    }
}
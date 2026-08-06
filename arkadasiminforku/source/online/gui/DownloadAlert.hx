package online.gui;

import openfl.Lib;
import openfl.Assets;
import openfl.text.TextFormat;
import openfl.text.TextField;
import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.display.Sprite;

@:allow(online.gui.DownloadAlert)
class DownloadAlerts extends Sprite {
	static var instance:DownloadAlerts;
	static var instances:Array<DownloadAlert> = [];
	
	static var isMobile:Bool = false;
	static var scaleFactor:Float = 1.0;

	public function new() {
		super();
		
		instance = this;
		
		isMobile = Controls.instance.mobileControls;
		scaleFactor = isMobile ? 2.5 : 1.0;
	}

	override function __enterFrame(delta) {
		super.__enterFrame(delta);

		if (FlxG.keys.pressed.ALT) {
			if (FlxG.keys.justPressed.ONE && ModDownloader.downloaders[0] != null)
				ModDownloader.downloaders[0].client.cancel();
			if (FlxG.keys.justPressed.TWO && ModDownloader.downloaders[1] != null)
				ModDownloader.downloaders[1].client.cancel();
			if (FlxG.keys.justPressed.THREE && ModDownloader.downloaders[2] != null)
				ModDownloader.downloaders[2].client.cancel();
			if (FlxG.keys.justPressed.FOUR && ModDownloader.downloaders[3] != null)
				ModDownloader.downloaders[3].client.cancel();
			if (FlxG.keys.justPressed.FIVE && ModDownloader.downloaders[4] != null)
				ModDownloader.downloaders[4].client.cancel();
			if (FlxG.keys.justPressed.SIX && ModDownloader.downloaders[5] != null)
				ModDownloader.downloaders[5].client.cancel();
			if (FlxG.keys.justPressed.SEVEN && ModDownloader.downloaders[6] != null)
				ModDownloader.downloaders[6].client.cancel();
			if (FlxG.keys.justPressed.EIGHT && ModDownloader.downloaders[7] != null)
				ModDownloader.downloaders[7].client.cancel();
			if (FlxG.keys.justPressed.NINE && ModDownloader.downloaders[8] != null)
				ModDownloader.downloaders[8].client.cancel();
		}

		var prevAlert:DownloadAlert = null;
		var i = 1;
		for (alert in instances) {
			var downloader = ModDownloader.downloaders[i - 1];

			if (downloader != null) {
				if (downloader.client.cancelRequested) {
					alert.cancelText.text = 'İptal Ediliyor...';
				}
				else {
					alert.cancelText.text = 'İptal Et: İptal + $i ';
					if (i >= 10) {
						alert.cancelText.text = "";
					}
				}

				switch (downloader.status) {
					case CONNECTING:
						alert.setStatus("Bağlanılıyor...");
					case READING_HEADERS:
						alert.setStatus("Başlıklar Okunuyor...");
					case READING_BODY:
						alert.updateProgress(downloader.client.receivedBytes, downloader.client.contentLength);
					case FAILED(exc):
						alert.setStatus("Başarısız! " + exc);
					case DOWNLOADED:
						alert.setStatus("Kurulum hazırlanıyor...");
					case INSTALLING:
						alert.setStatus("Kuruluyor...");
					case FINISHED:
						alert.setStatus("Bitti!");
					default:
						alert.setStatus("Başlatılıyor...");
				}
			}
			else {
				alert.setStatus("...");
			}

			var spacing = isMobile ? 25 : 10;
			
			if (prevAlert?.bg != null)
				alert.bg.y = prevAlert.bg.y + prevAlert.bg.height + spacing;
			else
				alert.bg.y = isMobile ? 30 : 0;
				
			alert.bg.x = Lib.application.window.width - alert.bg.width - (isMobile ? 20 : 0);
			alert.text.x = alert.bg.x + (isMobile ? 25 : 10);
			alert.text.y = alert.bg.y + (isMobile ? 10 : 0);

			alert.bar.y = alert.bg.y + alert.bg.height - (isMobile ? 30 : 15);
			alert.bar.x = alert.bg.x + (isMobile ? 25 : 10);

			alert.cancelText.width = alert.cancelText.textWidth;

			alert.cancelBg.x = alert.bg.x - alert.cancelText.textWidth - (isMobile ? 20 : 5);
			alert.cancelBg.y = alert.bg.y;
			alert.cancelText.x = alert.cancelBg.x + (isMobile ? 10 : 0);
			alert.cancelText.y = alert.cancelBg.y + (isMobile ? 10 : 0);

			alert.cancelBg.scaleX = alert.cancelText.textWidth + (isMobile ? 20 : 0);
			alert.cancelBg.scaleY = alert.cancelText.textHeight + (isMobile ? 25 : 5);

			if (Controls.instance.mobileControls && alert.cancelBg.getBounds(FlxG.stage).contains(FlxG.stage.mouseX, FlxG.stage.mouseY) && FlxG.mouse.justPressed)
				downloader.client.cancel();

			prevAlert = alert;
			i++;
		}
	}
}

class DownloadAlert extends Sprite {
	public var bg:Bitmap;
	public var bar:Bitmap;
	public var text:TextField;
	var id:String;

	public var cancelBg:Bitmap;
	public var cancelText:TextField;
	
	var isMobile:Bool = false;

    public function new(id:String) {
        super();

		this.id = id;
		isMobile = Controls.instance.mobileControls;

		DownloadAlerts.instances.push(this);
		DownloadAlerts.instance.addChild(this);

		var bgWidth = isMobile ? 900 : 600;
		var bgHeight = isMobile ? 110 : 40;
		
		bg = new Bitmap(new BitmapData(bgWidth, bgHeight, true, 0xFF000000));
		bg.alpha = 0.6;
        addChild(bg);

		var barHeight = isMobile ? 12 : 5;
		bar = new Bitmap(new BitmapData(1, barHeight, true, 0xFFFFFFFF));
		addChild(bar);

		text = new TextField();
		text.text = 'İndirme bekleniyor: $id';
		text.selectable = false;
		
		var fontSize = isMobile ? 36 : 15;
		text.defaultTextFormat = new TextFormat(Assets.getFont('assets/fonts/vcr.ttf').fontName, fontSize, 0xFFFFFFFF);
		addChild(text);

		var textPadding = isMobile ? 25 : 10;
		text.y = isMobile ? 15 : 5;
		text.wordWrap = false;
		text.width = bg.width - textPadding * 2;

		bar.y = bg.y + bg.height - (isMobile ? 30 : 15);
		text.x = textPadding;
		bar.x = textPadding;

		bar.visible = false;

		cancelBg = new Bitmap(new BitmapData(1, 1, true, 0xFF000000));
		cancelBg.alpha = 0.5;
		addChild(cancelBg);

		cancelText = new TextField();
		cancelText.text = 'İptal: İptal + ' + ModDownloader.downloaders.length;
		cancelText.selectable = false;
		
		var cancelFontSize = isMobile ? 30 : 13;
		cancelText.defaultTextFormat = new TextFormat(Assets.getFont('assets/fonts/vcr.ttf').fontName, cancelFontSize, 0xFFFFFFFF);
		addChild(cancelText);

		setStatus('İndirme Başlatılıyor...');
    }

    public function updateProgress(loaded:Float, total:Float) {
		if (text == null)
			return;

		var idCut = id.substr(id.length - 30);
		if (id.length > 30) {
			idCut = "..." + idCut;
		}

		if (total < 0 || loaded > total) {
			bar.visible = false;
			bar.scaleX = 1;
			total = 1;
			text.text = 'İndiriliyor $idCut: ${prettyBytes(loaded)} of ?MB';
			return;
		}
		
		bar.visible = true;
		text.text = 'İndiriliyor $idCut: ${prettyBytes(loaded)} of ${prettyBytes(total)}';

		var barWidth = isMobile ? (bg.width - 50) : (bg.width - 20);
		bar.scaleX = barWidth * (loaded / total);
    }

	public function setStatus(string:String) {
		if (text == null || string == text.text)
			return;

		bar.visible = false;
		text.text = string;
	}

	public static function prettyBytes(bytes:Float):String {
		if (bytes > 1000000000) {
			return FlxMath.roundDecimal(bytes / 1000000000, 2) + "GB";
		}
		return FlxMath.roundDecimal(bytes / 1000000, 1) + "MB";
	}

	public function destroy() {
		DownloadAlerts.instances.remove(this);
		Waiter.putPersist(() -> {
			bg = null;
			text = null;
			DownloadAlerts.instance.removeChild(this);
		});
	}
}
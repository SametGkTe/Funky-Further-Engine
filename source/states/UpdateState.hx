package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;
import backend.update.UpdateChecker;
import backend.modpack.ModpackPaths;
import backend.modpack.ModpackInstaller;
import backend.modpack.ModpackTypes;
import backend.modpack.DownloadManager;

enum UpdatePhase {
	Starting;
	Downloading;
	Installing;
	Done;
	Failed;
	Cancelled;
}

class UpdateState extends MusicBeatState {
	// ─── Veri ───
	var modpackQueue:Array<Dynamic> = [];
	var currentIndex:Int = 0;
	var currentPack:Dynamic = null;

	// ─── Sistemler ───
	var downloader:DownloadManager;
	var installer:ModpackInstaller;

	// ─── Durum ───
	var phase:UpdatePhase = Starting;
	var currentProgress:Float = 0.0;
	var targetProgress:Float = 0.0;
	var downloadedMB:Float = 0.0;
	var totalMB:Float = 0.0;
	var downloadSpeed:Float = 0.0;
	var cancelConfirm:Bool = false;

	// ─── UI ───
	var bg:FlxSprite;

	var phaseText:FlxText;
	var packNameText:FlxText;
	var detailText:FlxText;

	// Alt progress bar
	var barBg:FlxSprite;
	var barFill:FlxSprite;
	var barBorder:FlxSprite;
	var sizeText:FlxText;
	var speedText:FlxText;
	var percentText:FlxText;

	var queueText:FlxText;

	var cancelOverlay:FlxSprite;
	var cancelText:FlxText;

	// Sabitler
	static inline final BAR_HEIGHT:Int = 8;
	static inline final BAR_MARGIN:Int = 60;
	static inline final BAR_Y_OFFSET:Int = 80;
	static inline final ACCENT:Int = 0xFF14B8A6; // teal
	static inline final ACCENT_DIM:Int = 0xFF0D7377;
	static inline final ERROR_COLOR:Int = 0xFFEF4444;
	static inline final SUCCESS_COLOR:Int = 0xFF22C55E;

	// ─────────────────────────────────────────────
	//  Constructor
	// ─────────────────────────────────────────────

	public function new(updates:Array<Dynamic>) {
		super();
		modpackQueue = updates != null ? updates : [];
	}

	// ─────────────────────────────────────────────
	//  Create
	// ─────────────────────────────────────────────

	override function create() {
		super.create();

		downloader = new DownloadManager();
		installer = new ModpackInstaller();

		// ── Siyah arkaplan ──
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
		add(bg);

		queueText = new FlxText(0, 20, FlxG.width, "", 13);
		queueText.setFormat("VCR OSD Mono", 13, 0xFF555555, CENTER);
		add(queueText);

		phaseText = new FlxText(0, 0, FlxG.width, "Hazırlanıyor...", 36);
		phaseText.setFormat("VCR OSD Mono", 36, FlxColor.WHITE, CENTER);
		phaseText.screenCenter();
		phaseText.y -= 40;
		add(phaseText);

		packNameText = new FlxText(0, 0, FlxG.width, "", 16);
		packNameText.setFormat("VCR OSD Mono", 16, 0xFF888888, CENTER);
		packNameText.screenCenter();
		packNameText.y += 10;
		add(packNameText);

		// ── Orta: detay yazısı (hata mesajı vs) ──
		detailText = new FlxText(60, 0, FlxG.width - 120, "", 14);
		detailText.setFormat("VCR OSD Mono", 14, 0xFF666666, CENTER);
		detailText.screenCenter();
		detailText.y += 45;
		detailText.visible = false;
		add(detailText);

		// ── Alt: progress bar ──
		var barWidth:Int = FlxG.width - (BAR_MARGIN * 2);
		var barY:Int = FlxG.height - BAR_Y_OFFSET;

		// Border
		barBorder = new FlxSprite(BAR_MARGIN - 1, barY - 1).makeGraphic(barWidth + 2, BAR_HEIGHT + 2, 0xFF333333);
		add(barBorder);

		// Arkaplan
		barBg = new FlxSprite(BAR_MARGIN, barY).makeGraphic(barWidth, BAR_HEIGHT, 0xFF1A1A1A);
		add(barBg);

		// Dolgu
		barFill = new FlxSprite(BAR_MARGIN, barY).makeGraphic(1, BAR_HEIGHT, ACCENT);
		add(barFill);

		percentText = new FlxText(0, barY - 22, FlxG.width, "0%", 14);
		percentText.setFormat("VCR OSD Mono", 14, FlxColor.WHITE, CENTER);
		add(percentText);

		sizeText = new FlxText(0, barY + BAR_HEIGHT + 6, FlxG.width - BAR_MARGIN, "", 12);
		sizeText.setFormat("VCR OSD Mono", 12, 0xFF555555, RIGHT);
		add(sizeText);

		// Hız (barın solunda)
		speedText = new FlxText(BAR_MARGIN, barY + BAR_HEIGHT + 6, FlxG.width / 2, "", 12);
		speedText.setFormat("VCR OSD Mono", 12, 0xFF555555, LEFT);
		add(speedText);

		cancelOverlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xCC000000);
		cancelOverlay.visible = false;
		add(cancelOverlay);

		cancelText = new FlxText(0, 0, FlxG.width, "İptal etmek istediğinize emin misiniz?\n\n[ENTER] Evet    [ESC] Hayır", 20);
		cancelText.setFormat("VCR OSD Mono", 20, FlxColor.WHITE, CENTER);
		cancelText.screenCenter();
		cancelText.visible = false;
		add(cancelText);
		addTouchPad('LEFT_FULL', 'A_B');

		FlxG.camera.fade(FlxColor.BLACK, 0.3, true);

		if (modpackQueue.length == 0) {
			setPhase(Done, "Güncelleme bulunamadı.");
		} else {
			startNextInQueue();
		}
	}

	// ─────────────────────────────────────────────
	//  Update
	// ─────────────────────────────────────────────

	override function update(elapsed:Float) {
		super.update(elapsed);

		// ── Progress bar animasyonu ──
		currentProgress += (targetProgress - currentProgress) * elapsed * 8;
		if (Math.abs(currentProgress - targetProgress) < 0.001)
			currentProgress = targetProgress;

		updateBarVisual();

		if (cancelConfirm) {
			if (controls.ACCEPT) {
				cancelConfirm = false;
				cancelOverlay.visible = false;
				cancelText.visible = false;
				doCancel();
			} else if (controls.BACK) {
				cancelConfirm = false;
				cancelOverlay.visible = false;
				cancelText.visible = false;
			}
			return;
		}

		switch (phase) {
			case Starting:
				// bekle
			case Downloading | Installing:
				if (controls.BACK) {
					showCancelConfirm();
				}
			case Done:
			case Failed:
				if (controls.ACCEPT) {
					// Tekrar dene
					resetUI();
					startNextInQueue();
				}
				if (controls.BACK) {
					goToMainMenu();
				}
			case Cancelled:
				if (controls.ACCEPT || controls.BACK) {
					goToMainMenu();
				}
		}
	}

	// ─────────────────────────────────────────────
	//  Bar Güncelleme
	// ─────────────────────────────────────────────

	function updateBarVisual():Void {
		var barWidth:Int = FlxG.width - (BAR_MARGIN * 2);
		var fillWidth:Int = Std.int(Math.max(1, barWidth * currentProgress));
		barFill.makeGraphic(fillWidth, BAR_HEIGHT, phase == Installing ? 0xFF3B82F6 : ACCENT);
		percentText.text = '${Math.round(currentProgress * 100)}%';
	}

	// ─────────────────────────────────────────────
	//  Kuyruk Yönetimi
	// ─────────────────────────────────────────────

	function startNextInQueue():Void {
		// External modpackleri atla
		while (currentIndex < modpackQueue.length) {
			var mp:Dynamic = modpackQueue[currentIndex];
			var mode:String = mp.downloadMode != null ? mp.downloadMode : "direct";

			if (mode == "direct") break;

			trace('[UpdateState] External modpack atlandı: ${mp.id}');
			currentIndex++;
		}

		if (currentIndex >= modpackQueue.length) {
			allComplete();
			return;
		}

		currentPack = modpackQueue[currentIndex];

		var name:String = currentPack.displayName != null ? currentPack.displayName : currentPack.id;
		var ver:String = currentPack.versionLabel != null ? currentPack.versionLabel : currentPack.version;

		packNameText.text = '$name  •  $ver';

		if (modpackQueue.length > 1)
			queueText.text = '${currentIndex + 1} / ${modpackQueue.length}';
		else
			queueText.text = "";

		startDownload();
	}

	// ─────────────────────────────────────────────
	//  İndirme
	// ─────────────────────────────────────────────

	function startDownload():Void {
		var directUrl:String = currentPack.directDownloadUrl != null ? currentPack.directDownloadUrl : "";

		if (directUrl.length == 0) {
			setPhase(Failed, "İndirme linki bulunamadı.");
			return;
		}

		var packId:String = currentPack.id != null ? currentPack.id : "unknown";
		var version:String = currentPack.version != null ? currentPack.version : "0";
		var fileName = '$packId-v$version.zip';
		var savePath = ModpackPaths.getDownloadDirectory() + fileName;

		setPhase(Downloading);
		targetProgress = 0;
		currentProgress = 0;
		downloadedMB = 0;
		totalMB = 0;
		downloadSpeed = 0;

		downloader.download(directUrl, savePath, {
			onProgress: function(progress:DownloadProgress) {
				targetProgress = progress.percent;
				downloadedMB = progress.downloadedBytes / (1024 * 1024);
				totalMB = progress.totalBytes > 0 ? progress.totalBytes / (1024 * 1024) : 0;
				downloadSpeed = progress.speed;

				if (totalMB > 0)
					sizeText.text = '${formatMB(downloadedMB)} / ${formatMB(totalMB)} MB';
				else
					sizeText.text = '${formatMB(downloadedMB)} MB';

				if (downloadSpeed > 0) {
					if (downloadSpeed > 1024 * 1024)
						speedText.text = '${formatMB(downloadSpeed / (1024 * 1024))} MB/s';
					else
						speedText.text = '${Math.round(downloadSpeed / 1024)} KB/s';
				}
			},
			onComplete: function(path:String) {
				trace('[UpdateState] İndirme tamamlandı: $path');
				speedText.text = "";
				sizeText.text = "";
				startInstall(path);
			},
			onError: function(error:String) {
				setPhase(Failed, 'İndirme hatası:\n$error');
			},
			onCancelled: function() {
				setPhase(Cancelled);
			}
		});
	}

	// ─────────────────────────────────────────────
	//  Kurulum
	// ─────────────────────────────────────────────

	function startInstall(zipPath:String):Void {
		var packId:String = currentPack.id != null ? currentPack.id : "unknown";
		var name:String = currentPack.displayName != null ? currentPack.displayName : packId;

		setPhase(Installing);
		targetProgress = 0;
		currentProgress = 0;

		installer.install(zipPath, packId, {
			onProgress: function(progress:ModpackInstallProgress) {
				targetProgress = progress.overallProgress;

				if (progress.currentFile.length > 0)
					sizeText.text = progress.currentFile;
				else
					sizeText.text = progress.message;
			},
			onComplete: function(manifest:ModpackManifest) {
				#if sys
				try {
					if (sys.FileSystem.exists(zipPath))
						sys.FileSystem.deleteFile(zipPath);
				} catch (_) {}
				#end

				trace('[UpdateState] Kurulum tamamlandı: ${manifest.displayName} v${manifest.version}');

				currentIndex++;
				if (currentIndex < modpackQueue.length) {
					new FlxTimer().start(0.5, function(_) {
						resetUI();
						startNextInQueue();
					});
				} else {
					allComplete();
				}
			},
			onError: function(error:String) {
				setPhase(Failed, 'Kurulum hatası:\n$error');
			},
			onWarning: function(warning:String) {
				trace('[UpdateState] Uyarı: $warning');
			},
			onCancelled: function() {
				setPhase(Cancelled);
			}
		});
	}

	// ─────────────────────────────────────────────
	//  Tamamlandı
	// ─────────────────────────────────────────────

	function allComplete():Void {
		setPhase(Done);
		FlxG.sound.play(Paths.sound('confirmMenu'));

		phaseText.text = "Tamamlandı!";
		phaseText.color = SUCCESS_COLOR;

		var totalInstalled:Int = modpackQueue.length;
		if (totalInstalled > 1)
			packNameText.text = '$totalInstalled modpack başarıyla kuruldu';
		else if (currentPack != null) {
			var name:String = currentPack.displayName != null ? currentPack.displayName : "Modpack";
			packNameText.text = '$name başarıyla kuruldu';
		}

		sizeText.text = "";
		speedText.text = "";
		percentText.text = "100%";
		targetProgress = 1.0;
		currentProgress = 1.0;
		updateBarVisual();

		var barWidth:Int = FlxG.width - (BAR_MARGIN * 2);
		barFill.makeGraphic(barWidth, BAR_HEIGHT, SUCCESS_COLOR);

		// 2.5 saniye sonra otomatik ana menüye dön
		new FlxTimer().start(2.5, function(_) {
			goToMainMenu();
		});
	}

	// ─────────────────────────────────────────────
	//  Faz Yönetimi
	// ─────────────────────────────────────────────

	function setPhase(newPhase:UpdatePhase, ?errorMsg:String):Void {
		phase = newPhase;

		FlxTween.cancelTweensOf(phaseText);
		phaseText.alpha = 0;
		FlxTween.tween(phaseText, {alpha: 1}, 0.3);

		switch (newPhase) {
			case Starting:
				phaseText.text = "Hazırlanıyor...";
				phaseText.color = FlxColor.WHITE;
				detailText.visible = false;

			case Downloading:
				phaseText.text = "İndiriliyor...";
				phaseText.color = FlxColor.WHITE;
				detailText.visible = false;

			case Installing:
				phaseText.text = "Kuruluyor...";
				phaseText.color = FlxColor.WHITE;
				detailText.visible = false;
				sizeText.text = "";
				speedText.text = "";

			case Done:
				// allComplete() içinde özel işlem yapılıyor
				detailText.visible = false;

			case Failed:
				phaseText.text = "Hata!";
				phaseText.color = ERROR_COLOR;
				targetProgress = 0;

				if (errorMsg != null) {
					detailText.text = errorMsg;
					detailText.visible = true;
					detailText.screenCenter();
					detailText.y = phaseText.y + 60;
				}

				// Alt bilgi
				sizeText.text = "";
				speedText.text = "[ENTER] Tekrar Dene  |  [ESC] Çık";
				speedText.alignment = CENTER;
				speedText.x = 0;
				speedText.fieldWidth = FlxG.width;

				var barWidth:Int = FlxG.width - (BAR_MARGIN * 2);
				barFill.makeGraphic(Std.int(Math.max(1, barWidth * 0.15)), BAR_HEIGHT, ERROR_COLOR);

			case Cancelled:
				phaseText.text = "İptal Edildi";
				phaseText.color = 0xFFFFAA00;
				detailText.visible = false;
				sizeText.text = "";
				speedText.text = "[ENTER/ESC] Ana Menü";
				speedText.alignment = CENTER;
				speedText.x = 0;
				speedText.fieldWidth = FlxG.width;
				targetProgress = 0;
		}
	}

	// ─────────────────────────────────────────────
	//  İptal
	// ─────────────────────────────────────────────

	function showCancelConfirm():Void {
		cancelConfirm = true;
		cancelOverlay.visible = true;
		cancelText.visible = true;
	}

	function doCancel():Void {
		downloader.cancel();
		installer.cancel();
		setPhase(Cancelled);
	}

	// ─────────────────────────────────────────────
	//  UI Reset
	// ─────────────────────────────────────────────

	function resetUI():Void {
		targetProgress = 0;
		currentProgress = 0;
		downloadedMB = 0;
		totalMB = 0;
		downloadSpeed = 0;
		sizeText.text = "";
		speedText.text = "";
		speedText.alignment = LEFT;
		speedText.x = BAR_MARGIN;
		speedText.fieldWidth = FlxG.width / 2;
		percentText.text = "0%";
		detailText.visible = false;
		phaseText.color = FlxColor.WHITE;
	}

	// ─────────────────────────────────────────────
	//  Geçiş
	// ─────────────────────────────────────────────

	function goToMainMenu():Void {
		FlxG.camera.fade(FlxColor.BLACK, 0.4, false, function() {
			MusicBeatState.switchState(new MainMenuState());
		});
	}

	// ─────────────────────────────────────────────
	//  Yardımcılar
	// ─────────────────────────────────────────────

	function formatMB(mb:Float):String {
		if (mb >= 100)
			return '${Math.round(mb)}';
		else if (mb >= 10)
			return '${FlxMath.roundDecimal(mb, 1)}';
		else
			return '${FlxMath.roundDecimal(mb, 2)}';
	}
}
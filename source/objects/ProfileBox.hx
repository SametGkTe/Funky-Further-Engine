package objects;

import backend.AuthManager;
import backend.SupabaseClient;
import backend.Paths;
import backend.ClientPrefs;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.text.FlxText;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;
import substates.LinkSubState;
import Lambda;
import states.MainMenuState;
import openfl.geom.Matrix;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ProfileBox extends FlxSpriteGroup {
	static inline final COL_BG = 0xEE0D0D1A;
	static inline final COL_ACCENT = 0xFFA855F7;
	static inline final COL_GREEN = 0xFF22c55e;
	static inline final COL_MUTED = 0xFF6b6b88;
	static inline final COL_GOLD = 0xFFFBBF24;
	static inline final COL_CYAN = 0xFF22D3EE;
	static inline final COL_PINK = 0xFFF472B6;
	static inline final COL_RED = 0xFFef4444;
	static inline final COL_BORDER = 0xFF1e1e34;
	static inline final COL_TEXT = 0xFFE2E2F0;
	static inline final COL_TEXT_DIM = 0xFF8888A8;
	static inline final COL_AVATAR_BG = 0xFF1A1A32;

	var dropdownOpen:Bool = false;
	var dropdownBg:FlxSprite;
	var dropdownAccent:FlxSprite;
	var dropdownBorder:FlxSprite;
	public var noStateSwitch:Bool = false;

	var dropSettingsIcon:FlxSprite;
	var dropSettingsBg:FlxSprite;
	var dropSettingsText:FlxText;

	var dropLogoutIcon:FlxSprite;
	var dropLogoutBg:FlxSprite;
	var dropLogoutText:FlxText;

	var dropSeparator:FlxSprite;

	var _dropHoverIdx:Int = -1;

	static inline final DROP_W = 200;
	static inline final DROP_ITEM_H = 38;
	static inline final DROP_ICON_SIZE = 18;
	static inline final COL_DROP_BG = 0xF2141414;
	static inline final COL_DROP_HOVER = 0xFF222222;
	static inline final COL_DROP_BORDER = 0xFF2a2a2a;
	static inline final COL_DROP_SEP = 0xFF2a2a2a;
	static inline final COL_LOGOUT = 0xFFef4444;
	static inline final COL_SETTINGS = 0xFF888888;

	static inline final BOX_W = 330;
	static inline final BOX_H = 108;
	static inline final BOX_H_GUEST = 64;
	static inline final AVATAR_SIZE = 56;
	static inline final ACCENT_W = 3;
	static inline final UNPLUG_SIZE = 20;

	static inline final CACHE_FILE = "fe_profile_cache.json";

	var bg:FlxSprite;
	var accentBar:FlxSprite;
	var accentTop:FlxSprite;
	var borderBottom:FlxSprite;

	var avatarBorder:FlxSprite;
	var avatarBg:FlxSprite;
	var avatarSprite:FlxSprite;
	var avatarLetter:FlxText;
	var avatarLoadingCircle:FlxSprite;
	var statusDot:FlxSprite;
	var statusRing:FlxSprite;

	var usernameText:FlxText;
	var levelText:FlxText;
	var upText:FlxText;
	var achievementLabel:FlxText;

	var guestText:FlxText;
	var guestSubText:FlxText;
	var guestArrow:FlxText;

	var unplugIcon:FlxSprite;
	var unplugLabel:FlxText;
	var _lastServerConn:Bool = true;

	var _pulseTime:Float = 0;
	var _built:Bool = false;
	var _isGuest:Bool = true;
	var _isHovered:Bool = false;
	var _clickCooldown:Float = 0;

	var _avatarDownloading:Bool = false;
	var _avatarDownloadDone:Bool = false;
	var _avatarDownloadFailed:Bool = false;
	var _avatarBytes:haxe.io.Bytes = null;
	var _avatarApplied:Bool = false;
	var _lastAvatarUrl:String = null;
	var _circleAngle:Float = 0;
	
	static var _cachedAvatarBytes:haxe.io.Bytes = null;
	static var _cachedAvatarUrl:String = null;

	public static var instance:ProfileBox = null;

	public function new(?xPos:Float = 0, ?yPos:Float = 0) {
		super(xPos, yPos);
		instance = this;
		_lastServerConn = ClientPrefs.data.serverConnection;

		if (AuthManager.isLoggedIn)
			buildLoggedIn();
		else
			buildGuest();
	}

	function buildGuest():Void {
		_isGuest = true;
		_built = true;

		bg = makeRect(0, 0, BOX_W, BOX_H_GUEST, COL_BG);
		bg.alpha = 0.95;
		add(bg);

		accentBar = makeRect(0, 0, ACCENT_W, BOX_H_GUEST, COL_RED);
		add(accentBar);

		accentTop = makeRect(ACCENT_W, 0, BOX_W - ACCENT_W, 1, COL_RED);
		accentTop.alpha = 0.3;
		add(accentTop);

		borderBottom = makeRect(0, BOX_H_GUEST - 1, BOX_W, 1, COL_BORDER);
		add(borderBottom);

		statusDot = makeRect(ACCENT_W + 14, BOX_H_GUEST / 2 - 5, 10, 10, COL_RED);
		add(statusDot);

		guestText = new FlxText(ACCENT_W + 32, 12, BOX_W - 80, Language.getPhrase('profile_not_logged_in', 'Giriş Yapılmadı'));
		guestText.setFormat(Paths.font("Avgardd.ttf"), 16, COL_TEXT, LEFT);
		guestText.scrollFactor.set(0, 0);
		add(guestText);

		guestSubText = new FlxText(ACCENT_W + 32, 34, BOX_W - 80, Language.getPhrase('profile_login_prompt', 'Hesabına giriş yap'));
		guestSubText.setFormat(Paths.font("Avgardd.ttf"), 11, COL_TEXT_DIM, LEFT);
		guestSubText.scrollFactor.set(0, 0);
		add(guestSubText);

		guestArrow = new FlxText(BOX_W - 28, BOX_H_GUEST / 2 - 10, 20, ">");
		guestArrow.setFormat(Paths.font("vcr.ttf"), 22, COL_RED, CENTER);
		guestArrow.scrollFactor.set(0, 0);
		add(guestArrow);

		animateEntry();
	}

	function buildLoggedIn():Void {
		_isGuest = false;
		_built = true;

		var username = AuthManager.currentUsername ?? Language.getPhrase('profile_default_player', 'Oyuncu');
		var level = AuthManager.currentLevel ?? 1;
		var up = AuthManager.currentUltraPoints ?? 0.0;
		var rankColor = getRankColorFromUP(up);
		var serverOn = ClientPrefs.data.serverConnection;

		bg = makeRect(0, 0, BOX_W, BOX_H, COL_BG);
		bg.alpha = 0.95;
		add(bg);

		accentBar = makeRect(0, 0, ACCENT_W, BOX_H, rankColor);
		add(accentBar);

		accentTop = makeRect(ACCENT_W, 0, BOX_W - ACCENT_W, 1, rankColor);
		accentTop.alpha = 0.25;
		add(accentTop);

		borderBottom = makeRect(0, BOX_H - 1, BOX_W, 1, COL_BORDER);
		add(borderBottom);

		var avX:Float = ACCENT_W + 12;
		var avY:Float = (BOX_H - AVATAR_SIZE) / 2 - 2;

		avatarBorder = makeRect(avX - 2, avY - 2, AVATAR_SIZE + 4, AVATAR_SIZE + 4, rankColor);
		avatarBorder.alpha = 0.5;
		add(avatarBorder);

		avatarBg = makeRect(avX, avY, AVATAR_SIZE, AVATAR_SIZE, COL_AVATAR_BG);
		add(avatarBg);

		avatarSprite = new FlxSprite(avX, avY);
		avatarSprite.scrollFactor.set(0, 0);
		avatarSprite.antialiasing = ClientPrefs.data.antialiasing;
		avatarSprite.visible = false;
		add(avatarSprite);

		avatarLetter = new FlxText(avX, avY + 10, AVATAR_SIZE, username.charAt(0).toUpperCase());
		avatarLetter.setFormat(Paths.font("vcr.ttf"), 26, rankColor, CENTER);
		avatarLetter.scrollFactor.set(0, 0);
		avatarLetter.visible = true;
		add(avatarLetter);

		avatarLoadingCircle = null;

		statusRing = null;
		statusDot = makeRect(avX + AVATAR_SIZE - 10, avY + AVATAR_SIZE - 10, 8, 8, serverOn ? COL_GREEN : COL_RED);
		add(statusDot);

		var textX:Float = avX + AVATAR_SIZE + 14;
		var textW:Int = Std.int(BOX_W - textX - 14);

		usernameText = new FlxText(textX, 14, textW, username + '  ·  '
			+ Language.getPhrase('profile_level_prefix', 'Sv') + '.$level');
		usernameText.setFormat(Paths.font("Avgardd.ttf"), 18, COL_TEXT, LEFT);
		usernameText.scrollFactor.set(0, 0);
		add(usernameText);

		levelText = new FlxText(textX, 14, textW, "");
		levelText.setFormat(Paths.font("Avgardd.ttf"), 18, rankColor, LEFT);
		levelText.scrollFactor.set(0, 0);
		levelText.visible = false;
		add(levelText);

		upText = new FlxText(textX, 40, textW, '${formatNumber(up)} UP');
		upText.setFormat(Paths.font("vcr.ttf"), 11, COL_TEXT_DIM, LEFT);
		upText.scrollFactor.set(0, 0);
		add(upText);

		var badge = AuthManager.currentBadge;
		if (badge != null && badge.length > 0)
			upText.text = '${formatNumber(up)} UP  ·  $badge';

		#if ACHIEVEMENTS_ALLOWED
		var achUnlocked = Achievements.achievementsUnlocked.length;
		var achTotal = Lambda.count(Achievements.achievements);

		achievementLabel = new FlxText(textX, 58, textW, Language.getPhrase('profile_achievements', 'Başarımlar') + ': $achUnlocked/$achTotal');
		achievementLabel.setFormat(Paths.font("vcr.ttf"), 11, COL_GOLD, LEFT);
		achievementLabel.scrollFactor.set(0, 0);
		add(achievementLabel);
		#end

		buildUnplugIndicator(serverOn);
		startAvatarLoad();
		animateEntry();
		saveCache();
	}

	function startAvatarLoad():Void {
		_avatarApplied = false;
		_avatarDownloading = false;
		_avatarDownloadDone = false;
		_avatarDownloadFailed = false;
		_avatarBytes = null;

		var avatarFile = AuthManager.currentAvatarUrl;
		_lastAvatarUrl = avatarFile;

		showPlayerPngWithLoading();

		if (avatarFile != null && avatarFile.length > 0) {
			if (_cachedAvatarBytes != null && _cachedAvatarUrl == avatarFile) {
				trace('[ProfileBox] Avatar loaded from RAM cache (instant)');
				hideLoadingCircle();
				applyAvatarFromBytes(_cachedAvatarBytes);
				return;
			}

			if (ClientPrefs.data.serverConnection) {
				var fullUrl = AuthManager.getFullAvatarUrl(true);
				trace('[ProfileBox] Full avatar URL: ' + fullUrl);
				if (fullUrl != null && fullUrl.length > 0) {
					trace('[ProfileBox] Downloading avatar (fresh)...');
					downloadAvatar(fullUrl);
					return;
				}
			}
		}

		trace('[ProfileBox] No avatar URL or server off, keeping player.png');
		hideLoadingCircle();
	}

	function showPlayerPngWithLoading():Void {
		var avX:Float = ACCENT_W + 12;
		var avY:Float = (BOX_H - AVATAR_SIZE) / 2 - 2;

		try {
			var graphic = Paths.image("mainmenu/player");
			if (graphic != null) {
				if (avatarSprite != null) {
					remove(avatarSprite, true);
					avatarSprite.destroy();
				}

				avatarSprite = new FlxSprite(avX, avY);
				avatarSprite.scrollFactor.set(0, 0);
				avatarSprite.antialiasing = ClientPrefs.data.antialiasing;
				avatarSprite.loadGraphic(graphic);

				var imgW:Float = avatarSprite.frameWidth;
				var imgH:Float = avatarSprite.frameHeight;
				if (imgW > 0 && imgH > 0) {
					var sc = Math.min(AVATAR_SIZE / imgW, AVATAR_SIZE / imgH);
					avatarSprite.scale.set(sc, sc);
					avatarSprite.updateHitbox();
					avatarSprite.x = avX + (AVATAR_SIZE - avatarSprite.width) / 2;
					avatarSprite.y = avY + (AVATAR_SIZE - avatarSprite.height) / 2;
				}

				avatarSprite.visible = true;
				avatarSprite.alpha = 0.5;

				var letterIdx = members.indexOf(avatarLetter);
				if (letterIdx >= 0)
					insert(letterIdx, avatarSprite);
				else
					add(avatarSprite);

				if (avatarLetter != null) avatarLetter.visible = false;
			}
		} catch (e:Dynamic) {
			trace('[ProfileBox] player.png load failed: ' + e);
		}

		try {
			if (avatarLoadingCircle != null) {
				remove(avatarLoadingCircle, true);
				avatarLoadingCircle.destroy();
				avatarLoadingCircle = null;
			}

			avatarLoadingCircle = new FlxSprite(avX, avY);
			avatarLoadingCircle.scrollFactor.set(0, 0);
			avatarLoadingCircle.antialiasing = ClientPrefs.data.antialiasing;
			avatarLoadingCircle.loadGraphic(Paths.image("other/circle"));

			var circW:Float = avatarLoadingCircle.frameWidth;
			var circH:Float = avatarLoadingCircle.frameHeight;
			if (circW > 0 && circH > 0) {
				var sc = (AVATAR_SIZE * 0.45) / Math.max(circW, circH);
				avatarLoadingCircle.scale.set(sc, sc);
				avatarLoadingCircle.updateHitbox();
			}

			avatarLoadingCircle.x = avX + (AVATAR_SIZE - avatarLoadingCircle.width) / 2;
			avatarLoadingCircle.y = avY + (AVATAR_SIZE - avatarLoadingCircle.height) / 2;
			avatarLoadingCircle.alpha = 0.8;
			avatarLoadingCircle.visible = true;
			_circleAngle = 0;

			add(avatarLoadingCircle);
		} catch (e:Dynamic) {
			trace('[ProfileBox] circle.png load failed: ' + e);
		}
	}

	function hideLoadingCircle():Void {
		if (avatarLoadingCircle != null) {
			FlxTween.tween(avatarLoadingCircle, {alpha: 0}, 0.3, {
				ease: FlxEase.sineOut,
				onComplete: function(_) {
					if (avatarLoadingCircle != null) {
						remove(avatarLoadingCircle, true);
						avatarLoadingCircle.destroy();
						avatarLoadingCircle = null;
					}
				}
			});
		}

		if (avatarSprite != null && avatarSprite.visible) {
			FlxTween.cancelTweensOf(avatarSprite);
			FlxTween.tween(avatarSprite, {alpha: 1}, 0.3, {ease: FlxEase.sineOut});
		}
	}

	function downloadAvatar(url:String):Void {
		if (_avatarDownloading) return;
		_avatarDownloading = true;

		#if sys
		#if ios
		try {
			var req = new lime.net.HTTPRequest<haxe.io.Bytes>();
			req.timeout = 15000;
			req.load(url).onComplete(function(data:haxe.io.Bytes) {
				if (data != null && data.length > 100) {
					trace('[ProfileBox] Avatar downloaded: ${data.length} bytes');
					_avatarBytes = data;
					_avatarDownloadDone = true;
					_avatarDownloading = false;
					_avatarDownloadFailed = false;

					_cachedAvatarBytes = data;
					_cachedAvatarUrl = AuthManager.currentAvatarUrl;
				} else {
					trace('[ProfileBox] Avatar download empty');
					_avatarDownloading = false;
					_avatarDownloadFailed = true;
				}
			}).onError(function(error:Dynamic) {
				trace('[ProfileBox] HTTP onError (ignorable): ' + error);
				_avatarDownloading = false;
				_avatarDownloadFailed = true;
			});
		} catch (e:Dynamic) {
			trace('[ProfileBox] Avatar download exception: ' + e);
			_avatarDownloading = false;
			_avatarDownloadFailed = true;
		}
		#else
		sys.thread.Thread.create(function() {
			try {
				var http = new haxe.Http(url);
				var bytesOutput = new haxe.io.BytesOutput();

				http.onError = function(error:String) {
					trace('[ProfileBox] HTTP onError (ignorable): ' + error);
				};

				http.customRequest(false, bytesOutput, null, "GET");

				var data = bytesOutput.getBytes();

				if (data != null && data.length > 100) {
					trace('[ProfileBox] Avatar downloaded: ${data.length} bytes');
					_avatarBytes = data;
					_avatarDownloadDone = true;
					_avatarDownloading = false;
					_avatarDownloadFailed = false;

					_cachedAvatarBytes = data;
					_cachedAvatarUrl = AuthManager.currentAvatarUrl;
				} else {
					trace('[ProfileBox] Avatar download empty');
					_avatarDownloading = false;
					_avatarDownloadFailed = true;
				}
			} catch (e:Dynamic) {
				trace('[ProfileBox] Avatar download exception: ' + e);
				_avatarDownloading = false;
				_avatarDownloadFailed = true;
			}
		});
		#end
		#else
		_avatarDownloading = false;
		_avatarDownloadFailed = true;
		hideLoadingCircle();
		#end
	}

	function applyAvatarFromBytes(bytes:haxe.io.Bytes):Void {
		if (bytes == null) return;

		try {
			var bitmapData = openfl.display.BitmapData.fromBytes(openfl.utils.ByteArray.fromBytes(bytes));

			if (bitmapData == null || bitmapData.width <= 0 || bitmapData.height <= 0) {
				trace('[ProfileBox] BitmapData decode failed');
				return;
			}

			var avX:Float = ACCENT_W + 12;
			var avY:Float = (BOX_H - AVATAR_SIZE) / 2 - 2;

			var srcW = bitmapData.width;
			var srcH = bitmapData.height;
			var cropSize = Std.int(Math.min(srcW, srcH));
			var cropX = Std.int((srcW - cropSize) / 2);
			var cropY = Std.int((srcH - cropSize) / 2);

			var finalBmp = new openfl.display.BitmapData(AVATAR_SIZE, AVATAR_SIZE, true, 0x00000000);
			var scaleRatio:Float = AVATAR_SIZE / cropSize;
			var matrix = new Matrix();
			matrix.translate(-cropX, -cropY);
			matrix.scale(scaleRatio, scaleRatio);
			finalBmp.draw(bitmapData, matrix);

			if (avatarSprite != null) {
				remove(avatarSprite, true);
				avatarSprite.destroy();
				avatarSprite = null;
			}

			avatarSprite = new FlxSprite(avX, avY);
			avatarSprite.scrollFactor.set(0, 0);
			avatarSprite.antialiasing = ClientPrefs.data.antialiasing;
			avatarSprite.pixels = finalBmp;
			avatarSprite.scale.set(1, 1);
			avatarSprite.updateHitbox();
			avatarSprite.x = avX;
			avatarSprite.y = avY;
			avatarSprite.visible = true;
			avatarSprite.alpha = 0;

			var letterIdx = members.indexOf(avatarLetter);
			if (letterIdx >= 0)
				insert(letterIdx, avatarSprite);
			else
				add(avatarSprite);

			if (avatarLetter != null) avatarLetter.visible = false;

			hideLoadingCircle();

			FlxTween.tween(avatarSprite, {alpha: 1}, 0.35, {ease: FlxEase.sineOut});

			_avatarApplied = true;
			trace('[ProfileBox] Avatar applied (${srcW}x${srcH} -> ${AVATAR_SIZE}x${AVATAR_SIZE})');
		} catch (e:Dynamic) {
			trace('[ProfileBox] Avatar apply error: $e');
		}
	}

	function showFallbackAvatar():Void {
		_avatarApplied = false;
		hideLoadingCircle();

		var avX:Float = ACCENT_W + 12;
		var avY:Float = (BOX_H - AVATAR_SIZE) / 2 - 2;

		try {
			var graphic = Paths.image("mainmenu/player");
			if (graphic != null) {
				if (avatarSprite != null) {
					remove(avatarSprite, true);
					avatarSprite.destroy();
				}

				avatarSprite = new FlxSprite(avX, avY);
				avatarSprite.scrollFactor.set(0, 0);
				avatarSprite.antialiasing = ClientPrefs.data.antialiasing;
				avatarSprite.loadGraphic(graphic);

				var imgW:Float = avatarSprite.frameWidth;
				var imgH:Float = avatarSprite.frameHeight;
				if (imgW > 0 && imgH > 0) {
					var sc = Math.min(AVATAR_SIZE / imgW, AVATAR_SIZE / imgH);
					avatarSprite.scale.set(sc, sc);
					avatarSprite.updateHitbox();
					avatarSprite.x = avX + (AVATAR_SIZE - avatarSprite.width) / 2;
					avatarSprite.y = avY + (AVATAR_SIZE - avatarSprite.height) / 2;
				}

				avatarSprite.visible = true;

				var letterIdx = members.indexOf(avatarLetter);
				if (letterIdx >= 0)
					insert(letterIdx, avatarSprite);
				else
					add(avatarSprite);

				if (avatarLetter != null) avatarLetter.visible = false;
				_avatarApplied = true;
				trace('[ProfileBox] Using player.png fallback');
				return;
			}
		} catch (e:Dynamic) {}

		if (avatarLetter != null) avatarLetter.visible = true;
		if (avatarSprite != null) avatarSprite.visible = false;
		trace('[ProfileBox] Using letter fallback');
	}

	function buildUnplugIndicator(serverOn:Bool):Void {
		destroyUnplugElements();
		if (serverOn) return;

		var textX:Float = ACCENT_W + 12;
		var indicatorY:Float = BOX_H - UNPLUG_SIZE - 6;

		unplugIcon = new FlxSprite(textX, indicatorY);
		unplugIcon.scrollFactor.set(0, 0);
		unplugIcon.antialiasing = ClientPrefs.data.antialiasing;

		try {
			unplugIcon.loadGraphic(Paths.image("other/unplug"));
			unplugIcon.setGraphicSize(UNPLUG_SIZE, UNPLUG_SIZE);
			unplugIcon.updateHitbox();
			unplugIcon.x = textX;
			unplugIcon.y = indicatorY;
		} catch (e:Dynamic) {
			unplugIcon.makeGraphic(UNPLUG_SIZE, UNPLUG_SIZE, COL_RED);
		}

		unplugIcon.alpha = 0.85;
		add(unplugIcon);

		var labelX:Float = textX + UNPLUG_SIZE + 6;
		var labelW:Int = Std.int(BOX_W - labelX - 10);

		unplugLabel = new FlxText(labelX, indicatorY + 2, labelW,
			Language.getPhrase('profile_server_off', 'Sunucu bağlantısı kapalı'));
		unplugLabel.setFormat(Paths.font("vcr.ttf"), 11, COL_RED, LEFT);
		unplugLabel.scrollFactor.set(0, 0);
		unplugLabel.alpha = 0.85;
		add(unplugLabel);
	}

	function destroyUnplugElements():Void {
		if (unplugIcon != null) {
			remove(unplugIcon, true);
			unplugIcon.destroy();
			unplugIcon = null;
		}
		if (unplugLabel != null) {
			remove(unplugLabel, true);
			unplugLabel.destroy();
			unplugLabel = null;
		}
	}

	function checkServerConnectionChanged():Void {
		if (_isGuest) return;
		var currentConn = ClientPrefs.data.serverConnection;
		if (currentConn != _lastServerConn) {
			_lastServerConn = currentConn;
			if (statusDot != null)
				statusDot.color = currentConn ? COL_GREEN : COL_RED;
			buildUnplugIndicator(currentConn);
		}
	}

	function makeRect(rx:Float, ry:Float, w:Dynamic, h:Dynamic, color:FlxColor):FlxSprite {
		var spr = new FlxSprite(rx, ry);
		spr.makeGraphic(Std.int(w), Std.int(h), color);
		spr.scrollFactor.set(0, 0);
		return spr;
	}

	function animateEntry():Void {
		alpha = 0;
		var startX = x;
		x += 30;
		FlxTween.tween(this, {alpha: 1, x: startX}, 0.45, {
			ease: FlxEase.backOut,
			startDelay: 0.1
		});
	}

	public function rebuild():Void {
		if (dropdownOpen) {
			dropdownOpen = false;
			destroyDropElements();
		}

		destroyUnplugElements();

		if (avatarLoadingCircle != null) {
			remove(avatarLoadingCircle, true);
			avatarLoadingCircle.destroy();
			avatarLoadingCircle = null;
		}

		while (members.length > 0) {
			var m = members[0];
			remove(m, true);
			if (m != null)
				m.destroy();
		}

		bg = null;
		accentBar = null;
		accentTop = null;
		borderBottom = null;
		avatarBorder = null;
		avatarBg = null;
		avatarSprite = null;
		avatarLetter = null;
		avatarLoadingCircle = null;
		statusDot = null;
		statusRing = null;
		usernameText = null;
		levelText = null;
		upText = null;
		achievementLabel = null;
		guestText = null;
		guestSubText = null;
		guestArrow = null;
		unplugIcon = null;
		unplugLabel = null;
		_built = false;
		_avatarDownloading = false;
		_avatarDownloadDone = false;
		_avatarDownloadFailed = false;
		_avatarBytes = null;
		_avatarApplied = false;
		_lastAvatarUrl = null;
		_circleAngle = 0;

		_lastServerConn = ClientPrefs.data.serverConnection;

		if (AuthManager.isLoggedIn)
			buildLoggedIn();
		else
			buildGuest();
	}

	override function update(elapsed:Float):Void {
		if (!_built)
			return;

		super.update(elapsed);
		_pulseTime += elapsed;

		if (_clickCooldown > 0)
			_clickCooldown -= elapsed;

		if (_isGuest && guestArrow != null)
			guestArrow.x = (BOX_W - 28) + x + Math.sin(_pulseTime * 3) * 3;

		checkServerConnectionChanged();

		if (_avatarDownloadDone && _avatarBytes != null) {
			_avatarDownloadDone = false;
			var bytes = _avatarBytes;
			_avatarBytes = null;
			applyAvatarFromBytes(bytes);
		}

		if (_avatarDownloadFailed && !_avatarDownloading) {
			_avatarDownloadFailed = false;
			hideLoadingCircle();
			trace('[ProfileBox] Download failed, keeping player.png');
		}

		if (avatarLoadingCircle != null && avatarLoadingCircle.visible) {
			_circleAngle += elapsed * 180;
			avatarLoadingCircle.angle = _circleAngle;
		}

		if (dropdownOpen)
			handleDropdownInput();

		var hovered = isMouseOver();
		if (hovered != _isHovered) {
			_isHovered = hovered;
			if (bg != null) {
				FlxTween.cancelTweensOf(bg);
				FlxTween.tween(bg, {alpha: hovered ? 1.0 : 0.95}, 0.15);
			}
			if (accentBar != null) {
				FlxTween.cancelTweensOf(accentBar.scale);
				FlxTween.tween(accentBar.scale, {x: hovered ? 2.0 : 1.0}, 0.2, {ease: FlxEase.sineOut});
			}
		}

		if (hovered && justPressed() && _clickCooldown <= 0)
			onClick();

		if (dropdownOpen && justPressed() && !hovered && !isDropdownHovered())
			closeDropdown();
	}

	function isMouseOver():Bool {
		var boxH = _isGuest ? BOX_H_GUEST : BOX_H;
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;

		if (mx >= x && mx <= x + BOX_W && my >= y && my <= y + boxH)
			return true;

		#if mobile
		for (touch in FlxG.touches.list) {
			if (touch.pressed && touch.screenX >= x && touch.screenX <= x + BOX_W
				&& touch.screenY >= y && touch.screenY <= y + boxH)
				return true;
		}
		#end
		return false;
	}

	function isAvatarClicked():Bool {
		if (_isGuest) return false;

		var avX:Float = x + ACCENT_W + 12;
		var avY:Float = y + (BOX_H - AVATAR_SIZE) / 2 - 2;
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;

		if (mx >= avX && mx <= avX + AVATAR_SIZE && my >= avY && my <= avY + AVATAR_SIZE)
			return true;

		#if mobile
		for (touch in FlxG.touches.list) {
			if (touch.justPressed && touch.screenX >= avX && touch.screenX <= avX + AVATAR_SIZE
				&& touch.screenY >= avY && touch.screenY <= avY + AVATAR_SIZE)
				return true;
		}
		#end
		return false;
	}

	function justPressed():Bool {
		if (FlxG.mouse.justPressed)
			return true;

		#if mobile
		for (touch in FlxG.touches.list) {
			if (touch.justPressed)
				return true;
		}
		#end
		return false;
	}

	function onClick():Void {
		_clickCooldown = 0.3;

		if (accentBar != null) {
			var origColor = accentBar.color;
			accentBar.color = FlxColor.WHITE;
			new FlxTimer().start(0.1, function(_) {
				if (accentBar != null)
					accentBar.color = origColor;
			});
		}

		if (_isGuest) {
			FlxG.sound.play(Paths.sound('confirmMenu'));
			MusicBeatState.switchState(new states.LoginState());
		} else if (isAvatarClicked()) {
			FlxG.sound.play(Paths.sound('confirmMenu'));
			if (dropdownOpen)
				closeDropdown();
			else
				openDropdown();
		} else {
			FlxG.sound.play(Paths.sound('confirmMenu'));
			if (dropdownOpen) closeDropdown();
			LinkSubState.requestURL("https://further-engine.github.io/", Language.getPhrase('profile_open_page', 'Profil sayfanızı açmak istiyor musunuz?'));
		}
	}

	function openDropdown():Void {
		if (dropdownOpen) return;
		if (FlxG.state == null) return;
		dropdownOpen = true;

		var dropX:Float = this.x;
		var dropY:Float = this.y + BOX_H + 4;
		var totalH:Int = DROP_ITEM_H * 2 + 1;

		dropdownBg = new FlxSprite(dropX, dropY).makeGraphic(DROP_W, totalH, COL_DROP_BG);
		dropdownBg.scrollFactor.set(0, 0);
		dropdownBg.alpha = 0;
		FlxG.state.add(dropdownBg);

		dropdownAccent = new FlxSprite(dropX, dropY).makeGraphic(2, totalH, COL_SETTINGS);
		dropdownAccent.scrollFactor.set(0, 0);
		dropdownAccent.alpha = 0;
		FlxG.state.add(dropdownAccent);

		dropdownBorder = new FlxSprite(dropX, dropY + totalH - 1).makeGraphic(DROP_W, 1, COL_DROP_BORDER);
		dropdownBorder.scrollFactor.set(0, 0);
		dropdownBorder.alpha = 0;
		FlxG.state.add(dropdownBorder);

		var itemY:Float = dropY;

		dropSettingsBg = new FlxSprite(dropX, itemY).makeGraphic(DROP_W, DROP_ITEM_H, COL_DROP_BG);
		dropSettingsBg.scrollFactor.set(0, 0);
		dropSettingsBg.alpha = 0;
		FlxG.state.add(dropSettingsBg);

		dropSettingsIcon = new FlxSprite();
		dropSettingsIcon.scrollFactor.set(0, 0);
		dropSettingsIcon.alpha = 0;
		try {
			dropSettingsIcon.loadGraphic(Paths.image("other/settings"));
			dropSettingsIcon.setGraphicSize(DROP_ICON_SIZE, DROP_ICON_SIZE);
			dropSettingsIcon.updateHitbox();
		} catch (e:Dynamic) {
			dropSettingsIcon.makeGraphic(DROP_ICON_SIZE, DROP_ICON_SIZE, COL_SETTINGS);
		}
		dropSettingsIcon.x = dropX + 12;
		dropSettingsIcon.y = itemY + (DROP_ITEM_H - DROP_ICON_SIZE) / 2;
		FlxG.state.add(dropSettingsIcon);

		dropSettingsText = new FlxText(Std.int(dropX + 38), Std.int(itemY + 10), Std.int(DROP_W - 50), Language.getPhrase('profile_settings', 'Ayarlar'));
		dropSettingsText.setFormat(Paths.font("vcr.ttf"), 13, COL_TEXT, LEFT);
		dropSettingsText.scrollFactor.set(0, 0);
		dropSettingsText.alpha = 0;
		FlxG.state.add(dropSettingsText);

		itemY += DROP_ITEM_H;

		dropSeparator = new FlxSprite(dropX + 10, itemY).makeGraphic(DROP_W - 20, 1, COL_DROP_SEP);
		dropSeparator.scrollFactor.set(0, 0);
		dropSeparator.alpha = 0;
		FlxG.state.add(dropSeparator);

		itemY += 1;

		dropLogoutBg = new FlxSprite(dropX, itemY).makeGraphic(DROP_W, DROP_ITEM_H, COL_DROP_BG);
		dropLogoutBg.scrollFactor.set(0, 0);
		dropLogoutBg.alpha = 0;
		FlxG.state.add(dropLogoutBg);

		dropLogoutIcon = new FlxSprite();
		dropLogoutIcon.scrollFactor.set(0, 0);
		dropLogoutIcon.alpha = 0;
		try {
			dropLogoutIcon.loadGraphic(Paths.image("other/logout"));
			dropLogoutIcon.setGraphicSize(DROP_ICON_SIZE, DROP_ICON_SIZE);
			dropLogoutIcon.updateHitbox();
		} catch (e:Dynamic) {
			dropLogoutIcon.makeGraphic(DROP_ICON_SIZE, DROP_ICON_SIZE, COL_LOGOUT);
		}
		dropLogoutIcon.x = dropX + 12;
		dropLogoutIcon.y = itemY + (DROP_ITEM_H - DROP_ICON_SIZE) / 2;
		FlxG.state.add(dropLogoutIcon);

		dropLogoutText = new FlxText(Std.int(dropX + 38), Std.int(itemY + 10), Std.int(DROP_W - 50), Language.getPhrase('profile_logout', 'Hesaptan Çık'));
		dropLogoutText.setFormat(Paths.font("vcr.ttf"), 13, COL_LOGOUT, LEFT);
		dropLogoutText.scrollFactor.set(0, 0);
		dropLogoutText.alpha = 0;
		FlxG.state.add(dropLogoutText);

		FlxTween.tween(dropdownBg, {alpha: 1}, 0.18, {ease: FlxEase.sineOut});
		FlxTween.tween(dropdownAccent, {alpha: 1}, 0.18, {ease: FlxEase.sineOut});
		FlxTween.tween(dropdownBorder, {alpha: 0.5}, 0.18, {ease: FlxEase.sineOut});
		FlxTween.tween(dropSettingsBg, {alpha: 1}, 0.18, {ease: FlxEase.sineOut, startDelay: 0.03});
		FlxTween.tween(dropSettingsIcon, {alpha: 0.7}, 0.18, {ease: FlxEase.sineOut, startDelay: 0.04});
		FlxTween.tween(dropSettingsText, {alpha: 1}, 0.18, {ease: FlxEase.sineOut, startDelay: 0.04});
		FlxTween.tween(dropSeparator, {alpha: 0.3}, 0.18, {ease: FlxEase.sineOut, startDelay: 0.05});
		FlxTween.tween(dropLogoutBg, {alpha: 1}, 0.18, {ease: FlxEase.sineOut, startDelay: 0.06});
		FlxTween.tween(dropLogoutIcon, {alpha: 0.7}, 0.18, {ease: FlxEase.sineOut, startDelay: 0.07});
		FlxTween.tween(dropLogoutText, {alpha: 1}, 0.18, {ease: FlxEase.sineOut, startDelay: 0.07});
	}

	function closeDropdown():Void {
		if (!dropdownOpen) return;
		dropdownOpen = false;
		_dropHoverIdx = -1;

		FlxTween.tween(dropdownBg, {alpha: 0}, 0.1);
		FlxTween.tween(dropdownAccent, {alpha: 0}, 0.1);
		FlxTween.tween(dropdownBorder, {alpha: 0}, 0.1);
		FlxTween.tween(dropSettingsBg, {alpha: 0}, 0.1);
		FlxTween.tween(dropSettingsIcon, {alpha: 0}, 0.1);
		FlxTween.tween(dropSettingsText, {alpha: 0}, 0.1);
		FlxTween.tween(dropSeparator, {alpha: 0}, 0.1);
		FlxTween.tween(dropLogoutBg, {alpha: 0}, 0.1);
		FlxTween.tween(dropLogoutIcon, {alpha: 0}, 0.1);
		FlxTween.tween(dropLogoutText, {alpha: 0}, 0.1);

		new FlxTimer().start(0.15, function(_) {
			destroyDropElements();
		});
	}

	function destroyDropElements():Void {
		if (FlxG.state == null) return;
		if (dropdownBg != null) { FlxG.state.remove(dropdownBg, true); dropdownBg.destroy(); dropdownBg = null; }
		if (dropdownAccent != null) { FlxG.state.remove(dropdownAccent, true); dropdownAccent.destroy(); dropdownAccent = null; }
		if (dropdownBorder != null) { FlxG.state.remove(dropdownBorder, true); dropdownBorder.destroy(); dropdownBorder = null; }
		if (dropSettingsBg != null) { FlxG.state.remove(dropSettingsBg, true); dropSettingsBg.destroy(); dropSettingsBg = null; }
		if (dropSettingsIcon != null) { FlxG.state.remove(dropSettingsIcon, true); dropSettingsIcon.destroy(); dropSettingsIcon = null; }
		if (dropSettingsText != null) { FlxG.state.remove(dropSettingsText, true); dropSettingsText.destroy(); dropSettingsText = null; }
		if (dropSeparator != null) { FlxG.state.remove(dropSeparator, true); dropSeparator.destroy(); dropSeparator = null; }
		if (dropLogoutBg != null) { FlxG.state.remove(dropLogoutBg, true); dropLogoutBg.destroy(); dropLogoutBg = null; }
		if (dropLogoutIcon != null) { FlxG.state.remove(dropLogoutIcon, true); dropLogoutIcon.destroy(); dropLogoutIcon = null; }
		if (dropLogoutText != null) { FlxG.state.remove(dropLogoutText, true); dropLogoutText.destroy(); dropLogoutText = null; }
	}

	function handleDropdownInput():Void {
		if (!dropdownOpen) return;

		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		var newHover = -1;

		if (dropSettingsBg != null && isDropOver(dropSettingsBg, mx, my))
			newHover = 0;
		else if (dropLogoutBg != null && isDropOver(dropLogoutBg, mx, my))
			newHover = 1;

		#if mobile
		for (touch in FlxG.touches.list) {
			if (touch.pressed) {
				if (dropSettingsBg != null && isTouchDropOver(dropSettingsBg, touch))
					newHover = 0;
				else if (dropLogoutBg != null && isTouchDropOver(dropLogoutBg, touch))
					newHover = 1;
			}
		}
		#end

		if (newHover != _dropHoverIdx) {
			_dropHoverIdx = newHover;

			if (dropSettingsBg != null) {
				FlxTween.cancelTweensOf(dropSettingsBg);
				dropSettingsBg.color = (_dropHoverIdx == 0) ? COL_DROP_HOVER : COL_DROP_BG;
			}
			if (dropSettingsIcon != null) {
				FlxTween.cancelTweensOf(dropSettingsIcon);
				dropSettingsIcon.alpha = (_dropHoverIdx == 0) ? 1.0 : 0.7;
			}
			if (dropSettingsText != null) {
				FlxTween.cancelTweensOf(dropSettingsText);
				dropSettingsText.color = (_dropHoverIdx == 0) ? FlxColor.WHITE : COL_TEXT;
			}

			if (dropLogoutBg != null) {
				FlxTween.cancelTweensOf(dropLogoutBg);
				dropLogoutBg.color = (_dropHoverIdx == 1) ? COL_DROP_HOVER : COL_DROP_BG;
			}
			if (dropLogoutIcon != null) {
				FlxTween.cancelTweensOf(dropLogoutIcon);
				dropLogoutIcon.alpha = (_dropHoverIdx == 1) ? 1.0 : 0.7;
			}
			if (dropLogoutText != null) {
				FlxTween.cancelTweensOf(dropLogoutText);
				dropLogoutText.color = (_dropHoverIdx == 1) ? 0xFFff6b6b : COL_LOGOUT;
			}
		}

		var clicked = FlxG.mouse.justPressed;
		#if mobile
		if (!clicked) {
			for (touch in FlxG.touches.list) {
				if (touch.justPressed) { clicked = true; break; }
			}
		}
		#end

		if (clicked) {
			if (_dropHoverIdx == 0) {
				FlxG.sound.play(Paths.sound('confirmMenu'));
				closeDropdown();
				LinkSubState.requestURL("https://further-engine.github.io/", Language.getPhrase('profile_open_settings', 'Profilinizin ayarlarını açmak istiyor musunuz?'));
			} else if (_dropHoverIdx == 1) {
				FlxG.sound.play(Paths.sound('cancelMenu'));
				closeDropdown();
				onLogout();
				if (!noStateSwitch)
					MusicBeatState.switchState(new states.MainMenuState());
			} else if (!isMouseOver() && !isDropdownHovered()) {
				closeDropdown();
			}
		}
	}

	function isDropOver(spr:FlxSprite, mx:Float, my:Float):Bool {
		return mx >= spr.x && mx <= spr.x + spr.width
			&& my >= spr.y && my <= spr.y + spr.height;
	}

	#if mobile
	function isTouchDropOver(spr:FlxSprite, touch:flixel.input.touch.FlxTouch):Bool {
		return touch.screenX >= spr.x && touch.screenX <= spr.x + spr.width
			&& touch.screenY >= spr.y && touch.screenY <= spr.y + spr.height;
	}
	#end

	function isDropdownHovered():Bool {
		if (dropdownBg == null) return false;
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		if (isDropOver(dropdownBg, mx, my)) return true;
		#if mobile
		for (touch in FlxG.touches.list) {
			if (touch.pressed && isTouchDropOver(dropdownBg, touch)) return true;
		}
		#end
		return false;
	}

	public function refresh():Void {
		if (!AuthManager.isLoggedIn && !_isGuest) {
			rebuild();
			return;
		}
		if (AuthManager.isLoggedIn && _isGuest) {
			rebuild();
			return;
		}

		if (_isGuest)
			return;

		var username = AuthManager.currentUsername ?? Language.getPhrase('profile_default_player', 'Oyuncu');
		var level = AuthManager.currentLevel ?? 1;
		var up = AuthManager.currentUltraPoints ?? 0.0;
		var rankColor = getRankColorFromUP(up);
		var serverOn = ClientPrefs.data.serverConnection;

		if (usernameText != null)
			usernameText.text = username + '  ·  '
				+ Language.getPhrase('profile_level_prefix', 'Sv') + '.$level';

		if (avatarLetter != null && avatarLetter.visible) {
			avatarLetter.text = username.charAt(0).toUpperCase();
			avatarLetter.color = rankColor;
		}

		if (avatarBorder != null)
			avatarBorder.color = rankColor;

		if (upText != null) {
			var badge = AuthManager.currentBadge;
			if (badge != null && badge.length > 0)
				upText.text = '${formatNumber(up)} UP  ·  $badge';
			else
				upText.text = '${formatNumber(up)} UP';
		}

		if (accentBar != null)
			accentBar.color = rankColor;
		if (accentTop != null)
			accentTop.color = rankColor;

		if (statusDot != null)
			statusDot.color = serverOn ? COL_GREEN : COL_RED;

		if (serverOn != _lastServerConn) {
			_lastServerConn = serverOn;
			buildUnplugIndicator(serverOn);
		}

		var newAvatarUrl = AuthManager.currentAvatarUrl;
		if (newAvatarUrl != _lastAvatarUrl && !_avatarDownloading) {
			_lastAvatarUrl = newAvatarUrl;
			_avatarApplied = false;
			startAvatarLoad();
		}

		#if ACHIEVEMENTS_ALLOWED
		if (achievementLabel != null) {
			var achUnlocked = Achievements.achievementsUnlocked.length;
			var achTotal = Lambda.count(Achievements.achievements);
			achievementLabel.text = Language.getPhrase('profile_achievements', 'Başarımlar') + ': $achUnlocked/$achTotal';
		}
		#end

		saveCache();
	}

	function getRankColorFromUP(up:Float):FlxColor {
		if (up >= 100000) return 0xFFFF6B6B;
		if (up >= 50000) return COL_PINK;
		if (up >= 25000) return COL_ACCENT;
		if (up >= 10000) return COL_CYAN;
		if (up >= 5000) return 0xFFE5E4E2;
		if (up >= 2000) return COL_GOLD;
		if (up >= 500) return 0xFFC0C0C0;
		return 0xFFCD7F32;
	}

	function formatNumber(num:Float):String {
		if (num >= 1000000)
			return Std.string(FlxMath.roundDecimal(num / 1000000, 1)) + "M";
		if (num >= 1000)
			return Std.string(FlxMath.roundDecimal(num / 1000, 1)) + "K";
		return Std.string(Std.int(num));
	}

	static function getSaveDirectory():String {
		#if android
		return StorageUtil.getExternalStorageDirectory();
		#elseif sys
		var saveDir:String = null;
		try {
			saveDir = lime.system.System.applicationStorageDirectory;
		} catch (e:Dynamic) {
			saveDir = null;
		}

		if (saveDir == null || saveDir.length == 0) {
			#if windows
			var appdata = Sys.getEnv("APPDATA");
			if (appdata != null && appdata.length > 0)
				saveDir = appdata + "/PsychEngine/";
			else
				saveDir = Sys.getCwd();
			#elseif linux
			var home = Sys.getEnv("HOME");
			if (home != null && home.length > 0)
				saveDir = home + "/.psychengine/";
			else
				saveDir = Sys.getCwd();
			#elseif mac
			var home = Sys.getEnv("HOME");
			if (home != null && home.length > 0)
				saveDir = home + "/Library/Application Support/PsychEngine/";
			else
				saveDir = Sys.getCwd();
			#else
			saveDir = Sys.getCwd();
			#end
		}

		try {
			if (!FileSystem.exists(saveDir))
				FileSystem.createDirectory(saveDir);
		} catch (e:Dynamic) {}

		return saveDir;
		#else
		return "";
		#end
	}

	static function cachePath():String {
		#if android
		return StorageUtil.getExternalStorageDirectory() + CACHE_FILE;
		#elseif sys
		return getSaveDirectory() + CACHE_FILE;
		#else
		return CACHE_FILE;
		#end
	}

	function saveCache():Void {
		#if sys
		try {
			var data = {
				username: AuthManager.currentUsername,
				level: AuthManager.currentLevel,
				score: AuthManager.currentScore,
				ultraPoints: AuthManager.currentUltraPoints,
				country: AuthManager.currentCountry,
				avatarUrl: AuthManager.currentAvatarUrl,
				timestamp: Date.now().toString()
			};
			var path = cachePath();
			File.saveContent(path, haxe.Json.stringify(data));
		} catch (e:Dynamic) {}
		#end
	}

	public static function loadCache():Bool {
		#if sys
		try {
			var path = cachePath();
			if (!FileSystem.exists(path)) return false;
			var data:Dynamic = haxe.Json.parse(File.getContent(path));
			AuthManager.currentUsername = data.username ?? "Player";
			AuthManager.currentLevel = data.level ?? 1;
			AuthManager.currentScore = data.score ?? 0;
			AuthManager.currentUltraPoints = data.ultraPoints ?? 0.0;
			AuthManager.currentCountry = data.country ?? "";
			AuthManager.currentAvatarUrl = data.avatarUrl;
			return true;
		} catch (e:Dynamic) {}
		#end
		return false;
	}

	public static function clearCache():Void {
		#if sys
		try {
			var path = cachePath();
			if (FileSystem.exists(path))
				FileSystem.deleteFile(path);
		} catch (e:Dynamic) {}
		#end
	}

	public static function getCachedProfile():Dynamic {
		#if sys
		try {
			var path = cachePath();
			if (!FileSystem.exists(path)) return null;
			return haxe.Json.parse(File.getContent(path));
		} catch (e:Dynamic) {}
		#end
		return null;
	}

	public static function syncFromAuth():Void {
		if (!AuthManager.isLoggedIn) return;

		#if sys
		try {
			var data = {
				username: AuthManager.currentUsername,
				level: AuthManager.currentLevel,
				score: AuthManager.currentScore,
				ultraPoints: AuthManager.currentUltraPoints,
				country: AuthManager.currentCountry,
				avatarUrl: AuthManager.currentAvatarUrl,
				timestamp: Date.now().toString()
			};
			File.saveContent(cachePath(), haxe.Json.stringify(data));
		} catch (e:Dynamic) {}
		#end

		if (instance != null)
			instance.rebuild();
	}

	public static function onLogin():Void {
		if (instance != null)
			instance.rebuild();
	}

	public static function onLogout():Void {
		clearCache();
		_cachedAvatarBytes = null;
		_cachedAvatarUrl = null;
		AuthManager.logout();
		if (instance != null)
			instance.rebuild();
	}

	override function destroy():Void {
		if (dropdownOpen) closeDropdown();
		destroyUnplugElements();
		if (avatarLoadingCircle != null) {
			remove(avatarLoadingCircle, true);
			avatarLoadingCircle.destroy();
			avatarLoadingCircle = null;
		}
		if (instance == this)
			instance = null;
		super.destroy();
	}
}
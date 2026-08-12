package objects;

import flixel.FlxG;
import backend.AuthManager;

import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.geom.ColorTransform;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.AntiAliasType;
import openfl.text.TextField;
import openfl.text.TextFormat;

import objects.PopupThing;
import objects.PopupThing.PopupMgr;
import objects.PopupThing.PopupLine;
import objects.PopupThing.PopupPosition;

class UPPopup
{
	static inline var COUNT_DURATION:Float = 2.0;
	static inline var MIN_TICK_INTERVAL:Float = 0.02;
	static inline var MAX_TICK_INTERVAL:Float = 0.12;
	static inline var ACCEL_FACTOR:Float = 3.0;

	static inline var FLAME_XML_PATH:String = "assets/shared/images/freeplay/freeplayFlame.xml";
	static inline var FLAME_PNG_PATH:String = "assets/shared/images/freeplay/freeplayFlame.png";

	static inline var STREAK_COUNT_TIME:Float = 0.45;
	static inline var FLAME_FPS:Float = 24.0;
	static inline var BREAK_TRIGGER_TIME:Float = 0.85;
	static inline var BREAK_SHAKE_TIME:Float = 0.32;
	static inline var FLAME_SCALE:Float = 1.1;

	public static var streakDebug:Bool = false;

	static var _targetUP:Int = 0;
	static var _currentUP:Float = 0;
	static var _tickTimer:Float = 0;
	static var _finished:Bool = false;
	static var _totalElapsed:Float = 0;

	static var _flameFrames:Array<BitmapData> = null;
	static var _fallbackFrame:BitmapData = null;

	static function _parseIntOr(value:String, defaultValue:Int):Int
	{
		if (value == null)
			return defaultValue;
		var parsed:Null<Int> = Std.parseInt(value);
		return parsed == null ? defaultValue : parsed;
	}

	static function _getTips():Array<String>
	{
		var name:String = AuthManager.currentUsername;
		if (name == null || name == "" || name == "Player")
			name = "Oyuncu";

		return [
			"AYNEN BÖYLE DEVAM ET, " + name + "!",
			"HARİKASIN " + name + "!",
			"DAHA İYİSİNİ YAPABİLİRSİN, " + name + "!",
			"DURDURULAMAZSIN " + name + "!",
			"MÜKEMMELİMSİ, " + name + "!",
			"KOMBO CANAVARISIN " + name + "!",
			"WOHOOO " + name + "!",
			"AYNI YAĞMUR GİBİ, " + name + "!",
			name + ", SEN BIR EFSANESIN!",
			name + ", YANIYORSUN!",
			"MÜQ, " + name + "!",
			name + ", KIMSE SENI DURDURAMAZ!",
			"HARIKA OYNUYORSUN, " + name + "!",
			name + " SAHNEYE CIKIYOR!",
			"TAM GAZ DEVAM, " + name + "!",
			name + ", NOTALAR SENINLE DANS EDIYOR!"
		];
	}

	public static function show(
		earnedUP:Int,
		totalUP:Float,
		level:Int,
		streakBonusUP:Int = 0,
		ultraStreakCount:Int = 0,
		requiredAccNext:Float = 90,
		ultraBroken:Bool = false,
		ultraActivated:Bool = false,
		previousUltraStreak:Int = 0
	):Void
	{
		if (PopupMgr.instance == null)
			return;
		if (earnedUP <= 0 && !streakDebug)
			return;

		if (streakDebug)
		{
			trace('[UPPopup] DEBUG MODE ACTIVE - forcing streak visuals');
			if (earnedUP <= 0) earnedUP = 1;
			if (ultraStreakCount < 2) ultraStreakCount = 3;
			if (streakBonusUP <= 0) streakBonusUP = 2;
			ultraActivated = true;
			ultraBroken = false;
			previousUltraStreak = 0;
		}

		trace('[UPPopup] show called | earnedUP=' + earnedUP
			+ ' streakBonusUP=' + streakBonusUP
			+ ' ultraStreakCount=' + ultraStreakCount
			+ ' ultraBroken=' + ultraBroken
			+ ' ultraActivated=' + ultraActivated
			+ ' previousUltraStreak=' + previousUltraStreak
			+ ' debug=' + streakDebug);

		_targetUP = earnedUP;
		_currentUP = 0;
		_tickTimer = 0;
		_finished = false;
		_totalElapsed = 0;

		var tips = _getTips();
		var tip:String = tips[Std.int(Math.random() * tips.length)];

		// ========== UP CARD ==========
		var upLines:Array<PopupLine> = [
			new PopupLine("KAZANILAN PUANLAR!", 16, 0xCCCCCC, true),
			new PopupLine("0 UP", 28, 0xFFD740, true),
			new PopupLine(tip, 14, 0x69F0AE, false)
		];

		var showDormantFlame:Bool = (!ultraBroken && ultraStreakCount == 1);
		var showActiveStreak:Bool = (!ultraBroken && ultraStreakCount >= 2);
		var showBrokenStreak:Bool = (ultraBroken && previousUltraStreak >= 2);
		var showBadge:Bool = showDormantFlame || showActiveStreak || showBrokenStreak;

		trace('[UPPopup] showDormantFlame=' + showDormantFlame
			+ ' showActiveStreak=' + showActiveStreak
			+ ' showBrokenStreak=' + showBrokenStreak
			+ ' showBadge=' + showBadge);

		var holdTime:Float = COUNT_DURATION + (showBadge ? 4.5 : 3.5);

		var localShowActiveStreak:Bool = showActiveStreak;
		var localUltraActivated:Bool = ultraActivated;
		var localStreakDebug:Bool = streakDebug;

		// UP Card - sagdan gelir
		PopupMgr.instance.spawn(upLines, holdTime, 0xFFFFD740, PopupPosition.BOTTOM_RIGHT, null, function(card:PopupThing, dt:Float)
		{
			if (localStreakDebug)
				return;

			if (!_finished)
			{
				_totalElapsed += dt;

				var progress:Float = _totalElapsed / COUNT_DURATION;
				if (progress > 1) progress = 1;

				var eased:Float = 1 - Math.pow(1 - progress, ACCEL_FACTOR);
				var interval:Float = MAX_TICK_INTERVAL - (MAX_TICK_INTERVAL - MIN_TICK_INTERVAL) * eased;

				_tickTimer += dt;

				if (_tickTimer >= interval)
				{
					_tickTimer = 0;

					var newVal:Int = Std.int(eased * _targetUP);
					if (newVal > _targetUP) newVal = _targetUP;

					if (newVal != Std.int(_currentUP))
					{
						_currentUP = newVal;

						var prefix:String = newVal >= _targetUP ? "" : "+";
						card.updateLine(1, prefix + newVal + " UP");

						if (newVal >= _targetUP)
						{
							_finished = true;
							card.updateLine(1, "+" + _targetUP + " UP");

							if (localShowActiveStreak)
								card.updateLineColor(1, 0xFFFFB300);
							else
								card.updateLineColor(1, 0x69F0AE);

							_playSound('confirmMenu');

							if (localUltraActivated)
								card.shake(4.0, 0.10);
						}
						else
						{
							card.shake(2.5, 0.06);
							_playSound('scrollMenu');
						}
					}
				}
			}
		});

		// ========== US CARD ==========
		if (showBadge)
		{
			_spawnUSCard(
				showDormantFlame,
				showActiveStreak,
				showBrokenStreak,
				streakBonusUP,
				ultraStreakCount,
				previousUltraStreak,
				holdTime
			);
		}
	}

	static function _spawnUSCard(
		dormant:Bool,
		active:Bool,
		broken:Bool,
		streakBonusUP:Int,
		ultraStreakCount:Int,
		previousUltraStreak:Int,
		holdTime:Float
	):Void
	{
		trace('[UPPopup] Spawning US Card...');

		var countTarget:Int = broken ? previousUltraStreak : ultraStreakCount;

		// Flame genisligi icin bos satirlar
		// Line 0: bos (flame alani)
		// Line 1: streak label
		// Line 2: streak count
		var flameSpacerText:String = "          "; // bosluk - flame alani

		var streakLabel:String = "";
		var streakColor:Int = 0xFFC107;

		if (active)
		{
			streakLabel = "ULTRA STREAK: +" + streakBonusUP + " UP";
			streakColor = 0xFF6D00;
		}
		else if (broken)
		{
			streakLabel = "ULTRA STREAK...";
			streakColor = 0xFFC107;
		}
		else if (dormant)
		{
			streakLabel = "ULTRA STREAK...";
			streakColor = 0x999999;
		}

		var usLines:Array<PopupLine> = [
			new PopupLine(flameSpacerText + streakLabel, 18, streakColor, true),
			new PopupLine(flameSpacerText + "0X", 22, 0xFFFFFF, true)
		];

		var accentColor:Int = active ? 0xFFFF6D00 : (broken ? 0xFFFF1744 : 0xFF888888);

		var flameBmp:Bitmap = null;
		var flameAnimElapsed:Float = 0.0;
		var flameFrameIndex:Int = 0;
		var localFlameAnimated:Bool = active || broken;

		var countShown:Int = -1;
		var countElapsed:Float = 0.0;

		var breakElapsed:Float = 0.0;
		var breakTriggered:Bool = false;
		var breakShakeElapsed:Float = 0.0;

		var flameBuilt:Bool = false;

		var localActive:Bool = active;
		var localBroken:Bool = broken;
		var localDormant:Bool = dormant;
		var localCountTarget:Int = countTarget;
		var localStreakBonusUP:Int = streakBonusUP;

		PopupMgr.instance.spawn(usLines, holdTime, accentColor, PopupPosition.BOTTOM_RIGHT_LEFT, null, function(card:PopupThing, dt:Float)
		{
			// ========== BUILD FLAME (once) ==========
			if (!flameBuilt)
			{
				flameBuilt = true;
				trace('[UPPopup] Building flame on US Card...');

				var frames = _getFlameFrames();
				var firstFrame:BitmapData = (frames != null && frames.length > 0) ? frames[0] : _getFallbackFrame();

				flameBmp = new Bitmap(firstFrame);
				flameBmp.smoothing = true;
				// Flame'i kart yuksekligine sigdir
				var maxFlameH:Float = card.totalH - 8;
				var rawH:Float = firstFrame.height * FLAME_SCALE;

				var finalScale:Float = FLAME_SCALE;
				if (rawH > maxFlameH)
					finalScale = (maxFlameH / firstFrame.height);

				flameBmp.scaleX = finalScale;
				flameBmp.scaleY = finalScale;

				flameBmp.y = Math.max(2, (card.totalH - flameBmp.height) * 0.5);

				if (localDormant)
					flameBmp.alpha = 0.30;
				else
					flameBmp.alpha = 1.0;

				// Flame sol tarafta, dikey olarak ortalanmis
				flameBmp.x = 12;

				card.addChild(flameBmp);

				trace('[UPPopup] Flame added | scale=' + FLAME_SCALE
					+ ' w=' + flameBmp.width + ' h=' + flameBmp.height
					+ ' cardW=' + card.totalW + ' cardH=' + card.totalH
					+ ' frames=' + frames.length);
			}

			// ========== STREAK COUNT ANIM ==========
			if (localCountTarget >= 2)
			{
				countElapsed += dt;

				var ct:Float = (countElapsed - 0.15) / STREAK_COUNT_TIME;
				if (ct < 0) ct = 0;
				if (ct > 1) ct = 1;

				var cEase:Float = 1 - Math.pow(1 - ct, 3);
				var newCount:Int = Std.int(cEase * localCountTarget);
				if (newCount > localCountTarget) newCount = localCountTarget;

				if (newCount != countShown)
				{
					countShown = newCount;
					if (countShown < 0) countShown = 0;
					card.updateLine(1, flameSpacerText + Std.string(countShown) + "X");

					if (countShown > 0)
						_playSound('scrollMenu');
				}
			}
			else if (localDormant)
			{
				card.updateLine(1, flameSpacerText + "1X");
			}

			// ========== FLAME ANIMATION ==========
			if (flameBmp != null && localFlameAnimated && !breakTriggered)
			{
				var frames = _getFlameFrames();
				if (frames != null && frames.length > 1)
				{
					flameAnimElapsed += dt;
					var frameTime:Float = 1.0 / FLAME_FPS;

					while (flameAnimElapsed >= frameTime)
					{
						flameAnimElapsed -= frameTime;
						flameFrameIndex++;
						if (flameFrameIndex >= frames.length)
							flameFrameIndex = 0;

						flameBmp.bitmapData = frames[flameFrameIndex];
					}
				}
			}

			// ========== BREAK ANIMATION ==========
			if (localBroken)
			{
				breakElapsed += dt;

				if (!breakTriggered && breakElapsed >= BREAK_TRIGGER_TIME)
				{
					breakTriggered = true;
					localFlameAnimated = false;

					card.updateLine(0, flameSpacerText + "ULTRA STREAK: GGs");
					card.updateLineColor(0, 0x9E9E9E);
					card.updateLineColor(1, 0xBDBDBD);

					if (flameBmp != null)
					{
						var grayTf = new ColorTransform();
						grayTf.redMultiplier = 0.35;
						grayTf.greenMultiplier = 0.35;
						grayTf.blueMultiplier = 0.35;
						grayTf.alphaMultiplier = 0.95;
						grayTf.redOffset = 28;
						grayTf.greenOffset = 28;
						grayTf.blueOffset = 28;
						flameBmp.transform.colorTransform = grayTf;
					}

					_playSound('cancelMenu');
				}

				if (breakTriggered)
				{
					breakShakeElapsed += dt;

					if (breakShakeElapsed < BREAK_SHAKE_TIME)
					{
						card.shake(6.0, BREAK_SHAKE_TIME - breakShakeElapsed);
					}
				}
			}
		});
	}

	static function _getFlameFrames():Array<BitmapData>
	{
		if (_flameFrames != null)
			return _flameFrames;

		_flameFrames = [];

		try
		{
			var xmlText:String = Assets.getText(FLAME_XML_PATH);
			var atlasBmp:BitmapData = Assets.getBitmapData(FLAME_PNG_PATH);
			var xml:Xml = Xml.parse(xmlText).firstElement();

			var subs:Array<Xml> = [];
			for (node in xml.elements())
			{
				if (node.nodeName == "SubTexture")
					subs.push(node);
			}

			subs.sort(function(a:Xml, b:Xml):Int
			{
				var an:String = a.get("name");
				var bn:String = b.get("name");
				if (an < bn) return -1;
				if (an > bn) return 1;
				return 0;
			});

			for (sub in subs)
			{
				var sx:Int = _parseIntOr(sub.get("x"), 0);
				var sy:Int = _parseIntOr(sub.get("y"), 0);
				var sw:Int = _parseIntOr(sub.get("width"), 1);
				var sh:Int = _parseIntOr(sub.get("height"), 1);

				var fx:Int = _parseIntOr(sub.get("frameX"), 0);
				var fy:Int = _parseIntOr(sub.get("frameY"), 0);
				var fw:Int = _parseIntOr(sub.get("frameWidth"), sw);
				var fh:Int = _parseIntOr(sub.get("frameHeight"), sh);

				var out:BitmapData = new BitmapData(fw, fh, true, 0x00000000);
				out.copyPixels(
					atlasBmp,
					new Rectangle(sx, sy, sw, sh),
					new Point(-fx, -fy)
				);

				_flameFrames.push(out);
			}

			trace('[UPPopup] Flame frames loaded: ' + _flameFrames.length);
		}
		catch (e:Dynamic)
		{
			trace('[UPPopup] Flame atlas load failed: ' + Std.string(e));
			_flameFrames = [_getFallbackFrame()];
		}

		if (_flameFrames == null || _flameFrames.length == 0)
			_flameFrames = [_getFallbackFrame()];

		return _flameFrames;
	}

	static function _getFallbackFrame():BitmapData
	{
		if (_fallbackFrame != null)
			return _fallbackFrame;

		_fallbackFrame = new BitmapData(64, 96, true, 0x00000000);

		for (yy in 0...96)
		{
			for (xx in 0...64)
			{
				var dx:Float = xx - 32;
				var dy:Float = yy - 62;
				var dist:Float = Math.sqrt(dx * dx + dy * dy);

				if (dist < 18)
					_fallbackFrame.setPixel32(xx, yy, 0xFFFFC107);
				else if (dist < 24)
					_fallbackFrame.setPixel32(xx, yy, 0xFFFF6F00);
			}
		}

		return _fallbackFrame;
	}

	static function _playSound(name:String):Void
	{
		try
		{
			FlxG.sound.play(Paths.sound(name), 0.5);
		}
		catch (e:Dynamic)
		{
			trace('[UPPopup] Sound error: ' + Std.string(e));
		}
	}
}
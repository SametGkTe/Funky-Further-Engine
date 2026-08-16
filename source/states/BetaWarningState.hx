package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import shaders.WarpEffect;

class BetaWarningState extends MusicBeatState
{
	static inline final FONT_PATH:String = "Avgardd.ttf";
	static inline final FONT_SIZE_TITLE:Int = 48;
	static inline final FONT_SIZE_BODY:Int = 22;
	static inline final FONT_SIZE_HINT:Int = 20;
	static inline final FONT_SIZE_VERSION:Int = 14;
	static inline final SIDE_MARGIN:Float = 80;

	static inline final TITLE_COLOR:Int = 0xFFE8D5F5;
	static inline final BODY_COLOR:Int = 0xFFBFADD4;
	static inline final HINT_COLOR:Int = 0xFF8A7A9A;
	static inline final VERSION_COLOR:Int = 0xFF5A4A6A;

	static inline final AMBIENCE_FADE_TIME:Float = 0.8;
	static inline final PORTAL_APPEAR_DELAY:Float = 0.4;
	static inline final PORTAL_SCALE_IN_TIME:Float = 1.8;
	static inline final PORTAL_ALPHA_IN_TIME:Float = 1.0;
	static inline final TEXT_APPEAR_DELAY:Float = 2.0;
	static inline final TEXT_STAGGER:Float = 0.15;
	static inline final HINT_PULSE_SPEED:Float = 1.8;

	static inline final PORTAL_IDLE_SCALE:Float = 0.35;
	static inline final PORTAL_IDLE_ALPHA:Float = 1.0;
	static inline final PORTAL_IDLE_BRIGHTNESS:Float = 1.0;
	static inline final PORTAL_EDGE_SOFTNESS:Float = 0.12;
	static inline final PORTAL_PULSE_AMOUNT:Float = 0.015;
	static inline final PORTAL_PULSE_SPEED:Float = 1.5;

	static inline final EXIT_ZOOM_TIME:Float = 1.4;
	static inline final EXIT_ZOOM_TARGET_SCALE:Float = 2.5;
	static inline final EXIT_FADE_DELAY_RATIO:Float = 0.45;
	static inline final EXIT_FADE_TIME:Float = 0.6;
	static inline final EXIT_TEXT_FADE:Float = 0.35;
	static inline final EXIT_HOLD_BLACK:Float = 0.3;

	static inline final PARTICLE_COUNT:Int = 28;
	static inline final PARTICLE_ORBIT_MIN:Float = 120;
	static inline final PARTICLE_ORBIT_MAX:Float = 230;
	static inline final PARTICLE_SPEED_MIN:Float = 0.3;
	static inline final PARTICLE_SPEED_MAX:Float = 1.4;

	static inline final CENTER_IMAGE_PATH:String = "fe";
	static inline final CENTER_IMAGE_SIZE:Int = 160;
	static inline final CENTER_IMAGE_Y_RATIO:Float = 0.5;

	static inline final WARNING_TITLE:String = "RELEASE BETA 2";
	static inline final WARNING_BODY:String =
		"DİKKAT: Bu proje hala yapılma aşamasındadır.\n" +
		"bitirilmemiş sistemler ve bug'lar vs. bulunmaktadır,\n" +
		"eğer çökme hataları vs. alırsanız lütfen Kurucuya bildirin.\n\n" +
		"Further Engine OWW YEAHH";
	static inline final VERSION_TEXT:String = "Yayınlanmış Beta 2 Sürümü";
	static inline final HINT_DESKTOP:String = "[ENTER] Devam Et    [ESC] Atla";
	static inline final HINT_MOBILE:String = "[A] Devam Et    [B] Atla";

	var leftState:Bool = false;
	var allowInput:Bool = false;
	var introComplete:Bool = false;
	var isExiting:Bool = false;
	var elapsed_total:Float = 0;

	var currentPortalScale:Float = 0.0;
	var currentPortalAlpha:Float = 0.0;
	var currentPortalBrightness:Float = 1.0;
	var currentEdgeSoftness:Float = 0.12;

	var bg:FlxSprite;
	var portalSprite:FlxSprite;
	var warpEffect:WarpEffect;
	var centerImage:FlxSprite;
	var vignette:FlxSprite;
	var particles:FlxTypedGroup<PortalParticle>;
	var blackout:FlxSprite;

	var titleText:FlxText;
	var bodyText:FlxText;
	var hintText:FlxText;
	var versionText:FlxText;

	var ambiencePlaying:Bool = false;

	override function create()
	{
		super.create();

		createBackground();
		createPortalShader();
		createCenterImage();
		createParticles();
		createVignette();
		createTexts();
		createBlackout();
		createMobilePad();

		playIntroSequence();
	}

	function createBackground():Void
	{
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF050208);
		bg.alpha = 0;
		add(bg);
	}

	function createPortalShader():Void
	{
		portalSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
		portalSprite.setPosition(0, 0);
		portalSprite.blend = ADD;

		warpEffect = new WarpEffect(portalSprite);
		warpEffect.setPortalScale(0.0);
		warpEffect.setPortalAlpha(0.0);
		warpEffect.setPortalBrightness(PORTAL_IDLE_BRIGHTNESS);
		warpEffect.setPortalEdgeSoftness(PORTAL_EDGE_SOFTNESS);

		currentPortalScale = 0.0;
		currentPortalAlpha = 0.0;
		currentPortalBrightness = PORTAL_IDLE_BRIGHTNESS;
		currentEdgeSoftness = PORTAL_EDGE_SOFTNESS;

		add(warpEffect);
		add(portalSprite);
	}

	function createCenterImage():Void
	{
		centerImage = new FlxSprite();

		var graphic = Paths.image(CENTER_IMAGE_PATH);
		if (graphic != null)
		{
			centerImage.loadGraphic(graphic);
			centerImage.setGraphicSize(CENTER_IMAGE_SIZE, CENTER_IMAGE_SIZE);
			centerImage.updateHitbox();
		}
		else
		{
			centerImage.makeGraphic(CENTER_IMAGE_SIZE, CENTER_IMAGE_SIZE, 0xFFFFFFFF);
		}

		centerImage.screenCenter();
		centerImage.y = FlxG.height * CENTER_IMAGE_Y_RATIO - centerImage.height * 0.5;
		centerImage.alpha = 0;
		add(centerImage);
	}

	function createParticles():Void
	{
		particles = new FlxTypedGroup<PortalParticle>();
		add(particles);

		final cx = FlxG.width * 0.5;
		final cy = FlxG.height * 0.5;

		for (i in 0...PARTICLE_COUNT)
		{
			var p = new PortalParticle(cx, cy);
			p.orbitRadius = PARTICLE_ORBIT_MIN + Math.random() * (PARTICLE_ORBIT_MAX - PARTICLE_ORBIT_MIN);
			p.orbitSpeed = PARTICLE_SPEED_MIN + Math.random() * (PARTICLE_SPEED_MAX - PARTICLE_SPEED_MIN);
			p.orbitAngle = Math.random() * Math.PI * 2;
			p.orbitDirection = (Math.random() > 0.5) ? 1 : -1;
			p.baseAlpha = 0.25 + Math.random() * 0.55;
			p.particleSize = 2 + Std.int(Math.random() * 4);
			p.makeGraphic(p.particleSize, p.particleSize, 0xFFCBAAF0);
			p.blend = ADD;
			p.alpha = 0;
			particles.add(p);
		}
	}

	function createVignette():Void
	{
		vignette = new FlxSprite();

		if (Paths.image("betaVignette") != null)
		{
			vignette.loadGraphic(Paths.image("betaVignette"));
			vignette.setGraphicSize(FlxG.width, FlxG.height);
			vignette.updateHitbox();
		}
		else
		{
			vignette.makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
			drawVignette(vignette);
		}

		vignette.alpha = 0;
		add(vignette);
	}

	function drawVignette(sprite:FlxSprite):Void
	{
		final w = FlxG.width;
		final h = FlxG.height;
		final cx = w * 0.5;
		final cy = h * 0.5;
		final maxDist = Math.sqrt(cx * cx + cy * cy);

		for (py in 0...h)
		{
			for (px in 0...w)
			{
				final dx = px - cx;
				final dy = py - cy;
				final dist = Math.sqrt(dx * dx + dy * dy);
				final ratio = dist / maxDist;

				var a:Float = 0;
				if (ratio > 0.35)
				{
					a = (ratio - 0.35) / 0.65;
					a = a * a * 0.9;
				}

				if (a > 0)
				{
					final ai = Std.int(FlxMath.bound(a, 0, 1) * 255);
					sprite.pixels.setPixel32(px, py, FlxColor.fromRGB(0, 0, 0, ai));
				}
			}
		}
	}

	function createBlackout():Void
	{
		blackout = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		blackout.alpha = 0;
		blackout.scrollFactor.set();
		add(blackout);
	}

	function createTexts():Void
	{
		titleText = new FlxText(0, FlxG.height * 0.58, FlxG.width, WARNING_TITLE);
		titleText.setFormat(Paths.font(FONT_PATH), FONT_SIZE_TITLE, TITLE_COLOR, CENTER);
		titleText.alpha = 0;
		titleText.setBorderStyle(OUTLINE, 0xFF2A1040, 2);
		add(titleText);

		bodyText = new FlxText(SIDE_MARGIN, FlxG.height * 0.67, FlxG.width - SIDE_MARGIN * 2, WARNING_BODY);
		bodyText.setFormat(Paths.font(FONT_PATH), FONT_SIZE_BODY, BODY_COLOR, CENTER);
		bodyText.alpha = 0;
		add(bodyText);

		hintText = new FlxText(0, FlxG.height - 70, FlxG.width, controls.mobileC ? HINT_MOBILE : HINT_DESKTOP);
		hintText.setFormat(Paths.font(FONT_PATH), FONT_SIZE_HINT, HINT_COLOR, CENTER);
		hintText.alpha = 0;
		add(hintText);

		versionText = new FlxText(0, FlxG.height - 36, FlxG.width, VERSION_TEXT);
		versionText.setFormat(Paths.font(FONT_PATH), FONT_SIZE_VERSION, VERSION_COLOR, CENTER);
		versionText.alpha = 0;
		add(versionText);
	}

	function createMobilePad():Void
	{
		addTouchPad("NONE", "A_B");
		touchPad.alpha = 0;
	}

	// =========================================================================
	// INTRO SEQUENCE
	// =========================================================================

	function playIntroSequence():Void
	{
		allowInput = false;

		FlxTween.tween(bg, {alpha: 1}, AMBIENCE_FADE_TIME, {ease: FlxEase.quadOut});

		new FlxTimer().start(0.2, function(_)
		{
			startAmbience();
		});

		new FlxTimer().start(PORTAL_APPEAR_DELAY, function(_)
		{
			showPortal();
		});

		new FlxTimer().start(TEXT_APPEAR_DELAY, function(_)
		{
			showTexts();
		});
	}

	function startAmbience():Void
	{
		if (!ambiencePlaying)
		{
			FlxG.sound.play(Paths.sound("betaAmbience"), 0.0).fadeIn(1.5, 0, 0.35);
			ambiencePlaying = true;
		}
	}

	function showPortal():Void
	{
		FlxG.sound.play(Paths.sound("portalOpen"), 0.5);

		tweenShaderFloat(0.0, PORTAL_IDLE_SCALE, PORTAL_SCALE_IN_TIME, FlxEase.elasticOut,
			function(v:Float)
			{
				currentPortalScale = v;
				if (!isExiting)
					warpEffect.setPortalScale(v);
			});

		tweenShaderFloat(0.0, PORTAL_IDLE_ALPHA, PORTAL_ALPHA_IN_TIME, FlxEase.quadOut,
			function(v:Float)
			{
				currentPortalAlpha = v;
				warpEffect.setPortalAlpha(v);
			});

		new FlxTimer().start(0.6, function(_)
		{
			final imgTargetY = centerImage.y;
			centerImage.y += 15;
			FlxTween.tween(centerImage, {alpha: 1, y: imgTargetY}, 0.7, {ease: FlxEase.quadOut});
		});

		new FlxTimer().start(0.5, function(_)
		{
			for (p in particles)
			{
				FlxTween.tween(p, {alpha: p.baseAlpha}, 0.8, {
					startDelay: Math.random() * 0.6,
					ease: FlxEase.quadOut
				});
			}
		});

		FlxTween.tween(vignette, {alpha: 0.9}, PORTAL_SCALE_IN_TIME * 0.7, {ease: FlxEase.quadOut});
	}

	function showTexts():Void
	{
		animateTextIn(titleText, 0.1, function()
		{
			animateTextIn(bodyText, TEXT_STAGGER, function()
			{
				animateTextIn(hintText, TEXT_STAGGER, function()
				{
					animateTextIn(versionText, TEXT_STAGGER * 0.5, function()
					{
						introComplete = true;
						allowInput = true;
						FlxTween.tween(touchPad, {alpha: 1}, 0.4, {ease: FlxEase.quadOut});
					});
				});
			});
		});
	}

	function animateTextIn(text:FlxText, delay:Float, ?onDone:Void->Void):Void
	{
		final targetY = text.y;
		text.y += 22;

		FlxTween.tween(text, {alpha: 1, y: targetY}, 0.5, {
			startDelay: delay,
			ease: FlxEase.quadOut,
			onComplete: function(_)
			{
				if (onDone != null) onDone();
			}
		});
	}

	// =========================================================================
	// UPDATE
	// =========================================================================

	override function update(elapsed:Float)
	{
		if (!leftState)
		{
			elapsed_total += elapsed;
			updatePortalPulse();
			updateParticles(elapsed);
			updateHintPulse();

			if (allowInput)
				handleInput();
		}

		super.update(elapsed);
	}

	function updatePortalPulse():Void
	{
		if (warpEffect == null || isExiting || !introComplete)
			return;

		final pulse = currentPortalScale + Math.sin(elapsed_total * PORTAL_PULSE_SPEED) * PORTAL_PULSE_AMOUNT;
		warpEffect.setPortalScale(pulse);

		final bPulse = currentPortalBrightness + Math.sin(elapsed_total * PORTAL_PULSE_SPEED * 0.7) * 0.05;
		warpEffect.setPortalBrightness(bPulse);
	}

	function updateParticles(elapsed:Float):Void
	{
		if (isExiting)
			return;

		final cx = FlxG.width * 0.5;
		final cy = FlxG.height * 0.5;

		for (p in particles)
		{
			p.orbitAngle += p.orbitSpeed * p.orbitDirection * elapsed;

			p.x = cx + Math.cos(p.orbitAngle) * p.orbitRadius - p.width * 0.5;
			p.y = cy + Math.sin(p.orbitAngle) * p.orbitRadius * 0.45 - p.height * 0.5;

			if (p.alpha > 0)
				p.alpha = p.baseAlpha * (0.6 + Math.sin(elapsed_total * 3.5 + p.orbitAngle * 2) * 0.4);
		}
	}

	function updateHintPulse():Void
	{
		if (hintText == null || !introComplete || isExiting)
			return;

		hintText.alpha = 0.45 + Math.sin(elapsed_total * HINT_PULSE_SPEED) * 0.45;
	}

	// =========================================================================
	// INPUT
	// =========================================================================

	function handleInput():Void
	{
		if (controls.ACCEPT || controls.BACK)
		{
			confirmAndExit();
			return;
		}
	}

	// =========================================================================
	// EXIT - ZOOM IN + FADE OUT
	// =========================================================================

	function confirmAndExit():Void
	{
		if (leftState)
			return;

		leftState = true;
		allowInput = false;
		isExiting = true;

		FlxG.sound.play(Paths.sound("confirmMenu"));
		skipTransitions();

		// ---- Yazıları hemen fade out ----
		fadeOutTexts();

		// ---- Center image fade out ----
		FlxTween.tween(centerImage, {alpha: 0}, EXIT_TEXT_FADE, {ease: FlxEase.quadIn});

		// ---- Parçacıkları merkeze çek ve kaybet ----
		suckParticlesIn();

		// ---- Vignette fade out ----
		FlxTween.tween(vignette, {alpha: 0}, EXIT_TEXT_FADE, {ease: FlxEase.quadIn});

		// ---- Mobile pad fade out ----
		FlxTween.tween(touchPad, {alpha: 0}, EXIT_TEXT_FADE * 0.6, {ease: FlxEase.quadIn});

		// ---- Portal: zoom in (scale büyür) ----
		tweenShaderFloat(currentPortalScale, EXIT_ZOOM_TARGET_SCALE, EXIT_ZOOM_TIME, FlxEase.quadInOut,
			function(v:Float)
			{
				currentPortalScale = v;
				warpEffect.setPortalScale(v);
			});

		// ---- Edge softness artır (kenarlar yumuşasın zoom sırasında) ----
		tweenShaderFloat(currentEdgeSoftness, 0.6, EXIT_ZOOM_TIME * 0.8, FlxEase.quadOut,
			function(v:Float)
			{
				currentEdgeSoftness = v;
				warpEffect.setPortalEdgeSoftness(v);
			});

		// ---- Portal yaklaşıp ortaya geldiğinde fade out başlasın ----
		final fadeStartDelay = EXIT_ZOOM_TIME * EXIT_FADE_DELAY_RATIO;

		new FlxTimer().start(fadeStartDelay, function(_)
		{
			// Portal alpha fade out
			tweenShaderFloat(currentPortalAlpha, 0.0, EXIT_FADE_TIME, FlxEase.quadIn,
				function(v:Float)
				{
					currentPortalAlpha = v;
					warpEffect.setPortalAlpha(v);
				});
		});

		// ---- Tam süre bitince siyah ekran + geçiş ----
		final totalExitTime = fadeStartDelay + EXIT_FADE_TIME;

		new FlxTimer().start(totalExitTime, function(_)
		{
			// Blackout'u en üste getir
			remove(blackout, true);
			add(blackout);

			FlxTween.tween(blackout, {alpha: 1.0}, EXIT_HOLD_BLACK * 0.5, {
				ease: FlxEase.quadIn,
				onComplete: function(_)
				{
					new FlxTimer().start(EXIT_HOLD_BLACK, function(_)
					{
						MusicBeatState.switchState(new TitleState());
					});
				}
			});
		});
	}

	function fadeOutTexts():Void
	{
		final textElements:Array<FlxSprite> = [titleText, bodyText, hintText, versionText];

		for (i in 0...textElements.length)
		{
			final elem = textElements[i];
			if (elem != null)
			{
				FlxTween.tween(elem, {alpha: 0, y: elem.y - 12}, EXIT_TEXT_FADE, {
					startDelay: i * 0.03,
					ease: FlxEase.quadIn
				});
			}
		}
	}

	function suckParticlesIn():Void
	{
		final cx = FlxG.width * 0.5;
		final cy = FlxG.height * 0.5;

		for (p in particles)
		{
			FlxTween.tween(p, {
				x: cx - p.width * 0.5,
				y: cy - p.height * 0.5,
				alpha: 0
			}, EXIT_TEXT_FADE + Math.random() * 0.2, {
				ease: FlxEase.quadIn
			});
		}
	}

	// =========================================================================
	// SHADER FLOAT TWEEN HELPER
	// =========================================================================

	function tweenShaderFloat(from:Float, to:Float, duration:Float, ease:flixel.tweens.FlxEase.EaseFunction,
		onUpdate:Float->Void, ?onDone:Void->Void):Void
	{
		var dummy = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		dummy.alpha = 0;
		dummy.visible = false;
		add(dummy);

		final range = to - from;

		FlxTween.tween(dummy, {alpha: 1.0}, duration, {
			ease: ease,
			onUpdate: function(_)
			{
				final val = from + dummy.alpha * range;
				onUpdate(val);
			},
			onComplete: function(_)
			{
				onUpdate(to);
				remove(dummy, true);
				dummy.destroy();
				if (onDone != null) onDone();
			}
		});
	}

	inline function skipTransitions():Void
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
	}

	// =========================================================================
	// DESTROY
	// =========================================================================

	override function destroy()
	{
		if (warpEffect != null)
		{
			remove(warpEffect, true);
			warpEffect = null;
		}

		super.destroy();
	}
}

// =============================================================================
// PORTAL PARTICLE
// =============================================================================

class PortalParticle extends FlxSprite
{
	public var centerX:Float;
	public var centerY:Float;
	public var orbitRadius:Float = 100;
	public var orbitSpeed:Float = 1.0;
	public var orbitAngle:Float = 0;
	public var orbitDirection:Int = 1;
	public var baseAlpha:Float = 0.5;
	public var particleSize:Int = 4;

	public function new(cx:Float, cy:Float)
	{
		super(cx, cy);
		centerX = cx;
		centerY = cy;
	}
}
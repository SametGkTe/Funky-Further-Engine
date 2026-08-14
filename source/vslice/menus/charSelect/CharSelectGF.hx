package vslice.menus.charSelect;

import haxe.Exception;
import vslice.funkin.FlxAtlasSprite;
import vslice.funkin.FramesJSFLParser;
import vslice.funkin.FramesJSFLParser.FramesJSFLInfo;
import vslice.funkin.FramesJSFLParser.FramesJSFLFrame;
import flixel.math.FlxMath;
import funkin.vis.dsp.SpectralAnalyzer;

class CharSelectGF extends FlxAtlasSprite 
{
  var fadeTimer:Float = 0;
  var fadingStatus:FadeStatus = OFF;
  var fadeAnimIndex:Int = 0;

  var animInInfo:FramesJSFLInfo;
  var animOutInfo:FramesJSFLInfo;

  var intendedYPos:Float = 0;
  var intendedAlpha:Float = 0;

  var analyzer:SpectralAnalyzer;

  var currentGFPath:Null<String>;
  var enableVisualizer:Bool = false;

  public function new()
  {
    super(0, 0, null);

    switchGF("bf");
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    switch (fadingStatus)
    {
      case OFF:
        // do nothing if it's off!
        // or maybe force position to be 0,0?
        // maybe reset timers?
        resetFadeAnimParams();
      case FADE_OUT:
        doFade(animOutInfo);
      case FADE_IN:
        doFade(animInInfo);
      default:
    }

    #if FEATURE_DEBUG_FUNCTIONS
    if (FlxG.keys.justPressed.J)
    {
      alpha = 1;
      x = y = 0;
      fadingStatus = FADE_OUT;
    }
    if (FlxG.keys.justPressed.K)
    {
      alpha = 0;
      fadingStatus = FADE_IN;
    }
    #end
  }

  var danceEvery:Int = 2;

  public function onBeatHit(beat:Int):Void //? gather beat instead of event
  {
    // TODO: There's a minor visual bug where there's a little stutter.
    // This happens because the animation is getting restarted while it's already playing.
    // I tried make this not interrupt an existing idle,
    // but isAnimationFinished() and isLoopComplete() both don't work! What the hell?
    // danceEvery isn't necessary if that gets fixed.
    if (getCurrentAnimation() == "idle" && (beat % danceEvery == 0))
    {
      //trace('GF beat hit');
      playAnimation("idle", true, false, false);
    }
  };

	override public function draw()
	{
		if (analyzer != null && enableVisualizer)
		{
			try
			{
				drawFFT();
			}
			catch (e:Dynamic) {}
		}

		try
		{
			super.draw();
		}
		catch (e:Dynamic)
		{
			// Atlas henüz tam yüklenmemişse veya bozuksa sessizce geç
		}
	}

	function drawFFT()
	{
		try
		{
			if (!enableVisualizer)
				return;

			if (anim == null || anim.curSymbol == null || anim.curSymbol.timeline == null)
				return;

			var vizBars = anim.curSymbol.timeline.get("VIZ_bars");
			if (vizBars == null)
				return;

			var frame = vizBars.get(anim.curFrame);
			if (frame == null)
				return;

			var levels = analyzer.getLevels();
			var elements = frame.getList();
			var len:Int = cast Math.min(elements.length, 7);

			for (i in 0...len)
			{
				var animFrame:Int = Math.round(levels[i].value * 12);

				#if desktop
				// animFrame = Math.round(animFrame * FlxG.sound.volume);
				#end

				animFrame = Math.floor(Math.min(12, animFrame));
				animFrame = Math.floor(Math.max(0, animFrame));
				animFrame = Std.int(Math.abs(animFrame - 12));

				elements[i].symbol.firstFrame = animFrame;
			}
		}
		catch (x:Exception)
		{
		}
	}

  /**
   * @param animInfo Should not be confused with animInInfo!
   *                 This is merely a local var for the function!
   */
  function doFade(animInfo:FramesJSFLInfo):Void
  {
    // Null-guard: In/Out.txt bulunamadıysa fade yapma (crash yerine)
    if (animInfo == null || animInfo.frames == null || animInfo.frames.length < 2)
    {
      fadingStatus = OFF;
      return;
    }

    fadeTimer += FlxG.elapsed;
    if (fadeTimer >= 1 / 24)
    {
      fadeTimer -= FlxG.elapsed;
      // only inc the index for the first frame, used for reference of where to "start"
      if (fadeAnimIndex == 0)
      {
        fadeAnimIndex++;
        return;
      }

      if (fadeAnimIndex >= animInfo.frames.length)
      {
        fadingStatus = OFF;
        return;
      }

      var curFrame:FramesJSFLFrame = animInfo.frames[fadeAnimIndex];
      var prevFrame:FramesJSFLFrame = animInfo.frames[fadeAnimIndex - 1];

      if (curFrame == null || prevFrame == null)
      {
        fadeAnimIndex++;
        return;
      }

      var xDiff:Float = curFrame.x - prevFrame.x;
      var yDiff:Float = curFrame.y - prevFrame.y;
      var alphaDiff:Float = curFrame.alpha - prevFrame.alpha;
      alphaDiff /= 100; // flash exports alpha as a whole number

      alpha += alphaDiff;
      alpha = FlxMath.bound(alpha, 0, 1);
      x += xDiff;
      y += yDiff;

      fadeAnimIndex++;
    }

    if (fadeAnimIndex >= animInfo.frames.length) fadingStatus = OFF;
  }

  function resetFadeAnimParams()
  {
    fadeTimer = 0;
    fadeAnimIndex = 0;
  }

	public function switchGF(bf:String):Void
	{
		var previousGFPath = currentGFPath;

		if (bf == "locked")
		{
			this.visible = false;
			return;
		}

		var bfObj = PlayerRegistry.instance.fetchEntry(bf);
		var gfData = bfObj?.getCharSelectData()?.gf;
		currentGFPath = gfData?.assetPath != null ? gfData?.assetPath : null;

		trace('currentGFPath(${currentGFPath})');

		// Eğer bu karakter V-Slice player değilse → varsayılan gfChill kullan
		if (currentGFPath == null)
		{
			// Base game default GF'e dön
			var defaultBfObj = PlayerRegistry.instance.fetchEntry("bf");
			var defaultGfData = defaultBfObj?.getCharSelectData()?.gf;
			currentGFPath = defaultGfData?.assetPath ?? "charSelect/gfChill";

			var defaultAnimInfoPath = 'images/${defaultGfData?.animInfoPath ?? "charSelect/gfAnimInfo"}';
			
			this.visible = true;

			if (previousGFPath != currentGFPath)
			{
				loadAtlas(currentGFPath);
				enableVisualizer = false;

				// FramesJSFLParser.parse dosya yoksa THROW eder (try/catch'siz sessiz çöküş!)
				// → In/Out.txt bulunamazsa null bırak, fade animasyonları atlanır.
				try
				{
					animInInfo = FramesJSFLParser.parse(defaultAnimInfoPath + '/In.txt');
				}
				catch (e)
				{
					animInInfo = null;
					trace('[CharSelectGF] In.txt yok, fade atlanıyor: ' + defaultAnimInfoPath + '/In.txt');
				}

				try
				{
					animOutInfo = FramesJSFLParser.parse(defaultAnimInfoPath + '/Out.txt');
				}
				catch (e)
				{
					animOutInfo = null;
					trace('[CharSelectGF] Out.txt yok, fade atlanıyor: ' + defaultAnimInfoPath + '/Out.txt');
				}
			}

			playAnimation("idle", true, false, false);
			updateHitbox();
			return;
		}

		if (previousGFPath != currentGFPath)
		{
			this.visible = true;
			loadAtlas(currentGFPath);
			enableVisualizer = gfData?.visualizer ?? false;
			var animInfoPath = 'images/${gfData?.animInfoPath}';

			// Aynı şekilde In/Out.txt yoksa throw → try/catch ile koru
			try
			{
				animInInfo = FramesJSFLParser.parse(animInfoPath + '/In.txt');
			}
			catch (e)
			{
				animInInfo = null;
				trace('[CharSelectGF] In.txt yok: ' + animInfoPath + '/In.txt');
			}

			try
			{
				animOutInfo = FramesJSFLParser.parse(animInfoPath + '/Out.txt');
			}
			catch (e)
			{
				animOutInfo = null;
				trace('[CharSelectGF] Out.txt yok: ' + animInfoPath + '/Out.txt');
			}
		}
		
		if (anim == null || anim.stageInstance == null)
		{
			trace('[CharSelectGF] Atlas loaded but invalid for path: ' + currentGFPath);
			this.visible = false;
			return;
		}

		playAnimation("idle", true, false, false);
		updateHitbox();
	}
}

enum FadeStatus
{
  OFF;
  FADE_OUT;
  FADE_IN;
}

enum abstract GFChar(String) from String to String
{
  var GF = "gf";
  var NENE = "nene";
}

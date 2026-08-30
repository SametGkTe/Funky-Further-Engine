package vslice.menus.results;

import vslice.funkin.custom.mobile.MobileScaleMode;
import haxe.Exception;
import vslice.compatibility.ModsHelper;
import vslice.compatibility.VsliceOptions;
import vslice.funkin.FlxAtlasSprite;
import vslice.funkin.FunkinSprite;
import vslice.funkin.players.PlayerData;
import flixel.FlxSubState;
import vslice.compatibility.freeplay.FreeplayHelpers;
import vslice.compatibility.funkin.FunkinPath as Paths;
import vslice.menus.results.Tallies.SaveScoreData;
import vslice.compatibility.funkin.FunkinCamera;
import vslice.menus.freeplay.FreeplayState;
import flixel.addons.transition.FlxTransitionableState;
import vslice.menus.StickerSubState;
import vslice.funkin.Scoring;
import shaders.LeftMaskShader;
import flixel.FlxSprite;

import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxBitmapFont;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;

import flixel.math.FlxRect;
import flixel.text.FlxBitmapText;

import flixel.util.FlxColor;
import flixel.tweens.FlxEase;

import flixel.tweens.FlxTween;
import flixel.addons.display.FlxBackdrop;

import flixel.util.FlxGradient;
import flixel.util.FlxTimer;
import vslice.funkin.players.*;
import vslice.funkin.players.PlayerData.PlayerFreeplayDJData;
import vslice.funkin.custom.VsliceSubState as MusicBeatSubState;

class ResultState extends MusicBeatSubState
{
  final params:ResultsStateParams;

  final rank:ScoringRank;
  final songName:FlxBitmapText;
  final difficulty:FlxBitmapText;
  final clearPercentSmall:ClearPercentCounter;

  final maskShaderSongName:LeftMaskShader = new LeftMaskShader();
  final maskShaderDifficulty:LeftMaskShader = new LeftMaskShader();

  final resultsAnim:FunkinSprite;
  final ratingsPopin:FunkinSprite;
  final scorePopin:FunkinSprite;

  final bgFlash:FlxSprite;

  final highscoreNew:FlxSprite;
  final score:ResultScore;

  var characterAtlasAnimations:Array<
    {
      sprite:FlxAtlasSprite,
      delay:Float,
      forceLoop:Bool,
      startFrameLabel:String,
      sound:String
    }> = [];
  var characterSparrowAnimations:Array<
    {
      sprite:FunkinSprite,
      delay:Float
    }> = [];

  var playerCharacterId:Null<String>;

  var rankBg:FunkinSprite;
  final cameraBG:FunkinCamera;
  final cameraScroll:FunkinCamera;
  final cameraEverything:FunkinCamera;

  public function new(params:ResultsStateParams)
  {
    super();

    this.params = params;

    rank = Scoring.calculateRank(params.scoreData) ?? SHIT;

    cameraBG = new FunkinCamera('resultsBG', 0, 0, FlxG.width, FlxG.height);
    cameraScroll = new FunkinCamera('resultsScroll', 0, 0, FlxG.width, FlxG.height);
    cameraEverything = new FunkinCamera('resultsEverything', 0, 0, FlxG.width, FlxG.height);

    var fontLetters:String = "AaBbCcDdEeFfGgHhiIJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz:1234567890";
    songName = new FlxBitmapText(FlxBitmapFont.fromMonospace(Paths.image("resultScreen/tardlingSpritesheet"), fontLetters, FlxPoint.get(49, 62)));
    songName.text = params.title;
    songName.letterSpacing = -15;
    songName.angle = -4.4;
    var difColor = PlayState.storyDifficultyColor;
    var fractal = difColor.redFloat*0.33;
    difColor.greenFloat = Math.max(difColor.greenFloat,fractal);

    difficulty = new FlxBitmapText(FlxBitmapFont.fromMonospace(Paths.image("resultScreen/tardlingSpritesheet"), fontLetters, FlxPoint.get(49, 62)));
    difficulty.text = FreeplayHelpers.getDifficultyName();
    difficulty.color = difColor;
    difficulty.letterSpacing = -11;
    difficulty.angle = -4.4;

    clearPercentSmall = new ClearPercentCounter(FlxG.width / 2 + 300, FlxG.height / 2 - 100, 100, true);
    clearPercentSmall.visible = false;

    bgFlash = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFFF1A6, 0xFFFFF1BE], 90);

    resultsAnim = FunkinSprite.createSparrow(FlxG.width -(1480 + (MobileScaleMode.gameCutoutSize.x / 2)), -10, "resultScreen/results");

    ratingsPopin = FunkinSprite.createSparrow(-135+ MobileScaleMode.gameNotchSize.x, 135, "resultScreen/ratingsPopin");

    scorePopin = FunkinSprite.createSparrow(-180+ MobileScaleMode.gameNotchSize.x, 515, "resultScreen/scorePopin");

    highscoreNew = new FlxSprite(44+ MobileScaleMode.gameNotchSize.x, 557);

    score = new ResultScore(35+ MobileScaleMode.gameNotchSize.x, 305, 10, params.scoreData.score);

    rankBg = new FunkinSprite(0, 0);

    var sngMeta = FreeplayMeta.getMeta(params.songId);
    
    if(sngMeta.freeplayCharacter != '' ){
      playerCharacterId = sngMeta.freeplayCharacter;
    }
    else if (!PlayState.isStoryMode){
      var mod_char = VsliceOptions.LAST_MOD;
      playerCharacterId = mod_char.char_name;
      ModsHelper.loadModDir(mod_char.mod_dir);
    }
    else{
      playerCharacterId = "bf";
    }
  }

  override function create():Void
  {
    if (FlxG.sound.music != null) FlxG.sound.music.stop();

    cameraScroll.angle = -3.8;

    cameraBG.bgColor = FlxColor.MAGENTA;
    cameraScroll.bgColor = FlxColor.TRANSPARENT;
    cameraEverything.bgColor = FlxColor.TRANSPARENT;

    FlxG.cameras.add(cameraBG, false);
    FlxG.cameras.add(cameraScroll, false);
    FlxG.cameras.add(cameraEverything, false);

    FlxG.cameras.setDefaultDrawTarget(cameraEverything, true);
    this.camera = cameraEverything;

    FlxG.camera.zoom = 1.0;

    var bg:FlxSprite = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFECC5C, 0xFFFDC05C], 90);
    bg.scrollFactor.set();
    bg.cameras = [cameraBG];
    add(bg);

    bgFlash.scrollFactor.set();
    bgFlash.visible = false;
    add(bgFlash);

    var soundSystem:FlxSprite = FunkinSprite.createSparrow(-15+ MobileScaleMode.gameNotchSize.x, -180, 'resultScreen/soundSystem');
    soundSystem.animation.addByPrefix("idle", "sound system", 24, false);
    soundSystem.visible = false;
    new FlxTimer().start(8 / 24, _ -> {
      soundSystem.animation.play("idle");
      soundSystem.visible = true;
    });
    add(soundSystem);

    
    var playerCharacter:Null<PlayableCharacter> = PlayerRegistry.instance.fetchEntry(playerCharacterId ?? 'bf');

    var playerAnimationDatas:Array<PlayerResultsAnimationData> = playerCharacter != null ? playerCharacter.getResultsAnimationDatas(rank) : [];

    for (animData in playerAnimationDatas)
    {
      if (animData == null) continue;

      switch (animData.filter){
        case ""|"both"|null:
        case "naughty":
          if(!VsliceOptions.NAUGHTYNESS) continue;        
        case "safe":
          if(VsliceOptions.NAUGHTYNESS) continue;
        default: 
          trace(animData.filter+" is not a valid filter!");
          continue; 
      }

      var animPath:String = "";
      var animLibrary:String = "";

      if (animData.assetPath != null)
      {
        animPath = Paths.stripLibrary(animData.assetPath);
        animLibrary = "";
      }
      var offsets = animData.offsets ?? [0, 0];
      try{

      
      switch (animData.renderType)
      {
        case 'animateatlas':

          var animation:FlxAtlasSprite = new FlxAtlasSprite(offsets[0] + MobileScaleMode.gameNotchSize.x, offsets[1], animPath);
          animation.scale.set(animData.scale ?? 1.0, animData.scale ?? 1.0);

          if (!(animData.looped ?? true))
            {
              animation.onAnimationComplete.add((_name:String) -> {
                if (animation != null)
                {
                  animation.anim.pause();
                }
              });
            }
            else if (animData.loopFrameLabel != null)
            {
              animation.onAnimationComplete.add((_name:String) -> {
                if (animation != null)
                {
                  animation.playAnimation(animData.loopFrameLabel ?? '', true, false, true);
                }
              });
            }
            else if (animData.loopFrame != null)
            {
              animation.onAnimationComplete.add((_name:String) -> {
                if (animation != null)
                {
                  animation.anim.curFrame = animData.loopFrame ?? 0;
                  animation.anim.play();
                }
              });
            }

          animation.visible = false;
          characterAtlasAnimations.push(
            {
              sprite: animation,
              delay: animData.delay ?? 0.0,
              forceLoop: (animData.loopFrame ?? -1) == 0,
              startFrameLabel: (animData.startFrameLabel ?? ""),
              sound: (animData.sound ?? "")
            });
          add(animation);
        case 'sparrow':
          var animation:FunkinSprite = FunkinSprite.createSparrow(offsets[0] + MobileScaleMode.gameNotchSize.x, offsets[1], animPath);
          animation.animation.addByPrefix('idle', '', 24, false, false, false);

          if (animData.loopFrame != null)
          {
            animation.animation.finishCallback = (_name:String) -> {
              if (animation != null)
              {
                animation.animation.play('idle', true, false, animData.loopFrame ?? 0);
              }
            }
          }

          animation.visible = false;
          characterSparrowAnimations.push(
            {
              sprite: animation,
              delay: animData.delay ?? 0.0
            });
          add(animation);
      }
      }
      catch(error:Exception){
        trace("Failed to load "+animPath);
        trace(error);
      }
    }

    var diffSpr:String = 'diff_${params?.difficultyId ?? 'Normal'}';
    difficulty.loadGraphic(Paths.image("resultScreen/" + diffSpr));
    add(difficulty);

    add(songName);

    var angleRad = songName.angle * Math.PI / 180;
    speedOfTween.x = -1.0 * Math.cos(angleRad);
    speedOfTween.y = -1.0 * Math.sin(angleRad);

    timerThenSongName(1.0, false);

    var blackTopBar:FlxSprite = new FlxSprite().loadGraphic(BitmapUtil.createResultsBar());
    blackTopBar.y = -blackTopBar.height;
    FlxTween.tween(blackTopBar, {y: 0}, 7 / 24, {ease: FlxEase.quartOut, startDelay: 3 / 24});
    add(blackTopBar);

    resultsAnim.animation.addByPrefix("result", "results instance 1", 24, false);
    resultsAnim.visible = false;
    add(resultsAnim);
    new FlxTimer().start(6 / 24, _ -> {
      resultsAnim.visible = true;
      resultsAnim.animation.play("result");
    });

    ratingsPopin.animation.addByPrefix("idle", "Categories", 24, false);
    ratingsPopin.visible = false;
    add(ratingsPopin);
    new FlxTimer().start(21 / 24, _ -> {
      ratingsPopin.visible = true;
      ratingsPopin.animation.play("idle");
    });

    scorePopin.animation.addByPrefix("score", "tally score", 24, false);
    scorePopin.visible = false;
    add(scorePopin);
    new FlxTimer().start(36 / 24, _ -> {
      scorePopin.visible = true;
      scorePopin.animation.play("score");
      scorePopin.animation.finishCallback = anim -> {};
    });

    new FlxTimer().start(37 / 24, _ -> {
      score.visible = true;
      score.animateNumbers();
      startRankTallySequence();
    });

    new FlxTimer().start(rank.getBFDelay(), _ -> {
      afterRankTallySequence();
    });

    new FlxTimer().start(rank.getFlashDelay(), _ -> {
      displayRankText();
    });

    highscoreNew.frames = Paths.getSparrowAtlas("resultScreen/highscoreNew");
    highscoreNew.animation.addByPrefix("new", "highscoreAnim0", 24, false);
    highscoreNew.visible = false;
    highscoreNew.updateHitbox();
    add(highscoreNew);

    new FlxTimer().start(rank.getHighscoreDelay(), _ -> {
      if (params.isNewHighscore ?? false)
      {
        highscoreNew.visible = true;
        highscoreNew.animation.play("new");
        highscoreNew.animation.finishCallback = _ -> highscoreNew.animation.play("new", true, false, 16);
      }
      else
      {
        highscoreNew.visible = false;
      }
    });

    var hStuf:Int = 50;

    var ratingGrp:FlxTypedGroup<TallyCounter> = new FlxTypedGroup<TallyCounter>();
    add(ratingGrp);

    var totalHit:TallyCounter = new TallyCounter(375 + MobileScaleMode.gameNotchSize.x, hStuf * 3, params.scoreData.totalNotesHit);
    ratingGrp.add(totalHit);

    var maxCombo:TallyCounter = new TallyCounter(375 + MobileScaleMode.gameNotchSize.x, hStuf * 4, params.scoreData.maxCombo);
    ratingGrp.add(maxCombo);

    hStuf += 2;
    var extraYOffset:Float = 7;

    hStuf += 2;

    var tallySick:TallyCounter = new TallyCounter(230 + MobileScaleMode.gameNotchSize.x, (hStuf * 5) + extraYOffset, params.scoreData.sick, 0xFF89E59E);
    ratingGrp.add(tallySick);

    var tallyGood:TallyCounter = new TallyCounter(210+ MobileScaleMode.gameNotchSize.x, (hStuf * 6) + extraYOffset, params.scoreData.good, 0xFF89C9E5);
    ratingGrp.add(tallyGood);

    var tallyBad:TallyCounter = new TallyCounter(190 + MobileScaleMode.gameNotchSize.x, (hStuf * 7) + extraYOffset, params.scoreData.bad, 0xFFE6CF8A);
    ratingGrp.add(tallyBad);

    var tallyShit:TallyCounter = new TallyCounter(220 + MobileScaleMode.gameNotchSize.x, (hStuf * 8) + extraYOffset, params.scoreData.shit, 0xFFE68C8A);
    ratingGrp.add(tallyShit);

    var tallyMissed:TallyCounter = new TallyCounter(260 + MobileScaleMode.gameNotchSize.x, (hStuf * 9) + extraYOffset, params.scoreData.missed, 0xFFC68AE6);
    ratingGrp.add(tallyMissed);

    score.visible = false;
    add(score);

    for (ind => rating in ratingGrp.members)
    {
      rating.visible = false;
      new FlxTimer().start((0.3 * ind) + 1.20, _ -> {
        rating.visible = true;
        FlxTween.tween(rating, {curNumber: rating.neededNumber}, 0.5, {ease: FlxEase.quartOut});
      });
    }

    new FlxTimer().start(rank.getMusicDelay(), _ -> {
      var introMusic:String = getMusicPath(playerCharacter, rank) + '/' + getMusicPath(playerCharacter, rank) + '-intro';
      if (Paths.exists('music/$introMusic.ogg'))
      {
        FlxG.sound.music = FunkinSound.load(Paths.music(introMusic), 1.0, false, true, true, () -> {
          FunkinSound.playMusic(getMusicPath(playerCharacter, rank),
            {
              startingVolume: 1.0,
              overrideExisting: true,
              restartTrack: true
            });
        });
      }
      else
      {
        FunkinSound.playMusic(getMusicPath(playerCharacter, rank),
          {
            startingVolume: 1.0,
            overrideExisting: true,
            restartTrack: true
          });
      }
    });

    rankBg.makeSolidColor(FlxG.width, FlxG.height, 0xFF000000);
    add(rankBg);

    rankBg.alpha = 0;

    refresh();

    super.create();
  }

  function getMusicPath(playerCharacter:Null<PlayableCharacter>, rank:ScoringRank):String
  {
    return playerCharacter?.getResultsMusicPath(rank) ?? 'resultsNORMAL';
  }

  var rankTallyTimer:Null<FlxTimer> = null;
  var clearPercentTarget:Int = 100;
  var clearPercentLerp:Int = 0;

  function startRankTallySequence():Void
  {
    bgFlash.visible = true;
    FlxTween.tween(bgFlash, {alpha: 0}, 5 / 24);
    var clearPercentFloat = (params.scoreData.accPoints/params.scoreData.totalNotesHit)* 100;
    if(params.scoreData.totalNotesHit == 0) clearPercentFloat = 0;
    clearPercentTarget = Math.floor(clearPercentFloat);

    clearPercentLerp = Std.int(Math.max(0, clearPercentTarget - 36));

    trace('Clear percent target: ' + clearPercentFloat + ', round: ' + clearPercentTarget);

    var clearPercentCounter:ClearPercentCounter = new ClearPercentCounter(FlxG.width / 2 + 190, FlxG.height / 2 - 70, clearPercentLerp);
    FlxTween.tween(clearPercentCounter, {curNumber: clearPercentTarget}, 58 / 24,
      {
        ease: FlxEase.quartOut,
        onUpdate: _ -> {
          if (clearPercentLerp != clearPercentCounter.curNumber)
          {
            clearPercentLerp = clearPercentCounter.curNumber;
            FunkinSound.playOnce(Paths.sound('scrollMenu'));
          }
        },
        onComplete: _ -> {
          FunkinSound.playOnce(Paths.sound('confirmMenu'));

          clearPercentCounter.curNumber = clearPercentTarget;

          clearPercentCounter.flash(true);
          new FlxTimer().start(0.4, _ -> {
            clearPercentCounter.flash(false);
          });

          new FlxTimer().start(0.25, _ -> {
            FlxTween.tween(clearPercentCounter, {alpha: 0}, 0.5,
              {
                startDelay: 0.5,
                ease: FlxEase.quartOut,
                onComplete: _ -> {
                  remove(clearPercentCounter);
                }
              });
          });
        }
      });
    add(clearPercentCounter);

    if (ratingsPopin == null)
    {
      trace("Could not build ratingsPopin!");
    }
    else
    {
      ratingsPopin.animation.finishCallback = anim -> {
        if (params.isNewHighscore ?? false)
        {
          highscoreNew.visible = true;
          highscoreNew.animation.play("new");
        }
        else
        {
          highscoreNew.visible = false;
        }
      };
    }

    refresh();
  }

  function displayRankText():Void
  {
    bgFlash.visible = true;
    bgFlash.alpha = 1;
    FlxTween.tween(bgFlash, {alpha: 0}, 14 / 24);

    var rankTextVert:FlxBackdrop = new FlxBackdrop(Paths.image(rank.getVerTextAsset()), Y, 0, 30);
    rankTextVert.x = FlxG.width - 44;
    rankTextVert.y = 100;
    add(rankTextVert);

    FlxFlicker.flicker(rankTextVert, 2 / 24 * 3, 2 / 24, true);

    new FlxTimer().start(30 / 24, _ -> {
      rankTextVert.velocity.y = -80;
    });

    for (i in 0...12)
    {
      var rankTextBack:FlxBackdrop = new FlxBackdrop(Paths.image(rank.getHorTextAsset()), X, 10, 0);
      rankTextBack.x = FlxG.width / 2 - 320;
      rankTextBack.y = 50 + (135 * i / 2) + 10;
      rankTextBack.cameras = [cameraScroll];
      add(rankTextBack);

      rankTextBack.velocity.x = (i % 2 == 0) ? -7.0 : 7.0;
    }

    refresh();
  }

  function afterRankTallySequence():Void
  {
    showSmallClearPercent();

    for (atlas in characterAtlasAnimations)
    {
      new FlxTimer().start(atlas.delay, _ -> {
        if (atlas.sprite == null) return;
        atlas.sprite.visible = true;
        atlas.sprite.playAnimation(atlas.startFrameLabel);
        if (atlas.sound != "")
        {
          var sndPath:String = Paths.stripLibrary(atlas.sound);
          var sndLibrary:String = "";

          FunkinSound.playOnce(Paths.sound(sndPath), 1.0);
        }
      });
    }

    for (sprite in characterSparrowAnimations)
    {
      new FlxTimer().start(sprite.delay, _ -> {
        if (sprite.sprite == null) return;
        sprite.sprite.visible = true;
        sprite.sprite.animation.play('idle', true);
      });
    }
  }

  private function handleAnimationVibrations()
  {
    for (atlas in characterAtlasAnimations)
    {
      if (atlas == null || atlas.sprite == null) continue;

      switch (rank)
      {
        case ScoringRank.PERFECT | ScoringRank.PERFECT_GOLD:
          switch (playerCharacterId)
          {
            case "bf":
              if (atlas.sprite.anim.curFrame > 87 && atlas.sprite.anim.curFrame % 5 == 0)
              {
                HapticUtil.vibrate(0, 0.01, Constants.MAX_VIBRATION_AMPLITUDE);
                break;
              }

              if (atlas.sprite.anim.curFrame == 51)
              {
                HapticUtil.vibrate(0, 0.01, (Constants.MAX_VIBRATION_AMPLITUDE / 3) * 2.5);
                break;
              }

            case "pico":
              if (atlas.sprite.anim.curFrame == 52)
              {
                HapticUtil.vibrate(Constants.DEFAULT_VIBRATION_PERIOD, Constants.DEFAULT_VIBRATION_DURATION * 5, Constants.MAX_VIBRATION_AMPLITUDE);
                break;
              }

            default:
              break;
          }

        case ScoringRank.GREAT | ScoringRank.EXCELLENT:
          switch (playerCharacterId)
          {
            case "pico":
              if (atlas.sprite.anim.curFrame == 45)
              {
                HapticUtil.vibrate(0, 0.01, (Constants.MAX_VIBRATION_AMPLITUDE / 3) * 2.5);
                break;
              }

              if (atlas.sprite.anim.curFrame == 50)
              {
                HapticUtil.vibrate(Constants.DEFAULT_VIBRATION_PERIOD, Constants.DEFAULT_VIBRATION_DURATION, Constants.MAX_VIBRATION_AMPLITUDE);
                break;
              }

            default:
              break;
          }

        case ScoringRank.GOOD:
          switch (playerCharacterId)
          {
            case "pico":
              if (atlas.sprite.anim.curFrame % 2 != 0) continue;

              final frames:Array<Array<Int>> = [[40, 50], [80, 90], [140, 157]];
              for (i in 0...frames.length)
              {
                if (atlas.sprite.anim.curFrame < frames[i][0] || atlas.sprite.anim.curFrame > frames[i][1]) continue;

                HapticUtil.vibrate(0, 0.01, Constants.MAX_VIBRATION_AMPLITUDE);
                break;
              }

            default:
              break;
          }

        case ScoringRank.SHIT:
          switch (playerCharacterId)
          {
            case "bf":
              if (atlas.sprite.anim.curFrame == 5 || atlas.sprite.anim.curFrame == 90)
              {
                HapticUtil.vibrate(Constants.DEFAULT_VIBRATION_PERIOD * 2, Constants.DEFAULT_VIBRATION_DURATION * 2, Constants.MAX_VIBRATION_AMPLITUDE);
                break;
              }

            default:
              break;
          }
      }
    }
  }

  function timerThenSongName(timerLength:Float = 3.0, autoScroll:Bool = true):Void
  {
    movingSongStuff = false;

    difficulty.x = 555 + MobileScaleMode.gameNotchSize.x;

    var diffYTween:Float = 122;

    difficulty.y = -difficulty.height;
    FlxTween.tween(difficulty, {y: diffYTween}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.8});

    if (clearPercentSmall != null)
    {
      clearPercentSmall.x = (difficulty.x + difficulty.width) + 60;
      clearPercentSmall.y = -clearPercentSmall.height;
      FlxTween.tween(clearPercentSmall, {y: 122 - 5}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.85});
    }

    songName.y = -songName.height;
    var fuckedupnumber = (10) * (songName.text.length / 15);
    FlxTween.tween(songName, {y: diffYTween - 25 - fuckedupnumber}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.9});
    songName.x = clearPercentSmall.x + 94;

    new FlxTimer().start(timerLength, _ -> {
      var tempSpeed = FlxPoint.get(speedOfTween.x, speedOfTween.y);

      speedOfTween.set(0, 0);
      FlxTween.tween(speedOfTween, {x: tempSpeed.x, y: tempSpeed.y}, 0.7, {ease: FlxEase.quadIn});

      movingSongStuff = (autoScroll);
    });
  }

  function showSmallClearPercent():Void
  {
    if (clearPercentSmall != null)
    {
      add(clearPercentSmall);
      clearPercentSmall.visible = true;
      clearPercentSmall.flash(true);
      new FlxTimer().start(0.4, _ -> {
        clearPercentSmall.flash(false);
      });

      clearPercentSmall.curNumber = clearPercentTarget;
      refresh();
    }

    new FlxTimer().start(2.5, _ -> {
      movingSongStuff = true;
    });
  }

  var movingSongStuff:Bool = false;
  var speedOfTween:FlxPoint = FlxPoint.get(-1, 1);
  var resultsAutoSkipTimer:Float = 0;
  var resultsAutoSkipFired:Bool = false;

  override function draw():Void
  {
    super.draw();

    songName.clipRect = FlxRect.get(Math.max(0, 520 - songName.x), 0, FlxG.width, songName.height);
  }

  override function update(elapsed:Float):Void
  {
    maskShaderDifficulty.swagSprX = difficulty.x;

    if (movingSongStuff)
    {
      var deltaScale = elapsed*190;
      songName.x += speedOfTween.x*deltaScale;
      difficulty.x += speedOfTween.x*deltaScale;
      clearPercentSmall.x += speedOfTween.x*deltaScale;
      songName.y += speedOfTween.y*deltaScale;
      difficulty.y += speedOfTween.y*deltaScale;
      clearPercentSmall.y += speedOfTween.y*deltaScale;

      if (songName.x + songName.width < 100)
      {
        timerThenSongName();
      }
    }

    if (FlxG.keys.justPressed.RIGHT) speedOfTween.x += 0.1;

    if (FlxG.keys.justPressed.LEFT)
    {
      speedOfTween.x -= 0.1;
    }

    var autoSkipTrigger:Bool = false;
    var autoSkip:Int = ClientPrefs.data.resultsAutoSkip;
    if (autoSkip > 0 && !resultsAutoSkipFired)
    {
      resultsAutoSkipTimer += elapsed;
      if (resultsAutoSkipTimer >= autoSkip)
      {
        resultsAutoSkipFired = true;
        autoSkipTrigger = true;
      }
    }

    if (TouchUtil.justPressed || controls.PAUSE || autoSkipTrigger)
    {
      if (FlxG.sound.music != null)
      {
        FlxTween.tween(FlxG.sound.music, {volume: 0}, 0.8);
        FlxTween.tween(FlxG.sound.music, {pitch: 3}, 0.1,
          {
            onComplete: _ -> {
              FlxTween.tween(FlxG.sound.music, {pitch: 0.5}, 0.4);
            }
          });
      }

      var targetState = MenuStyleRouter.getMainMenu();
      var shouldTween = false;
      var shouldUseSubstate = false;

      if (params.storyMode)
      {
        FlxG.sound.pause();

        if (MenuStyleRouter.isNewStyle())
        {
          shouldTween = false;
          shouldUseSubstate = true;
          targetState = new StickerSubState(null, (sticker) -> new vslice.menus.states.StoryMenuState(sticker));
        }
        else
        {
          shouldTween = false;
          shouldUseSubstate = true;
          targetState = new StickerSubState(null, (sticker) -> new states.StoryMenuState());
        }
      }
      else
      {
        if (MenuStyleRouter.isNewStyle())
        {
          if (rank > params.prevScoreRank)
          {
            trace('THE RANK IS Higher.....');

            shouldTween = true;
            controls.isInSubstate = FlxTransitionableState.skipNextTransOut = true;

            targetState = vslice.menus.freeplay.FreeplayState.build(
              {
                fromResults:
                {
                  oldRank: params.prevScoreRank,
                  newRank: rank,
                  songId: params.songId,
                  difficultyId: params.difficultyId,
                  playRankAnim: true
                }
              });
          }
          else
          {
            FlxG.sound.pause();
            shouldTween = false;
            controls.isInSubstate = shouldUseSubstate = true;

            targetState = new StickerSubState(null, (sticker) ->
              vslice.menus.freeplay.FreeplayState.build(null, sticker)
            );
          }
        }
        else
        {
          FlxG.sound.pause();
          shouldTween = false;
          shouldUseSubstate = true;
          controls.isInSubstate = true;

          var hasNewRank:Bool = rank > params.prevScoreRank;

          targetState = new StickerSubState(null, (sticker) ->
            new states.FreeplayState(
              hasNewRank ? {
                fromResults:
                {
                  oldRank: params.prevScoreRank,
                  newRank: rank,
                  songId: params.songId,
                  difficultyId: params.difficultyId,
                  playRankAnim: true
                }
              } : null,
              sticker
            )
          );
        }
      }

      if (shouldTween)
      {
        FlxTween.tween(rankBg, {alpha: 1}, 0.5,
          {
            ease: FlxEase.expoOut,
            onComplete: function(_) {
              if (shouldUseSubstate && targetState is FlxSubState)
              {
                openSubState(cast targetState);
              }
              else
              {
                FlxG.sound.pause();
                states.LoadingState.loadAndSwitchState(targetState, true, true);
              }
            }
          });
      }
      else
      {
        if (shouldUseSubstate && targetState is FlxSubState)
        {
          openSubState(cast targetState);
        }
        else
        {
          states.LoadingState.loadAndSwitchState(targetState, true, true);
        }
      }
    }
    
    if (HapticUtil.hapticsAvailable) handleAnimationVibrations();
    super.update(elapsed);
  }
}

typedef ResultsStateParams =
{
  var storyMode:Bool;

  var title:String;

  var songId:String;

  var ?characterId:String;

  var ?isNewHighscore:Bool;

  var ?difficultyId:String;

  var scoreData:SaveScoreData;

  var prevScoreRank:ScoringRank;
};

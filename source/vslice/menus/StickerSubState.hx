package vslice.menus;

import vslice.compatibility.ModsHelper;
import vslice.menus.components.crash.UserErrorSubstate;
import vslice.compatibility.VsliceOptions;
import states.MainMenuState;

import flixel.FlxSprite;
import haxe.Json;
import lime.utils.Assets;
// import flxtyped group
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxTimer;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.util.FlxSort;
import flixel.addons.transition.FlxTransitionableState;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.display.Sprite;
import openfl.display.Bitmap;
import flixel.FlxState;

using Lambda;
using vslice.funkin.IteratorTools;

class StickerSubState extends MusicBeatSubstate
{
  public static var STICKER_SET = "stickers-set-1";
  public static var STICKER_PACK = "all";
  public var grpStickers:FlxTypedGroup<StickerSprite>;

  // yes... a damn OpenFL sprite!!!
  public var dipshit:Sprite;

  /**
   * The state to switch to after the stickers are done.
   * This is a FUNCTION so we can pass it directly to `FlxG.switchState()`,
   * and we can add constructor parameters in the caller.
   */
  var targetState:StickerSubState->FlxState;

  // what "folders" to potentially load from (as of writing only "keys" exist)
  var soundSelections:Array<String> = [];
  // what "folder" was randomly selected
  var soundSelection:String = "";
  var sounds:Array<String> = [];

  public function new(?oldStickers:Array<StickerSprite>, ?targetState:StickerSubState->FlxState):Void
  {
    //controls.isInSubstate = true;
    super();

    this.targetState = (targetState == null) ? ((sticker) -> new MainMenuState()) : targetState;

    // todo still
    // make sure that ONLY plays mp3/ogg files
    // if there's no mp3/ogg file, then it regenerates/reloads the random folder

    var assetsInList = openfl.utils.Assets.list();

    var soundFilterFunc = function(a:String) {
      return a.startsWith('assets/shared/sounds/stickersounds/');
    };

    soundSelections = assetsInList.filter(soundFilterFunc);
    soundSelections = soundSelections.map(function(a:String) {
      return a.replace('assets/shared/sounds/stickersounds/', '').split('/')[0];
    });

    // cracked cleanup... yuchh...
    for (i in soundSelections)
    {
      while (soundSelections.contains(i))
      {
        soundSelections.remove(i);
      }
      soundSelections.push(i);
    }

    soundSelection = FlxG.random.getObject(soundSelections);

    var filterFunc = function(a:String) {
      return a.startsWith('assets/shared/sounds/stickersounds/' + soundSelection + '/');
    };
    var assetsInList3 = openfl.utils.Assets.list();
    sounds = assetsInList3.filter(filterFunc);
    for (i in 0...sounds.length)
    {
      sounds[i] = sounds[i].replace('assets/shared/sounds/', '');
      sounds[i] = sounds[i].substring(0, sounds[i].lastIndexOf('.'));
    }

    grpStickers = new FlxTypedGroup<StickerSprite>();
    add(grpStickers);

    // makes the stickers on the most recent camera, which is more often than not... a UI camera!!
    // grpStickers.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
    grpStickers.cameras = FlxG.cameras.list;

    if (oldStickers != null)
    {
      for (sticker in oldStickers)
      {
        grpStickers.add(sticker);
      }

      degenStickers();
    }
    else
      regenStickers();
  }

  public function degenStickers():Void
  {
    grpStickers.cameras = FlxG.cameras.list;

    /*
      if (dipshit != null)
      {
        FlxG.removeChild(dipshit);
        dipshit = null;
      }
     */

    if (grpStickers.members == null || grpStickers.members.length == 0)
    {
      switchingState = false;
      close();
      return;
    }

    for (ind => sticker in grpStickers.members)
    {
      new FlxTimer().start(sticker.timing, _ -> {
        sticker.visible = false;
        var daSound:String = FlxG.random.getObject(sounds);
        #if !LEGACY_PSYCH
        new FlxSound().loadEmbedded(Paths.sound(daSound)).play();
        #else
        new FlxSound().loadEmbedded(Paths.sound(daSound,"shared")).play();
        #end

        if (grpStickers == null || ind == grpStickers.members.length - 1)
        {
          switchingState = false;
          FlxTransitionableState.skipNextTransIn = false;
          close();
        }
      });
    }
  }

  function regenStickers():Void
  {
    if (grpStickers.members.length > 0)
    {
      grpStickers.clear();
    }

    trace("Collecting stickers...");
    trace("Current mod: "+ModsHelper.getActiveMod());
    var stickers:StickerInfo = null;

    try
    {
      var infoObj = new StickerInfo(STICKER_SET);
      stickers = infoObj;

      if (infoObj.getPack(STICKER_PACK) == null)
      {
        trace('Sticker pack "$STICKER_PACK" missing, all sticker groups will be used.');
      }
    }
    catch (x:Dynamic)
    {
      trace('FAILED TO LOAD STICKER SET: ' + STICKER_SET);
      UserErrorSubstate.makeMessage('Sticker load error', 'Could not load sticker set "$STICKER_SET"\n\n$x');
      stickers = null;
    }
    // sticker group -> array of sticker names

    var xPos:Float = -100;
    var yPos:Float = -100;
    while (xPos <= FlxG.width)
    {
      // A little complicateb block, so let me explain:
      var sticky:StickerSprite = null;
      // Determinate if we actually have a valid set.
      if (stickers != null)
      {
        var stickerPack:Array<String> = stickers.getPack(STICKER_PACK);
        if (stickerPack == null || stickerPack.length == 0)
        {
          stickerPack = [for (k in stickers.stickers.keys()) k];
        }

        var stickerSetCollection:Array<String> = [];
        for (x in stickerPack)
        {
          var arr = stickers.getStickers(x);
          if (arr != null && arr.length > 0)
            stickerSetCollection = stickerSetCollection.concat(arr);
        }

        if (stickerSetCollection.length > 0)
        {
          var sticker:String = FlxG.random.getObject(stickerSetCollection);
          sticky = new StickerSprite(0, 0, STICKER_SET, sticker);
        }
        else
        {
          trace('Sticker collection empty, using fallback justBf');
          sticky = new StickerSprite(0, 0, null, "justBf");
        }
      }
      else
      {
        trace('StickerInfo is null, using fallback justBf');
        sticky = new StickerSprite(0, 0, null, "justBf");
      }
      sticky.visible = false;

      sticky.x = xPos;
      sticky.y = yPos;
      xPos += sticky.frameWidth * 0.5;

      if (xPos >= FlxG.width)
      {
        if (yPos <= FlxG.height)
        {
          xPos = -100;
          yPos += FlxG.random.float(70, 120);
        }
      }

      sticky.angle = FlxG.random.int(-60, 70);
      grpStickers.add(sticky);
    }

    FlxG.random.shuffle(grpStickers.members);

    // var stickerCount:Int = 0;

    // for (w in 0...6)
    // {
    //   var xPos:Float = FlxG.width * (w / 6);
    //   for (h in 0...6)
    //   {
    //     var yPos:Float = FlxG.height * (h / 6);
    //     var sticker = grpStickers.members[stickerCount];
    //     xPos -= sticker.width / 2;
    //     yPos -= sticker.height * 0.9;
    //     sticker.x = xPos;
    //     sticker.y = yPos;

    //   }
    // }

    // for (ind => sticker in grpStickers.members)
    // {
    //   sticker.x = (ind % 8) * sticker.width;
    //   var yShit:Int = Math.floor(ind / 8);
    //   sticker.y += yShit * sticker.height;
    //   // scales it juuuust a smidge
    //   sticker.y += 20 * yShit;
    // }

    // another damn for loop... apologies!!!
    for (ind => sticker in grpStickers.members)
    {
      sticker.timing = FlxMath.remapToRange(ind, 0, grpStickers.members.length, 0, 0.9);

      new FlxTimer().start(sticker.timing, _ -> {
        if (grpStickers == null) return;

        sticker.visible = true;
        var daSound:String = FlxG.random.getObject(sounds);
        #if !LEGACY_PSYCH
        new FlxSound().loadEmbedded(Paths.sound(daSound)).play();
        #else
        new FlxSound().loadEmbedded(Paths.sound(daSound,"shared")).play();
        #end

        var frameTimer:Int = FlxG.random.int(0, 2);

        // always make the last one POP
        if (ind == grpStickers.members.length - 1) frameTimer = 2;

        new FlxTimer().start((1 / 24) * frameTimer, _ -> {
          if (sticker == null) return;

          sticker.scale.x = sticker.scale.y = FlxG.random.float(0.97, 1.02);

          if (ind == grpStickers.members.length - 1)
          {
            switchingState = true;

            FlxTransitionableState.skipNextTransIn = true;
            FlxTransitionableState.skipNextTransOut = true;

            // I think this grabs the screen and puts it under the stickers?
            // Leaving this commented out rather than stripping it out because it's cool...
            /*
              dipshit = new Sprite();
              var scrn:BitmapData = new BitmapData(FlxG.width, FlxG.height, true, 0x00000000);
              var mat:Matrix = new Matrix();
              scrn.draw(grpStickers.cameras[0].canvas, mat);

              var bitmap:Bitmap = new Bitmap(scrn);

              dipshit.addChild(bitmap);
              // FlxG.addChildBelowMouse(dipshit);
             */
             if(subState != null){
              subStateClosed.addOnce(s -> {
                FlxG.switchState(targetState(this));
              });
             }
             else FlxG.switchState(targetState(this));
          }
        });
      });
    }

    grpStickers.sort((ord, a, b) -> {
      return FlxSort.byValues(ord, a.timing, b.timing);
    });

    // centers the very last sticker
    var lastOne:StickerSprite = grpStickers.members[grpStickers.members.length - 1];
    lastOne.updateHitbox();
    lastOne.angle = 0;
    lastOne.screenCenter();

    STICKER_SET = "stickers-set-1";
    STICKER_PACK = "all";
    #if !LEGACY_PSYCH
    Mods.loadTopMod(); // We won't be messing with mods from here on
    #else
    WeekData.loadTheFirstEnabledMod();
    #end
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    // if (FlxG.keys.justPressed.ANY)
    // {
    //   regenStickers();
    // }
  }

  var switchingState:Bool = false;

  override public function close():Void
  {
    if (switchingState) return;
    super.close();
  }

  override public function destroy():Void
  {
    //controls.isInSubstate = false;
    if (switchingState) return;
    super.destroy();
  }
}

class StickerSprite extends FlxSprite
{
  public var timing:Float = 0;
  var stickerPath:String;
  public function loadSticker() {
    loadGraphic(Paths.image(stickerPath));
    updateHitbox();
    scrollFactor.set();
  }

  public function new(x:Float, y:Float, stickerSet:String, stickerName:String):Void
  {
    super(x, y);
    stickerPath = stickerSet == null ? stickerName : 'transitionSwag/$stickerSet/$stickerName';
    antialiasing = VsliceOptions.ANTIALIASING;
    loadSticker();
    
  }
}

class StickerInfo
{
  public var name:String;
  public var artist:String;
  public var modDir:String;
  public var stickers:Map<String, Array<String>>;
  public var stickerPacks:Map<String, Array<String>>;

  public function new(stickerSet:String):Void
  {
    var rawJson:String = Paths.getTextFromFile('images/transitionSwag/$stickerSet/stickers.json');
    var json:Dynamic = Json.parse(rawJson);

    this.name = Reflect.field(json, "name");
    this.artist = Reflect.field(json, "artist");
    this.modDir = Mods.currentModDirectory;

    stickers = new Map<String, Array<String>>();
    stickerPacks = new Map<String, Array<String>>();

    var packsObj:Dynamic = Reflect.field(json, "stickerPacks");
    if (packsObj == null)
      packsObj = Reflect.field(json, "sticker-packs");

    if (packsObj != null)
    {
      for (field in Reflect.fields(packsObj))
      {
        stickerPacks.set(field, cast Reflect.field(packsObj, field));
      }
    }

    var stickersObj:Dynamic = Reflect.field(json, "stickers");
    if (stickersObj == null)
      throw 'Missing "stickers" object in stickers.json';

    for (field in Reflect.fields(stickersObj))
    {
      stickers.set(field, cast Reflect.field(stickersObj, field));
    }

    trace('Sticker set loaded: ' + stickerSet);
    trace('Sticker groups: ' + [for (k in stickers.keys()) k]);
    trace('Sticker packs: ' + [for (k in stickerPacks.keys()) k]);
  }

  public function getStickers(stickerName:String):Array<String>
  {
    return stickers.get(stickerName);
  }

  public function getPack(packName:String):Array<String>
  {
    return stickerPacks.get(packName);
  }
}

// somethin damn cute just for the json to cast to!
typedef StickerShit =
{
  name:String,
  artist:String,
  stickers:Map<String, Array<String>>,
  stickerPacks:Map<String, Array<String>>
}

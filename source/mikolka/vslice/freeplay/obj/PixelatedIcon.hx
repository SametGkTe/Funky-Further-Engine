package mikolka.vslice.freeplay.obj;

import mikolka.compatibility.funkin.FunkinPath;
import mikolka.compatibility.ModsHelper;
import mikolka.compatibility.freeplay.FreeplayHelpers;
import flixel.FlxSprite;
import mikolka.funkin.FlxFilteredSprite;

class PixelatedIcon extends FlxFilteredSprite
{
  private inline static final ICON_FRAMERATE = 10;
	public var type:IconType;
  public function new(x:Float, y:Float)
  {
    super(x, y);
    this.makeGraphic(32, 32, 0x00000000);
    this.antialiasing = false;
    this.active = false;
  }

  public function setCharacter(char:String):Void
  {
    if(char.startsWith("icon-")) char = char.replace("icon-","");
    type = IconType.LEGACY;
    if(FunkinPath.exists('images/freeplay/icons/${char}pixel.png')){
      if(FunkinPath.exists('images/freeplay/icons/${char}pixel.xml')) type = ANIMATED;
      else type = PIXEL;
    }
    switch (type){
      case LEGACY:
        var charPath:String = "icons/";
        charPath += "icon-";
        charPath += '${char}';
        
        
        var image = Paths.image(charPath);

        if (image == null)
        {
          trace('[WARN] Character ${char} has no freeplay icon.');
          image = Paths.image("icons/icon-face");
        }
        this.loadGraphic(image,true,Math.floor(image.width / 2), Math.floor(image.height));
        animation.add("idle",[0],ICON_FRAMERATE,false);
        animation.add("confirm",[1],ICON_FRAMERATE,false);
        this.scale.x = this.scale.y = 0.58;
        this.updateHitbox();
        this.origin.x = 100;
      case PIXEL:
        var image = Paths.image('freeplay/icons/${char}pixel');
        this.loadGraphic(image);
        this.scale.x = this.scale.y = 2;
        this.updateHitbox();
        animation.add("idle",[0],ICON_FRAMERATE,false);
        animation.add("confirm",[0],ICON_FRAMERATE,false);
        this.origin.x = 25;
        if(char == "parents") this.origin.x = 55;
      case ANIMATED:
        frames = FunkinPath.getSparrowAtlas('freeplay/icons/${char}pixel');
        this.active = true;
        this.scale.x = this.scale.y = 2;
        this.updateHitbox();
        this.animation.addByPrefix('idle', 'idle0', ICON_FRAMERATE, true);
        this.animation.addByPrefix('confirm', 'confirm0', ICON_FRAMERATE, false);
        this.animation.addByPrefix('confirm-hold', 'confirm-hold0', ICON_FRAMERATE, true);

        var idleAnim = this.animation.getByName('idle');
        #if !LEGACY_PSYCH
        if(idleAnim?.numFrames == 1) idleAnim.looped = false;
        #end

        this.animation.finishCallback = function(name:String):Void {
          if (name == 'confirm') this.animation.play('confirm-hold');
        };
        this.origin.x = 25;
        if(char == "parents") this.origin.x = 55;
    }
      animation.play("idle");
    
  }
}
enum IconType {
  LEGACY;
  PIXEL;
  ANIMATED;
}
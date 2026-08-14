package vslice.menus.charSelect;

import flixel.system.debug.watch.Tracker.TrackerProfile;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import shaders.MosaicEffect;
import flixel.util.FlxTimer;
import vslice.compatibility.ModsHelper;
import vslice.compatibility.funkin.FunkinPath as Paths;
import backend.Paths as BackendPaths;

class Nametag extends FlxSprite
{
	public var midpointX(default, set):Float = 1008;
	public var midpointY(default, set):Float = 100;
	var mosaicShader:MosaicEffect;
	var fallbackText:FlxText;
	var charEntryMap:Map<String, CharSelectSubState.CharSelectEntry>;

	public function new(?x:Float = 0, ?y:Float = 0, initialChar:String, ?entryMap:Map<String, CharSelectSubState.CharSelectEntry>)
	{
		super(x, y);

		charEntryMap = entryMap;

		mosaicShader = new MosaicEffect();
		shader = mosaicShader;

		fallbackText = new FlxText(0, 0, 400, "", 28);
		fallbackText.setFormat(BackendPaths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER);
		fallbackText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		fallbackText.visible = false;
		fallbackText.scrollFactor.set();

		switchChar(initialChar);

		FlxG.debugger.addTrackerProfile(new TrackerProfile(Nametag, ["midpointX", "midpointY"]));
		FlxG.debugger.track(this, "Nametag");
	}

	public function updatePosition():Void
	{
		var offsetX:Float = getMidpoint().x - midpointX;
		var offsetY:Float = getMidpoint().y - midpointY;
		x -= offsetX;
		y -= offsetY;

		if (fallbackText != null)
		{
			fallbackText.x = midpointX - fallbackText.width / 2;
			fallbackText.y = midpointY - fallbackText.height / 2;
		}
	}

	function switchModContext(charId:String):Void
	{
		if (charEntryMap != null && charEntryMap.exists(charId))
		{
			var entry = charEntryMap.get(charId);
			if (entry.sourceMod != null)
				ModsHelper.loadModDir(entry.sourceMod);
			else
				ModsHelper.loadModDir("");
		}
	}

	public function switchChar(str:String):Void
	{
		shaderEffect();

		new FlxTimer().start(4 / 30, _ -> {
			var path:String = str;
			switch str
			{
				case "bf": path = "boyfriend";
			}

			switchModContext(str);

			var nametagPath = 'charSelect/' + path + "Nametag";
			var imageExists = false;

			try
			{
				var testGraphic = Paths.image(nametagPath);
				if (testGraphic != null)
					imageExists = true;
			}
			catch (e)
			{
				imageExists = false;
			}

			if (imageExists)
			{
				visible = true;
				if (fallbackText != null) fallbackText.visible = false;

				loadGraphic(Paths.image(nametagPath));
				updateHitbox();
				scale.x = scale.y = 0.77;
				updatePosition();
				shaderEffect(true);
			}
			else
			{
				visible = false;
				if (fallbackText != null)
				{
					var displayName = str;
					if (charEntryMap != null && charEntryMap.exists(str))
						displayName = charEntryMap.get(str).name;
					else
					{
						displayName = str.charAt(0).toUpperCase() + str.substr(1);
						displayName = displayName.split("-").join(" ");
					}
					fallbackText.text = displayName.toUpperCase();
					fallbackText.visible = true;
					updatePosition();
				}
				shaderEffect(true);
			}
		});
	}

	override public function draw():Void
	{
		super.draw();
		if (fallbackText != null && fallbackText.visible)
			fallbackText.draw();
	}

	function shaderEffect(fadeOut:Bool = false):Void
	{
		if (fadeOut)
		{
			setBlockTimer(0, 1, 1);
			setBlockTimer(1, width / 27, height / 26);
			setBlockTimer(2, width / 10, height / 10);
			setBlockTimer(3, 1, 1);
			setBlockTimer(5, 1, 1);
		}
		else
		{
			setBlockTimer(0, (width / 10), (height / 10));
			setBlockTimer(1, width / 73, height / 6);
			setBlockTimer(2, width / 10, height / 10);
		}
	}

	function setBlockTimer(frame:Int, ?forceX:Float, ?forceY:Float)
	{
		var daX:Float = 10 * FlxG.random.int(1, 4);
		var daY:Float = 10 * FlxG.random.int(1, 4);
		if (forceX != null) daX = forceX;
		if (forceY != null) daY = forceY;
		new FlxTimer().start(frame / 30, _ -> { mosaicShader.setBlockSize(daX, daY); });
	}

	function set_midpointX(val:Float):Float
	{
		this.midpointX = val;
		updatePosition();
		return val;
	}

	function set_midpointY(val:Float):Float
	{
		this.midpointY = val;
		updatePosition();
		return val;
	}
}

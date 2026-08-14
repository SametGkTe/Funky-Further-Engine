package vslice.menus.freeplay;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.Difficulty;
import vslice.compatibility.VsliceOptions;
import vslice.compatibility.funkin.FunkinPath as Paths;

/**
 * The sprite for the difficulty
 */
class DifficultySprite extends FlxSprite
{
	/**
	 * The difficulty id which this sprite represents.
	 */
	public var difficultyId:String;

	/** Sprite dosyası için normalize edilmiş id (Türkçe adlar İngilizce dosyaya eşlenir). */
	public var spriteDiffId:String;

	public var hasValidTexture:Bool = true;
	public var difficultyColor:FlxColor;
	public var widthOffset:Float = 0;

	public function new(diffId:String)
	{
		super();
		difficultyId = diffId;
		spriteDiffId = Difficulty.getSpriteDiffId(diffId);

		var tex:FlxGraphic = null;
		var loadedAnimated:Bool = false;

		if (Paths.exists('images/freeplay/freeplayDifficulties/freeplay' + spriteDiffId + ".xml"))
		{
			try
			{
				frames = Paths.getSparrowAtlas('freeplay/freeplayDifficulties/freeplay' + spriteDiffId, false);

				if (frames != null && frames.frames != null && frames.frames.length > 0)
				{
					animation.addByPrefix('idle', 'idle0', 24, true);

					animation.play('idle', true);

					// FLASHBANG kapalıysa animasyon dönmesin ama frame kalsın
					if (!VsliceOptions.FLASHBANG && animation.curAnim != null)
						animation.curAnim.paused = true;

					updateHitbox();
					widthOffset = (frameWidth / 2) - 20;
					loadedAnimated = true;
				}
			}
			catch (e:Dynamic)
			{
				trace('Failed loading animated difficulty sprite for $diffId: ' + Std.string(e));
				loadedAnimated = false;
			}
		}

		if (!loadedAnimated)
		{
			tex = Paths.noGpuImage('freeplay/freeplayDifficulties/freeplay' + spriteDiffId);
			if (tex != null)
				widthOffset = (tex.width / 2) - 20;

			if (tex == null)
			{
				tex = Paths.noGpuImage('menudifficulties/' + spriteDiffId);
				if (tex != null)
					widthOffset = (tex.width / 2) - 80;
			}

			if (tex == null)
			{
				hasValidTexture = false;

				var grpFallbackDifficulty = new FlxText(70, 90, 250, difficultyId);
				grpFallbackDifficulty.setFormat("VCR OSD Mono", 60, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				grpFallbackDifficulty.borderSize = 2;
				@:privateAccess
				grpFallbackDifficulty.regenGraphic();
				@:privateAccess
				tex = grpFallbackDifficulty.graphic;
				widthOffset = (tex.width / 2) - 55;
			}

			if (tex != null)
			{
				loadGraphic(tex);
				updateHitbox();
			}
		}

		difficultyColor = resolveDifficultyColor(diffId);

		x = -((width / 2) - 106);
	}

	function resolveDifficultyColor(diffId:String):FlxColor
	{
		// Türkçe adlar da İngilizce renk sabitleriyle eşleşsin
		var id = Difficulty.getSpriteDiffId(diffId);

		// Standart zorluklar için direkt sabit renk
		switch (id)
		{
			case "easy":
				return 0xFF92D050;
			case "normal":
				return 0xFFFFD966;
			case "hard":
				return 0xFFFF6B6B;
			case "erect":
				return 0xFF7C5CFF;
			case "nightmare":
				return 0xFFB00020;
		}

		// Custom difficulty ise dominantColor dene
		try
		{
			if (graphic != null || frames != null)
				return CoolUtil.dominantColor(this);
		}
		catch (e:Dynamic)
		{
			trace('Failed to get prime color for $diffId: ' + Std.string(e));
		}

		return FlxColor.GRAY;
	}
}

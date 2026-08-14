package vslice.menus.freeplay.backcards;

import vslice.compatibility.freeplay.FreeplayHelpers;
import vslice.compatibility.VsliceOptions;
import vslice.menus.freeplay.pslice.FreeplayColorTweener;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxSpriteUtil;
import openfl.display.BlendMode;

class BoyfriendCard extends BackingCard
{
	public var moreWays:BGScrollingText;
	public var funnyScroll:BGScrollingText;
	public var txtNuts:BGScrollingText;
	public var funnyScroll2:BGScrollingText;
	public var moreWays2:BGScrollingText;
	public var funnyScroll3:BGScrollingText;
	public var colorEngine:FreeplayColorTweener;

	var glow:FlxSprite;
	var glowDark:FlxSprite;

	var scrollTextsEnabled:Bool = true;

	public override function applyExitMovers(?exitMovers:FreeplayState.ExitMoverData, ?exitMoversCharSel:FreeplayState.ExitMoverData):Void
	{
		super.applyExitMovers(exitMovers, exitMoversCharSel);
		if (exitMovers == null || exitMoversCharSel == null)
			return;
		exitMovers.set([moreWays], {
			x: FlxG.width * 2,
			speed: 0.4,
		});
		exitMovers.set([funnyScroll], {
			x: -funnyScroll.width * 2,
			y: funnyScroll.y,
			speed: 0.4,
			wait: 0
		});
		exitMovers.set([txtNuts], {
			x: FlxG.width * 2,
			speed: 0.4,
		});
		exitMovers.set([funnyScroll2], {
			x: -funnyScroll2.width * 2,
			speed: 0.5,
		});
		exitMovers.set([moreWays2], {
			x: FlxG.width * 2,
			speed: 0.4
		});
		exitMovers.set([funnyScroll3], {
			x: -funnyScroll3.width * 2,
			speed: 0.3
		});

		exitMoversCharSel.set([moreWays, funnyScroll, txtNuts, funnyScroll2, moreWays2, funnyScroll3], {
			y: -60,
			speed: 0.8,
			wait: 0.1
		});
	}

	public override function enterCharSel():Void
	{
		FlxTween.tween(funnyScroll, {speed: 0}, 0.8, {ease: FlxEase.sineIn});
		FlxTween.tween(funnyScroll2, {speed: 0}, 0.8, {ease: FlxEase.sineIn});
		FlxTween.tween(moreWays, {speed: 0}, 0.8, {ease: FlxEase.sineIn});
		FlxTween.tween(moreWays2, {speed: 0}, 0.8, {ease: FlxEase.sineIn});
		FlxTween.tween(txtNuts, {speed: 0}, 0.8, {ease: FlxEase.sineIn});
		FlxTween.tween(funnyScroll3, {speed: 0}, 0.8, {ease: FlxEase.sineIn});
	}

	public override function new(currentCharacter:PlayableCharacter)
	{
		super(currentCharacter);
		if (VsliceOptions.ALLOW_COLORING)
			colorEngine = new FreeplayColorTweener(this);

		funnyScroll = new BGScrollingText(0, 220, currentCharacter.getFreeplayDJText(1), FlxG.width / 2, false, 60);
		funnyScroll2 = new BGScrollingText(0, 335, currentCharacter.getFreeplayDJText(1), FlxG.width / 2, false, 60);
		moreWays = new BGScrollingText(0, 160, currentCharacter.getFreeplayDJText(2), FlxG.width, true, 43);
		moreWays2 = new BGScrollingText(0, 397, currentCharacter.getFreeplayDJText(2), FlxG.width, true, 43);
		txtNuts = new BGScrollingText(0, 285, currentCharacter.getFreeplayDJText(3), FlxG.width / 2, true, 43);
		funnyScroll3 = new BGScrollingText(0, orangeBackShit.y + 10, currentCharacter.getFreeplayDJText(1), FlxG.width / 2, 60);

		// Mobile performans: scroll text sayısını azalt
		#if mobile
		scrollTextsEnabled = !VsliceOptions.LOW_QUALITY;
		#end
	}

	public override function init():Void
	{
		FlxTween.tween(pinkBack, {x: 0}, 0.6, {ease: FlxEase.quartOut});
		add(pinkBack);

		add(orangeBackShit);

		add(alsoOrangeLOL);

		orangeBackShit.visible = false;
		alsoOrangeLOL.visible = false;

		confirmTextGlow.blend = BlendMode.ADD;
		confirmTextGlow.visible = false;

		confirmGlow.blend = BlendMode.ADD;

		confirmGlow.visible = false;
		confirmGlow2.visible = false;

		add(confirmGlow2);
		add(confirmGlow);

		add(confirmTextGlow);

		add(backingTextYeah);

		cardGlow.blend = BlendMode.ADD;
		cardGlow.visible = false;

		moreWays.visible = false;
		funnyScroll.visible = false;
		txtNuts.visible = false;
		funnyScroll2.visible = false;
		moreWays2.visible = false;
		funnyScroll3.visible = false;

		moreWays.color = 0xFFFFF383;
		moreWays.speed = 6.8;
		add(moreWays);

		funnyScroll.color = 0xFFFF9963;
		funnyScroll.speed = -3.8;
		add(funnyScroll);

		txtNuts.speed = 3.5;
		add(txtNuts);

		funnyScroll2.color = 0xFFFF9963;
		funnyScroll2.speed = -3.8;
		add(funnyScroll2);

		moreWays2.color = 0xFFFFF383;
		moreWays2.speed = 6.8;
		add(moreWays2);

		funnyScroll3.color = 0xFFFEA400;
		funnyScroll3.speed = -3.8;
		add(funnyScroll3);

		// Mobile'da gereksiz scroll text'leri devre dışı bırak
		if (!scrollTextsEnabled)
		{
			moreWays.active = false;
			funnyScroll.active = false;
			txtNuts.active = false;
			funnyScroll2.active = false;
			moreWays2.active = false;
			funnyScroll3.active = false;
		}

		glowDark = new FlxSprite(-300, 330).loadGraphic(Paths.image('freeplay/beatglow'));
		glowDark.blend = BlendMode.MULTIPLY;
		add(glowDark);

		glow = new FlxSprite(-300, 330).loadGraphic(Paths.image('freeplay/beatglow'));
		glow.blend = BlendMode.ADD;
		add(glow);

		glowDark.visible = false;
		glow.visible = false;

		add(cardGlow);
	}

	var beatFreq:Int = 1;
	var beatFreqList:Array<Int> = [1, 2, 4, 8];

	public override function beatHit(curBeat:Int):Void
	{
		beatFreq = beatFreqList[Math.floor(FreeplayHelpers.BPM / 140)];

		#if mobile
		if (beatFreq < 4)
			beatFreq = 4;
		#end

		if (curBeat % beatFreq != 0)
			return;

		FlxTween.cancelTweensOf(glow);
		FlxTween.cancelTweensOf(glowDark);

		glow.alpha = 0.8;
		FlxTween.tween(glow, {alpha: 0}, 16 / 24, {ease: FlxEase.quartOut});
		glowDark.alpha = 0;
		FlxTween.tween(glowDark, {alpha: 0.6}, 18 / 24, {ease: FlxEase.quartOut});
	}

	public override function introDone():Void
	{
		super.introDone();

		glowDark.visible = true;
		glow.visible = true;

		if (!scrollTextsEnabled)
			return;

		moreWays.visible = true;
		funnyScroll.visible = true;
		txtNuts.visible = true;
		funnyScroll2.visible = true;
		moreWays2.visible = true;
		funnyScroll3.visible = true;
	}

	public override function confirm():Void
	{
		super.confirm();
		colorEngine?.cancelTween();

		moreWays.visible = false;
		funnyScroll.visible = false;
		txtNuts.visible = false;
		funnyScroll2.visible = false;
		moreWays2.visible = false;
		funnyScroll3.visible = false;
		glowDark.visible = false;
		glow.visible = false;
	}

	public override function disappear():Void
	{
		colorEngine?.cancelTween();

		super.disappear();
		moreWays.visible = false;
		funnyScroll.visible = false;
		txtNuts.visible = false;
		funnyScroll2.visible = false;
		moreWays2.visible = false;
		funnyScroll3.visible = false;
		glowDark.visible = false;
		glow.visible = false;
	}
}

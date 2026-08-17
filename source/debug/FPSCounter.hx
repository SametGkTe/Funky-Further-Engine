package debug;

import flixel.FlxG;
import openfl.Lib;
import haxe.Timer;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldAutoSize;
import openfl.system.System as OpenFlSystem;
import lime.system.System as LimeSystem;
import lime.app.Application;
import backend.Language;
import openfl.display.Sprite;
import openfl.display.Shape;

class FPSCounter extends Sprite
{
	public var currentFPS(default, null):Int;
	public var memoryMegas(get, never):Float;
	public var memoryPeak:Float = 0;

	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var lastFramerateUpdateTime:Float;
	@:noCompletion private var updateTime:Int;
	@:noCompletion private var nextDisplayUpdate:Int;
	@:noCompletion private var framesCount:Int;
	@:noCompletion private var prevTime:Int;

	private var textField:TextField;
	private var bg:Shape;

	private var bgPaddingX:Float = 6;
	private var bgPaddingY:Float = 4;

	public var os:String = '';

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		#if !officialBuild
		var systemText:String = Language.getPhrase('debug_system', 'Sistem');
		if (LimeSystem.platformName == LimeSystem.platformVersion || LimeSystem.platformVersion == null)
			os = '\n$systemText: ${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end;
		else
			os = '\n$systemText: ${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end + ' - ${LimeSystem.platformVersion}';
		#end

		mouseEnabled = false;
		mouseChildren = false;

		bg = new Shape();
		addChild(bg);

		textField = new TextField();
		textField.selectable = false;
		textField.mouseEnabled = false;
		textField.multiline = true;
		textField.autoSize = TextFieldAutoSize.LEFT;

		var fontName:String = Paths.font("vcr.ttf");
		textField.defaultTextFormat = new TextFormat(fontName, 14, color);
		textField.embedFonts = true;
		textField.textColor = 0xFFFFFFFF;
		textField.text = "FPS: ";
		textField.x = bgPaddingX;
		textField.y = bgPaddingY;
		addChild(textField);

		positionFPS(x, y);

		currentFPS = 0;
		framesCount = 0;
		times = [];
		lastFramerateUpdateTime = Timer.stamp();
		prevTime = Lib.getTimer();
		updateTime = prevTime + 500;
		nextDisplayUpdate = prevTime;

		redrawBackground();
	}

	public dynamic function updateText():Void
	{
		if (!ClientPrefs.data.fpsCounter)
		{
			textField.text = '';
			bg.graphics.clear();
			visible = false;
			return;
		}

		visible = true;

		if (memoryMegas > memoryPeak) memoryPeak = memoryMegas;

		var memoryText:String = Language.getPhrase('debug_memory', 'Bellek');
		var peakText:String = Language.getPhrase('debug_peak', 'En Yüksek');
		var versionText:String = Language.getPhrase('debug_version', 'Sürüm');
		var systemText:String = Language.getPhrase('debug_system', 'Sistem');

		var osText:String = '';
		#if !officialBuild
		if (LimeSystem.platformName == LimeSystem.platformVersion || LimeSystem.platformVersion == null)
			osText = '\n$systemText: ${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end;
		else
			osText = '\n$systemText: ${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end + ' - ${LimeSystem.platformVersion}';
		#end

		textField.text =
			'FPS: $currentFPS' +
			'\n$memoryText: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)} ($peakText: ${flixel.util.FlxStringUtil.formatBytes(memoryPeak)})' +
			'\n$versionText: ${Application.current.meta.get('version')}' +
			osText;

		textField.textColor = 0xFFFFFFFF;
		if (currentFPS < FlxG.stage.window.frameRate * 0.5)
			textField.textColor = 0xFFFF0000;

		redrawBackground();
	}

	private override function __enterFrame(deltaTime:Float):Void
	{
		if (ClientPrefs.data.fpsRework)
		{
			var currentTime = Lib.getTimer();
			framesCount++;

			if (currentTime >= updateTime)
			{
				var elapsed = currentTime - prevTime;
				currentFPS = Math.ceil((framesCount * 1000) / elapsed);
				framesCount = 0;
				prevTime = currentTime;
				updateTime = currentTime + 500;
			}
		}
		else
		{
			final now:Float = Timer.stamp() * 1000;
			times.push(now);

			while (times.length > 0 && times[0] < now - 1000)
				times.shift();

			currentFPS = times.length;
		}

		// TextField metni, bellek sorgusu ve arka plan Shape çizimi her render
		// frame'inde yapılmamalı. Sayaç örneklemeye devam eder, UI 4 Hz yenilenir.
		var displayNow:Int = Lib.getTimer();
		if (displayNow >= nextDisplayUpdate)
		{
			nextDisplayUpdate = displayNow + 250;
			updateText();
		}
	}

	private function redrawBackground():Void
	{
		bg.graphics.clear();

		if (!ClientPrefs.data.fpsCounter)
			return;

		var opacity:Int = ClientPrefs.data.fpsCounterOpacity;

		if (opacity < 0) opacity = 0;
		if (opacity > 100) opacity = 100;

		if (opacity <= 0)
			return;

		var boxW:Float = textField.width + (bgPaddingX * 2);
		var boxH:Float = textField.height + (bgPaddingY * 2);
		var radius:Float = 8;

		bg.graphics.beginFill(0x000000, opacity / 100);
		bg.graphics.drawRoundRect(0, 0, boxW, boxH, radius, radius);
		bg.graphics.endFill();
	}

	inline function get_memoryMegas():Float
		return cast(OpenFlSystem.totalMemory, Float);

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1)
	{
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;
		this.x = FlxG.game.x + X;
		this.y = FlxG.game.y + Y;
	}

	#if cpp
	private function getArch():String
	{
		return "Unknown";
	}
	#end
}
package backend;

import openfl.utils.Assets;
import lime.utils.Assets as LimeAssets;
import flixel.FlxG;
import objects.AlertMgr.AlertMgr;
import objects.AlertMgr.AlertMsg;

#if cpp
@:cppFileCode('#include <thread>')
#end
class CoolUtil
{
	public static function checkForUpdates(url:String = null):String {
		if (url == null || url.length == 0)
			url = "https://raw.githubusercontent.com/MobilePorting/FNF-PsychEngine-Mobile/main/gitVersion.txt";
		var version:String = states.MainMenuState.psychEngineVersion.trim();
		if(ClientPrefs.data.checkForUpdates) {
			trace('checking for updates...');
			var http = new haxe.Http(url);
			http.onData = function (data:String)
			{
				var newVersion:String = data.split('\n')[0].trim();
				trace('version online: $newVersion, your version: $version');
				if(newVersion != version) {
					trace('versions arent matching! please update');
					version = newVersion;
					http.onData = null;
					http.onError = null;
					http = null;
				}
			}
			http.onError = function (error) {
				trace('error: $error');
			}
			http.request();
		}
		return version;
	}
	inline public static function quantize(f:Float, snap:Float){
		// changed so this actually works lol
		var m:Float = Math.fround(f * snap);
		//trace(snap);
		return (m / snap);
	}

	inline public static function capitalize(text:String)
		return text.charAt(0).toUpperCase() + text.substr(1).toLowerCase();

	inline public static function coolTextFile(path:String):Array<String>
	{
		var daList:String = null;
		#if (sys && MODS_ALLOWED)
		if(FileSystem.exists(path)) daList = File.getContent(path);
		#else
		if(Assets.exists(path)) daList = Assets.getText(path);
		#end
		return daList != null ? listFromString(daList) : [];
	}

	inline public static function colorFromString(color:String):FlxColor
	{
		var hideChars = ~/[\t\n\r]/;
		var color:String = hideChars.split(color).join('').trim();
		if(color.startsWith('0x')) color = color.substring(color.length - 6);

		var colorNum:Null<FlxColor> = FlxColor.fromString(color);
		if(colorNum == null) colorNum = FlxColor.fromString('#$color');
		return colorNum != null ? colorNum : FlxColor.WHITE;
	}

	inline public static function listFromString(string:String):Array<String>
	{
		var daList:Array<String> = [];
		daList = string.trim().split('\n');

		for (i in 0...daList.length)
			daList[i] = daList[i].trim();

		return daList;
	}

	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if(decimals < 1)
			return Math.floor(value);

		return Math.floor(value * Math.pow(10, decimals)) / Math.pow(10, decimals);
	}

	#if linux
	public static function sortAlphabetically(list:Array<String>):Array<String> {
		if (list == null) return [];

		list.sort((a, b) -> {
			var upperA = a.toUpperCase();
			var upperB = b.toUpperCase();
			
			return upperA < upperB ? -1 : upperA > upperB ? 1 : 0;
		});
		return list;
	}
	#end

	inline public static function dominantColor(sprite:flixel.FlxSprite, ?sampleStep:Int = 4):Int
	{
		// ORİJİNAL: her piksel tek tek dolaşılıyordu. Büyük spritelarda (128x128 = 16384 piksel)
		// ana thread bloklanıyordu. Bunun yerine sampleStep piksel atlayarak örnekle; renk
		// histogramı için %3-5 örnek yeterlidir.
		// Ayrıca çoğunlukla saydam pikseli atla.
		if (sprite == null || sprite.pixels == null) return FlxColor.BLACK;
		var step:Int = sampleStep != null && sampleStep > 0 ? sampleStep : 4;
		var countByColor:Map<Int, Int> = [];
		var w = sprite.frameWidth;
		var h = sprite.frameHeight;
		var maxCount = 0;
		var maxKey:Int = FlxColor.BLACK;
		for (col in 0...w)
		{
			if (col % step != 0) continue;
			for (row in 0...h)
			{
				if (row % step != 0) continue;
				var colorOfThisPixel:FlxColor = sprite.pixels.getPixel32(col, row);
				if (colorOfThisPixel.alphaFloat > 0.1)
				{
					// Alpha'yı 255'e sabitle, aynı rengin farklı alpha'ları aynı kaba girsin
					var key:Int = FlxColor.fromRGB(colorOfThisPixel.red, colorOfThisPixel.green, colorOfThisPixel.blue, 255);
					var count:Int = countByColor.exists(key) ? countByColor.get(key) : 0;
					count++;
					countByColor.set(key, count);
					if (count > maxCount)
					{
						maxCount = count;
						maxKey = key;
					}
				}
			}
		}
		countByColor = null;
		return maxKey;
	}

	inline public static function numberArray(max:Int, ?min = 0):Array<Int>
	{
		var dumbArray:Array<Int> = [];
		for (i in min...max) dumbArray.push(i);

		return dumbArray;
	}

	inline public static function browserLoad(site:String) {
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}

	inline public static function openFolder(folder:String, absolute:Bool = false) {
		#if android
			StorageUtil.openDataFolder();
		#elseif sys
			if (!absolute) folder = haxe.io.Path.join([Sys.getCwd(), folder]);
			folder = haxe.io.Path.normalize(folder);

			#if windows
			var command:String = 'explorer.exe';
			#elseif mac
			var command:String = '/usr/bin/open';
			#else
			var command:String = '/usr/bin/xdg-open';
			#end
			Sys.command(command, [folder]);
			trace('$command $folder');
		#else
			FlxG.error("Platform is not supported for CoolUtil.openFolder");
		#end
	}

	/**
		Helper Function to Fix Save Files for Flixel 5

		-- EDIT: [November 29, 2023] --

		this function is used to get the save path, period.
		since newer flixel versions are being enforced anyways.
		@crowplexus
	**/
	@:access(flixel.util.FlxSave.validate)
	inline public static function getSavePath():String {
		var company:String = FlxG.stage.application.meta.get('company');
		// #if (flixel < "5.0.0") return company; #else
		return '${company}/${flixel.util.FlxSave.validate(FlxG.stage.application.meta.get('file'))}';
		// #end
	}

	public static function setTextBorderFromString(text:FlxText, border:String)
	{
		switch(border.toLowerCase().trim())
		{
			case 'shadow':
				text.borderStyle = SHADOW;
			case 'outline':
				text.borderStyle = OUTLINE;
			case 'outline_fast', 'outlinefast':
				text.borderStyle = OUTLINE_FAST;
			default:
				text.borderStyle = NONE;
		}
	}

	public static function showPopUp(message:String, title:String):Void
	{
		#if android
		try {
			AndroidTools.showAlertDialog(title, message, {name: "OK", func: null}, null);
			return;
		} catch (e:Dynamic) {}
		#end

		// Önce oyun-içi bildirimi dene — native window.alert TAM EKRANDA oyunu kilitliyor
		// (Lua hatası diyalogu arkada kalıyor, OK basılamıyor). AlertMgr yoksa alta düşeriz.
		try {
			if (AlertMgr.instance != null) {
				AlertMsg.show(title, message, 8, AlertMsg.COLOR_ERROR);
				return;
			}
		} catch (e:Dynamic) {}

		// Native yol: tam ekrandan çık ve pencereye odak ver, yoksa alert yine arkanızda kalır
		try {
			if (FlxG.fullscreen) {
				FlxG.fullscreen = false;
				if (FlxG.stage != null && FlxG.stage.window != null)
					FlxG.stage.window.focus();
			}
		} catch (e:Dynamic) {}

		try {
			if (openfl.Lib.current != null && openfl.Lib.current.stage != null && openfl.Lib.current.stage.window != null) {
				openfl.Lib.current.stage.window.alert(message, title);
				return;
			}
		} catch (e:Dynamic) {}

		try {
			if (openfl.Lib.application != null && openfl.Lib.application.window != null) {
				openfl.Lib.application.window.alert(message, title);
				return;
			}
		} catch (e:Dynamic) {}

		try {
			if (FlxG.stage != null && FlxG.stage.window != null) {
				FlxG.stage.window.alert(message, title);
				return;
			}
		} catch (e:Dynamic) {}

		trace('$title: $message');
	}

	#if cpp
    @:functionCode('
        return std::thread::hardware_concurrency();
    ')
	#end
    public static function getCPUThreadsCount():Int
    {
        return 1;
    }
}

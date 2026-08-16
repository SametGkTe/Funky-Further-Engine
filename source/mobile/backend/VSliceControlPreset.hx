package mobile.backend;

import haxe.Json;
import lime.system.Clipboard;

class VSliceControlPreset
{
	public static inline var FORMAT_VERSION:Int = 1;
	public static final DEFAULT_X:Array<Float> = [0.21875, 0.390625, 0.609375, 0.78125];

	public static function copyToClipboard():Void
	{
		Clipboard.text = Json.stringify({
			format: 'FurtherEngineVSliceControls',
			version: FORMAT_VERSION,
			customX: ClientPrefs.data.vSliceCustomX,
			customZones: ClientPrefs.data.vSliceCustomZones,
			x: ClientPrefs.data.vSliceButtonX,
			y: ClientPrefs.data.vSliceButtonY,
			height: ClientPrefs.data.vSliceButtonHeight
		});
	}

	public static function pasteFromClipboard():String
	{
		var text:String = Clipboard.text;
		if (text == null || StringTools.trim(text).length == 0) return 'Panoda preset bulunamadı.';
		try
		{
			var data:Dynamic = Json.parse(text);
			if (Reflect.field(data, 'format') != 'FurtherEngineVSliceControls') return 'Geçersiz V-Slice preset biçimi.';
			var x = readArray(Reflect.field(data, 'x'), DEFAULT_X);
			var y = readArray(Reflect.field(data, 'y'), [0, 0, 0, 0]);
			var h = readArray(Reflect.field(data, 'height'), [1, 1, 1, 1]);
			for (i in 0...4)
			{
				x[i] = clamp(x[i], 0.03, 0.97);
				y[i] = clamp(y[i], 0, 0.95);
				h[i] = clamp(h[i], 0.05, 1 - y[i]);
			}
			ClientPrefs.data.vSliceButtonX = x;
			ClientPrefs.data.vSliceButtonY = y;
			ClientPrefs.data.vSliceButtonHeight = h;
			ClientPrefs.data.vSliceCustomX = Reflect.field(data, 'customX') == true;
			ClientPrefs.data.vSliceCustomZones = Reflect.field(data, 'customZones') == true;
			ClientPrefs.saveSettings();
			return null;
		}
		catch (e:Dynamic) return 'Preset okunamadı: ' + Std.string(e);
	}

	public static function reset():Void
	{
		ClientPrefs.data.vSliceCustomX = false;
		ClientPrefs.data.vSliceCustomZones = false;
		ClientPrefs.data.vSliceButtonX = DEFAULT_X.copy();
		ClientPrefs.data.vSliceButtonY = [0, 0, 0, 0];
		ClientPrefs.data.vSliceButtonHeight = [1, 1, 1, 1];
		ClientPrefs.saveSettings();
	}

	static function readArray(value:Dynamic, fallback:Array<Float>):Array<Float>
	{
		if (!Std.isOfType(value, Array) || cast(value, Array<Dynamic>).length < 4) return fallback.copy();
		var out:Array<Float> = [];
		for (i in 0...4)
		{
			var parsed = Std.parseFloat(Std.string(cast(value, Array<Dynamic>)[i]));
			out.push(Math.isNaN(parsed) ? fallback[i] : parsed);
		}
		return out;
	}

	static inline function clamp(v:Float, min:Float, max:Float):Float return Math.max(min, Math.min(max, v));
}

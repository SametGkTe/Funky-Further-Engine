package backend;

import backend.update.UpdateConfig;
import objects.AlertMgr.AlertMsg;
import objects.AlertMgr.AlertMessage;

class ModCompatibility
{
	static var checked:Bool = false;

	public static function checkEnabledMods():Void
	{
		#if MODS_ALLOWED
		if (checked || SafeMode.active) return;
		checked = true;

		for (folder in Mods.parseList().enabled)
		{
			var pack:Dynamic = Mods.getPack(folder);
			if (pack == null) continue;

			var minimum:String = readMinimumVersion(pack);
			if (minimum == null || StringTools.trim(minimum).length == 0) continue;

			var current:String = UpdateConfig.CURRENT_ENGINE_VERSION;
			if (compareVersions(current, minimum) < 0)
				showWarning(folder, pack, minimum, current);
		}
		#end
	}

	static function readMinimumVersion(pack:Dynamic):Null<String>
	{
		if (Reflect.hasField(pack, 'minimumFurtherVersion'))
			return Std.string(Reflect.field(pack, 'minimumFurtherVersion'));
		if (Reflect.hasField(pack, 'minimumEngineVersion'))
			return Std.string(Reflect.field(pack, 'minimumEngineVersion'));

		var further:Dynamic = Reflect.field(pack, 'furtherEngine');
		if (further != null && Reflect.hasField(further, 'minimumVersion'))
			return Std.string(Reflect.field(further, 'minimumVersion'));

		return null;
	}

	static function showWarning(folder:String, pack:Dynamic, minimum:String, current:String):Void
	{
		var displayName:String = folder;
		if (Reflect.hasField(pack, 'name') && Reflect.field(pack, 'name') != null)
			displayName = Std.string(Reflect.field(pack, 'name'));

		var shortMessage = 'Mod Klasöründeki "$folder" bu engine sürümünü desteklemiyor, lütfen sürümünüzü yükseltin';
		var details = [
			'MOD UYUMLULUK HATASI',
			'',
			'Mod: $displayName',
			'Mod klasörü: $folder',
			'Gereken minimum Further Engine sürümü: $minimum',
			'Kullanılan Further Engine sürümü: $current',
			'',
			'Bu mod daha yeni bir Further Engine sürümü için hazırlanmış.',
			'Modun hatalı çalışmasını veya oyunun çökmesini önlemek için lütfen Engine son sürüme güncelleyin.',
			'',
			'Geri dönmek için ESC/B; devam etmek için ENTER/A basın.'
		].join('\n');

		AlertMsg.show('UYARI', shortMessage, 12, AlertMessage.COLOR_WARNING, function()
		{
			MusicBeatState.switchState(new states.DebugErrState(details));
		});
	}

	/** SemVer benzeri sürümleri karşılaştırır. Sonuç: -1, 0 veya 1. */
	public static function compareVersions(a:String, b:String):Int
	{
		var av = parseVersion(a);
		var bv = parseVersion(b);
		var max = av.numbers.length > bv.numbers.length ? av.numbers.length : bv.numbers.length;

		for (i in 0...max)
		{
			var ai = i < av.numbers.length ? av.numbers[i] : 0;
			var bi = i < bv.numbers.length ? bv.numbers[i] : 0;
			if (ai < bi) return -1;
			if (ai > bi) return 1;
		}

		// Aynı temel sürümde kararlı sürüm prerelease sürümünden yenidir.
		if (av.pre.length == 0 && bv.pre.length > 0) return 1;
		if (av.pre.length > 0 && bv.pre.length == 0) return -1;
		if (av.pre < bv.pre) return -1;
		if (av.pre > bv.pre) return 1;
		return 0;
	}

	static function parseVersion(value:String):{numbers:Array<Int>, pre:String}
	{
		var clean = value == null ? '0' : StringTools.trim(value).toLowerCase();
		if (StringTools.startsWith(clean, 'v')) clean = clean.substr(1);
		clean = clean.split('+')[0];
		var pieces = clean.split('-');
		var numberPart = pieces.shift();
		var numbers:Array<Int> = [];
		for (part in numberPart.split('.'))
		{
			var match = ~/^(\d+)/;
			var parsed = 0;
			if (match.match(part))
			{
				var result = Std.parseInt(match.matched(1));
				if (result != null) parsed = result;
			}
			numbers.push(parsed);
		}
		return {numbers: numbers, pre: pieces.join('-')};
	}
}

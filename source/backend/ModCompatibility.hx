package backend;

import backend.update.UpdateConfig;
import objects.AlertMgr.AlertMsg;
import objects.AlertMgr.AlertMessage;

typedef ModCompatibilityIssue = {
	var folder:String;
	var displayName:String;
	var minimum:String;
	var current:String;
}

/** Geriye uyumlu pack.json preflight ve Further Engine sürüm kontrolü. */
class ModCompatibility
{
	static var preflightDone:Bool = false;
	static var warningsShown:Bool = false;
	static var pendingIssues:Array<ModCompatibilityIssue> = [];

	/** Mod scriptleri, global modlar ve Polymod çalışmadan önce çağrılmalıdır. */
	public static function preflightEnabledMods():Void
	{
		#if MODS_ALLOWED
		if (preflightDone || SafeMode.active) return;
		preflightDone = true;
		pendingIssues = [];
		Mods.blockedMods.clear();

		// blockedMods henüz boşken kullanıcının gerçekten etkinleştirdiği listeyi al.
		var enabled = Mods.parseList().enabled.copy();
		for (folder in enabled)
		{
			var pack:Dynamic = Mods.getPack(folder);
			if (pack == null) continue; // Klasik/Psych pack.json'sız modlar desteklenir.

			var minimum:String = readMinimumVersion(pack);
			if (minimum == null || StringTools.trim(minimum).length == 0) continue;
			var current:String = UpdateConfig.CURRENT_ENGINE_VERSION;
			if (compareVersions(current, minimum) >= 0) continue;

			var displayName:String = folder;
			if (Reflect.hasField(pack, 'name') && Reflect.field(pack, 'name') != null)
				displayName = Std.string(Reflect.field(pack, 'name'));
			var reason = 'Further Engine $minimum veya üzeri gerekiyor (mevcut: $current)';
			Mods.blockMod(folder, reason);
			pendingIssues.push({folder: folder, displayName: displayName, minimum: minimum, current: current});
			trace('[ModPreflight] "$folder" yüklenmedi: $reason');
		}
		#end
	}

	/** AlertMgr hazır olduktan sonra bekleyen preflight sonuçlarını gösterir. */
	public static function checkEnabledMods():Void
	{
		#if MODS_ALLOWED
		if (SafeMode.active || warningsShown) return;
		if (!preflightDone) preflightEnabledMods();
		warningsShown = true;
		for (issue in pendingIssues) showWarning(issue);
		#end
	}

	static function readMinimumVersion(pack:Dynamic):Null<String>
	{
		if (Reflect.hasField(pack, 'minimumFurtherVersion')) return Std.string(Reflect.field(pack, 'minimumFurtherVersion'));
		if (Reflect.hasField(pack, 'minimumEngineVersion')) return Std.string(Reflect.field(pack, 'minimumEngineVersion'));
		var further:Dynamic = Reflect.field(pack, 'furtherEngine');
		if (further != null && Reflect.hasField(further, 'minimumVersion')) return Std.string(Reflect.field(further, 'minimumVersion'));
		return null;
	}

	static function showWarning(issue:ModCompatibilityIssue):Void
	{
		var shortMessage = 'Mod Klasöründeki "${issue.folder}" bu sürümü desteklemiyor ve güvenlik için yüklenmedi. Lütfen sürümünüzü yükseltin.';
		var details = [
			'FURTHER ENGINE MOD UYUMLULUK HATASI', '',
			'Mod: ${issue.displayName}', 'Mod klasörü: ${issue.folder}',
			'Gereken minimum Further Engine sürümü: ${issue.minimum}',
			'Kullanılan Further Engine sürümü: ${issue.current}', '',
			'Bu modun scriptleri ve Polymod varlıkları güvenlik için yüklenmedi.',
			'Motoru güncelledikten sonra mod otomatik olarak yeniden denenecektir.', '',
			'Geri dönmek için ESC/B; devam etmek için ENTER/A tuşunu kullanabilirsiniz.'
		].join('\n');
		AlertMsg.show('UYARI', shortMessage, 12, AlertMessage.COLOR_WARNING, function()
			MusicBeatState.switchState(new states.DebugErrState(details)));
	}

	public static function compareVersions(a:String, b:String):Int
	{
		var av = parseVersion(a); var bv = parseVersion(b);
		var max = av.numbers.length > bv.numbers.length ? av.numbers.length : bv.numbers.length;
		for (i in 0...max)
		{
			var ai = i < av.numbers.length ? av.numbers[i] : 0;
			var bi = i < bv.numbers.length ? bv.numbers[i] : 0;
			if (ai < bi) return -1; if (ai > bi) return 1;
		}
		if (av.pre.length == 0 && bv.pre.length > 0) return 1;
		if (av.pre.length > 0 && bv.pre.length == 0) return -1;
		if (av.pre < bv.pre) return -1; if (av.pre > bv.pre) return 1;
		return 0;
	}

	static function parseVersion(value:String):{numbers:Array<Int>, pre:String}
	{
		var clean = value == null ? '0' : StringTools.trim(value).toLowerCase();
		if (StringTools.startsWith(clean, 'v')) clean = clean.substr(1);
		clean = clean.split('+')[0]; var pieces = clean.split('-'); var numberPart = pieces.shift();
		var numbers:Array<Int> = [];
		for (part in numberPart.split('.'))
		{
			var match = ~/^(\d+)/; var parsed = 0;
			if (match.match(part)) { var result = Std.parseInt(match.matched(1)); if (result != null) parsed = result; }
			numbers.push(parsed);
		}
		return {numbers: numbers, pre: pieces.join('-')};
	}
}

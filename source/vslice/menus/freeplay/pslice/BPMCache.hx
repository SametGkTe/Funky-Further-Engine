package vslice.menus.freeplay.pslice;

typedef BpmEntry = {
	b:Int,
	s:Int,
	c:String,
	d:Bool
}

class BPMCache {
	private static final DEFAULT_BPM_MAP:Map<String,Int> = [
		"tutorial" => 100,
		"bopeebo" => 100,
		"fresh" => 120,
		"dad-battle" => 180,
		"spookeez" => 150,
		"south" => 165,
		"monster" => 95,
		"pico" => 150,
		"philly-nice" => 175,
		"blammed" => 165,
		"satin-panties" => 110,
		"high" => 125,
		"milf" => 180,
		"cocoa" => 100,
		"eggnog" => 150,
		"winter-horrorland" => 159,
		"senpai" => 144,
		"roses" => 120,
		"thorns" => 190,
		"ugh" => 160,
		"guns" => 125,
		"stress" => 178,
	];

	private var bpmMap:Map<String, BpmEntry> = [];
	private var bpmFinder:EReg = ~/"bpm": *([0-9]+)/g;
	private var chartClean:EReg = ~/"notes": *\[.*\]/gs;

	var dirty:Bool = false;
	var persistedLoaded:Bool = false;
	var modsSignature:String = null;

	public static var instance = new BPMCache();
	public function new() {}

	private function normalizePath(path:String):String
	{
		if (path == null) return "";
		path = path.split("\\").join("/");
		while (path.indexOf("//") >= 0)
			path = path.split("//").join("/");
		return path;
	}

	private function pathExists(path:String):Bool
	{
		if (path == null || path.length == 0) return false;
		try {
			return sys.FileSystem.exists(path);
		} catch(e:Dynamic) {
			return false;
		}
	}

	private function isDir(path:String):Bool
	{
		if (!pathExists(path)) return false;
		try {
			return sys.FileSystem.isDirectory(path);
		} catch(e:Dynamic) {
			return false;
		}
	}

	private function fileSize(path:String):Int
	{
		try {
			return sys.FileSystem.stat(path).size;
		} catch(e:Dynamic) {
			return -1;
		}
	}

	private function readFile(path:String):String
	{
		try {
			return sys.io.File.getContent(path);
		} catch(e:Dynamic) {
			trace('[BPMCache] Failed to read file: $path — $e');
			return "";
		}
	}

	function computeModsSignature():String
	{
		var dirs:Array<String> = [];
		try
		{
			dirs = Mods.getModDirectories();
			dirs.sort(Reflect.compare);
		}
		catch (e:Dynamic) {}
		return Mods.currentModDirectory + '|' + dirs.join(',');
	}

	function loadPersisted():Void
	{
		if (persistedLoaded) return;
		persistedLoaded = true;

		modsSignature = computeModsSignature();

		try
		{
			var sig:String = FlxG.save.data.furtherBpmCacheSig;
			var list:Array<Dynamic> = FlxG.save.data.furtherBpmCache;
			if (sig == null || sig != modsSignature || list == null)
				return;

			for (raw in list)
			{
				var p:String = raw.p != null ? Std.string(raw.p) : null;
				if (p == null) continue;
				bpmMap.set(p, {
					b: raw.b != null ? Std.int(raw.b) : 0,
					s: raw.s != null ? Std.int(raw.s) : -1,
					c: raw.c != null ? Std.string(raw.c) : '',
					d: raw.d == true
				});
			}
			trace('[BPMCache] ' + Lambda.count(bpmMap) + ' kayitli BPM kalici bellekten yuklendi');
		}
		catch (e:Dynamic)
		{
			trace('[BPMCache] Kalici bellek okunamadi: $e');
		}
	}

	public function flushIfDirty():Void
	{
		loadPersisted();
		if (!dirty) return;
		dirty = false;

		try
		{
			var list:Array<Dynamic> = [];
			for (key in bpmMap.keys())
			{
				var e:BpmEntry = bpmMap.get(key);
				list.push({p: key, b: e.b, s: e.s, c: e.c, d: e.d});
			}
			FlxG.save.data.furtherBpmCache = list;
			FlxG.save.data.furtherBpmCacheSig = modsSignature;
			FlxG.save.flush();
		}
		catch (e:Dynamic)
		{
			trace('[BPMCache] Kalici bellek yazilamadi: $e');
		}
	}

	public function invalidateIfModsChanged():Void
	{
		loadPersisted();
		var sig = computeModsSignature();
		if (sig != modsSignature)
		{
			trace('[BPMCache] Mod listesi degisti, onbellek sifirlaniyor');
			clearCache();
			modsSignature = sig;
			dirty = true;
			flushIfDirty();
		}
	}

	public function clearCache():Void
	{
		bpmMap = [];
		dirty = true;
		flushIfDirty();
	}

	public function getBPM(sngDataPath:String, fileSngName:String):Int
	{
		loadPersisted();

		var normalPath = normalizePath(sngDataPath);

		var cached:BpmEntry = bpmMap.get(normalPath);
		if (cached != null)
		{
			if (cached.d || cached.s < 0)
				return cached.b;
			if (cached.c != '' && fileSize(cached.c) == cached.s)
				return cached.b;
		}

		if (DEFAULT_BPM_MAP.exists(fileSngName))
		{
			bpmMap[normalPath] = {b: DEFAULT_BPM_MAP[fileSngName], s: -1, c: '', d: true};
			dirty = true;
			return DEFAULT_BPM_MAP[fileSngName];
		}

		if (!pathExists(normalPath) || !isDir(normalPath))
		{
			trace('[BPMCache] Missing data folder for $fileSngName in $normalPath for BPM scrapping!!');
			bpmMap[normalPath] = {b: 0, s: -2, c: '', d: true};
			dirty = true;
			return 0;
		}

		var chartFiles:Array<String>;
		try {
			chartFiles = sys.FileSystem.readDirectory(normalPath);
		} catch(e:Dynamic) {
			trace('[BPMCache] Failed to read directory: $normalPath — $e');
			return 0;
		}

		chartFiles = chartFiles.filter(s ->
			s != null
			&& s.toLowerCase().startsWith(fileSngName.toLowerCase())
			&& s.toLowerCase().endsWith(".json")
		);

		if (chartFiles.length == 0)
		{
			trace('[BPMCache] No chart files found for $fileSngName in $normalPath');
			bpmMap[normalPath] = {b: 0, s: -2, c: '', d: true};
			dirty = true;
			return 0;
		}

		var chosenChart = normalPath + "/" + chartFiles[0];
		var result:Int = 0;

		if (pathExists(chosenChart))
		{
			var content = readFile(chosenChart);
			if (content != null && content.length > 0)
			{
				var cleanChart = chartClean.replace(content, "");
				if (bpmFinder.match(cleanChart))
				{
					var parsed = Std.parseInt(bpmFinder.matched(1));
					result = parsed != null ? parsed : 0;
					trace('[BPMCache] Found BPM $result for $fileSngName');
				}
			}
		}
		else
		{
			trace('[BPMCache] Missing chart file: $chosenChart');
		}

		bpmMap[normalPath] = {b: result, s: fileSize(chosenChart), c: chosenChart, d: false};
		dirty = true;
		return result;
	}
}
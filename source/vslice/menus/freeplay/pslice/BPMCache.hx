package vslice.menus.freeplay.pslice;

//? uses sys.FileSystem instead of NativeFileSystem for reliable path resolution
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

    private var bpmMap:Map<String,Int> = DEFAULT_BPM_MAP.copy();
    private var bpmFinder:EReg = ~/"bpm": *([0-9]+)/g;
    private var chartClean:EReg = ~/"notes": *\[.*\]/gs;

    public static var instance = new BPMCache();
    public function new() {}

    // ✅ Güvenli path normalize fonksiyonu
    private function normalizePath(path:String):String
    {
        if (path == null) return "";
        path = path.split("\\").join("/");
        while (path.indexOf("//") >= 0)
            path = path.split("//").join("/");
        return path;
    }

    // ✅ sys.FileSystem ile güvenli exists kontrolü
    private function pathExists(path:String):Bool
    {
        if (path == null || path.length == 0) return false;
        try {
            return sys.FileSystem.exists(path);
        } catch(e:Dynamic) {
            return false;
        }
    }

    // ✅ sys.FileSystem ile güvenli directory kontrolü
    private function isDir(path:String):Bool
    {
        if (!pathExists(path)) return false;
        try {
            return sys.FileSystem.isDirectory(path);
        } catch(e:Dynamic) {
            return false;
        }
    }

    // ✅ sys.FileSystem ile güvenli dosya okuma
    private function readFile(path:String):String
    {
        try {
            return sys.io.File.getContent(path);
        } catch(e:Dynamic) {
            trace('[BPMCache] Failed to read file: $path — $e');
            return "";
        }
    }

    public function getBPM(sngDataPath:String, fileSngName:String):Int
    {
        var normalPath = normalizePath(sngDataPath);

        if (bpmMap.exists(normalPath))
            return bpmMap[normalPath];

        bpmMap[normalPath] = 0;

        // ✅ DEFAULT_BPM_MAP'te varsa direkt dön
        if (DEFAULT_BPM_MAP.exists(fileSngName))
        {
            bpmMap[normalPath] = DEFAULT_BPM_MAP[fileSngName];
            return bpmMap[normalPath];
        }

        if (!pathExists(normalPath) || !isDir(normalPath))
        {
            trace('[BPMCache] Missing data folder for $fileSngName in $normalPath for BPM scrapping!!');
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
            return 0;
        }

        var chosenChart = normalPath + "/" + chartFiles[0];

        if (pathExists(chosenChart))
        {
            var content = readFile(chosenChart);
            if (content != null && content.length > 0)
            {
                var cleanChart = chartClean.replace(content, "");
                if (bpmFinder.match(cleanChart))
                {
                    bpmMap[normalPath] = Std.parseInt(bpmFinder.matched(1));
                    trace('[BPMCache] Found BPM ${bpmMap[normalPath]} for $fileSngName');
                }
                else
                {
                    trace('[BPMCache] Failed to scrape BPM for $fileSngName, using default');
                    if (DEFAULT_BPM_MAP.exists(fileSngName))
                        bpmMap[normalPath] = DEFAULT_BPM_MAP[fileSngName];
                }
            }
        }
        else
        {
            trace('[BPMCache] Missing chart file: $chosenChart');
        }

        return bpmMap[normalPath];
    }

    public function clearCache()
    {
        bpmMap = DEFAULT_BPM_MAP.copy();
    }
}

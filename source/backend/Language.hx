package backend;

class Language
{
    public static var defaultLangName:String = 'Türkçe (TR)';
    public static var currentLanguage:String = '';
    public static var loadedPhraseCount:Int = 0;

    #if TRANSLATIONS_ALLOWED
    private static var phrases:Map<String, String> = [];

    // -------------------------------------------------------------------------
    // Desteklenen dil dosyası varyantları (öncelik sırasına göre)
    // Örn: language = "EN-US" ise şu sırayla arar:
    //   1) EN-US.lang
    //   2) en-us.lang  
    //   3) EN_US.lang
    //   4) en_us.lang
    //   5) en.lang     (fallback — tire/alt çizgiden önceki kısım)
    //   6) EN.lang
    // -------------------------------------------------------------------------
    private static function buildSearchVariants(langFile:String):Array<String>
    {
        var variants:Array<String> = [];
        var raw = langFile.trim();

        if (raw.length == 0)
            return variants;

        // Uzantıyı temizle (kullanıcı yanlışlıkla .lang yazmışsa)
        if (raw.toLowerCase().endsWith('.lang'))
            raw = raw.substr(0, raw.length - 5);

        // Temel varyantlar
        variants.push(raw);                                    // EN-US
        variants.push(raw.toLowerCase());                      // en-us
        variants.push(raw.toUpperCase());                      // EN-US (zaten aynı olabilir ama garanti)

        // Tire <-> alt çizgi varyantları
        if (raw.contains('-'))
        {
            var underscored = raw.split('-').join('_');
            variants.push(underscored);                        // EN_US
            variants.push(underscored.toLowerCase());          // en_us
            variants.push(underscored.toUpperCase());          // EN_US
        }
        else if (raw.contains('_'))
        {
            var dashed = raw.split('_').join('-');
            variants.push(dashed);                             // EN-US
            variants.push(dashed.toLowerCase());               // en-us
            variants.push(dashed.toUpperCase());               // EN-US
        }

        // Kısa fallback: EN-US → EN, tr-TR → tr
        var shortLang = '';
        if (raw.contains('-'))
            shortLang = raw.split('-')[0];
        else if (raw.contains('_'))
            shortLang = raw.split('_')[0];

        if (shortLang.length > 0)
        {
            variants.push(shortLang);                          // EN
            variants.push(shortLang.toLowerCase());            // en
            variants.push(shortLang.toUpperCase());            // EN
        }

        // Duplikatları temizle (sırayı koru)
        var seen:Map<String, Bool> = [];
        var unique:Array<String> = [];
        for (v in variants)
        {
            if (!seen.exists(v))
            {
                seen.set(v, true);
                unique.push(v);
            }
        }

        return unique;
    }

    private static function tryLoadLangFile(langFile:String):Array<String>
    {
        var variants = buildSearchVariants(langFile);

        for (variant in variants)
        {
            var path = 'data/$variant.lang';
            var loaded:Array<String> = Mods.mergeAllTextsNamed(path);

            if (loaded != null && loaded.length > 0)
            {
                trace('[Language] Loaded: $path (variant: $variant)');
                currentLanguage = variant;
                return loaded;
            }
        }

        // Hiçbiri bulunamadı — hepsini logla
        trace('[Language] WARNING: No lang file found! Tried variants:');
        for (variant in variants)
            trace('  - data/$variant.lang');

        return [];
    }
    #end

	public static function reloadPhrases()
	{
		#if TRANSLATIONS_ALLOWED
		phrases.clear();

		var langFile:String = ClientPrefs.data.language;

		// Hardcoded dil ise dosya aramaya gerek yok
		if (langFile == null || langFile.length == 0 || langFile == ClientPrefs.defaultData.language)
		{
			trace('[Language] Using default hardcoded language. No file needed.');
			AlphaCharacter.loadAlphabetData();
			return;
		}

		var loadedText:Array<String> = Mods.mergeAllTextsNamed('data/$langFile.lang');

		var hasPhrases:Bool = false;
		for (num => phrase in loadedText)
		{
			phrase = phrase.trim();

			// BOM temizle
			if (phrase.length > 0 && phrase.charCodeAt(0) == 0xFEFF)
				phrase = phrase.substr(1);

			// İlk satır: dil adı
			if (num < 1 && !phrase.contains(':'))
			{
				phrases.set('language_name', phrase.trim());
				continue;
			}

			// Kısa satır veya yorum
			if (phrase.length < 4 || phrase.startsWith('//'))
				continue;

			var n:Int = phrase.indexOf(':');
			if (n < 0)
				continue;

			var key:String = phrase.substr(0, n).trim().toLowerCase();

			var value:String = phrase.substr(n);
			n = value.indexOf('"');
			if (n < 0)
				continue;

			phrases.set(key, value.substring(n + 1, value.lastIndexOf('"')).replace('\\n', '\n'));
			hasPhrases = true;
		}

		if (!hasPhrases)
		{
			trace('[Language] No phrases found in: $langFile.lang — falling back to default');
			ClientPrefs.data.language = ClientPrefs.defaultData.language;
		}

		var alphaPath:String = getFileTranslation('images/alphabet');
		if (alphaPath.startsWith('images/'))
			alphaPath = alphaPath.substr('images/'.length);
		var pngPos:Int = alphaPath.indexOf('.png');
		if (pngPos > -1)
			alphaPath = alphaPath.substring(0, pngPos);
		AlphaCharacter.loadAlphabetData(alphaPath);

		#else
		AlphaCharacter.loadAlphabetData();
		#end
	}

    // -------------------------------------------------------------------------
    // Line cleaning
    // -------------------------------------------------------------------------

    private static function cleanLine(line:String):String
    {
        var cleaned = line.trim();

        // UTF-8 BOM karakterini temizle
        if (cleaned.length > 0 && cleaned.charCodeAt(0) == 0xFEFF)
            cleaned = cleaned.substr(1);

        // Satır sonu karakterlerini temizle
        cleaned = cleaned.split('\r').join('');

        return cleaned;
    }

    private static function processEscapes(str:String):String
    {
        str = str.replace('\\n', '\n');
        str = str.replace('\\t', '\t');
        str = str.replace('\\"', '"');
        str = str.replace('\\\\', '\\');
        return str;
    }

    // -------------------------------------------------------------------------
    // Getters (bunlar aynı kaldı, küçük iyileştirmeler)
    // -------------------------------------------------------------------------

    inline public static function getPhrase(key:String, ?defaultPhrase:String, values:Array<Dynamic> = null):String
    {
        #if TRANSLATIONS_ALLOWED
        var str:String = phrases.get(formatKey(key));
        if (str == null)
            str = defaultPhrase;
        #else
        var str:String = defaultPhrase;
        #end

        if (str == null)
            str = key;

        if (values != null)
            for (num => value in values)
                str = str.replace('{${num + 1}}', Std.string(value));

        return str;
    }

    inline public static function getFileTranslation(key:String)
    {
        #if TRANSLATIONS_ALLOWED
        var str:String = phrases.get(key.trim().toLowerCase());
        if (str != null)
            key = str;
        #end
        return key;
    }

    // -------------------------------------------------------------------------
    // Yeni: Debug / bilgi fonksiyonları
    // -------------------------------------------------------------------------

    #if TRANSLATIONS_ALLOWED
    public static function hasPhrase(key:String):Bool
    {
        return phrases.exists(formatKey(key));
    }

    public static function getAllKeys():Array<String>
    {
        var keys:Array<String> = [];
        for (key in phrases.keys())
            keys.push(key);
        return keys;
    }

    public static function getLoadedLanguageName():String
    {
        var name = phrases.get('language_name');
        return (name != null) ? name : currentLanguage;
    }

    public static function getPhraseCount():Int
    {
        return loadedPhraseCount;
    }

    public static function dumpAllPhrases():Void
    {
        trace('========== LANGUAGE DUMP ==========');
        trace('Language: $currentLanguage');
        trace('Phrases: $loadedPhraseCount');
        trace('-----------------------------------');
        for (key => value in phrases)
            trace('  [$key] => "$value"');
        trace('===================================');
    }

    inline static private function formatKey(key:String)
    {
        final hideChars = ~/[~&\\\/;:<>#.,'"%?!]/g;
        return hideChars.replace(key.replace(' ', '_'), '').toLowerCase().trim();
    }
    #end

    // -------------------------------------------------------------------------
    // Lua callbacks
    // -------------------------------------------------------------------------

    #if LUA_ALLOWED
    public static function addLuaCallbacks(lua:State)
    {
        Lua_helper.add_callback(lua, "getTranslationPhrase", function(key:String, ?defaultPhrase:String, ?values:Array<Dynamic> = null) {
            return getPhrase(key, defaultPhrase, values);
        });

        Lua_helper.add_callback(lua, "getFileTranslation", function(key:String) {
            return getFileTranslation(key);
        });

        // Yeni lua callbacks
        Lua_helper.add_callback(lua, "hasTranslationPhrase", function(key:String) {
            #if TRANSLATIONS_ALLOWED
            return hasPhrase(key);
            #else
            return false;
            #end
        });

        Lua_helper.add_callback(lua, "getLoadedLanguageName", function() {
            #if TRANSLATIONS_ALLOWED
            return getLoadedLanguageName();
            #else
            return defaultLangName;
            #end
        });

        Lua_helper.add_callback(lua, "getTranslationPhraseCount", function() {
            #if TRANSLATIONS_ALLOWED
            return getPhraseCount();
            #else
            return 0;
            #end
        });
    }
    #end
}
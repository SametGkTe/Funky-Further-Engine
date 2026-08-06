package backend;

#if ACHIEVEMENTS_ALLOWED
import objects.AchievementPopup;
import haxe.Exception;
import haxe.Json;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

typedef Achievement =
{
	var name:String;
	var description:String;
	@:optional var hidden:Bool;
	@:optional var maxScore:Float;
	@:optional var maxDecimals:Int;

	//handled automatically, ignore these two
	@:optional var mod:String;
	@:optional var ID:Int; 
}

enum abstract AchievementOp(String)
{
	var GET = 'get';
	var SET = 'set';
	var ADD = 'add';
}

class Achievements {
	public static function init()
	{
		createAchievement('friday_night_play',		{name: "Cuma Gecesi Çılgınlığı", description: "Bir Cuma... Gecesi oyna.", hidden: true});

		createAchievement('week1_nomiss',			{name: "Banada Baba Diyor", description: "1. Haftayı Zorlukta Hata Yapmadan Bitir."});
		createAchievement('week2_nomiss',			{name: "Hile Yok Artık", description: "2. Haftayı Zorlukta Hata Yapmadan Bitir."});
		createAchievement('week3_nomiss',			{name: "Bana Tetikçi Deyin", description: "3. Haftayı Zorlukta Hata Yapmadan Bitir."});
		createAchievement('week4_nomiss',			{name: "Kadın Avcısı", description: "4. Haftayı Zorlukta Hata Yapmadan Bitir."});
		createAchievement('week5_nomiss',			{name: "Hatasız Noel", description: "5. Haftayı Zorlukta Hata Yapmadan Bitir."});
		createAchievement('week6_nomiss',			{name: "Yüksek Skor!!", description: "6. Haftayı Zorlukta Hata Yapmadan Bitir."});
		createAchievement('week7_nomiss',			{name: "Kahretsin Tanrım!", description: "7. Haftayı Zorlukta Hata Yapmadan Bitir."});

		createAchievement('ur_bad',					{name: "Ne Biçim Bir Felaket!", description: "Bir şarkıyı %20'den düşük bir puanla bitir."});
		createAchievement('ur_good',				{name: "Mükemmeliyetçi", description: "Bir şarkıyı %100 puanla bitir."});
		createAchievement('roadkill_enthusiast',	{name: "Yol Kazası Meraklısı", description: "Yardımcıların (Henchmen) 50 kez ölmesini izle.", maxScore: 50, maxDecimals: 0});
		createAchievement('oversinging', 			{name: "Fazla mı Şarkı Söyledin...?", description: "Boş duruma (Idle) dönmeden 10 saniye boyunca şarkı söyle."});
		createAchievement('hype',					{name: "Hiperaktif", description: "Boş duruma (Idle) dönmeden bir şarkıyı bitir."});
		createAchievement('two_keys',				{name: "Sadece İkimiz", description: "Sadece iki tuşa basarak bir şarkıyı bitir."});
		createAchievement('toastie',				{name: "Tost Makinesi Oyuncusu", description: "Oyunu bir tost makinesinde çalıştırmayı denedin mi?"});
		createAchievement('debugger',				{name: "Hata Ayıklayıcı", description: "Şarkı Düzenleyicisinden (Chart Editor) Test Şarkısını bitir.", hidden: true});
		createAchievement('1000combo',				{name: "1000 in Üzerinde!", description: "1000 den yüksek bir kombo ile bir şarkıyı tamamla.", hidden: true});
		// createAchievement('gkte',					{name: "N-NASIL?", description: "SametGkTe yi bir şarkıda Liderlik Tablosundan geç. (sanırım aktif değil)", hidden: true});
		
		createAchievement('turkiye',				{name: "NE MUTLU TÜRKÜM DİYENE!", description: "AS BAYRAKLI AS!", hidden: true});
		createAchievement('peto',				{name: "Oynadığın İçin Teşekkürler! :D", description: "Psych Engine Türkiye Online'ın Oyuncularından Ol."});
		createAchievement('abonem',				{name: "Abonem Kalmadı!", description: "Abonelerin Hepsini Öldürdün!", hidden: true});
		//dont delete this thing below
		_originalLength = _sortID + 1;
	}

	public static var achievements:Map<String, Achievement> = new Map<String, Achievement>();
	public static var variables:Map<String, Float> = [];
	public static var achievementsUnlocked:Array<String> = [];
	private static var _firstLoad:Bool = true;

	public static function get(name:String):Achievement
		return achievements.get(name);
	public static function exists(name:String):Bool
		return achievements.exists(name);

	public static function load():Void
	{
		if(!_firstLoad) return;

		if(_originalLength < 0) init();

		if(FlxG.save.data != null) {
			if(FlxG.save.data.achievementsUnlocked != null)
				achievementsUnlocked = FlxG.save.data.achievementsUnlocked;

			if(FlxG.save.data.achievementsMap != null) {
				var achievementsMap:Map<String, Bool> = cast FlxG.save.data.achievementsMap;
				trace('Found legacy achievement save data! ($achievementsMap)');
				for(achievement=>unlocked in achievementsMap) {
					if(unlocked && !achievementsUnlocked.contains(achievement))
						achievementsUnlocked.push(achievement);
				}

				FlxG.save.data.achievementsMap = null;
			}

			var savedMap:Map<String, Float> = cast FlxG.save.data.achievementsVariables;
			if(savedMap != null)
			{
				for (key => value in savedMap)
				{
					variables.set(key, value);
				}
			}

			if(FlxG.save.data.henchmenDeath != null) {
				trace('Found legacy "Roadkill Enthusiast" save data! (${FlxG.save.data.henchmenDeath})');

				if((variables.get('roadkill_enthusiast') ?? 0) < FlxG.save.data.henchmenDeath)
					variables.set('roadkill_enthusiast', FlxG.save.data.henchmenDeath);

				FlxG.save.data.henchmenDeath = null;
			}

			_firstLoad = false;
		}
	}

	public static function save():Void
	{
		FlxG.save.data.achievementsUnlocked = achievementsUnlocked;
		FlxG.save.data.achievementsVariables = variables;
	}
	
	public static function getScore(name:String):Float
		return _scoreFunc(name, GET);

	public static function setScore(name:String, value:Float, saveIfNotUnlocked:Bool = true):Float
		return _scoreFunc(name, SET, value, saveIfNotUnlocked);

	public static function addScore(name:String, value:Float = 1, saveIfNotUnlocked:Bool = true):Float
		return _scoreFunc(name, ADD, value, saveIfNotUnlocked);

	static function _scoreFunc(name:String, mode:AchievementOp, addOrSet:Float = 1, saveIfNotUnlocked:Bool = true):Float
	{
		if(!variables.exists(name))
			variables.set(name, 0);

		if(achievements.exists(name))
		{
			var achievement:Achievement = achievements.get(name);
			if(achievement.maxScore < 1) throw new Exception('Achievement has score disabled or is incorrectly configured: $name');

			if(achievementsUnlocked.contains(name)) return achievement.maxScore;

			var val = addOrSet;
			switch(mode)
			{
				case GET: return variables.get(name); //get
				case ADD: val += variables.get(name); //add
				default:
			}

			if(val >= achievement.maxScore)
			{
				unlock(name);
				val = achievement.maxScore;
			}
			variables.set(name, val);

			Achievements.save();
			if(saveIfNotUnlocked || val >= achievement.maxScore) FlxG.save.flush();
			return val;
		}
		return -1;
	}

	static var _lastUnlock:Int = -999;
	public static function unlock(name:String, autoStartPopup:Bool = true):String {
		if(!achievements.exists(name))
		{
			FlxG.log.error('Achievement "$name" does not exists!');
			throw new Exception('Achievement "$name" does not exists!');
			return null;
		}

		if(Achievements.isUnlocked(name)) return null;

		trace('Completed achievement "$name"');
		achievementsUnlocked.push(name);

		// earrape prevention
		var time:Int = openfl.Lib.getTimer();
		if(Math.abs(time - _lastUnlock) >= 100) //If last unlocked happened in less than 100 ms (0.1s) ago, then don't play sound
		{
			FlxG.sound.play(Paths.sound('confirmMenu'), 0.5);
			_lastUnlock = time;
		}

		Achievements.save();
		FlxG.save.flush();

		if(autoStartPopup) startPopup(name);
		return name;
	}

	inline public static function isUnlocked(name:String)
		return achievementsUnlocked.contains(name);

	@:allow(objects.AchievementPopup)
	private static var _popups:Array<AchievementPopup> = [];

	public static var showingPopups(get, never):Bool;
	public static function get_showingPopups()
		return _popups.length > 0;

	public static function startPopup(achieve:String, endFunc:Void->Void = null) {
		for (popup in _popups)
		{
			if(popup == null) continue;
			popup.intendedY += 150;
		}

		var newPop:AchievementPopup = new AchievementPopup(achieve, endFunc);
		_popups.push(newPop);
		//trace('Giving achievement ' + achieve);
	}

	// Map sorting cuz haxe is physically incapable of doing that by itself
	static var _sortID = 0;
	static var _originalLength = -1;
	public static function createAchievement(name:String, data:Achievement, ?mod:String = null)
	{
		data.ID = _sortID;
		data.mod = mod;
		achievements.set(name, data);
		_sortID++;
	}

	#if MODS_ALLOWED
	public static function reloadList()
	{
		// remove modded achievements
		if((_sortID + 1) > _originalLength)
			for (key => value in achievements)
				if(value.mod != null)
					achievements.remove(key);

		_sortID = _originalLength-1;

		var modLoaded:String = Mods.currentModDirectory;
		Mods.currentModDirectory = null;
		loadAchievementJson(Paths.mods('data/achievements.json'));
		for (i => mod in Mods.parseList().enabled)
		{
			Mods.currentModDirectory = mod;
			loadAchievementJson(Paths.mods('$mod/data/achievements.json'));
		}
		Mods.currentModDirectory = modLoaded;
	}

	inline static function loadAchievementJson(path:String, addMods:Bool = true)
	{
		var retVal:Array<Dynamic> = null;
		if(FunkinFileSystem.exists(path)) {
			try {
				var rawJson:String = FunkinFileSystem.getText(path).trim();
				if(rawJson != null && rawJson.length > 0) retVal = tjson.TJSON.parse(rawJson); //Json.parse('{"achievements": $rawJson}').achievements;
				
				if(addMods && retVal != null)
				{
					for (i in 0...retVal.length)
					{
						var achieve:Dynamic = retVal[i];
						if(achieve == null)
						{
							var errorTitle = 'Mod name: ' + Mods.currentModDirectory != null ? Mods.currentModDirectory : "None";
							var errorMsg = 'Achievement #${i+1} is invalid.';
							#if windows
							lime.app.Application.current.window.alert(errorMsg, errorTitle);
							#end
							trace('$errorTitle - $errorMsg');
							continue;
						}

						var key:String = achieve.save;
						if(key == null || key.trim().length < 1)
						{
							var errorTitle = 'Error on Achievement: ' + (achieve.name != null ? achieve.name : achieve.save);
							var errorMsg = 'Missing valid "save" value.';
							#if windows
							lime.app.Application.current.window.alert(errorMsg, errorTitle);
							#end
							trace('$errorTitle - $errorMsg');
							continue;
						}
						key = key.trim();
						if(achievements.exists(key)) continue;

						createAchievement(key, achieve, Mods.currentModDirectory);
					}
				}
			} catch(e:Dynamic) {
				var errorTitle = 'Mod name: ' + Mods.currentModDirectory != null ? Mods.currentModDirectory : "None";
				var errorMsg = 'Error loading achievements.json: $e';
				#if windows
				lime.app.Application.current.window.alert(errorMsg, errorTitle);
				#end
				trace('$errorTitle - $errorMsg');
			}
		}
		return retVal;
	}
	#end

	#if LUA_ALLOWED
	public static function addLuaCallbacks(funk:FunkinLua)
	{
		var lua:State = funk.lua;

		Lua_helper.add_callback(lua, "getAchievementScore", function(name:String):Float
		{
			if(!achievements.exists(name))
			{
				funk.luaTrace('getAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return getScore(name);
		});
		Lua_helper.add_callback(lua, "setAchievementScore", function(name:String, ?value:Float = 0, ?saveIfNotUnlocked:Bool = true):Float
		{
			if(!achievements.exists(name))
			{
				funk.luaTrace('setAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return setScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "addAchievementScore", function(name:String, ?value:Float = 1, ?saveIfNotUnlocked:Bool = true):Float
		{
			if(!achievements.exists(name))
			{
				funk.luaTrace('addAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return addScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "unlockAchievement", function(name:String):Dynamic
		{
			if(!achievements.exists(name))
			{
				funk.luaTrace('unlockAchievement: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return null;
			}
			return unlock(name);
		});
		Lua_helper.add_callback(lua, "isAchievementUnlocked", function(name:String):Dynamic
		{
			if(!achievements.exists(name))
			{
				funk.luaTrace('isAchievementUnlocked: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return null;
			}
			return isUnlocked(name);
		});
		Lua_helper.add_callback(lua, "achievementExists", function(name:String) return achievements.exists(name));
	}
	#end
}
#end
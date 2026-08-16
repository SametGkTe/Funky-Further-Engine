package backend;

#if ACHIEVEMENTS_ALLOWED
import objects.AchievementPopup;
import haxe.Exception;
import haxe.Json;

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
		createAchievement('friday_night_play',		{name: Language.getPhrase('achievement_friday_night_play', "Cuma Gecesi Çılgınlığı"), description: Language.getPhrase('achievement_desc_friday_night_play', "Bir Cuma... Gecesi oyna."), hidden: true});
		#if BASE_GAME_FILES
		createAchievement('week1_nomiss',			{name: Language.getPhrase('achievement_week1_nomiss', "O Bana da Baba Diyor"), description: Language.getPhrase('achievement_desc_week1_nomiss', "Hafta 1'i Zor modda Iskasız bitir.")});
		createAchievement('week2_nomiss',			{name: Language.getPhrase('achievement_week2_nomiss', "Artık Numara Yok"), description: Language.getPhrase('achievement_desc_week2_nomiss', "Hafta 2'yi Zor modda Iskasız bitir.")});
		createAchievement('week3_nomiss',			{name: Language.getPhrase('achievement_week3_nomiss', "Bana Tetikçi Deyin"), description: Language.getPhrase('achievement_desc_week3_nomiss', "Hafta 3'ü Zor modda Iskasız bitir.")});
		createAchievement('week4_nomiss',			{name: Language.getPhrase('achievement_week4_nomiss', "Hanım Avcısı"), description: Language.getPhrase('achievement_desc_week4_nomiss', "Hafta 4'ü Zor modda Iskasız bitir.")});
		createAchievement('week5_nomiss',			{name: Language.getPhrase('achievement_week5_nomiss', "Iskasız Noel"), description: Language.getPhrase('achievement_desc_week5_nomiss', "Hafta 5'i Zor modda Iskasız bitir.")});
		createAchievement('week6_nomiss',			{name: Language.getPhrase('achievement_week6_nomiss', "Yüksek Skor!!"), description: Language.getPhrase('achievement_desc_week6_nomiss', "Hafta 6'yı Zor modda Iskasız bitir.")});
		createAchievement('week7_nomiss',			{name: Language.getPhrase('achievement_week7_nomiss', "Kahretsin Ya!"), description: Language.getPhrase('achievement_desc_week7_nomiss', "Hafta 7'yi Zor modda Iskasız bitir.")});
		createAchievement('weekend1_nomiss',		{name: Language.getPhrase('achievement_weekend1_nomiss', "Sadece Dostça Bir Antrenman"), description: Language.getPhrase('achievement_desc_weekend1_nomiss', "Hafta Sonu 1'i Zor modda Iskasız bitir.")});
		#end
		createAchievement('ur_bad',					{name: Language.getPhrase('achievement_ur_bad', "Ne Büyük Bir Felaket!"), description: Language.getPhrase('achievement_desc_ur_bad', "Bir şarkıyı %20'nin altında bir doğruluk ile tamamla.")});
		createAchievement('ur_good',				{name: Language.getPhrase('achievement_ur_good', "Mükemmeliyetçi"), description: Language.getPhrase('achievement_desc_ur_good', "Bir şarkıyı %100 doğruluk ile tamamla.")});
		#if BASE_GAME_FILES
		createAchievement('roadkill_enthusiast',	{name: Language.getPhrase('achievement_roadkill_enthusiast', "Ezilme Meraklısı"), description: Language.getPhrase('achievement_desc_roadkill_enthusiast', "Uşakların 50 kez ölmesini izle."), maxScore: 50, maxDecimals: 0});
		#end
		createAchievement('oversinging', 			{name: Language.getPhrase('achievement_oversinging', "Fazla Söyleme...?"), description: Language.getPhrase('achievement_desc_oversinging', "Boş duruma \"idle\" dönmeden 10 saniye boyunca şarkı söyle.")});
		createAchievement('hype',					{name: Language.getPhrase('achievement_hype', "Hiperaktif"), description: Language.getPhrase('achievement_desc_hype', "Bir şarkıyı boş duruma \"idle\" dönmeden bitir.")});
		createAchievement('two_keys',				{name: Language.getPhrase('achievement_two_keys', "Sadece İkimiz"), description: Language.getPhrase('achievement_desc_two_keys', "Bir şarkıyı sadece iki tuşa basarak bitir.")});
		createAchievement('toastie',				{name: Language.getPhrase('achievement_toastie', "Tost Makinesi Oyuncusu"), description: Language.getPhrase('achievement_desc_toastie', "Oyunu tost makinesinde çalıştırmayı denedin mi?")});
		createAchievement('keyboard',				{name: Language.getPhrase('achievement_keyboard', "Klavye Kıran"), description: Language.getPhrase('achievement_desc_keyboard', "Hiç bunları okumayı düşünmemiştin.")});
		#if BASE_GAME_FILES
		createAchievement('debugger',				{name: Language.getPhrase('achievement_debugger', "Hata Ayıklayıcı"), description: Language.getPhrase('achievement_desc_debugger', "Nota Editöründen \"Test\" Şarkısını bitir."), hidden: true});
		createAchievement('pet', 			{name: Language.getPhrase('achievement_pet', "Oynadığın için Teşekkürler!"), description: Language.getPhrase('achievement_desc_pet', "Psych Engine Türkiye Oyuncularından biri ol!")});
		#end
		#if (TITLE_SCREEN_EASTER_EGG || PSYCH_WATERMARKS)
		createAchievement('pessy_easter_egg',		{name: Language.getPhrase('achievement_pessy_easter_egg', "Pessy Kızı"), description: Language.getPhrase('achievement_desc_pessy_easter_egg', "Heehee, beni buldun~!"), hidden: true});
		#end

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

			var savedMap:Map<String, Float> = cast FlxG.save.data.achievementsVariables;
			if(savedMap != null)
			{
				for (key => value in savedMap)
				{
					variables.set(key, value);
				}
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

		var time:Int = openfl.Lib.getTimer();
		if(Math.abs(time - _lastUnlock) >= 100)
		{
			FlxG.sound.play(Paths.sound('confirmMenu'), 0.5);
			_lastUnlock = time;
		}

		Achievements.save();
		FlxG.save.flush();

		//  SUPABASE
		AchievementSync.reportUnlock(name);

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
		if(FileSystem.exists(path)) {
			try {
				var rawJson:String = File.getContent(path).trim();
				if(rawJson != null && rawJson.length > 0) retVal = tjson.TJSON.parse(rawJson); //Json.parse('{"achievements": $rawJson}').achievements;
				
				if(addMods && retVal != null)
				{
					for (i in 0...retVal.length)
					{
						var achieve:Dynamic = retVal[i];
						if(achieve == null)
						{
							var errorTitle = 'Mod Adı: ' + Mods.currentModDirectory != null ? Mods.currentModDirectory : "None";
							var errorMsg = 'Başarı: #${i+1} geçersiz.';
							CoolUtil.showPopUp(errorMsg, errorTitle);
							continue;
						}

						var key:String = achieve.save;
						if(key == null || key.trim().length < 1)
						{
							var errorTitle = 'Başarım Hatası: ' + (achieve.name != null ? achieve.name : achieve.save);
							var errorMsg = '"save" değeri kullanılmamış durumda.';
							CoolUtil.showPopUp(errorMsg, errorTitle);
							continue;
						}
						key = key.trim();
						if(achievements.exists(key)) continue;

						createAchievement(key, achieve, Mods.currentModDirectory);
					}
				}
			} catch(e:Dynamic) {
				var errorTitle = 'Mod name: ' + Mods.currentModDirectory != null ? Mods.currentModDirectory : "None";
				var errorMsg = 'achievements.json yüklemesinde hata oluştu: $e';
				CoolUtil.showPopUp(errorMsg, errorTitle);
			}
		}
		return retVal;
	}
	#end

	#if LUA_ALLOWED
	public static function addLuaCallbacks(lua:State)
	{
		Lua_helper.add_callback(lua, "getAchievementScore", function(name:String):Float
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('getAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return getScore(name);
		});
		Lua_helper.add_callback(lua, "setAchievementScore", function(name:String, ?value:Float = 0, ?saveIfNotUnlocked:Bool = true):Float
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('setAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return setScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "addAchievementScore", function(name:String, ?value:Float = 1, ?saveIfNotUnlocked:Bool = true):Float
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('addAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return addScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "unlockAchievement", function(name:String):Dynamic
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('unlockAchievement: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return null;
			}
			return unlock(name);
		});
		Lua_helper.add_callback(lua, "isAchievementUnlocked", function(name:String):Dynamic
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('isAchievementUnlocked: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return null;
			}
			return isUnlocked(name);
		});
		Lua_helper.add_callback(lua, "achievementExists", function(name:String) return achievements.exists(name));
	}
	#end
}
#end
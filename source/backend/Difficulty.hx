package backend;

import openfl.utils.Assets as OpenFlAssets;
#if sys
import sys.FileSystem;
#end

class Difficulty
{
	public static final defaultList:Array<String> = [
		'Easy',
		'Normal',
		'Hard',
		'Erect',
		'Nightmare'
	];
	private static final defaultDifficulty:String = 'Normal';

	public static var list:Array<String> = [];

	inline static function getInternalName(?num:Null<Int> = null):String
	{
		var diffName:String = list[num == null ? PlayState.storyDifficulty : num];
		if(diffName == null) diffName = defaultDifficulty;
		return diffName;
	}

	static function parseDiffString(diffStr:String):Array<String>
	{
		var diffs:Array<String> = [];
		if(diffStr == null) return diffs;

		for(part in diffStr.split(','))
		{
			var diff:String = StringTools.trim(part);
			if(diff.length > 0 && !diffs.contains(diff))
				diffs.push(diff);
		}
		return diffs;
	}

	static function getBaseDiffList(?week:WeekData = null):Array<String>
	{
		var diffs:Array<String> = parseDiffString(week != null ? week.difficulties : null);
		if(diffs.length < 1) diffs = defaultList.copy();
		return diffs;
	}

	static function getChartKey(songName:String, diffName:String):String
	{
		var songPath:String = Paths.formatToSongPath(songName);
		var diffPath:String = Paths.formatToSongPath(diffName);

		var chartName:String = songPath;
		if(diffPath != Paths.formatToSongPath(defaultDifficulty))
			chartName += '-' + diffPath;

		return songPath + '/' + chartName;
	}

	static function pathExists(path:String):Bool
	{
		if(path == null || path.length < 1) return false;

		#if sys
		if(FileSystem.exists(path)) return true;
		#end

		return OpenFlAssets.exists(path);
	}

	public static function chartExists(songName:String, diffName:String):Bool
	{
		var chartKey:String = getChartKey(songName, diffName);

		#if MODS_ALLOWED
		if(pathExists(Paths.modsJson(chartKey))) return true;
		#end

		return pathExists(Paths.json(chartKey));
	}

	static function allSongsHaveDifficulty(week:WeekData, diffName:String):Bool
	{
		if(week == null || week.songs == null || week.songs.length < 1) return false;

		for(songData in week.songs)
		{
			var data:Array<Dynamic> = cast songData;
			if(data == null || data.length < 1) return false;

			var songName:String = data[0];
			if(songName == null || songName.length < 1 || !chartExists(songName, diffName))
				return false;
		}
		return true;
	}

	static function fixCurrentDiffIndex()
	{
		if(list == null || list.length < 1)
			list = [defaultDifficulty];

		if(PlayState.storyDifficulty < 0 || PlayState.storyDifficulty >= list.length)
		{
			var defaultIndex:Int = list.indexOf(defaultDifficulty);
			PlayState.storyDifficulty = defaultIndex >= 0 ? defaultIndex : 0;
		}
	}

	// STORY MODE İÇİN:
	// Bir zorluk ancak week içindeki TÜM şarkılarda varsa gösterilir.
	public static function buildListForWeek(week:WeekData = null):Array<String>
	{
		if(week == null) week = WeekData.getCurrentWeek();

		var baseDiffs:Array<String> = getBaseDiffList(week);
		if(week == null || week.songs == null || week.songs.length < 1)
			return baseDiffs;

		var result:Array<String> = [];
		for(diff in baseDiffs)
		{
			if(allSongsHaveDifficulty(week, diff))
				result.push(diff);
		}

		if(result.length < 1 && allSongsHaveDifficulty(week, defaultDifficulty))
			result.push(defaultDifficulty);

		return result.length > 0 ? result : [defaultDifficulty];
	}

	// FREEPLAY İÇİN:
	// Bir zorluk sadece seçili şarkıda varsa gösterilir.
	public static function buildListForSong(songName:String, ?week:WeekData = null):Array<String>
	{
		var baseDiffs:Array<String> = getBaseDiffList(week);
		var result:Array<String> = [];

		for(diff in baseDiffs)
		{
			if(chartExists(songName, diff))
				result.push(diff);
		}

		if(result.length < 1 && chartExists(songName, defaultDifficulty))
			result.push(defaultDifficulty);

		return result.length > 0 ? result : [defaultDifficulty];
	}

	public static function loadFromWeek(week:WeekData = null)
	{
		list = buildListForWeek(week);
		fixCurrentDiffIndex();
	}

	public static function loadFromSong(songName:String, ?week:WeekData = null)
	{
		list = buildListForSong(songName, week);
		fixCurrentDiffIndex();
	}

	inline public static function getFilePath(num:Null<Int> = null)
	{
		if(num == null) num = PlayState.storyDifficulty;

		var filePostfix:String = list[num];
		if(filePostfix != null && Paths.formatToSongPath(filePostfix) != Paths.formatToSongPath(defaultDifficulty))
			filePostfix = '-' + filePostfix;
		else
			filePostfix = '';

		return Paths.formatToSongPath(filePostfix);
	}

	public static function resetList()
	{
		list = defaultList.copy();
		fixCurrentDiffIndex();
	}

	public static function copyFrom(diffs:Array<String>)
	{
		list = diffs.copy();
		fixCurrentDiffIndex();
	}

	// DOSYA / PATH / JSON İÇİN ORİJİNAL AD
	inline public static function getString(?num:Null<Int> = null, ?canTranslate:Bool = false):String
	{
		return getInternalName(num);
	}

	// SADECE EKRANDA GÖSTERİLECEK AD
	inline public static function getDisplayString(?num:Null<Int> = null, ?canTranslate:Bool = true):String
	{
		var diffName:String = getInternalName(num);
		var defaultTurkishName:String = diffName;

		switch(Paths.formatToSongPath(diffName))
		{
			case 'easy':
				defaultTurkishName = 'Kolay';
			case 'normal':
				defaultTurkishName = 'Normal';
			case 'hard':
				defaultTurkishName = 'Zor';
			case 'erect':
				defaultTurkishName = 'Erect';
			case 'nightmare':
				defaultTurkishName = 'Kabus';
			case 'classic':
				defaultTurkishName = 'Klasik';
			case 'very-hard':
				defaultTurkishName = 'Çok Zor';
			case 'insane':
				defaultTurkishName = 'Çılgın';
		}

		var langKey:String = 'difficulty_' + Paths.formatToSongPath(diffName);
		return canTranslate ? Language.getPhrase(langKey, defaultTurkishName) : defaultTurkishName;
	}

	inline public static function getDefault():String
	{
		return defaultDifficulty;
	}

	/**
	 * Sprite dosyası için kullanılacak İngilizce diff id'sini döner.
	 *
	 * Zorluk adları Türkçeye çevrildiğinde ("Kolay", "Zor", "Kabus" vb.)
	 * freeplay sprite dosyaları hâlâ İngilizce isimlidir:
	 *   freeplayDifficulties/freeplay-easy.png  (kolay → easy)
	 *   freeplayDifficulties/freeplay-hard.png  (zor → hard)
	 * Bu fonksiyon görünen adı dosya adına eşler; bilinmeyen adlar olduğu gibi döner.
	 *
	 * @param diffId Görünen/gelen zorluk adı ("Kolay", "Easy", "normal" vb.)
	 * @return Sprite dosyasında kullanılacak normalize id ("easy", "hard" vb.)
	 */
	public static function getSpriteDiffId(diffId:String):String
	{
		if(diffId == null || diffId.length < 1)
			return diffId != null ? diffId : 'normal';

		var normalized:String = Paths.formatToSongPath(diffId);

		// Türkçe → İngilizce dosya adı eşlemesi
		switch(normalized)
		{
			case 'kolay':
				return 'easy';
			case 'normal':
				return 'normal';
			case 'zor':
				return 'hard';
			case 'kabus':
				return 'nightmare';
			case 'klasik':
				return 'classic';
			case 'cok-zor':
				return 'very-hard';
			case 'cilgin':
				return 'insane';
			case 'erect':
				return 'erect';
		}

		return normalized;
	}
}
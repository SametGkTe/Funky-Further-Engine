package options;

import states.TitleState;

#if MODS_ALLOWED
import sys.FileSystem;
#end

class PetSettingsState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('pet_settings_menu', 'P.E.T Ayarları');
		rpcTitle = 'P.E.T Ayarları Menüsünde';

		var option:Option = new Option(
			'P.E.T Filigranı',
			'Aktif edildiğinde, sol üst tarafta Psych Engine Türkiye filigranı görünür.',
			'petwatermark',
			BOOL,
			null,
			'pet_watermark'
		);
		addOption(option);

		option = new Option(
			'P.E.T Yükleme Ekranı',
			'Aktif edildiğinde, P.E.T yükleme ekranlarını etkinleştirir.',
			'petloadingscreen',
			BOOL,
			null,
			'pet_loading_screen'
		);
		addOption(option);

		option = new Option(
			'P.E.T Logo Stili:',
			'Filigrandaki logoyu seçin.',
			'petwatermarklogo',
			STRING,
			['V1', 'V2', 'V2U', 'ONLINE', 'Varsayılan'],
			'pet_logo_style'
		);
		addOption(option);

		option = new Option(
			'P.E.T Yükleme Ekranı Stili:',
			'P.E.T\'nin kullanacağı yükleme ekranı stilini seçin.',
			'petloadingscreenimage',
			STRING,
			['V1', 'V2', 'V2U', 'ONLINE'],
			'pet_loading_screen_style'
		);
		addOption(option);

		option = new Option(
			'Introyu Kapat',
			'Aktif edildiğinde, oyunun başlangıcında oynatılan intro videosu devre dışı bırakılır.',
			'disableIntroVideo',
			BOOL,
			null,
			'disable_intro'
		);
		addOption(option);

		var menuMusicOption:Option = new Option(
			'Menü Müziği',
			'Menüde çalacak müziği seçin. ENTER ile dropdown açın.',
			'menuMusic',
			DROPDOWN,
			getMenuMusicOptions(),
			'menu_music'
		);
		menuMusicOption.dropdownLabels = getMenuMusicLabels();
		menuMusicOption.dropdownIcons = getMenuMusicIcons();
		menuMusicOption.onChange = function() {
			applyMenuMusic();
		};
		addOption(menuMusicOption);
		
		option = new Option(
			'Menü Stili:',
			'P.E.T\'nin kullanacağı menü stilini seçin.',
			'menuStyle',
			STRING,
			['Orjinal', 'Yeni'],
			'pet_loading_screen_style'
		);
		addOption(option);

		super();
	}

	function getMenuMusicOptions():Array<String>
	{
		var options:Array<String> = [];

		options.push('freakyMenu');
		options.push('freakyMenuOLD');
		options.push('freakyMenu2');
		options.push('freakyMenu3');
		options.push('freakyMenu4');
		options.push('freakyMenu5');
		options.push('nothing');

		#if MODS_ALLOWED
		var modList = Mods.parseList();
		for (mod in modList.enabled)
		{
			var modMusicPath:String = Paths.mods(mod + '/music/freakyMenu.ogg');
			if (FileSystem.exists(modMusicPath))
				options.push('mod:' + mod);
		}
		#end

		return options;
	}

	function getMenuMusicLabels():Array<String>
	{
		var labels:Array<String> = [];

		labels.push(Language.getPhrase('menu_music_default', 'Varsayılan'));
		labels.push(Language.getPhrase('menu_music_default', 'Eski'));
		labels.push(Language.getPhrase('menu_music_original', 'Orijinal'));
		labels.push(Language.getPhrase('menu_music_online', 'Online'));
		labels.push(Language.getPhrase('menu_music_v2', 'V2'));
		labels.push(Language.getPhrase('menu_music_v1', 'V1'));
		labels.push(Language.getPhrase('menu_music_none', 'Yok'));

		#if MODS_ALLOWED
		var modList = Mods.parseList();
		for (mod in modList.enabled)
		{
			var modMusicPath:String = Paths.mods(mod + '/music/freakyMenu.ogg');
			if (FileSystem.exists(modMusicPath))
				labels.push(mod);
		}
		#end

		return labels;
	}

	function getMenuMusicIcons():Array<String>
	{
		var icons:Array<String> = [];

		icons.push('');
		icons.push('');
		icons.push('');
		icons.push('');
		icons.push('');
		icons.push('');

		#if MODS_ALLOWED
		var modList = Mods.parseList();
		for (mod in modList.enabled)
		{
			var modMusicPath:String = Paths.mods(mod + '/music/freakyMenu.ogg');
			if (FileSystem.exists(modMusicPath))
			{
				var iconName:String = getModOpponentIcon(mod);
				icons.push(iconName);
			}
		}
		#end

		return icons;
	}

	function getModOpponentIcon(modName:String):String
	{
		#if MODS_ALLOWED
		var weekDir:String = Paths.mods(modName + '/weeks/');
		if (FileSystem.exists(weekDir))
		{
			for (file in FileSystem.readDirectory(weekDir))
			{
				if (file.endsWith('.json'))
				{
					try
					{
						var content:String = sys.io.File.getContent(weekDir + file);
						var weekData:Dynamic = haxe.Json.parse(content);
						if (weekData.songs != null)
						{
							var songs:Array<Dynamic> = weekData.songs;
							if (songs.length > 0 && songs[0].length > 1)
								return songs[0][1];
						}
					}
					catch(e:Dynamic) {}
				}
			}
		}
		#end
		return 'face';
	}

	public static function applyMenuMusic()
	{
		var musicName:String = TitleState.getMenuMusicName();

		if (StringTools.startsWith(ClientPrefs.data.menuMusic, 'mod:'))
		{
			var modName:String = ClientPrefs.data.menuMusic.substr(4);
			#if MODS_ALLOWED
			Mods.currentModDirectory = modName;
			#end
		}

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		if (musicName != null)
		{
			FlxG.sound.playMusic(Paths.music(musicName), 0);
			FlxG.sound.music.fadeIn(1, 0, 0.7);
		}

		#if MODS_ALLOWED
		Mods.loadTopMod();
		#end
	}

	public static function getMenuMusicPath():String
	{
		var selected:String = ClientPrefs.data.menuMusic;
		if (selected == null || selected.length == 0)
			return 'freakyMenu';

		if (selected.indexOf('mod:') == 0)
		{
			var modName:String = selected.substr(4);
			#if MODS_ALLOWED
			Mods.currentModDirectory = modName;
			#end
			return 'freakyMenu';
		}

		return selected;
	}
}
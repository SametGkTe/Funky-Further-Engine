package mikolka.vslice.ui.obj;

import mikolka.compatibility.ModsHelper;
import mikolka.vslice.charSelect.CharSelectSubState;

class ModSelector extends FlxTypedSpriteGroup<FlxSprite>
{
	public var curMod(get, never):String;
	function get_curMod()
	{
		return directories[curDirectory] ?? '';
	}

	public var hasModsAvailable(get, never):Bool;
	function get_hasModsAvailable()
	{
		return directories.length > 1;
	}

	private var directoryTxt:FlxText;
	private var curDirectory = 0;
	private var directories:Array<String> = [null];
	private var parent:CharSelectSubState;
	public var allowInput:Bool = false;

	public function new(parent:CharSelectSubState)
	{
		super();
		this.parent = parent;

		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 70, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);

		directoryTxt = new FlxText(textBG.x, textBG.y + 4, FlxG.width, '', 32);
		directoryTxt.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);

		var enabledMods:Array<String> = [];
		#if !LEGACY_PSYCH
		for (folder in Mods.parseList().enabled)
			enabledMods.push(folder);
		#else
		for (folder in ModsHelper.getEnabledMods())
			enabledMods.push(folder);
		#end

		for (folder in enabledMods)
		{
			if (modHasCharacters(folder) || modHasPlayers(folder))
			{
				if (!directories.contains(folder))
					directories.push(folder);
			}
		}

		var found:Int = directories.indexOf(ModsHelper.getActiveMod());
		if (found > -1)
			curDirectory = found;

		changeDirectory(0, true);
	}

	function modHasCharacters(folder:String):Bool
	{
		var charDir = 'mods/$folder/characters';
		if (!NativeFileSystem.exists(charDir))
			return false;

		for (file in NativeFileSystem.readDirectory(charDir))
		{
			if (file.endsWith(".json"))
				return true;
		}
		return false;
	}

	function modHasPlayers(folder:String):Bool
	{
		var playersDir = 'mods/$folder/data/players';
		if (!NativeFileSystem.exists(playersDir))
			return false;

		for (file in NativeFileSystem.readDirectory(playersDir))
		{
			if (file.endsWith(".json"))
				return true;
		}
		return false;
	}

	public function changeDirectory(change:Int = 0, ignoreInputBlock:Bool = false)
	{
		if (!allowInput && !ignoreInputBlock)
			return;

		curDirectory += change;

		if (curDirectory < 0)
			curDirectory = directories.length - 1;
		if (curDirectory >= directories.length)
			curDirectory = 0;

		if (directories[curDirectory] == null || directories[curDirectory].length < 1)
		{
			if (parent != null) visible = false;
			ModsHelper.loadModDir("");
			var nxtArrow = directories.length == 1 ? '  ' : '=>';
			var prvArrow = directories.length == 1 ? '  ' : '<=';
			directoryTxt.text = '$prvArrow No Mod Directory Loaded $nxtArrow';
		}
		else
		{
			if (parent != null) visible = true;
			var curModDir = directories[curDirectory];
			ModsHelper.loadModDir(curModDir);
			directoryTxt.text = '<= Loaded Mod Directory: ' + curModDir + " =>";
		}

		directoryTxt.text = directoryTxt.text.toUpperCase();

		@:privateAccess
		{
			if (parent != null)
			{
				parent.remove(parent.grpIcons);
				parent.availableChars.clear();
				parent.currentPage = 0;
				parent.loadAvailableCharacters();
				parent.initLocks();
				parent.updatePageIndicator();
			}
		}
	}
}
package options;

import states.editors.MasterEditorMenu;
import states.editors.ChartingState;
import states.editors.CharacterEditorState;
import states.editors.StageEditorState;
import states.editors.WeekEditorState;
import states.editors.NoteSplashEditorState;
import states.editors.DialogueEditorState;
import states.editors.ModPorterState;
import states.FreeplayState;
import objects.Character;

class EditorToolsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('editor_tools_menu', 'Editör Araçları');
		rpcTitle = 'Editor Tools Menu';

		addOpen('Editörler Menüsü',
			'Tüm editörlerin listelendiği ana editör menüsüne gider.',
			function() go(new MasterEditorMenu()));

		addOpen('Chart Editor',
			'Şarkı/chart düzenleme editörünü doğrudan açar.',
			function() goLoad(new ChartingState(), false));

		addOpen('Karakter Editörü',
			'Karakter animasyon, offset ve ölçek ayarlarını düzenler.',
			function() goLoad(new CharacterEditorState(Character.DEFAULT_CHARACTER, false), false));

		addOpen('Stage Editörü',
			'Sahne (stage/level) editörünü açar.',
			function() goLoad(new StageEditorState(), false));

		addOpen('Week Editörü',
			'Hafta ve hikâye modu akışını düzenler.',
			function() go(new WeekEditorState()));

		addOpen('Note Splash Editörü',
			'Nota vuruş efektlerini (splashleri) düzenler.',
			function() go(new NoteSplashEditorState()));

		addOpen('Diyalog Editörü',
			'Hikâye diyaloglarını ve portreleri düzenler.',
			function() goLoad(new DialogueEditorState(), false));

		addOpen('Mod Porter',
			'V-Slice ve Codename Engine modlarını Further formatına dönüştürür.',
			function() go(new ModPorterState()));

		super();
	}

	function addOpen(name:String, desc:String, fn:Void->Void):Void
	{
		var option:Option = new Option(name, desc, '', OPEN);
		option.onOpen = fn;
		addOption(option);
	}

	function prepareLeave():Void
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.volume = 0;
		try
		{
			FreeplayState.destroyFreeplayVocals();
		}
		catch (e:Dynamic) {}
	}

	function go(state:MusicBeatState):Void
	{
		prepareLeave();
		MusicBeatState.switchState(state);
	}

	function goLoad(state:MusicBeatState, stopMusic:Bool):Void
	{
		prepareLeave();
		LoadingState.loadAndSwitchState(state, stopMusic);
	}
}

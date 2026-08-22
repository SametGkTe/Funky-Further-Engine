package backend;

import states.PlayState;
import objects.Note;
import objects.StrumNote;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import objects.AlertMgr.AlertMsg;

class PinnedNotes
{
	public static var PROTECTED_PREFS:Array<String> = [
		"downScroll", "middleScroll", "opponentStrums", "ghostTapping", "hideHud"
	];
	public static var active(default, null):Bool = false;

	public static var sessionModPermissions:Map<String, Bool> = new Map();

	static var prefsSnapshot:Map<String, Dynamic> = new Map();
	static var pinnedTransforms:Array<PinnedTransform> = [];
	static var hudTransforms:Array<HudTransform> = [];

	public static function hudActive():Bool
	{
		return ClientPrefs.data.pinnedHud;
	}

	public static function baseActive():Bool
	{
		return ClientPrefs.data.pinnedNotes;
	}

	public static function snapshotPrefs():Void
	{
		prefsSnapshot = new Map();
		for (field in PROTECTED_PREFS)
			prefsSnapshot.set(field, Reflect.field(ClientPrefs.data, field));
	}

	public static function restorePrefs():Void
	{
		for (field => value in prefsSnapshot)
			Reflect.setField(ClientPrefs.data, field, value);
	}

	public static function onSongStart(play:PlayState):Void
	{
		// Bir kerelik otomatik açma (mevcut V-Slice kullanıcıları için)
		if (ClientPrefs.data.ogGameControls && !ClientPrefs.data.ogAutoPinDone)
		{
			ClientPrefs.data.pinnedNotes = true;
			ClientPrefs.data.ogAutoPinDone = true;
			ClientPrefs.saveSettings();
		}

		pinnedTransforms = [];
		active = baseActive();
		if (!active)
			return;

		var requesting:Array<String> = [];
		try
		{
			for (folder in Mods.parseList().enabled)
			{
				if (sessionModPermissions.exists(folder))
				{
					if (sessionModPermissions.get(folder) == true)
						active = false;
					continue;
				}
				var pack:Dynamic = Mods.getPack(folder);
				if (pack != null && Reflect.field(pack, "noteControl") == true)
					requesting.push(folder);
			}
		}
		catch (e:Dynamic)
		{
			trace('PinnedNotes: mod listesi okunamadı: $e');
		}

		if (requesting.length > 0)
		// I'm fucking genius
		{
			var names:String = requesting.join(', ');
			AlertMsg.showChoice(
				'Bu Mod Nota Kontrolü İstiyor',
				'"$names" modu notaları kendi düzenine göre hareket ettirmek istiyor.\nİzin veriyor musun?',
				15,
				AlertMsg.COLOR_WARNING,
				'EVET', function() {
					for (folder in requesting)
						sessionModPermissions.set(folder, true);
					active = false; // bu şarkıda sabitlemeyi bırak
				},
				'HAYIR', function() {
					for (folder in requesting)
						sessionModPermissions.set(folder, false);
				},
				false);
		}
	}

	public static function capture(play:PlayState):Void
	{
		pinnedTransforms = [];
		if (!active)
			return;
		try
		{
			for (strum in play.strumLineNotes.members)
			{
				if (strum == null)
					continue;
				pinnedTransforms.push({
					x: strum.x,
					y: strum.y,
					angle: strum.angle,
					scaleX: strum.scale.x,
					scaleY: strum.scale.y,
					downScroll: strum.downScroll
				});
			}
		}
		catch (e:Dynamic)
		{
			trace('PinnedNotes: sabitleme yakalanamadı: $e');
			pinnedTransforms = [];
		}
	}

	public static function captureHud(play:PlayState):Void
	{
		hudTransforms = [];
		if (!hudActive())
			return;
		try
		{
			for (obj in hudElements(play))
			{
				if (obj == null)
					continue;
				hudTransforms.push({obj: obj, x: obj.x, y: obj.y});
			}
			iconP1YSet = (play.iconP1 != null);
			iconP2YSet = (play.iconP2 != null);
			if (iconP1YSet) iconP1Y = play.iconP1.y;
			if (iconP2YSet) iconP2Y = play.iconP2.y;
		}
		catch (e:Dynamic)
		{
			trace('PinnedNotes: HUD sabitleme yakalanamadı: $e');
			hudTransforms = [];
		}
	}

	static var iconP1Y:Float = 0;
	static var iconP2Y:Float = 0;

	@:privateAccess
	static function hudElements(play:PlayState):Array<FlxSprite>
	{
		var list:Array<FlxSprite> = [];
		if (play.healthBar != null)
		{
			list.push(play.healthBar.bg);
			list.push(play.healthBar.leftBar);
			list.push(play.healthBar.rightBar);
		}
		if (play.timeBar != null)
		{
			list.push(play.timeBar.bg);
			list.push(play.timeBar.leftBar);
			list.push(play.timeBar.rightBar);
		}
		list.push(play.scoreTxt);
		// timeTxt private: erişim doğrudan @:privateAccess ile (fonksiyon
		// başına koyunca gövdeye yayılmıyor)
		var timeTxtTxt = @:privateAccess play.timeTxt;
		list.push(timeTxtTxt);
		if (play.botplayTxt != null)
			list.push(play.botplayTxt);
		return list;
	}

	public static function enforceHud(play:PlayState):Void
	{
		for (t in hudTransforms)
		{
			if (t.obj == null)
				continue;
			if (t.obj.x != t.x) t.obj.x = t.x;
			if (t.obj.y != t.y) t.obj.y = t.y;
		}
		if (iconP1YSet && play.iconP1 != null && play.iconP1.y != iconP1Y)
			play.iconP1.y = iconP1Y;
		if (iconP2YSet && play.iconP2 != null && play.iconP2.y != iconP2Y)
			play.iconP2.y = iconP2Y;
		// İkon X'lerini sağlık çubuğuna göre motor yeniden hesaplasın
		play.updateIconsPosition();
	}

	static var iconP1YSet:Bool = false;
	static var iconP2YSet:Bool = false;

	public static function enforce(play:PlayState, fakeCrochet:Float, speed:Float):Void
	{
		enforcePrefs();
		enforceStrums(play);
		enforceNotes(play, fakeCrochet, speed);
	}

	static function enforcePrefs():Void
	{
		for (field in PROTECTED_PREFS)
		{
			if (prefsSnapshot.exists(field))
			{
				var want:Dynamic = prefsSnapshot.get(field);
				if (Reflect.field(ClientPrefs.data, field) != want)
					Reflect.setField(ClientPrefs.data, field, want);
			}
		}
	}

	static function enforceStrums(play:PlayState):Void
	{
		if (pinnedTransforms.length == 0)
			return;
		var i:Int = 0;
		for (strum in play.strumLineNotes.members)
		{
			if (strum == null)
				continue;
			if (i >= pinnedTransforms.length)
				break;
			var t:PinnedTransform = pinnedTransforms[i];
			if (strum.x != t.x) strum.x = t.x;
			if (strum.y != t.y) strum.y = t.y;
			if (strum.angle != t.angle) strum.angle = t.angle;
			if (strum.scale.x != t.scaleX) strum.scale.x = t.scaleX;
			if (strum.scale.y != t.scaleY) strum.scale.y = t.scaleY;
			if (strum.downScroll != t.downScroll) strum.downScroll = t.downScroll; // gidiş yönü
			i++;
		}
	}

	static function enforceNotes(play:PlayState, fakeCrochet:Float, speed:Float):Void
	{
		var i:Int = 0;
		while (i < play.notes.length)
		{
			var daNote:Note = play.notes.members[i];
			if (daNote == null)
			{
				i++;
				continue;
			}

			var strumGroup:FlxTypedGroup<StrumNote> = daNote.mustPress ? play.playerStrums : play.opponentStrums;
			var strum:StrumNote = strumGroup.members[daNote.noteData];
			if (strum != null)
			{
				daNote.followStrumNote(strum, fakeCrochet, speed);
				if (daNote.isSustainNote && strum.sustainReduce)
					daNote.clipToStrumNote(strum);
			}
			i++;
		}
	}

	public static function clear():Void
	{
		pinnedTransforms = [];
		hudTransforms = [];
		iconP1YSet = false;
		iconP2YSet = false;
		active = false;
	}
}

typedef PinnedTransform =
{
	x: Float,
	y: Float,
	angle: Float,
	scaleX: Float,
	scaleY: Float,
	downScroll: Bool
};

typedef HudTransform =
{
	obj: FlxSprite,
	x: Float,
	y: Float
};

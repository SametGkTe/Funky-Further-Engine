package mikolka.funkin.players;

import mikolka.compatibility.ModsHelper;
import mikolka.funkin.custom.PsliceRegistry;
import mikolka.funkin.players.PlayerData;
import mikolka.funkin.players.PlayerData.PlayerFreeplayDJData;
import haxe.io.Path;

class PlayerRegistry extends PsliceRegistry
{
	public static var instance:PlayerRegistry = new PlayerRegistry();

	public function new()
	{
		super('players');
	}

	public function isCharacterOwned(id:String):Bool
	{
		return true;
	}

	public function hasNewCharacter():Bool
	{
		return false;
	}

	public function fetchEntry(playableCharId:String):Null<PlayableCharacter>
	{
		try
		{
			var player_blob:Dynamic = readJson(playableCharId);
			if (player_blob == null)
				return null;

			var player_data = new PlayerData().mergeWithJson(player_blob, ["freeplayDJ"]);
			var dj = new PlayerFreeplayDJData().mergeWithJson(player_blob.freeplayDJ);
			player_data.freeplayDJ = dj;
			return new PlayableCharacter(player_data);
		}
		catch (x)
		{
			trace('Couldn\'t pull $playableCharId: ${x.message}');
			return null;
		}
	}

	public function listEntryIds():Array<String>
	{
		var result:Array<String> = [];
		var seen:Map<String, Bool> = new Map<String, Bool>();

		inline function addId(id:String):Void
		{
			if (id == null || id.length < 1)
				return;
			if (seen.exists(id))
				return;

			seen.set(id, true);
			result.push(id);
		}

		var previousMod:String = ModsHelper.getActiveMod();

		// Base game
		ModsHelper.loadModDir("");
		for (id in listJsons())
			addId(id);

		// Aktif mod
		if (previousMod != null && previousMod.length > 0)
		{
			ModsHelper.loadModDir(previousMod);
			for (id in listJsons())
				addId(id);
		}

		// Geri yükle
		ModsHelper.loadModDir(previousMod ?? "");

		trace('[PlayerRegistry] listEntryIds -> ' + result.join(", "));
		return result;
	}

	public function countUnlockedCharacters():Int
	{
		var count:Int = 0;

		for (id in listEntryIds())
		{
			var entry = fetchEntry(id);
			if (entry != null && entry.isUnlocked())
				count++;
		}

		return count;
	}
}
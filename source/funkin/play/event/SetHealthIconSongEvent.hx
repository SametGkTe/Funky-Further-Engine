package funkin.play.event;

import funkin.data.song.SongData.SongEventData;

/**
 * V-Slice yerleşik chart event'i: SetHealthIcon (v15, Psych köprüsü).
 *
 * Resmî funkin v0.8.7 davranışı:
 *   { char: 0|1, id: 'healthicon-adi', shouldBop, scale, flipX, isPixel, offsetX, offsetY }
 *   char: 0 = oyuncu (iconP1), 1 = rakip (iconP2).
 *
 * Psych karşılığı: HealthIcon.changeIcon(id). Psik'in health icon sistemi
 * farklı olduğundan yalnızca `char` + `id` alanları uygulanır; bop/scale/
 * pixel/offset alanları yok sayılır (Psych kendi ikon davranışını kullanır).
 */
@:noCustomClass
class SetHealthIconSongEvent extends SongEvent
{
	static final DEFAULT_CHAR:Int = 0;

	public function new()
	{
		super('SetHealthIcon');
	}

	override public function handleEvent(data:SongEventData):Void
	{
		var state = states.PlayState.instance;
		if (state == null) return;

		var v:Dynamic = data.valueAsStruct();

		var charIdx:Null<Int> = null;
		var rawChar:Dynamic = Reflect.field(v, 'char');
		if (rawChar != null)
		{
			if (Std.isOfType(rawChar, Int) || Std.isOfType(rawChar, Float))
				charIdx = Std.int(rawChar);
			else
			{
				switch (Std.string(rawChar).toLowerCase())
				{
					case 'bf' | 'boyfriend' | 'player':
						charIdx = 0;
					case 'dad' | 'opponent':
						charIdx = 1;
					default:
						charIdx = Std.parseInt(Std.string(rawChar));
				}
			}
		}
		if (charIdx == null) charIdx = DEFAULT_CHAR;

		var rawId:Dynamic = Reflect.field(v, 'id');
		if (rawId == null) rawId = Reflect.field(v, 'icon');
		if (rawId == null)
		{
			trace('[SetHealthIconSongEvent] id alanı yok, atlanıyor.');
			return;
		}
		var iconId:String = Std.string(rawId);

		switch (charIdx)
		{
			case 0:
				if (state.iconP1 != null)
				{
					trace('[SetHealthIconSongEvent] Oyuncu ikonu: $iconId');
					state.iconP1.changeIcon(iconId);
					if (state.boyfriend != null) state.boyfriend.healthIcon = iconId;
				}
			case 1:
				if (state.iconP2 != null)
				{
					trace('[SetHealthIconSongEvent] Rakip ikonu: $iconId');
					state.iconP2.changeIcon(iconId);
					if (state.dad != null) state.dad.healthIcon = iconId;
				}
			default:
				trace('[SetHealthIconSongEvent] Bilinmeyen char: $charIdx');
		}
	}

	override public function getTitle():String
	{
		return 'Set Health Icon';
	}
}

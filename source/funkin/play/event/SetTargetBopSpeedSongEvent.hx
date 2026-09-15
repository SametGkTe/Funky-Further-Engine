package funkin.play.event;

import funkin.data.song.SongData.SongEventData;

/**
 * V-Slice yerleşik chart event'i: SetTargetBopSpeed (v18, Psych köprüsü).
 *
 * Resmî funkin v0.8.7 davranışı:
 *   { target: String ('boyfriend'|'dad'|'girlfriend'|prop adı, varsayılan 'boyfriend'),
 *     rate: Float (beat cinsinden dans hızı, varsayılan 1) }
 *   Hedef BaseCharacter/Bopper ise danceEvery = rate.
 *
 * Psych karşılığı: karakterler objects.Character -> danceEveryNumBeats.
 * SINIR: isimli sahne prop'u hedefi desteklenmez (Psych sahnelerinde
 * adlandırılmış prop kaydı yok) — yalnızca trace düşer.
 */
@:noCustomClass
class SetTargetBopSpeedSongEvent extends SongEvent
{
	static final DEFAULT_TARGET:String = 'boyfriend';
	static final DEFAULT_PROP_RATE:Float = 1;

	public function new()
	{
		super('SetTargetBopSpeed');
	}

	override public function handleEvent(data:SongEventData):Void
	{
		var state = states.PlayState.instance;
		if (state == null) return;

		var targetName:Null<String> = data.getString('target');
		if (targetName == null) targetName = DEFAULT_TARGET;

		var rate:Null<Float> = data.getFloat('rate');
		if (rate == null) rate = DEFAULT_PROP_RATE;

		var beats:Int = Math.round(rate);
		if (beats < 1) beats = 1;

		var char:objects.Character = null;
		switch (targetName)
		{
			case 'boyfriend' | 'bf' | 'player':
				char = state.boyfriend;
			case 'dad' | 'opponent':
				char = state.dad;
			case 'girlfriend' | 'gf':
				char = state.gf;
			default:
				trace('[SetTargetBopSpeed] Bilinmeyen hedef: $targetName (isimli prop destegi yok)');
		}

		if (char != null)
		{
			char.danceEveryNumBeats = beats;
			trace('[SetTargetBopSpeed] $targetName dans hizi: her $beats beat');
		}
	}

	override public function getTitle():String
	{
		return 'Set Target Bop Speed';
	}
}

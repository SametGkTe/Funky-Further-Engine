package funkin.play.event;

/**
 * FNF uyumluluk shim'i (SongEvent).
 * FNF'de tüm şarkı olaylarının tabanıdır; Further'da iptal edilebilir
 * olay tabanına bağlar. Script'ler `class X extends SongEvent { ... }`
 * türetip `event.cancel()` çağırabilir.
 */
@:noCustomClass
class SongEvent extends funkin.backend.scripting.events.CancellableEvent
{
	public function new()
	{
		super();
	}
}

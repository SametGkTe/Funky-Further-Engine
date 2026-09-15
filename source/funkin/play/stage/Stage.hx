package funkin.play.stage;

/**
 * FNF uyumluluk shim'i (Stage) — v20 (Faz 4.5, derinleştirildi).
 *
 * Resmî funkin v0.8.7: `Stage extends FlxSpriteGroup`; mod script'leri
 * `class garage extends Stage` + kurucuda `super('garage')` yazar.
 * Polymod'un scriptClassOverrides tablosu, `extends Stage` yazan script'leri
 * derleme zamanında otomatik olarak vslice.scripting.ScriptedStage'e
 * yönlendirir (ScriptedStage bu sınıftan türer ve @:hscriptClass'tır).
 *
 * FFE'de bu sınıf Psych'in BaseStage'i (FlxBasic) üzerine bir kabuktur:
 *   - add()/remove() BaseStage'ten gelir (FlxG.state'e köprü).
 *   - Resmî yaşam döngüsü metodları no-op'tur; script'ler override edip
 *     `super.onCreate(event)` çağırabilsin DİYE burada var olmaları ŞARTTIR
 *     (Polymod __super_X yardımcılarını yalnızca mevcut metodlar için üretir).
 *   - Karakter API'si (addCharacter/getBoyfriend/getDad/...) PlayState
 *     alanlarına köprülenir.
 */
@:noCustomClass
class Stage extends backend.BaseStage
{
	/** Sahne kimliği ('garage', 'mall', ...) — script'ler super(id) ile verir. */
	public var id:String;

	/** Ek kurulum parametreleri (resmî imza ile uyum için). */
	public var params:Dynamic;

	/**
	 * Resmî imza: new(id:String, ?params:Dynamic).
	 * Varsayılanlar sayesinde hem `new Stage()` hem `new Stage('garage')`
	 * hem de Polymod'un Type.createInstance çağrıları güvenle çalışır.
	 */
	public function new(id:String = '', ?params:Dynamic)
	{
		super();
		this.id = (id != null) ? id : '';
		this.params = params;
	}

	/* ---- Resmî yaşam döngüsü no-op'ları (super.X(event) desteği) ---- */

	public function onScriptEvent(event:Dynamic):Void {}
	public function onCreate(event:Dynamic):Void {}
	public function onCreatePost(event:Dynamic):Void {}
	public function onDestroy(event:Dynamic):Void {}
	public function onUpdate(event:Dynamic):Void {}
	public function onUpdatePost(event:Dynamic):Void {}
	public function onPause(event:Dynamic):Void {}
	public function onResume(event:Dynamic):Void {}
	public function onSongStart(event:Dynamic):Void {}
	public function onSongEnd(event:Dynamic):Void {}
	public function onSongLoaded(event:Dynamic):Void {}
	public function onGameOver(event:Dynamic):Void {}
	public function onStepHit(event:Dynamic):Void {}
	public function onBeatHit(event:Dynamic):Void {}
	public function onSongEvent(event:Dynamic):Void {}
	public function onCountdownStart(event:Dynamic):Void {}
	public function onCountdownStep(event:Dynamic):Void {}
	public function onCountdownEnd(event:Dynamic):Void {}
	public function onNoteIncoming(event:Dynamic):Void {}
	public function onNoteHit(event:Dynamic):Void {}
	public function onNoteMiss(event:Dynamic):Void {}
	public function onNoteHoldDrop(event:Dynamic):Void {}

	/* ---- Resmî sahne yönetim API'si ---- */

	/** Resmî: sahne objelerini yeniden kurar — Further'da no-op. */
	public function resetStage():Void {}

	/** Resmî: zIndex sıralaması — Psych'te zIndex yok, no-op. */
	public function refresh():Void {}

	/** Resmî: prop ekleme. BaseStage.add zaten FlxG.state'e köprüdür. */
	public function addProp(prop:Dynamic, ?name:String):Void
	{
		if (prop != null) add(prop);
	}

	/** Resmî: bopper ekleme (addProp ile aynı). */
	public function addBopper(bopper:Dynamic, ?name:String):Void
	{
		if (bopper != null) add(bopper);
	}

	/** Resmî: isimli prop lookup — Further isim tablosu tutmaz. */
	public function getNamedProp(name:String):Dynamic return null;

	/** Resmî: tüm sahne üyelerine shader — Further'da no-op. */
	public function setShader(shader:Dynamic):Void {}

	public function fetchAssetPaths():Array<String> return [];

	/**
	 * Resmî: addCharacter(character, charType). Further köprüsü: karakteri
	 * ilgili PlayState slotuna atar ve state'e ekler. Eski karakter sahneden
	 * çıkarılır (destroy script'e aittir — resmî davranışla aynı).
	 */
	public function addCharacter(character:Dynamic, charType:Dynamic = null):Void
	{
		var ps = states.PlayState.instance;
		if (ps == null || character == null) return;
		var t:String = (charType != null) ? Std.string(charType).toLowerCase() : 'other';
		try
		{
			switch (t)
			{
				case 'bf', 'player', 'boyfriend':
					if (ps.boyfriend != null && ps.boyfriend != character) ps.remove(ps.boyfriend);
					ps.boyfriend = cast character;
				case 'gf', 'girlfriend':
					if (ps.gf != null && ps.gf != character) ps.remove(ps.gf);
					ps.gf = cast character;
				case 'dad', 'opponent':
					if (ps.dad != null && ps.dad != character) ps.remove(ps.dad);
					ps.dad = cast character;
			}
			ps.add(character);
		}
		catch (e:Dynamic) {}
	}

	/** Resmî: getCharacter(id) — PlayState karakterlerinde curCharacter eşleşmesi. */
	public function getCharacter(charId:String):Dynamic
	{
		var ps = states.PlayState.instance;
		if (ps == null || charId == null) return null;
		if (ps.dad != null && ps.dad.curCharacter == charId) return ps.dad;
		if (ps.boyfriend != null && ps.boyfriend.curCharacter == charId) return ps.boyfriend;
		if (ps.gf != null && ps.gf.curCharacter == charId) return ps.gf;
		return null;
	}

	public function getBoyfriend(pop:Bool = false):Dynamic
		return (states.PlayState.instance != null) ? states.PlayState.instance.boyfriend : null;

	public function getPlayer(pop:Bool = false):Dynamic return getBoyfriend(pop);

	public function getGirlfriend(pop:Bool = false):Dynamic
		return (states.PlayState.instance != null) ? states.PlayState.instance.gf : null;

	public function getDad(pop:Bool = false):Dynamic
		return (states.PlayState.instance != null) ? states.PlayState.instance.dad : null;

	public function getOpponent(pop:Bool = false):Dynamic return getDad(pop);

	/** Resmî: olayı sahnedeki karakterlere yay. */
	public function dispatchToCharacters(event:Dynamic):Void
	{
		var ps = states.PlayState.instance;
		if (ps == null) return;
		if (ps.dad != null) vslice.scripting.VSScriptEventDispatcher.dispatch(ps.dad, 'onScriptEvent', event);
		if (ps.boyfriend != null) vslice.scripting.VSScriptEventDispatcher.dispatch(ps.boyfriend, 'onScriptEvent', event);
		if (ps.gf != null) vslice.scripting.VSScriptEventDispatcher.dispatch(ps.gf, 'onScriptEvent', event);
	}

	public function dispatchToCharacter(characterId:String, event:Dynamic):Void
	{
		var c:Dynamic = getCharacter(characterId);
		if (c != null) vslice.scripting.VSScriptEventDispatcher.dispatch(c, 'onScriptEvent', event);
	}
}

package backend;

import states.PlayState;
import objects.Note;
import objects.StrumNote;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import objects.AlertMgr.AlertMsg;

class PinnedNotes
{
	/** Modların değiştirmesine izin verilmeyen ClientPrefs alanları */
	public static var PROTECTED_PREFS:Array<String> = [
		"downScroll", "middleScroll", "opponentStrums", "ghostTapping", "hideHud"
	];

	/** Bu şarkıda sabitleme gerçekten aktif mi (mod izniyle kapatılmış olabilir) */
	public static var active(default, null):Bool = false;

	/** Bu oturumda mod klasörü bazında verilen Evet/Hayır cevapları */
	public static var sessionModPermissions:Map<String, Bool> = new Map();

	static var prefsSnapshot:Map<String, Dynamic> = new Map();
	static var pinnedTransforms:Array<PinnedTransform> = [];
	static var hudTransforms:Array<HudTransform> = [];

	/** Sabitlenmiş HUD aktif mi? (Sabitlenmiş Notalar'dan bağımsız ayar) */
	public static function hudActive():Bool
	{
		return ClientPrefs.data.pinnedHud;
	}

	public static function baseActive():Bool
	{
		return ClientPrefs.data.pinnedNotes;
	}

	/** PlayState.create en başında çağrılır — modlar dokunmadan prefs'i kaydet */
	public static function snapshotPrefs():Void
	{
		prefsSnapshot = new Map();
		for (field in PROTECTED_PREFS)
			prefsSnapshot.set(field, Reflect.field(ClientPrefs.data, field));
	}

	/** Kaydedilen prefs değerlerini geri yükle (şarkı çıkışında son bir kez) */
	public static function restorePrefs():Void
	{
		for (field => value in prefsSnapshot)
			Reflect.setField(ClientPrefs.data, field, value);
	}

	/**
	 * Şarkı başında çağrılır: (1) og açık ama otomatik açma hiç yapılmamışsa
	 * Sabitlenmiş Notalar'ı bir kereliğine açar (eski og kullanıcıları için),
	 * (2) aktiflik kararını verir, (3) izin isteyen modlara Evet/Hayır diyalogu açar.
	 */
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

		// pack.json'ında "noteControl": true olan aktif modlar izin istiyor
		var requesting:Array<String> = [];
		try
		{
			for (folder in Mods.parseList().enabled)
			{
				if (sessionModPermissions.exists(folder))
				{
					// Bu oturumda oyuncu bu moda zaten izin verdi
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
		{
			var names:String = requesting.join(', ');
			AlertMsg.showChoice(
				'Mod Nota Kontrolü İstiyor',
				'"$names" modu notaları kendi düzenine göre hareket ettirmek istiyor.\nİzin veriyor musun?',
				15, // süre (sn) — süre dolarsa seçim yapılmamış sayılır, sabitleme devam eder
				AlertMsg.COLOR_WARNING,
				'EVET', function() {
					for (folder in requesting)
						sessionModPermissions.set(folder, true);
					active = false; // bu şarkıda sabitlemeyi bırak
				},
				'HAYIR', function() {
					for (folder in requesting)
						sessionModPermissions.set(folder, false);
					// active zaten true, sabitleme devam eder
				},
				false);
		}
	}

	/**
	 * Strum dizilimi son halini aldıktan sonra çağrılır (arrow'lar + ogGameControls
	 * V-Slice dizilimi dahil). O andeki x/y/açı/boyut/yön değerleri sabitlenir.
	 */
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

	/**
	 * Sabitlenmiş HUD: sağlık çubuğu (bg + sol/sağ dolgu), süre çubuğu, skor
	 * yazısı, süre yazısı ve botplay yazısının konumu yakalanır. İkonların Y'si
	 * de sabitlenir; X'leri sağlık oranına göre motor hesaplar.
	 */
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
			// İkonlar: yalnız Y sabitlenir (X sağlık oranına bağlıdır)
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

	/**
	 * Her karede çağrılır (onUpdatePost'tan sonra): modun taşıdığı HUD
	 * parçalarını sabitlenen konuma geri koyar ve ikonları yeniden hizalar.
	 */
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

	/**
	 * PlayState.update'in SONUNDA çağrılır (onUpdatePost'tan sonra — son yazan biziz):
	 * prefs koruması + strum dönüşümleri + notaların standart konuma dönmesi.
	 */
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

	/**
	 * Modun elle yerleştirdiği notaları motorun standart konumuna döndürür.
	 * PlayState.update'teki döngünün birebir kopyasıdır (yalnız konumlandırma,
	 * vuruş/kaçırma mantığı HARİÇ).
	 */
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

	/** Şarkı bittiğinde temizle (prefs'i geri yüklemeyi unutma) */
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

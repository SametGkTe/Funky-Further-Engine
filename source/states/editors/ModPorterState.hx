package states.editors;

import flixel.group.FlxGroup;

import backend.Mods;
import backend.Paths;
import backend.VSliceMeta;
import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.thread.Thread;
#end

/**
 * ModPorterState — Mod Porter.
 *
 * Master Editor menüsünden açılır:
 *   1) mods/ klasöründeki modlar listelenir, biri seçilir.
 *   2) Mod türü sorulur: Psych / V-Slice / Codename (otomatik algılama önerilir).
 *   3) Türüne göre "CODENAME TO PSYCH" veya "V-SLICE TO PSYCH" dönüşümü
 *      yapılır; Psych modları olduğu gibi kopyalanır.
 *   4) Hazır Psych modu `saves/<ModAdı>_PsychPort/` klasörüne yazılır.
 *
 * Dönüşüm arka plan thread'inde çalışır; arayüz ilerlemeyi gösterir.
 * .hx/.hxc scriptler dönüştürülemez — atlanır ve raporda listelenir.
 */
typedef PorterProgress =
{
	var stage:String;
	var cur:Int;
	var total:Int;
	var done:Bool;
	var error:String;
	var report:Array<String>;
	var outDir:String;
}

class ModPorterState extends MusicBeatState
{
	static inline var TYPE_PSYCH:Int = 0;
	static inline var TYPE_VSLICE:Int = 1;
	static inline var TYPE_CNE:Int = 2;

	var phase:Int = 0; // 0 mod seç, 1 kaynak format, 2 onay, 3 dönüştürülüyor, 4 bitti, 5 hata, 6 hedef format (psych)

	var modList:Array<String> = [];
	var typeOptions:Array<String> = ['Psych Mod → CNE / V-Slice', 'V-Slice To Psych', 'Codename To Psych'];
	var targetOptions:Array<String> = ['Codename Engine', 'V-Slice'];
	var confirmOptions:Array<String> = ['Dönüştür', 'Geri'];

	var curSelected:Int = 0;
	var selectedMod:String = '';
	var selectedType:Int = TYPE_CNE;
	var selectedTarget:Int = TYPE_CNE;
	var detectedType:Int = TYPE_PSYCH;

	var grpTexts:FlxTypedGroup<Alphabet>;
	var descTxt:FlxText;
	var infoTxt:FlxText;
	var typeIconGroup:FlxGroup;
	var typeIcons:Array<FlxSprite> = [];

	var progress:PorterProgress = null;

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		var title:Alphabet = new Alphabet(0, 40, 'MOD PORTER', true);
		title.screenCenter(X);
		add(title);

		descTxt = new FlxText(0, 130, FlxG.width, '', 24);
		descTxt.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.YELLOW, CENTER);
		descTxt.scrollFactor.set();
		add(descTxt);

		grpTexts = new FlxTypedGroup<Alphabet>();
		add(grpTexts);

		typeIconGroup = new FlxGroup();
		add(typeIconGroup);

		infoTxt = new FlxText(20, FlxG.height - 160, FlxG.width - 40, '', 16);
		infoTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT);
		infoTxt.scrollFactor.set();
		add(infoTxt);

		#if MODS_ALLOWED
		modList = Mods.getModDirectories();
		#end

		enterPhase(0);
		FlxG.mouse.visible = false;

		// Mobil kontroller: D-Pad ile liste gezme, A = onay/seç, B = geri
		addTouchPad(#if MODS_ALLOWED 'LEFT_FULL' #else 'UP_DOWN' #end, 'A_B');

		super.create();
	}

	function enterPhase(newPhase:Int)
	{
		phase = newPhase;
		curSelected = 0;
		if (typeIconGroup != null && newPhase != 1 && newPhase != 6) typeIconGroup.clear();
		switch (phase)
		{
			case 0:
				descTxt.text = 'Dönüştürülecek modu seç (YUKARI/AŞAĞI + ENTER)';
				rebuildList(modList);
				infoTxt.text = 'Toplam ' + modList.length + ' mod bulundu. ESC: Editör menüsüne dön';
			case 1:
				buildTypeIcons();
				detectedType = detectType(selectedMod);
				var detectStr:String = switch (detectedType)
				{
					case TYPE_CNE: 'Codename Engine (algılandı)';
					case TYPE_VSLICE: 'V-Slice (algılandı)';
					default: 'Psych/Bilinmiyor';
				}
				descTxt.text = '"' + selectedMod + '" — Modun KAYNAK formatını seç\n(Hedef her zaman PSYCH — dönüştürme ona yapılır)\nAlgılanan kaynak format: ' + detectStr;
				curSelected = detectedType;
				rebuildList(typeOptions);
				infoTxt.text = 'ESC: Geri';
			case 2:
				var action:String = switch (selectedType)
				{
					case TYPE_CNE: 'CODENAME TO PSYCH';
					case TYPE_VSLICE: 'V-SLICE TO PSYCH';
					default: (selectedTarget == TYPE_CNE) ? 'PSYCH TO CODENAME' : 'PSYCH TO V-SLICE';
				}
				var warn:String = '';
				if (selectedType != detectedType)
				{
					var detStr:String = switch (detectedType)
					{
						case TYPE_CNE: 'Codename Engine';
						case TYPE_VSLICE: 'V-Slice';
						default: 'Psych/Bilinmiyor';
					}
					warn = '\n!! UYARI: Otomatik algılama bu modu "' + detStr + '" olarak tanıdı. Emin misin?';
				}
				descTxt.text = '"' + selectedMod + '" için işlem: ' + action + '\nÇıkış: saves/' + outName(selectedMod) + '/' + warn;
				rebuildList(confirmOptions);
				infoTxt.text = 'Dönüştürülemeyen scriptler (.hx/.hxc) atlanır ve raporda gösterilir.\nESC: Geri';
			case 3:
				grpTexts.clear();
				descTxt.text = 'Dönüştürülüyor...';
				infoTxt.text = '';
				startConversion();
			case 4:
				grpTexts.clear();
				descTxt.text = 'DÖNÜŞTÜRME TAMAMLANDI!';
				var txt:String = 'Hazır mod: ' + progress.outDir + '\n\n';
				for (line in progress.report)
					txt += line + '\n';
				txt += '\nBu klasörü mods/ içine taşıyıp Mods menüsünden etkinleştirebilirsin.\n\nENTER/ESC: Editör menüsüne dön';
				infoTxt.text = txt;
			case 5:
				grpTexts.clear();
				descTxt.text = 'DÖNÜŞTÜRME BAŞARISIZ!';
				infoTxt.text = 'Hata: ' + (progress != null ? progress.error : 'bilinmiyor') + '\n\nENTER/ESC: Editör menüsüne dön';
			case 6:
				buildTargetIcons();
				descTxt.text = '"' + selectedMod + '" (Psych modu) — HEDEF formatı seç';
				curSelected = 0;
				rebuildList(targetOptions);
				infoTxt.text = 'ESC: Geri';
		}
		changeSelection(0);
	}

	function detectType(mod:String):Int
	{
		#if MODS_ALLOWED
		if (cne.compatibility.CNECompat.isCNEMod(mod)) return TYPE_CNE;
		if (VSliceMeta.exists(mod)) return TYPE_VSLICE;
		#end
		return TYPE_PSYCH;
	}

	function outName(mod:String):String
	{
		var clean:String = mod;
		var buf:StringBuf = new StringBuf();
		for (i in 0...clean.length)
		{
			var c:String = clean.charAt(i);
			var code:Int = clean.charCodeAt(i);
			if ((code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || c == '-' || c == ' ')
				buf.add(c);
			else
				buf.add('_');
		}
		return buf.toString() + '_PsychPort';
	}

	function rebuildList(items:Array<String>)
	{
		grpTexts.clear();
		for (i in 0...items.length)
		{
			var leText:Alphabet = new Alphabet(90, 260, items[i], true);
			leText.isMenuItem = true;
			leText.targetY = i;
			grpTexts.add(leText);
			leText.snapToPosition();
			leText.color = FlxColor.WHITE;
			leText.x = (FlxG.width - leText.width) / 2;
		}
	}

	/** Tür seçim ekranı ikonları: images/further/editor/{psych, v-slice, codename}.png */
	function buildTypeIcons()
	{
		if (typeIconGroup == null) return;
		typeIconGroup.clear();
		typeIcons = [];
		var iconKeys:Array<String> = ['further/editor/psych', 'further/editor/v-slice', 'further/editor/codename'];
		for (key in iconKeys)
		{
			var spr:FlxSprite = null;
			if (Paths.fileExists('images/' + key + '.png', IMAGE))
			{
				spr = new FlxSprite();
				spr.loadGraphic(Paths.image(key));
				spr.setGraphicSize(72, 72);
				spr.updateHitbox();
				spr.antialiasing = ClientPrefs.data.antialiasing;
				typeIconGroup.add(spr);
			}
			typeIcons.push(spr);
		}
	}

	/** Hedef seçim ekranı ikonları: codename + v-slice */
	function buildTargetIcons()
	{
		if (typeIconGroup == null) return;
		typeIconGroup.clear();
		typeIcons = [];
		var iconKeys:Array<String> = ['further/editor/codename', 'further/editor/v-slice'];
		for (key in iconKeys)
		{
			var spr:FlxSprite = null;
			if (Paths.fileExists('images/' + key + '.png', IMAGE))
			{
				spr = new FlxSprite();
				spr.loadGraphic(Paths.image(key));
				spr.setGraphicSize(72, 72);
				spr.updateHitbox();
				spr.antialiasing = ClientPrefs.data.antialiasing;
				typeIconGroup.add(spr);
			}
			typeIcons.push(spr);
		}
	}

	/** İkonları ilgili Alphabet satırının soluna hizalar. */
	function updateIconPositions()
	{
		if ((phase != 1 && phase != 6) || typeIcons.length < 1) return;
		var i:Int = 0;
		for (item in grpTexts.members)
		{
			var icon:FlxSprite = (i < typeIcons.length) ? typeIcons[i] : null;
			if (icon != null)
			{
				icon.x = item.x - icon.width - 40;
				icon.y = item.y + (item.height - icon.height) / 2;
				icon.alpha = item.alpha;
			}
			i++;
		}
	}

	function changeSelection(change:Int = 0)
	{
		var items:Int = switch (phase)
		{
			case 0: modList.length;
			case 1: typeOptions.length;
			case 2: confirmOptions.length;
			case 6: targetOptions.length;
			default: 0;
		}
		if (items < 1) return;

		curSelected += change;
		if (curSelected < 0) curSelected = items - 1;
		if (curSelected >= items) curSelected = 0;

		var bullShit:Int = 0;
		for (item in grpTexts.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;
			item.alpha = 0.6;
			if (item.targetY == 0) item.alpha = 1;
		}
	}

	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);

		if (controls.BACK)
		{
			switch (phase)
			{
				case 0: MusicBeatState.switchState(new MasterEditorMenu());
				case 1: enterPhase(0);
				case 2: enterPhase(1);
				case 6: enterPhase(1);
				case 3: // dönüşüm sırasında çıkış yok
				default: MusicBeatState.switchState(new MasterEditorMenu());
			}
		}

		if (controls.ACCEPT)
		{
			switch (phase)
			{
				case 0:
					if (modList.length > 0)
					{
						selectedMod = modList[curSelected];
						enterPhase(1);
					}
				case 1:
					selectedType = curSelected;
					if (selectedType == TYPE_PSYCH) enterPhase(6);
					else enterPhase(2);
				case 6:
					selectedTarget = (curSelected == 0) ? TYPE_CNE : TYPE_VSLICE;
					enterPhase(2);
				case 2:
					if (curSelected == 0) enterPhase(3);
					else enterPhase((selectedType == TYPE_PSYCH) ? 6 : 1);
				case 3: // bekleniyor
				default:
					MusicBeatState.switchState(new MasterEditorMenu());
			}
		}

		updateIconPositions();

		if (phase == 3 && progress != null)
		{
			if (progress.error != null)
				enterPhase(5);
			else if (progress.done)
				enterPhase(4);
			else
			{
				var p:String = progress.total > 0 ? ' (' + progress.cur + '/' + progress.total + ')' : '';
				descTxt.text = 'Dönüştürülüyor: ' + progress.stage + p;
			}
		}

		super.update(elapsed);
	}

	function startConversion()
	{
		progress = {stage: 'Başlıyor', cur: 0, total: 0, done: false, error: null, report: [], outDir: ''};
		var mod:String = selectedMod;
		var type:Int = selectedType;
		var target:Int = selectedTarget;
		var prog:PorterProgress = progress;
		#if sys
		Thread.create(function()
		{
			try
			{
				switch (type)
				{
					case TYPE_CNE: convertCNE(mod, prog);
					case TYPE_VSLICE: convertVSlice(mod, prog);
					default:
						if (target == TYPE_CNE) convertPsychToCNE(mod, prog);
						else convertPsychToVSlice(mod, prog);
				}
				prog.done = true;
			}
			catch (e:Dynamic)
			{
				prog.error = Std.string(e);
			}
		});
		#else
		progress.error = 'Bu platformda dosya sistemi dönüşümü desteklenmiyor.';
		#end
	}

	// ================== ORTAK YARDIMCILAR ==================

	static function savesRoot():String
	{
		var p:String = Sys.getCwd() + 'saves/';
		if (!FileSystem.exists(p)) FileSystem.createDirectory(p);
		return p;
	}

	static function prepareOutDir(mod:String):String
	{
		var out:String = savesRoot() + outNameStatic(mod) + '/';
		if (FileSystem.exists(out)) deleteTree(out);
		FileSystem.createDirectory(out);
		return out;
	}

	static function outNameStatic(mod:String):String
	{
		var buf:StringBuf = new StringBuf();
		for (i in 0...mod.length)
		{
			var c:String = mod.charAt(i);
			var code:Int = mod.charCodeAt(i);
			if ((code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || c == '-' || c == ' ')
				buf.add(c);
			else
				buf.add('_');
		}
		return buf.toString() + '_PsychPort';
	}

	static function deleteTree(path:String)
	{
		if (!FileSystem.exists(path)) return;
		if (!FileSystem.isDirectory(path))
		{
			FileSystem.deleteFile(path);
			return;
		}
		for (f in FileSystem.readDirectory(path))
			deleteTree(path + '/' + f);
		FileSystem.deleteDirectory(path);
	}

	static function copyTree(src:String, dst:String):Int
	{
		if (!FileSystem.exists(src)) return 0;
		if (!FileSystem.isDirectory(src))
		{
			File.copy(src, dst);
			return 1;
		}
		if (!FileSystem.exists(dst)) FileSystem.createDirectory(dst);
		var n:Int = 0;
		for (f in FileSystem.readDirectory(src))
		{
			var s:String = src + '/' + f;
			var d:String = dst + '/' + f;
			if (FileSystem.isDirectory(s))
				n += copyTree(s, d);
			else
			{
				File.copy(s, d);
				n++;
			}
		}
		return n;
	}

	static function writeJsonFile(path:String, data:Dynamic)
	{
		File.saveContent(path, Json.stringify(data, null, '\t'));
	}

	static function listDir(path:String):Array<String>
	{
		if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return [];
		return FileSystem.readDirectory(path);
	}

	static function countFilesWithExt(path:String, exts:Array<String>):Int
	{
		var n:Int = 0;
		for (f in listDir(path))
			for (e in exts)
				if (StringTools.endsWith(f.toLowerCase(), e))
				{
					n++;
					break;
				}
		return n;
	}

	// ================== PSYCH (KOPYALA) ==================

	static function copyPsych(mod:String, prog:PorterProgress)
	{
		prog.stage = 'Psych modu kopyalanıyor';
		var src:String = Paths.mods(mod);
		var out:String = prepareOutDir(mod);
		prog.outDir = out;
		var n:Int = copyTree(src, out);
		prog.report.push('Kopyalanan dosya: ' + n);
		prog.report.push('Psych modu dönüşüm gerektirmez; birebir kopyalandı.');
	}

	// ================== CODENAME → PSYCH ==================

	static function convertCNE(mod:String, prog:PorterProgress)
	{
		var root:String = cne.compatibility.CNECompat.cneRoot(mod);
		if (root == null) throw 'Mod bir Codename Engine modu olarak algılanmadı.';
		var out:String = prepareOutDir(mod);
		prog.outDir = out;

		// --- Karakterler ---
		prog.stage = 'Karakterler';
		var charDir:String = root + '/data/characters/';
		var charFiles:Array<String> = [];
		for (f in listDir(charDir))
			if (StringTools.endsWith(f.toLowerCase(), '.xml')) charFiles.push(f);
		prog.total = charFiles.length;
		prog.cur = 0;
		var charCount:Int = 0;
		for (f in charFiles)
		{
			var id:String = f.substr(0, f.length - 4);
			var json:Dynamic = cne.compatibility.CNECharacterConverter.convertFromMod(mod, id);
			if (json != null)
			{
				if (!FileSystem.exists(out + 'characters/')) FileSystem.createDirectory(out + 'characters/');
				writeJsonFile(out + 'characters/' + id + '.json', json);
				charCount++;
			}
			else
				prog.report.push('Karakter çevrilemedi: ' + id);
			prog.cur++;
		}
		prog.report.push('Karakter: ' + charCount + ' dönüştürüldü');

		// --- Sahneler ---
		prog.stage = 'Sahneler';
		var stageDir:String = root + '/data/stages/';
		var stageFiles:Array<String> = [];
		for (f in listDir(stageDir))
			if (StringTools.endsWith(f.toLowerCase(), '.xml')) stageFiles.push(f);
		prog.total = stageFiles.length;
		prog.cur = 0;
		var stageCount:Int = 0;
		for (f in stageFiles)
		{
			var id:String = f.substr(0, f.length - 4);
			var json:Dynamic = cne.compatibility.CNEStageConverter.convertFromMod(mod, id);
			if (json != null)
			{
				if (!FileSystem.exists(out + 'stages/')) FileSystem.createDirectory(out + 'stages/');
				writeJsonFile(out + 'stages/' + id + '.json', json);
				stageCount++;
			}
			else
				prog.report.push('Sahne çevrilemedi: ' + id);
			prog.cur++;
		}
		prog.report.push('Sahne: ' + stageCount + ' dönüştürüldü');
		var stageScripts:Int = countFilesWithExt(stageDir, ['.hx']);
		if (stageScripts > 0) prog.report.push('Atlanan sahne scripti (.hx): ' + stageScripts);

		prog.stage = 'Şarkılar';
		var songs:Array<String> = cne.compatibility.CNECompat.listSongs(mod);
		prog.total = songs.length;
		prog.cur = 0;
		var songCount:Int = 0;
		var skippedSongScripts:Int = 0;
		var allDiffs:Array<String> = [];
		for (song in songs)
		{
			var songDir:String = cne.compatibility.CNECompat.songDir(mod, song);
			if (songDir == null)
			{
				prog.cur++;
				continue;
			}
			var chartsPath:String = songDir + '/charts/';
			var chartFiles:Array<String> = [];
			for (f in listDir(chartsPath))
				if (StringTools.endsWith(f.toLowerCase(), '.json')) chartFiles.push(f);

			// Psych düzeni: data/<şarkı>/<şarkı>.json ve <şarkı>-<zorluk>.json
			var outSongDir:String = out + 'data/' + song + '/';
			if (!FileSystem.exists(outSongDir)) FileSystem.createDirectory(outSongDir);

			var firstConverted:Dynamic = null;
			var hasBase:Bool = false;
			for (cf in chartFiles)
			{
				var diffName:String = cf.substr(0, cf.length - 5);
				var converted:Dynamic = cne.compatibility.CNESongConverter.convert(mod, song, diffName, chartsPath + cf);
				if (converted == null)
				{
					prog.report.push('Chart çevrilemedi: ' + song + '/' + cf);
					continue;
				}
				var dl:String = diffName.toLowerCase();
				var psychName:String;
				if (chartFiles.length == 1 || dl == 'normal' || dl == song.toLowerCase())
				{
					psychName = song; // varsayılan zorluk: <şarkı>.json
					hasBase = true;
				}
				else
					psychName = song + '-' + diffName; // <şarkı>-<zorluk>.json
				writeJsonFile(outSongDir + psychName + '.json', converted);
				if (firstConverted == null) firstConverted = converted;
				if (allDiffs.indexOf(dl) < 0) allDiffs.push(dl);
				songCount++;
			}
			// Temel chart yazılmadıysa ilkini temel olarak yaz
			if (!hasBase && firstConverted != null)
			{
				writeJsonFile(outSongDir + song + '.json', firstConverted);
				if (allDiffs.indexOf('normal') < 0) allDiffs.push('normal');
			}

			// Ses dosyaları: songs/<şarkı>/song/* -> songs/<şarkı>/
			var audioSrc:String = songDir + '/song/';
			if (FileSystem.exists(audioSrc))
			{
				var audioDst:String = out + 'songs/' + song + '/';
				if (!FileSystem.exists(audioDst)) FileSystem.createDirectory(audioDst);
				for (af in listDir(audioSrc))
					if (!FileSystem.isDirectory(audioSrc + '/' + af))
						File.copy(audioSrc + '/' + af, audioDst + af);
			}

			// Şarkı scriptleri: yalnız .lua taşınır (Psych şarkı script konumu: data/<şarkı>/)
			var songScripts:String = songDir + '/scripts/';
			for (sf in listDir(songScripts))
			{
				if (StringTools.endsWith(sf.toLowerCase(), '.lua'))
					File.copy(songScripts + sf, outSongDir + sf);
				else
					skippedSongScripts++;
			}
			prog.cur++;
		}
		prog.report.push('Chart: ' + songCount + ' dönüştürüldü (' + songs.length + ' şarkı)');
		if (skippedSongScripts > 0) prog.report.push('Atlanan şarkı scripti (.hx): ' + skippedSongScripts);

		// --- Haftalar ---
		prog.stage = 'Haftalar';
		var weekIds:Array<String> = [];
		var weeksSrc:String = root + '/data/weeks/weeks/';
		for (wf in listDir(weeksSrc))
		{
			if (!StringTools.endsWith(wf.toLowerCase(), '.xml')) continue;
			var id:String = wf.substr(0, wf.length - 4);
			var weekFile:Dynamic = cne.compatibility.CNEWeekConverter.convertWeekXml(mod, weeksSrc + wf, id);
			if (weekFile == null) continue;
			if (!FileSystem.exists(out + 'weeks/')) FileSystem.createDirectory(out + 'weeks/');
			writeJsonFile(out + 'weeks/' + id + '.json', weekFile);
			weekIds.push(id);
		}

		// Haftalara girmemiş şarkılar için sentetik freeplay haftası
		var covered:Map<String, Bool> = new Map();
		for (wid in weekIds)
		{
			try
			{
				var wf:Dynamic = Json.parse(File.getContent(out + 'weeks/' + wid + '.json'));
				for (s in (wf.songs : Array<Dynamic>))
				{
					var nm:String = Std.isOfType(s, Array) ? Std.string((cast(s, Array<Dynamic>)[0])) : (Reflect.hasField(s, 'name') ? Std.string(s.name) : null);
					if (nm != null) covered.set(nm.toLowerCase(), true);
				}
			}
			catch (e:Dynamic) {}
		}
		var loose:Array<String> = [];
		for (song in songs)
			if (!covered.exists(song.toLowerCase())) loose.push(song);
		if (loose.length > 0)
		{
			var looseSongs:Array<Dynamic> = [];
			for (song in loose)
				looseSongs.push([song, cneLooseIcon(mod, song), [146, 113, 253]]);
			var synthWeek:Dynamic = {
				songs: looseSongs,
				weekCharacters: ['none', 'bf', 'none'],
				weekBackground: 'stage',
				weekBefore: '',
				storyName: mod + ' (CNE Songs)',
				weekName: mod + ' (CNE Songs)',
				startUnlocked: true,
				hiddenUntilUnlocked: false,
				hideStoryMode: true,
				hideFreeplay: false,
				difficulties: ''
			};
			if (!FileSystem.exists(out + 'weeks/')) FileSystem.createDirectory(out + 'weeks/');
			writeJsonFile(out + 'weeks/' + outNameStatic(mod) + '_songs.json', synthWeek);
			weekIds.push(outNameStatic(mod) + '_songs');
		}
		// Zorluk listesini haftalara işle (freeplay zorluk seçici bunu kullanır)
		if (allDiffs.length > 0)
		{
			var order:Array<String> = ['easy', 'normal', 'hard'];
			var sortedDiffs:Array<String> = [];
			for (o in order)
				if (allDiffs.indexOf(o) >= 0) sortedDiffs.push(o);
			for (d in allDiffs)
				if (sortedDiffs.indexOf(d) < 0) sortedDiffs.push(d);
			var diffStr:String = sortedDiffs.join(',');
			for (wid in weekIds)
			{
				var wp:String = out + 'weeks/' + wid + '.json';
				if (!FileSystem.exists(wp)) continue;
				try
				{
					var wj:Dynamic = Json.parse(File.getContent(wp));
					wj.difficulties = diffStr;
					writeJsonFile(wp, wj);
				}
				catch (e:Dynamic) {}
			}
		}
		if (weekIds.length > 0)
			File.saveContent(out + 'weeks/weekList.txt', weekIds.join('\n'));
		prog.report.push('Hafta: ' + weekIds.length + ' yazıldı');

		// --- Asset kopyalama ---
		prog.stage = 'Asset kopyalama';
		var assetFolders:Array<String> = ['images', 'fonts', 'music', 'sounds', 'videos', 'shaders', 'languages'];
		var copiedAssets:Int = 0;
		for (af in assetFolders)
		{
			var src:String = root + '/' + af + '/';
			if (FileSystem.exists(src))
				copiedAssets += copyTree(src, out + af + '/');
		}
		prog.report.push('Asset dosyası kopyalandı: ' + copiedAssets);

		// --- Lua scriptler (Psych uyumlu olanlar) ---
		prog.stage = 'Lua scriptler';
		var luaSrc:String = root + '/scripts/';
		var luaCount:Int = 0;
		for (lf in listDir(luaSrc))
		{
			if (StringTools.endsWith(lf.toLowerCase(), '.lua'))
			{
				if (!FileSystem.exists(out + 'scripts/')) FileSystem.createDirectory(out + 'scripts/');
				File.copy(luaSrc + lf, out + 'scripts/' + lf);
				luaCount++;
			}
		}
		for (sub in ['custom_events', 'custom_notetypes'])
			if (FileSystem.exists(root + '/' + sub + '/'))
				luaCount += copyTree(root + '/' + sub + '/', out + sub + '/');
		if (luaCount > 0) prog.report.push('Lua/script dosyası kopyalandı: ' + luaCount);
		var globalHx:Int = countFilesWithExt(root + '/data/scripts/', ['.hx']);
		var eventHx:Int = countFilesWithExt(root + '/data/events/', ['.hx', '.hscript']);
		if (globalHx + eventHx > 0)
			prog.report.push('Atlanan CNE scripti (global/event .hx): ' + (globalHx + eventHx) + ' — Lua karşılıklarını yazman gerekir');

		// --- pack.json ---
		writeJsonFile(out + 'pack.json', {
			name: mod + ' (Psych Port)',
			description: 'Mod Porter ile Codename Engine formatından dönüştürüldü.',
			restart: true
		});
		prog.report.push('pack.json oluşturuldu');
	}

	static function cneLooseIcon(mod:String, song:String):String
	{
		try
		{
			var chartPath:String = cne.compatibility.CNECompat.findChartFile(mod, song, null);
			if (chartPath != null)
			{
				var chart:Dynamic = Json.parse(File.getContent(chartPath));
				for (sl in (chart.strumLines : Array<Dynamic>))
				{
					if (sl == null || sl.type == null || Std.int(sl.type) != 0) continue;
					var chars:Array<Dynamic> = (sl.characters != null) ? sl.characters : [];
					if (chars.length > 0 && chars[0] != null)
					{
						var icon:String = cne.compatibility.CNECharacterConverter.resolveIconName(Std.string(chars[0]));
						return (icon != null) ? icon : Std.string(chars[0]);
					}
				}
			}
		}
		catch (e:Dynamic) {}
		return 'face';
	}

	// ================== V-SLICE → PSYCH ==================

	static function convertVSlice(mod:String, prog:PorterProgress)
	{
		var base:String = Paths.mods(mod);
		if (!FileSystem.exists(base)) throw 'Mod klasörü bulunamadı.';
		var out:String = prepareOutDir(mod);
		prog.outDir = out;

		// --- Karakterler ---
		prog.stage = 'Karakterler';
		var charFiles:Array<String> = [];
		for (f in listDir(base + '/data/characters/'))
			if (StringTools.endsWith(f.toLowerCase(), '.json')) charFiles.push(f);
		prog.total = charFiles.length;
		prog.cur = 0;
		var charCount:Int = 0;
		for (f in charFiles)
		{
			var id:String = f.substr(0, f.length - 5);
			var json:Dynamic = vslice.compatibility.VSliceCharacterConverter.convertFromMod(mod, id);
			if (json != null)
			{
				if (!FileSystem.exists(out + 'characters/')) FileSystem.createDirectory(out + 'characters/');
				writeJsonFile(out + 'characters/' + id + '.json', json);
				charCount++;
			}
			else
				prog.report.push('Karakter çevrilemedi: ' + id);
			prog.cur++;
		}
		prog.report.push('Karakter: ' + charCount + ' dönüştürüldü');

		// --- Sahneler ---
		prog.stage = 'Sahneler';
		var stageFiles:Array<String> = [];
		for (f in listDir(base + '/data/stages/'))
			if (StringTools.endsWith(f.toLowerCase(), '.json')) stageFiles.push(f);
		prog.total = stageFiles.length;
		prog.cur = 0;
		var stageCount:Int = 0;
		for (f in stageFiles)
		{
			var id:String = f.substr(0, f.length - 5);
			var json:Dynamic = vslice.compatibility.VSliceStageConverter.convertFromMod(mod, id);
			if (json != null)
			{
				if (!FileSystem.exists(out + 'stages/')) FileSystem.createDirectory(out + 'stages/');
				writeJsonFile(out + 'stages/' + id + '.json', json);
				stageCount++;
			}
			else
				prog.report.push('Sahne çevrilemedi: ' + id);
			prog.cur++;
		}
		prog.report.push('Sahne: ' + stageCount + ' dönüştürüldü');

		prog.stage = 'Şarkılar';
		var songDirs:Array<String> = [];
		for (d in listDir(base + '/data/songs/'))
			if (FileSystem.isDirectory(base + '/data/songs/' + d)) songDirs.push(d);
		prog.total = songDirs.length;
		prog.cur = 0;
		var chartCount:Int = 0;
		for (id in songDirs)
		{
			var songPath:String = base + '/data/songs/' + id + '/';
			var chartFile:String = songPath + id + '-chart.json';
			if (!FileSystem.exists(chartFile))
			{
				prog.report.push('Chart bulunamadı: ' + id);
				prog.cur++;
				continue;
			}
			// Varyasyon chart'ları (-pico vb.) atlanır
			for (f in listDir(songPath))
				if (f != id + '-chart.json' && StringTools.endsWith(f.toLowerCase(), '-chart.json'))
					prog.report.push('Varyasyon chart atlandı: ' + id + '/' + f);

			var metaFile:String = songPath + id + '-metadata.json';
			var metaJson:Dynamic = null;
			if (FileSystem.exists(metaFile))
				try metaJson = Json.parse(File.getContent(metaFile)) catch (e:Dynamic) metaJson = null;

			var chartJson:Dynamic = null;
			try chartJson = Json.parse(File.getContent(chartFile)) catch (e:Dynamic) chartJson = null;
			if (chartJson == null || !vslice.compatibility.VSliceSongConverter.isVSliceChart(chartJson))
			{
				prog.report.push('Chart V-Slice formatında değil: ' + id);
				prog.cur++;
				continue;
			}

			var outSongDir:String = out + 'data/songs/' + id + '/';
			if (!FileSystem.exists(outSongDir)) FileSystem.createDirectory(outSongDir);

			var notesMap:Dynamic = chartJson.notes;
			var diffs:Array<String> = Reflect.fields(notesMap);
			var hasNormal:Bool = false;
			var firstConverted:Dynamic = null;
			for (diff in diffs)
			{
				var converted:Dynamic = vslice.compatibility.VSliceSongConverter.convert(chartJson, metaJson, diff, id);
				if (converted == null) continue;
				writeJsonFile(outSongDir + diff + '.json', converted);
				if (firstConverted == null) firstConverted = converted;
				if (diff.toLowerCase() == 'normal') hasNormal = true;
				chartCount++;
			}
			if (!hasNormal && firstConverted != null)
				writeJsonFile(outSongDir + 'normal.json', firstConverted);

			// Sesler: songs/<id>/ olduğu gibi kopyalanır (Inst + Voices-<karakter>)
			var audioSrc:String = base + '/songs/' + id + '/';
			if (FileSystem.exists(audioSrc))
			{
				var audioDst:String = out + 'songs/' + id + '/';
				if (!FileSystem.exists(audioDst)) FileSystem.createDirectory(audioDst);
				for (af in listDir(audioSrc))
					if (!FileSystem.isDirectory(audioSrc + '/' + af))
						File.copy(audioSrc + '/' + af, audioDst + af);
			}
			prog.cur++;
		}
		prog.report.push('Chart: ' + chartCount + ' dönüştürüldü (' + songDirs.length + ' şarkı)');

		// --- Haftalar (levels) ---
		prog.stage = 'Haftalar';
		var weekIds:Array<String> = [];
		var covered:Map<String, Bool> = new Map();
		for (lf in listDir(base + '/data/levels/'))
		{
			if (!StringTools.endsWith(lf.toLowerCase(), '.json')) continue;
			var id:String = lf.substr(0, lf.length - 5);
			var weekFile:Dynamic = convertVSliceLevel(base + '/data/levels/' + lf, id, mod);
			if (weekFile == null) continue;
			if (!FileSystem.exists(out + 'weeks/')) FileSystem.createDirectory(out + 'weeks/');
			writeJsonFile(out + 'weeks/' + id + '.json', weekFile);
			weekIds.push(id);
			for (s in (weekFile.songs : Array<Dynamic>))
			{
				var nm:String = Std.isOfType(s, Array) ? Std.string((cast(s, Array<Dynamic>)[0])) : null;
				if (nm != null) covered.set(nm.toLowerCase(), true);
			}
		}

		// Level'lara girmemiş şarkılar için sentetik hafta
		var loose:Array<String> = [];
		for (id in songDirs)
			if (!covered.exists(id.toLowerCase())) loose.push(id);
		if (loose.length > 0)
		{
			var looseSongs:Array<Dynamic> = [];
			for (id in loose)
				looseSongs.push([id, vsliceLooseIcon(base, mod, id), [146, 113, 253]]);
			var synthWeek:Dynamic = {
				songs: looseSongs,
				weekCharacters: ['none', 'bf', 'none'],
				weekBackground: '',
				weekBefore: '',
				storyName: mod + ' (V-Slice Songs)',
				weekName: mod + ' (V-Slice Songs)',
				startUnlocked: true,
				hiddenUntilUnlocked: false,
				hideStoryMode: true,
				hideFreeplay: false,
				difficulties: ''
			};
			if (!FileSystem.exists(out + 'weeks/')) FileSystem.createDirectory(out + 'weeks/');
			writeJsonFile(out + 'weeks/' + outNameStatic(mod) + '_songs.json', synthWeek);
			weekIds.push(outNameStatic(mod) + '_songs');
		}
		if (weekIds.length > 0)
			File.saveContent(out + 'weeks/weekList.txt', weekIds.join('\n'));
		prog.report.push('Hafta: ' + weekIds.length + ' yazıldı');

		// --- Asset kopyalama ---
		prog.stage = 'Asset kopyalama';
		var copiedAssets:Int = 0;
		for (af in ['images', 'fonts', 'music', 'sounds', 'videos', 'shaders'])
			if (FileSystem.exists(base + '/' + af + '/'))
				copiedAssets += copyTree(base + '/' + af + '/', out + af + '/');
		// shared/images -> images (V-Slice köprü düzeni)
		if (FileSystem.exists(base + '/shared/images/'))
			copiedAssets += copyTree(base + '/shared/images/', out + 'images/');
		prog.report.push('Asset dosyası kopyalandı: ' + copiedAssets + ' (shared/images birleştirildi)');

		// --- Lua scriptler ---
		prog.stage = 'Lua scriptler';
		var luaCount:Int = 0;
		for (lf in listDir(base + '/scripts/'))
			if (StringTools.endsWith(lf.toLowerCase(), '.lua'))
			{
				if (!FileSystem.exists(out + 'scripts/')) FileSystem.createDirectory(out + 'scripts/');
				File.copy(base + '/scripts/' + lf, out + 'scripts/' + lf);
				luaCount++;
			}
		// scripts/songs/<şarkı>.lua -> data/songs/<şarkı>/ (Psych şarkı script konumu)
		for (sf in listDir(base + '/scripts/songs/'))
			if (StringTools.endsWith(sf.toLowerCase(), '.lua'))
			{
				var songId:String = sf.substr(0, sf.length - 4);
				var dst:String = out + 'data/songs/' + songId + '/';
				if (FileSystem.exists(out + 'data/songs/' + songId + '/'))
				{
					File.copy(base + '/scripts/songs/' + sf, dst + sf);
					luaCount++;
				}
			}
		if (luaCount > 0) prog.report.push('Lua dosyası kopyalandı: ' + luaCount);
		var hxcCount:Int = countFilesWithExt(base + '/scripts/', ['.hxc']);
		for (sub in ['events', 'modules', 'songs', 'stages'])
			hxcCount += countFilesWithExt(base + '/scripts/' + sub + '/', ['.hxc', '.hx']);
		if (hxcCount > 0)
			prog.report.push('Atlanan V-Slice scripti (.hxc): ' + hxcCount + ' — Lua karşılıklarını yazman gerekir');

		// --- pack.json ---
		writeJsonFile(out + 'pack.json', {
			name: mod + ' (Psych Port)',
			description: 'Mod Porter ile V-Slice formatından dönüştürüldü.',
			restart: true
		});
		prog.report.push('pack.json oluşturuldu');
	}

	static function convertVSliceLevel(path:String, levelName:String, mod:String):Dynamic
	{
		try
		{
			var lvl:Dynamic = Json.parse(File.getContent(path));
			if (lvl == null || lvl.songs == null) return null;
			var psychSongs:Array<Dynamic> = [];
			for (s in (lvl.songs : Array<Dynamic>))
			{
				if (s == null) continue;
				var songName:String = Std.isOfType(s, String) ? Std.string(s) : (Reflect.hasField(s, 'name') ? Std.string(s.name) : '');
				if (songName.length < 1) continue;
				psychSongs.push([songName, vsliceLooseIcon('mods/' + mod, mod, Paths.formatToSongPath(songName)), [146, 113, 253]]);
			}
			if (psychSongs.length < 1) return null;
			return {
				songs: psychSongs,
				weekCharacters: ['dad', 'bf', 'gf'],
				weekBackground: '',
				weekBefore: '',
				storyName: (lvl.name != null) ? Std.string(lvl.name) : levelName,
				weekName: (lvl.name != null) ? Std.string(lvl.name) : levelName,
				startUnlocked: true,
				hiddenUntilUnlocked: false,
				hideStoryMode: false,
				hideFreeplay: false,
				difficulties: ''
			};
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	static function vsliceLooseIcon(basePath:String, mod:String, songId:String):String
	{
		try
		{
			var metaPath:String = basePath + '/data/songs/' + songId + '/' + songId + '-metadata.json';
			if (!FileSystem.exists(metaPath))
			{
				// formatlanmamış adla da dene
				for (d in listDir(basePath + '/data/songs/'))
				{
					var p:String = basePath + '/data/songs/' + d + '/' + d + '-metadata.json';
					if (d.toLowerCase() == songId.toLowerCase() && FileSystem.exists(p))
					{
						metaPath = p;
						break;
					}
				}
			}
			if (FileSystem.exists(metaPath))
			{
				var meta:Dynamic = Json.parse(File.getContent(metaPath));
				var chars:Dynamic = (meta != null && Reflect.hasField(meta, 'playData')) ? Reflect.field(meta.playData, 'characters') : null;
				for (who in ['player', 'opponent'])
				{
					var c:Dynamic = chars != null ? Reflect.field(chars, who) : null;
					if (c != null && Std.string(c).length > 0)
					{
						var iconFile:String = 'icon-' + Std.string(c).toLowerCase();
						for (sub in ['images/icons/', 'shared/images/icons/'])
							if (FileSystem.exists(basePath + '/' + sub + iconFile + '.png'))
								return Std.string(c);
					}
				}
			}
		}
		catch (e:Dynamic) {}
		return 'face';
	}

	// ================== PSYCH → CODENAME ==================

	static function convertPsychToCNE(mod:String, prog:PorterProgress)
	{
		var base:String = Paths.mods(mod);
		if (!FileSystem.exists(base)) throw 'Mod klasörü bulunamadı.';
		var out:String = prepareOutDir(mod);
		prog.outDir = out;

		// --- Karakterler: characters/*.json -> data/characters/*.xml ---
		prog.stage = 'Karakterler';
		var charFiles:Array<String> = [];
		for (f in listDir(base + '/characters/'))
			if (StringTools.endsWith(f.toLowerCase(), '.json')) charFiles.push(f);
		prog.total = charFiles.length;
		prog.cur = 0;
		var charCount:Int = 0;
		for (f in charFiles)
		{
			var id:String = f.substr(0, f.length - 5);
			try
			{
				var json:Dynamic = Json.parse(File.getContent(base + '/characters/' + f));
				if (!FileSystem.exists(out + 'data/characters/')) FileSystem.createDirectory(out + 'data/characters/');
				File.saveContent(out + 'data/characters/' + id + '.xml', psychCharToCNEXml(json, id));
				charCount++;
			}
			catch (e:Dynamic) prog.report.push('Karakter çevrilemedi: ' + id);
			prog.cur++;
		}
		prog.report.push('Karakter: ' + charCount + ' dönüştürüldü (XML)');

		// --- Sahneler: stages/*.json -> data/stages/*.xml ---
		prog.stage = 'Sahneler';
		var stageFiles:Array<String> = [];
		for (f in listDir(base + '/stages/'))
			if (StringTools.endsWith(f.toLowerCase(), '.json')) stageFiles.push(f);
		prog.total = stageFiles.length;
		prog.cur = 0;
		var stageCount:Int = 0;
		for (f in stageFiles)
		{
			var id:String = f.substr(0, f.length - 5);
			try
			{
				var json:Dynamic = Json.parse(File.getContent(base + '/stages/' + f));
				if (!FileSystem.exists(out + 'data/stages/')) FileSystem.createDirectory(out + 'data/stages/');
				File.saveContent(out + 'data/stages/' + id + '.xml', psychStageToCNEXml(json));
				stageCount++;
			}
			catch (e:Dynamic) prog.report.push('Sahne çevrilemedi: ' + id);
			prog.cur++;
		}
		prog.report.push('Sahne: ' + stageCount + ' dönüştürüldü (XML)');

		// --- Şarkılar: data/songs veya songs altındaki chart JSON'ları ---
		prog.stage = 'Şarkılar';
		var songCharts:Map<String, Array<String>> = findPsychCharts(base);
		var songIds:Array<String> = [for (k in songCharts.keys()) k];
		prog.total = songIds.length;
		prog.cur = 0;
		var chartCount:Int = 0;
		for (song in songIds)
		{
			var chartPaths:Array<String> = songCharts.get(song);
			var outSongDir:String = out + 'songs/' + song + '/charts/';
			if (!FileSystem.exists(outSongDir)) FileSystem.createDirectory(outSongDir);
			var metaWritten:Bool = false;
			for (cp in chartPaths)
			{
				var fname:String = cp.substring(cp.lastIndexOf('/') + 1);
				var diffName:String = fname.substr(0, fname.length - 5);
				var songLower:String = song.toLowerCase();
				if (diffName.toLowerCase() == songLower)
					diffName = 'normal';
				else if (StringTools.startsWith(diffName.toLowerCase(), songLower + '-'))
					diffName = diffName.substr(song.length + 1); // <şarkı>-<zorluk>.json
				try
				{
					var parsed:Dynamic = Json.parse(File.getContent(cp));
					if (parsed != null && Reflect.hasField(parsed, 'song') && Reflect.field(parsed, 'song') != null)
						parsed = Reflect.field(parsed, 'song');
					var cneChart:Dynamic = psychChartToCNE(parsed);
					writeJsonFile(outSongDir + diffName + '.json', cneChart);
					chartCount++;
					if (!metaWritten)
					{
						var metaOut:Dynamic = {
							displayName: song,
							bpm: (parsed.bpm != null) ? parsed.bpm : 100,
							needsVoices: (parsed.needsVoices != null) ? (parsed.needsVoices == true) : true
						};
						writeJsonFile(out + 'songs/' + song + '/meta.json', metaOut);
						metaWritten = true;
					}
				}
				catch (e:Dynamic) prog.report.push('Chart çevrilemedi: ' + song + '/' + fname);
			}
			// Sesler: Psych songs/<song>/ -> CNE songs/<song>/song/
			var audioSrc:String = base + '/songs/' + song + '/';
			if (FileSystem.exists(audioSrc))
			{
				var audioDst:String = out + 'songs/' + song + '/song/';
				if (!FileSystem.exists(audioDst)) FileSystem.createDirectory(audioDst);
				for (af in listDir(audioSrc))
				{
					var afl:String = af.toLowerCase();
					if (!FileSystem.isDirectory(audioSrc + af) && (StringTools.endsWith(afl, '.ogg') || StringTools.endsWith(afl, '.mp3')))
						File.copy(audioSrc + af, audioDst + af);
				}
			}
			prog.cur++;
		}
		prog.report.push('Chart: ' + chartCount + ' dönüştürüldü (' + songIds.length + ' şarkı)');

		// --- Haftalar: weeks/*.json -> data/weeks/weeks/*.xml ---
		prog.stage = 'Haftalar';
		var weekCount:Int = 0;
		for (wf in listDir(base + '/weeks/'))
		{
			if (!StringTools.endsWith(wf.toLowerCase(), '.json')) continue;
			var id:String = wf.substr(0, wf.length - 5);
			if (id.toLowerCase() == 'weeklist') continue;
			try
			{
				var week:Dynamic = Json.parse(File.getContent(base + '/weeks/' + wf));
				if (!FileSystem.exists(out + 'data/weeks/weeks/')) FileSystem.createDirectory(out + 'data/weeks/weeks/');
				File.saveContent(out + 'data/weeks/weeks/' + id + '.xml', psychWeekToCNEXml(week));
				weekCount++;
			}
			catch (e:Dynamic) prog.report.push('Hafta çevrilemedi: ' + id);
		}
		prog.report.push('Hafta: ' + weekCount + ' dönüştürüldü (XML)');

		// --- Assetler ---
		prog.stage = 'Asset kopyalama';
		var copiedAssets:Int = 0;
		for (af in ['images', 'fonts', 'music', 'sounds', 'videos', 'shaders'])
			if (FileSystem.exists(base + '/' + af + '/'))
				copiedAssets += copyTree(base + '/' + af + '/', out + af + '/');
		prog.report.push('Asset kopyalandı: ' + copiedAssets);

		prog.stage = 'Script kontrolü';
		var luaSkipped:Int = countFilesWithExt(base + '/scripts/', ['.lua']);
		luaSkipped += countFilesWithExt(base + '/custom_events/', ['.lua']);
		luaSkipped += countFilesWithExt(base + '/custom_notetypes/', ['.lua']);
		if (luaSkipped > 0)
			prog.report.push('Atlanan Psych Lua scripti: ' + luaSkipped + ' — Codename hscript karşılıklarını yazman gerekir');

		prog.report.push('BİTTİ: Codename Engine modu hazır');
	}

	static function xmlEscape(str:String):String
	{
		if (str == null) return '';
		return str.split('&').join('&amp;').split('<').join('&lt;').split('>').join('&gt;').split('"').join('&quot;');
	}

	static function psychCharToCNEXml(json:Dynamic, id:String):String
	{
		var image:String = (json.image != null) ? Std.string(json.image) : id;
		if (StringTools.startsWith(image, 'characters/')) image = image.substr(11);
		var buf:StringBuf = new StringBuf();
		buf.add('<!DOCTYPE codename-engine-character>\n');
		buf.add('<character');
		buf.add(' sprite="' + xmlEscape(image) + '"');
		if (json.healthicon != null) buf.add(' icon="' + xmlEscape(Std.string(json.healthicon)) + '"');
		var cols:Array<Dynamic> = json.healthbar_colors;
		if (cols != null && cols.length >= 3)
			buf.add(' color="#' + StringTools.hex(Std.int(cols[0]), 2) + StringTools.hex(Std.int(cols[1]), 2) + StringTools.hex(Std.int(cols[2]), 2) + '"');
		var pos:Array<Dynamic> = json.position;
		if (pos != null && pos.length >= 2) buf.add(' x="' + pos[0] + '" y="' + pos[1] + '"');
		var cam:Array<Dynamic> = json.camera_position;
		if (cam != null && cam.length >= 2) buf.add(' camx="' + cam[0] + '" camy="' + cam[1] + '"');
		if (json.flip_x == true) buf.add(' flipX="true"');
		if (json.scale != null && json.scale != 1) buf.add(' scale="' + json.scale + '"');
		if (json.sing_duration != null) buf.add(' holdTime="' + json.sing_duration + '"');
		if (json.no_antialiasing == true) buf.add(' antialiasing="false"');
		if (json.is_player == true || json._editor_isPlayer == true) buf.add(' isPlayer="true"');
		buf.add('>\n');
		if (json.animations != null)
			for (a in (json.animations : Array<Dynamic>))
			{
				if (a == null) continue;
				buf.add('\t<anim name="' + xmlEscape(Std.string(a.anim)) + '" anim="' + xmlEscape(Std.string(a.name)) + '"');
				var offs:Array<Dynamic> = a.offsets;
				if (offs != null && offs.length >= 2) buf.add(' x="' + offs[0] + '" y="' + offs[1] + '"');
				buf.add(' fps="' + ((a.fps != null) ? a.fps : 24) + '" loop="' + (a.loop == true) + '"');
				var idx:Array<Dynamic> = a.indices;
				if (idx != null && idx.length > 0) buf.add(' indices="' + idx.join(',') + '"');
				buf.add('/>\n');
			}
		buf.add('</character>\n');
		return buf.toString();
	}

	static function charNodeXml(nodeName:String, pos:Array<Dynamic>, cam:Array<Dynamic>):String
	{
		var str:String = '\t<' + nodeName;
		if (pos != null && pos.length >= 2) str += ' x="' + pos[0] + '" y="' + pos[1] + '"';
		if (cam != null && cam.length >= 2) str += ' camxoffset="' + cam[0] + '" camyoffset="' + cam[1] + '"';
		return str + ' />\n';
	}

	static function psychStageToCNEXml(st:Dynamic):String
	{
		var buf:StringBuf = new StringBuf();
		buf.add('<!DOCTYPE codename-engine-stage>\n');
		buf.add('<stage zoom="' + ((st.defaultZoom != null) ? st.defaultZoom : 0.9) + '" name="stage" folder="">\n');
		var charAdded:Map<String, Bool> = ['girlfriend' => false, 'dad' => false, 'boyfriend' => false];
		if (st.objects != null)
		{
			for (o in (st.objects : Array<Dynamic>))
			{
				if (o == null) continue;
				var t:String = (o.type != null) ? Std.string(o.type) : 'sprite';
				switch (t)
				{
					case 'gf', 'gfGroup':
						if (st.hide_girlfriend == true) continue;
						buf.add(charNodeXml('girlfriend', st.girlfriend, st.camera_girlfriend));
						charAdded.set('girlfriend', true);
					case 'dad', 'dadGroup':
						buf.add(charNodeXml('dad', st.opponent, st.camera_opponent));
						charAdded.set('dad', true);
					case 'boyfriend', 'boyfriendGroup':
						buf.add(charNodeXml('boyfriend', st.boyfriend, st.camera_boyfriend));
						charAdded.set('boyfriend', true);
					case 'sprite', 'animatedSprite':
						var img:String = (o.image != null) ? Std.string(o.image) : '';
						if (img.length < 1) continue;
						buf.add('\t<sprite name="' + xmlEscape((o.name != null) ? Std.string(o.name) : 'prop') + '" x="' + o.x + '" y="' + o.y + '" sprite="' + xmlEscape(img) + '"');
						var sc:Array<Dynamic> = o.scroll;
						if (sc != null && sc.length >= 2) buf.add(' scroll="' + sc[0] + '"');
						var scale:Array<Dynamic> = o.scale;
						if (scale != null && scale.length >= 2) buf.add(' scale="' + scale[0] + '"');
						if (o.alpha != null) buf.add(' alpha="' + o.alpha + '"');
						if (o.flipX == true) buf.add(' flipX="true"');
						if (o.antialiasing == false) buf.add(' antialiasing="false"');
						var anims:Array<Dynamic> = o.animations;
						if (anims != null && anims.length > 0)
						{
							buf.add(' animated="true">\n');
							for (a in anims)
							{
								if (a == null) continue;
								buf.add('\t\t<anim name="' + xmlEscape(Std.string(a.anim)) + '" anim="' + xmlEscape(Std.string(a.name)) + '" fps="' + ((a.fps != null) ? a.fps : 24) + '" loop="' + (a.loop == true) + '"');
								var idx:Array<Dynamic> = a.indices;
								if (idx != null && idx.length > 0) buf.add(' indices="' + idx.join(',') + '"');
								buf.add('/>\n');
							}
							buf.add('\t</sprite>\n');
						}
						else
							buf.add('/>\n');
					default:
						// 'square' vb. CNE'de karşılığı yok, atlanır
				}
			}
		}
		if (!charAdded.get('girlfriend') && st.hide_girlfriend != true)
			buf.add(charNodeXml('girlfriend', st.girlfriend, st.camera_girlfriend));
		if (!charAdded.get('dad'))
			buf.add(charNodeXml('dad', st.opponent, st.camera_opponent));
		if (!charAdded.get('boyfriend'))
			buf.add(charNodeXml('boyfriend', st.boyfriend, st.camera_boyfriend));
		buf.add('</stage>\n');
		return buf.toString();
	}

	static function psychChartToCNE(song:Dynamic):Dynamic
	{
		var noteTypes:Array<String> = [];
		var playerNotes:Array<Dynamic> = [];
		var oppNotes:Array<Dynamic> = [];
		var events:Array<Dynamic> = [];

		var curMs:Float = 0;
		var curBpm:Float = (song.bpm != null) ? song.bpm : 100;
		var sections:Array<Dynamic> = (song.notes != null) ? song.notes : [];
		for (sec in sections)
		{
			if (sec == null) continue;
			if (sec.changeBPM == true && sec.bpm != null && sec.bpm != curBpm)
			{
				curBpm = sec.bpm;
				events.push({name: 'BPM Change', time: curMs, params: [curBpm]});
			}
			var secNotes:Array<Dynamic> = (sec.sectionNotes != null) ? sec.sectionNotes : [];
			for (n in secNotes)
			{
				if (n == null) continue;
				var time:Float = n[0];
				var lane:Int = Std.int(n[1]);
				var sLen:Float = (n[2] != null) ? n[2] : 0;
				var typeStr:String = (n[3] != null && !Std.isOfType(n[3], Int)) ? Std.string(n[3]) : '';
				var typeIdx:Int = 0;
				if (typeStr.length > 0)
				{
					var ti:Int = noteTypes.indexOf(typeStr);
					if (ti < 0)
					{
						noteTypes.push(typeStr);
						ti = noteTypes.length - 1;
					}
					typeIdx = ti + 1;
				}
				var entry:Dynamic = {time: time, id: lane % 4, sLen: sLen, type: typeIdx};
				if (lane < 4) playerNotes.push(entry);
				else oppNotes.push(entry);
			}
			var beats:Float = (sec.sectionBeats != null) ? sec.sectionBeats : 4;
			curMs += beats * (60000.0 / curBpm);
		}

		if (song.events != null)
			for (ev in (song.events : Array<Dynamic>))
			{
				if (ev == null || !Std.isOfType(ev, Array)) continue;
				var arr:Array<Dynamic> = cast ev;
				var t:Float = arr[0];
				var list:Array<Dynamic> = (arr[1] != null) ? arr[1] : [];
				for (e in list)
				{
					if (e == null) continue;
					var name:String = Std.string(e[0]);
					var v1:Dynamic = (e.length > 1) ? e[1] : '';
					var v2:Dynamic = (e.length > 2) ? e[2] : '';
					events.push({name: name, time: t, params: [v1, v2]});
				}
			}

		return {
			codenameChart: true,
			meta: {bpm: (song.bpm != null) ? song.bpm : 100},
			stage: (song.stage != null) ? song.stage : 'stage',
			scrollSpeed: (song.speed != null) ? song.speed : 1,
			noteTypes: noteTypes,
			strumLines: [
				{position: 'dad', type: 0, characters: [(song.player2 != null) ? song.player2 : 'dad'], notes: oppNotes, visible: true},
				{position: 'boyfriend', type: 1, characters: [(song.player1 != null) ? song.player1 : 'bf'], notes: playerNotes, visible: true}
			],
			events: events
		};
	}

	static function psychWeekToCNEXml(week:Dynamic):String
	{
		var buf:StringBuf = new StringBuf();
		buf.add('<!DOCTYPE codename-engine-week>\n');
		var name:String = (week.storyName != null && Std.string(week.storyName).length > 0) ? Std.string(week.storyName) : ((week.weekName != null) ? Std.string(week.weekName) : 'Week');
		buf.add('<week name="' + xmlEscape(name) + '"');
		var chars:Array<Dynamic> = week.weekCharacters;
		if (chars != null && chars.length >= 3)
		{
			var parts:Array<String> = [];
			for (c in chars)
			{
				var cc:String = Std.string(c);
				if (cc == 'none' || cc == '') cc = 'none';
				parts.push(cc);
			}
			buf.add(' chars="' + parts.join(',') + '"');
		}
		if (week.weekBackground != null && Std.string(week.weekBackground).length > 0)
			buf.add(' sprite="' + xmlEscape(Std.string(week.weekBackground)) + '"');
		buf.add('>\n');
		if (week.songs != null)
			for (s in (week.songs : Array<Dynamic>))
			{
				var nm:String = Std.isOfType(s, Array) ? Std.string((cast(s, Array<Dynamic>))[0]) : (Reflect.hasField(s, 'name') ? Std.string(s.name) : '');
				if (nm.length > 0) buf.add('\t<song>' + xmlEscape(nm) + '</song>\n');
			}
		buf.add('</week>\n');
		return buf.toString();
	}

	// ================== PSYCH → V-SLICE ==================

	static function convertPsychToVSlice(mod:String, prog:PorterProgress)
	{
		var base:String = Paths.mods(mod);
		if (!FileSystem.exists(base)) throw 'Mod klasörü bulunamadı.';
		var out:String = prepareOutDir(mod);
		prog.outDir = out;

		// --- Karakterler: characters/*.json -> data/characters/*.json (v-slice) ---
		prog.stage = 'Karakterler';
		var charFiles:Array<String> = [];
		for (f in listDir(base + '/characters/'))
			if (StringTools.endsWith(f.toLowerCase(), '.json')) charFiles.push(f);
		prog.total = charFiles.length;
		prog.cur = 0;
		var charCount:Int = 0;
		for (f in charFiles)
		{
			var id:String = f.substr(0, f.length - 5);
			try
			{
				var json:Dynamic = Json.parse(File.getContent(base + '/characters/' + f));
				if (!FileSystem.exists(out + 'data/characters/')) FileSystem.createDirectory(out + 'data/characters/');
				writeJsonFile(out + 'data/characters/' + id + '.json', psychCharToVSlice(json, id));
				charCount++;
			}
			catch (e:Dynamic) prog.report.push('Karakter çevrilemedi: ' + id);
			prog.cur++;
		}
		prog.report.push('Karakter: ' + charCount + ' dönüştürüldü');

		// --- Sahneler ---
		prog.stage = 'Sahneler';
		var stageFiles:Array<String> = [];
		for (f in listDir(base + '/stages/'))
			if (StringTools.endsWith(f.toLowerCase(), '.json')) stageFiles.push(f);
		prog.total = stageFiles.length;
		prog.cur = 0;
		var stageCount:Int = 0;
		for (f in stageFiles)
		{
			var id:String = f.substr(0, f.length - 5);
			try
			{
				var json:Dynamic = Json.parse(File.getContent(base + '/stages/' + f));
				if (!FileSystem.exists(out + 'data/stages/')) FileSystem.createDirectory(out + 'data/stages/');
				writeJsonFile(out + 'data/stages/' + id + '.json', psychStageToVSlice(json, id));
				stageCount++;
			}
			catch (e:Dynamic) prog.report.push('Sahne çevrilemedi: ' + id);
			prog.cur++;
		}
		prog.report.push('Sahne: ' + stageCount + ' dönüştürüldü');

		prog.stage = 'Şarkılar';
		var songCharts:Map<String, Array<String>> = findPsychCharts(base);
		var songIds:Array<String> = [for (k in songCharts.keys()) k];
		prog.total = songIds.length;
		prog.cur = 0;
		var chartCount:Int = 0;
		for (song in songIds)
		{
			var chartPaths:Array<String> = songCharts.get(song);
			var outSongDir:String = out + 'data/songs/' + song + '/';
			if (!FileSystem.exists(outSongDir)) FileSystem.createDirectory(outSongDir);

			var notesMap:Dynamic = {};
			var scrollMap:Dynamic = {};
			var eventsArr:Array<Dynamic> = [];
			var firstSong:Dynamic = null;
			var diffs:Array<String> = [];

			for (cp in chartPaths)
			{
				var fname:String = cp.substring(cp.lastIndexOf('/') + 1);
				var diffName:String = fname.substr(0, fname.length - 5);
				var songLower:String = song.toLowerCase();
				if (diffName.toLowerCase() == songLower)
					diffName = 'normal';
				else if (StringTools.startsWith(diffName.toLowerCase(), songLower + '-'))
					diffName = diffName.substr(song.length + 1); // <şarkı>-<zorluk>.json
				try
				{
					var parsed:Dynamic = Json.parse(File.getContent(cp));
					if (parsed != null && Reflect.hasField(parsed, 'song') && Reflect.field(parsed, 'song') != null)
						parsed = Reflect.field(parsed, 'song');
					if (firstSong == null) firstSong = parsed;
					var conv:Dynamic = psychChartDiffToVSlice(parsed);
					Reflect.setField(notesMap, diffName, conv.notes);
					Reflect.setField(scrollMap, diffName, conv.speed);
					if (eventsArr.length == 0) eventsArr = conv.events;
					if (diffs.indexOf(diffName) < 0) diffs.push(diffName);
					chartCount++;
				}
				catch (e:Dynamic) prog.report.push('Chart çevrilemedi: ' + song + '/' + fname);
			}

			if (firstSong != null)
			{
				var chartOut:Dynamic = {
					version: '2.1.0',
					generatedBy: 'Further Mod Porter',
					timeFormat: 'ms',
					scrollSpeed: scrollMap,
					events: eventsArr,
					notes: notesMap
				};
				writeJsonFile(outSongDir + song + '-chart.json', chartOut);

				var metaOut:Dynamic = {
					version: '2.1.0',
					songName: (firstSong.song != null) ? firstSong.song : song,
					artist: 'Unknown',
					timeFormat: 'ms',
					timeChanges: psychBpmChanges(firstSong),
					playData: {
						songVariations: [],
						difficulties: diffs,
						characters: {
							player: (firstSong.player1 != null) ? firstSong.player1 : 'bf',
							girlfriend: (firstSong.gfVersion != null) ? firstSong.gfVersion : 'gf',
							opponent: (firstSong.player2 != null) ? firstSong.player2 : 'dad'
						},
						stage: (firstSong.stage != null) ? firstSong.stage : 'mainStage',
						noteStyle: 'funkin'
					},
					generatedBy: 'Further Mod Porter'
				};
				writeJsonFile(outSongDir + song + '-metadata.json', metaOut);
			}

			// Sesler aynı adlarla kalır (Inst.ogg / Voices*.ogg)
			var audioSrc:String = base + '/songs/' + song + '/';
			if (FileSystem.exists(audioSrc))
			{
				var audioDst:String = out + 'songs/' + song + '/';
				if (!FileSystem.exists(audioDst)) FileSystem.createDirectory(audioDst);
				for (af in listDir(audioSrc))
				{
					var afl:String = af.toLowerCase();
					if (!FileSystem.isDirectory(audioSrc + af) && (StringTools.endsWith(afl, '.ogg') || StringTools.endsWith(afl, '.mp3')))
						File.copy(audioSrc + af, audioDst + af);
				}
			}
			prog.cur++;
		}
		prog.report.push('Chart: ' + chartCount + ' dönüştürüldü (' + songIds.length + ' şarkı)');

		// --- Haftalar -> levels ---
		prog.stage = 'Haftalar';
		var weekCount:Int = 0;
		for (wf in listDir(base + '/weeks/'))
		{
			if (!StringTools.endsWith(wf.toLowerCase(), '.json')) continue;
			var id:String = wf.substr(0, wf.length - 5);
			if (id.toLowerCase() == 'weeklist') continue;
			try
			{
				var week:Dynamic = Json.parse(File.getContent(base + '/weeks/' + wf));
				var songsOut:Array<Dynamic> = [];
				if (week.songs != null)
					for (s in (week.songs : Array<Dynamic>))
					{
						var nm:String = Std.isOfType(s, Array) ? Std.string((cast(s, Array<Dynamic>))[0]) : (Reflect.hasField(s, 'name') ? Std.string(s.name) : '');
						if (nm.length > 0) songsOut.push({name: nm});
					}
				if (songsOut.length < 1) continue;
				if (!FileSystem.exists(out + 'data/levels/')) FileSystem.createDirectory(out + 'data/levels/');
				writeJsonFile(out + 'data/levels/' + id + '.json', {
					name: (week.storyName != null) ? week.storyName : ((week.weekName != null) ? week.weekName : id),
					songs: songsOut
				});
				weekCount++;
			}
			catch (e:Dynamic) prog.report.push('Level çevrilemedi: ' + id);
		}
		prog.report.push('Level: ' + weekCount + ' dönüştürüldü');

		// --- Assetler ---
		prog.stage = 'Asset kopyalama';
		var copiedAssets:Int = 0;
		for (af in ['images', 'fonts', 'music', 'sounds', 'videos', 'shaders'])
			if (FileSystem.exists(base + '/' + af + '/'))
				copiedAssets += copyTree(base + '/' + af + '/', out + af + '/');
		prog.report.push('Asset kopyalandı: ' + copiedAssets);

		// --- Lua scriptler ---
		prog.stage = 'Script kontrolü';
		var luaSkipped:Int = countFilesWithExt(base + '/scripts/', ['.lua']);
		luaSkipped += countFilesWithExt(base + '/custom_events/', ['.lua']);
		luaSkipped += countFilesWithExt(base + '/custom_notetypes/', ['.lua']);
		if (luaSkipped > 0)
			prog.report.push('Atlanan Psych Lua scripti: ' + luaSkipped + ' — V-Slice hxc karşılıklarını yazman gerekir');

		prog.report.push('BİTTİ: V-Slice modu hazır');
	}

	static function psychCharToVSlice(json:Dynamic, id:String):Dynamic
	{
		var image:String = (json.image != null) ? Std.string(json.image) : id;
		if (StringTools.startsWith(image, 'characters/')) image = image.substr(11);
		var animsOut:Array<Dynamic> = [];
		if (json.animations != null)
			for (a in (json.animations : Array<Dynamic>))
			{
				if (a == null) continue;
				var entry:Dynamic = {
					name: (a.anim != null) ? a.anim : 'idle',
					prefix: (a.name != null) ? a.name : 'idle',
					offsets: (a.offsets != null) ? a.offsets : [0, 0],
					fps: (a.fps != null) ? a.fps : 24,
					looped: a.loop == true
				};
				if (a.indices != null && a.indices.length > 0) entry.frameIndices = a.indices;
				animsOut.push(entry);
			}
		var cols:Array<Dynamic> = (json.healthbar_colors != null) ? json.healthbar_colors : [161, 161, 161];
		return {
			version: '1.0.0',
			name: id,
			assetPath: image,
			flipX: json.flip_x == true,
			healthIcon: {id: (json.healthicon != null) ? json.healthicon : id},
			renderType: 'sparrow',
			singTime: (json.sing_duration != null) ? json.sing_duration : 4,
			scale: (json.scale != null) ? json.scale : 1,
			cameraPosition: (json.camera_position != null) ? json.camera_position : [0, 0],
			position: (json.position != null) ? json.position : [0, 0],
			healthbarColors: cols,
			animations: animsOut
		};
	}

	static function psychStageToVSlice(st:Dynamic, id:String):Dynamic
	{
		var props:Array<Dynamic> = [];
		if (st.objects != null)
			for (o in (st.objects : Array<Dynamic>))
			{
				if (o == null) continue;
				var t:String = (o.type != null) ? Std.string(o.type) : 'sprite';
				if (t != 'sprite' && t != 'animatedSprite') continue;
				var img:String = (o.image != null) ? Std.string(o.image) : '';
				if (img.length < 1) continue;
				var animsOut:Array<Dynamic> = [];
				if (o.animations != null)
					for (a in (o.animations : Array<Dynamic>))
					{
						if (a == null) continue;
						var entry:Dynamic = {
							name: (a.anim != null) ? a.anim : 'idle',
							prefix: (a.name != null) ? a.name : 'idle',
							offsets: (a.offsets != null) ? a.offsets : [0, 0],
							fps: (a.fps != null) ? a.fps : 24,
							looped: a.loop == true
						};
						if (a.indices != null && a.indices.length > 0) entry.frameIndices = a.indices;
						animsOut.push(entry);
					}
				var prop:Dynamic = {
					name: (o.name != null) ? o.name : 'prop',
					assetPath: img,
					position: [(o.x != null) ? o.x : 0, (o.y != null) ? o.y : 0],
					scale: (o.scale != null) ? o.scale : [1, 1],
					scroll: (o.scroll != null) ? o.scroll : [1, 1]
				};
				if (animsOut.length > 0) prop.animations = animsOut;
				if (o.alpha != null) prop.alpha = o.alpha;
				props.push(prop);
			}
		var charsOut:Dynamic = {
			bf: {position: (st.boyfriend != null) ? st.boyfriend : [770, 100], cameraOffsets: (st.camera_boyfriend != null) ? st.camera_boyfriend : [0, 0]},
			dad: {position: (st.opponent != null) ? st.opponent : [100, 100], cameraOffsets: (st.camera_opponent != null) ? st.camera_opponent : [0, 0]}
		};
		if (st.hide_girlfriend != true)
			Reflect.setField(charsOut, 'gf', {position: (st.girlfriend != null) ? st.girlfriend : [400, 130], cameraOffsets: (st.camera_girlfriend != null) ? st.camera_girlfriend : [0, 0]});
		return {
			version: '1.0.0',
			name: id,
			cameraZoom: (st.defaultZoom != null) ? st.defaultZoom : 0.9,
			props: props,
			characters: charsOut
		};
	}

	/** Tek bir Psych chart'ını (bir zorluk) V-Slice note/event dizilerine çevirir. */
	static function psychChartDiffToVSlice(song:Dynamic):Dynamic
	{
		var notesOut:Array<Dynamic> = [];
		var eventsOut:Array<Dynamic> = [];
		var speed:Float = (song.speed != null) ? song.speed : 1;

		if (song.notes != null)
			for (sec in (song.notes : Array<Dynamic>))
			{
				if (sec == null || sec.sectionNotes == null) continue;
				for (n in (sec.sectionNotes : Array<Dynamic>))
				{
					if (n == null) continue;
					var lane:Int = Std.int(n[1]);
					var entry:Dynamic = {
						t: n[0],
						d: lane, // Psych: 0-3 oyuncu, 4-7 rakip — V-Slice ile birebir aynı
						l: (n[2] != null) ? n[2] : 0
					};
					if (n[3] != null && Std.isOfType(n[3], String) && Std.string(n[3]).length > 0)
						entry.k = Std.string(n[3]);
					notesOut.push(entry);
				}
			}

		if (song.events != null)
			for (ev in (song.events : Array<Dynamic>))
			{
				if (ev == null || !Std.isOfType(ev, Array)) continue;
				var arr:Array<Dynamic> = cast ev;
				var list:Array<Dynamic> = (arr[1] != null) ? arr[1] : [];
				for (e in list)
				{
					if (e == null) continue;
					var v1:Dynamic = (e.length > 1) ? e[1] : '';
					var v2:Dynamic = (e.length > 2) ? e[2] : '';
					eventsOut.push({t: arr[0], e: Std.string(e[0]), v: [v1, v2]});
				}
			}

		return {notes: notesOut, events: eventsOut, speed: speed};
	}

	/** Psych section'lardan V-Slice timeChanges (BPM haritası) üretir. */
	static function psychBpmChanges(song:Dynamic):Array<Dynamic>
	{
		var startBpm:Float = (song.bpm != null) ? song.bpm : 100;
		var out:Array<Dynamic> = [{t: 0, bpm: startBpm}];
		var curMs:Float = 0;
		var curBpm:Float = startBpm;
		if (song.notes != null)
			for (sec in (song.notes : Array<Dynamic>))
			{
				if (sec == null) continue;
				if (sec.changeBPM == true && sec.bpm != null && sec.bpm != curBpm)
				{
					curBpm = sec.bpm;
					out.push({t: curMs, bpm: curBpm});
				}
				var beats:Float = (sec.sectionBeats != null) ? sec.sectionBeats : 4;
				curMs += beats * (60000.0 / curBpm);
			}
		return out;
	}

	/** Psych modundaki chart dosyalarını bulur: şarkı id -> chart yolları.
	    Düzenler: data/songs/<şarkı>/*.json, songs/<şarkı>/*.json ve
	    klasik Psych: data/<şarkı>/<şarkı>.json + <şarkı>-<zorluk>.json */
	static function findPsychCharts(base:String):Map<String, Array<String>>
	{
		var result:Map<String, Array<String>> = new Map();
		for (root in ['/data/songs/', '/songs/'])
		{
			for (d in listDir(base + root))
			{
				if (result.exists(d)) continue;
				var dir:String = base + root + d + '/';
				if (!FileSystem.isDirectory(dir)) continue;
				var charts:Array<String> = [];
				for (f in listDir(dir))
					if (StringTools.endsWith(f.toLowerCase(), '.json')) charts.push(dir + f);
				if (charts.length > 0) result.set(d, charts);
			}
		}
		// Klasik Psych: data/<şarkı>/<şarkı>.json veya <şarkı>-easy.json vb.
		for (d in listDir(base + '/data/'))
		{
			if (result.exists(d)) continue;
			var dir:String = base + '/data/' + d + '/';
			if (!FileSystem.isDirectory(dir)) continue;
			var dl:String = d.toLowerCase();
			var charts:Array<String> = [];
			for (f in listDir(dir))
			{
				var fl:String = f.toLowerCase();
				if (!StringTools.endsWith(fl, '.json')) continue;
				if (fl == dl + '.json' || StringTools.startsWith(fl, dl + '-'))
					charts.push(dir + f);
			}
			if (charts.length > 0) result.set(d, charts);
		}
		return result;
	}

}

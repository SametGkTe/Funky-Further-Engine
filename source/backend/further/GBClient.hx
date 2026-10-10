package backend.further;

import backend.modpack.DownloadManager;
import haxe.Json;

/**
 * GameBanana apiv11 istemcisi — FNF mod tarayıcı/indirme verisi.
 * Uç noktalar 2026-09-24'te canlı doğrulandı (curl testleri):
 *   - Listeleme: /Mod/Index?_nPage&_nPerpage&_aFilters[Generic_Game]=8694&_sSort=Generic_MostDownloaded
 *   - Profil:    /Mod/<id>/ProfilePage   (->_aFiles[] içinde _sDownloadUrl, _nFilesize, _sMd5Checksum)
 * NOT: Generic_Name arama filtresi "INVALID_FILTER_VALUE" veriyor (değer DSL'i
 * belirsiz) — arama şimdilik istemci tarafı; Faz 2.5'te sunucu tarafına taşınacak.
 */
typedef GBFile =
{
	var id:Float;
	var name:String;
	var url:String;
	var size:Float;
	var md5:String;
	var dlCount:Float;
	var analysis:String;
	var av:String;
}

typedef GBModSummary =
{
	var id:Float;
	var name:String;
	var author:String;
	var category:String;
	var thumbUrl:String;
	var likes:Float;
	var profileUrl:String;
	var version:String;
}

typedef GBModProfile =
{
	var summary:GBModSummary;
	var description:String;
	var text:String;
	var dlCount:Float;
	var files:Array<GBFile>;
}

class GBClient
{
	public static inline var BASE:String = 'https://gamebanana.com/apiv11';
	/** Friday Night Funkin' — _aGame._idRow (canlı doğrulandı). */
	public static inline var FNF_GAME_ROW:Int = 8694;

	static var http:DownloadManager = new DownloadManager();

	/** Sayfa listesi (Popüler = indirmeye göre, Yeni = varsayılan sıra). */
	public static function listMods(page:Int, perPage:Int, popular:Bool, onData:Array<GBModSummary>->Void, onError:String->Void):Void
	{
		var url:String = '$BASE/Mod/Index?_nPage=$page&_nPerpage=$perPage&_aFilters%5BGeneric_Game%5D=$FNF_GAME_ROW';
		if (popular)
			url += '&_sSort=Generic_MostDownloaded';
		http.fetchUrlText(url, function(data:String)
		{
			try
			{
				var root:Dynamic = Json.parse(data);
				if (root == null)
				{
					onError('GameBanana boş yanıt verdi.');
					return;
				}
				var err:Dynamic = Reflect.field(root, '_sErrorCode');
				if (err != null)
				{
					onError('GameBanana hatası: ' + Std.string(err));
					return;
				}
				var records:Array<Dynamic> = cast Reflect.field(root, '_aRecords');
				var out:Array<GBModSummary> = [];
				if (records != null)
					for (r in records)
					{
						var s:GBModSummary = parseSummary(r);
						if (s != null)
							out.push(s);
					}
				onData(out);
			}
			catch (e:Dynamic)
			{
				onError('GameBanana yanıtı okunamadı: ' + Std.string(e));
			}
		}, onError);
	}

	/** Profil + dosya listesi (indirme URL'i için). */
	public static function getProfile(id:Float, onData:GBModProfile->Void, onError:String->Void):Void
	{
		var url:String = '$BASE/Mod/${Std.int(id)}/ProfilePage';
		http.fetchUrlText(url, function(data:String)
		{
			try
			{
				var root:Dynamic = Json.parse(data);
				if (root == null)
				{
					onError('GameBanana boş yanıt verdi.');
					return;
				}
				var err:Dynamic = Reflect.field(root, '_sErrorCode');
				if (err != null)
				{
					onError('GameBanana hatası: ' + Std.string(err));
					return;
				}
				var files:Array<GBFile> = [];
				var rawFiles:Array<Dynamic> = cast Reflect.field(root, '_aFiles');
				if (rawFiles != null)
					for (f in rawFiles)
					{
						var gf:GBFile = parseFile(f);
						if (gf != null)
							files.push(gf);
					}

				var summary:GBModSummary = parseSummary(root);
				var profile:GBModProfile = {
					summary: summary,
					description: str(Reflect.field(root, '_sDescription')),
					text: str(Reflect.field(root, '_sText')),
					dlCount: num(Reflect.field(root, '_nDownloadCount')),
					files: files
				};
				onData(profile);
			}
			catch (e:Dynamic)
			{
				onError('GameBanana profili okunamadı: ' + Std.string(e));
			}
		}, onError);
	}

	/**
	 * İndirilecek dosyayı seç: GB analizi temiz (ok/clean) olanları tercih et,
	 * eşitlikte en çok indirileni al. Hiçbiri temiz değilse en çok indirileni
	 * "dikkat" notuyla ver.
	 */
	public static function pickFile(profile:GBModProfile):Null<GBFile>
	{
		if (profile == null || profile.files == null || profile.files.length == 0)
			return null;
		var best:GBFile = null;
		var bestClean:Bool = false;
		for (f in profile.files)
		{
			var clean:Bool = (f.analysis == 'ok' || f.analysis == '') && (f.av == 'clean' || f.av == '');
			if (best == null)
			{
				best = f;
				bestClean = clean;
				continue;
			}
			if (clean && !bestClean)
			{
				best = f;
				bestClean = true;
			}
			else if (clean == bestClean && f.dlCount > best.dlCount)
			{
				best = f;
			}
		}
		return best;
	}

	// ______________________________ ayrıştırma ______________________________

	static function parseSummary(r:Dynamic):Null<GBModSummary>
	{
		if (r == null)
			return null;
		var id:Float = num(Reflect.field(r, '_idRow'));
		var name:String = str(Reflect.field(r, '_sName'));
		if (id <= 0 || name.length == 0)
			return null;

		var author:String = '';
		var submitter:Dynamic = Reflect.field(r, '_aSubmitter');
		if (submitter != null)
			author = str(Reflect.field(submitter, '_sName'));

		var category:String = '';
		var cat:Dynamic = Reflect.field(r, '_aRootCategory');
		if (cat != null)
			category = str(Reflect.field(cat, '_sName'));

		return {
			id: id,
			name: name,
			author: author,
			category: category,
			thumbUrl: parseThumb(r),
			likes: num(Reflect.field(r, '_nLikeCount')),
			profileUrl: str(Reflect.field(r, '_sProfileUrl')),
			version: str(Reflect.field(r, '_sVersion'))
		};
	}

	static function parseFile(f:Dynamic):Null<GBFile>
	{
		if (f == null)
			return null;
		var url:String = str(Reflect.field(f, '_sDownloadUrl'));
		var name:String = str(Reflect.field(f, '_sFile'));
		if (url.length == 0)
			return null;
		return {
			id: num(Reflect.field(f, '_idRow')),
			name: (name.length > 0) ? name : ('file_' + Std.int(num(Reflect.field(f, '_idRow'))) + '.zip'),
			url: url,
			size: num(Reflect.field(f, '_nFilesize')),
			md5: str(Reflect.field(f, '_sMd5Checksum')),
			dlCount: num(Reflect.field(f, '_nDownloadCount')),
			analysis: str(Reflect.field(f, '_sAnalysisResult')),
			av: str(Reflect.field(f, '_sAvResult'))
		};
	}

	static function parseThumb(r:Dynamic):String
	{
		var media:Dynamic = Reflect.field(r, '_aPreviewMedia');
		if (media == null)
			return '';
		var images:Array<Dynamic> = cast Reflect.field(media, '_aImages');
		if (images == null || images.length == 0)
			return '';
		var img:Dynamic = images[0];
		var base:String = str(Reflect.field(img, '_sBaseUrl'));
		var file:String = str(Reflect.field(img, '_sFile530'));
		if (file.length == 0)
			file = str(Reflect.field(img, '_sFile220'));
		if (file.length == 0)
			file = str(Reflect.field(img, '_sFile'));
		if (base.length == 0 || file.length == 0)
			return '';
		return base + '/' + file;
	}

	static function str(v:Dynamic):String
	{
		return (v == null) ? '' : Std.string(v);
	}

	static function num(v:Dynamic):Float
	{
		if (v == null)
			return 0;
		var n:Null<Float> = Std.parseFloat(Std.string(v));
		return (n == null || Math.isNaN(n)) ? 0 : n;
	}
}

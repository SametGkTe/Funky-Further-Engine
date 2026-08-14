package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import openfl.display.BitmapData;
import backend.modpack.ModpackTier;

class ModpackCard extends FlxSpriteGroup
{
	public var packId:String;
	public var packName:String;
	public var tierColor:Int = 0xFF888888;
	public var tierLabel:String = "";
	public var sizeLabel:String = "";
	public var downloadCountText:String = "";

	public var bg:FlxSprite;
	public var thumb:FlxSprite;
	public var thumbFallback:FlxText;
	public var tierText:FlxText;
	public var sizeText:FlxText;
	public var nameText:FlxText;
	public var dlBg:FlxSprite;
	public var dlText:FlxText;
	public var linkBg:FlxSprite;
	public var linkText:FlxText;

	public var selected:Bool = false;
	public var cardIndex:Int = 0;

	var dlCountText:FlxText;

	// Callback'ler (store tarafından set edilir)
	public var onDownloadPress:Void->Void = null;
	public var onLinkPress:Void->Void = null;

	var _cardW:Int;
	var _cardH:Int;
	var _thumbH:Int;
	var _btnVisible:Bool = false;
	var _prevSelected:Bool = false;

	public function new(mp:Dynamic, index:Int, x:Float, y:Float, cardW:Int, cardH:Int)
	{
		super(x, y);

		_cardW = cardW;
		_cardH = cardH;
		_thumbH = Std.int(cardH - 52);

		packId = mp.id != null ? Std.string(mp.id) : "?";
		packName = mp.displayName != null ? Std.string(mp.displayName) : packId;
		cardIndex = index;

		var tierId:String = mp.tier != null ? Std.string(mp.tier) : packId;
		tierColor = ModpackTier.colorFor(tierId);
		tierLabel = ModpackTier.labelFor(tierId);
		sizeLabel = mp.fileSize != null ? Std.string(mp.fileSize) : "";

		bg = new FlxSprite();
		bg.makeGraphic(cardW, cardH, FlxColor.BLACK);
		bg.alpha = 0.7;
		add(bg);

		thumb = new FlxSprite(6, 6);
		thumb.makeGraphic(cardW - 12, _thumbH - 6, 0xFF111111);
		add(thumb);

		thumbFallback = new FlxText(6, 6, cardW - 12, "", 11);
		thumbFallback.setFormat("VCR OSD Mono", 11, 0xFF4B5563, CENTER);
		thumbFallback.y = 6 + Std.int((_thumbH - 6) / 2) - 8;
		thumbFallback.visible = false;
		add(thumbFallback);

		tierText = new FlxText(10, 10, Std.int(cardW * 0.5), tierLabel, 13);
		tierText.setFormat("VCR OSD Mono", 13, FlxColor.WHITE, LEFT);
		tierText.borderStyle = OUTLINE;
		tierText.borderColor = 0xFF000000;
		tierText.borderSize = 1.2;
		add(tierText);

		// ── Boyut etiketi (üst sağ) ──
		sizeText = new FlxText(0, 10, Std.int(cardW * 0.48), sizeLabel, 13);
		sizeText.setFormat("VCR OSD Mono", 13, 0xFFDDDDDD, RIGHT);
		sizeText.borderStyle = OUTLINE;
		sizeText.borderColor = 0xFF000000;
		sizeText.borderSize = 1.2;
		sizeText.x = cardW - sizeText.width - 10;
		add(sizeText);

		// ── İsim (alt, ortalanmış) ──
		nameText = new FlxText(4, _thumbH + 2, cardW - 8, packName, 18);
		nameText.setFormat("VCR OSD Mono", 18, FlxColor.WHITE, CENTER);
		nameText.borderStyle = OUTLINE;
		nameText.borderColor = 0xFF000000;
		nameText.borderSize = 1.2;
		nameText.y = _thumbH + 2;
		add(nameText);

	// ── İndirme sayısı rozeti (alt sağ, ismin altında) ──
	// (dlCountText field'ı class gövdesinde tanımlıdır — constructor içinde değil)

	function createDownloadCount():Void
	{
		dlCountText = new FlxText(6, _thumbH + 22, Std.int(_cardW * 0.62), downloadCountText, 10);
		dlCountText.setFormat("VCR OSD Mono", 10, 0xFF94A3B8, LEFT);
		dlCountText.borderStyle = OUTLINE;
		dlCountText.borderColor = 0xFF000000;
		dlCountText.borderSize = 1.1;
		add(dlCountText);
	}

		// ── Butonlar (alt sağ; seçiliyken görünür) ──
		var btnW:Int = 52;
		var btnH:Int = 32;
		var btnY:Float = _thumbH + 18;

		linkBg = new FlxSprite(cardW - btnW - 6, btnY);
		linkBg.makeGraphic(btnW, btnH, FlxColor.BLACK);
		linkBg.alpha = 0.7;
		linkBg.visible = false;
		add(linkBg);

		linkText = new FlxText(linkBg.x, btnY + 6, btnW, "LINK", 12);
		linkText.setFormat("VCR OSD Mono", 12, FlxColor.WHITE, CENTER);
		linkText.visible = false;
		add(linkText);

		dlBg = new FlxSprite(cardW - btnW * 2 - 10, btnY);
		dlBg.makeGraphic(btnW, btnH, FlxColor.BLACK);
		dlBg.alpha = 0.7;
		dlBg.visible = false;
		add(dlBg);

		dlText = new FlxText(dlBg.x, btnY + 6, btnW, "İNDİR", 12);
		dlText.setFormat("VCR OSD Mono", 12, FlxColor.WHITE, CENTER);
		dlText.visible = false;
		add(dlText);

		createDownloadCount();
	}

	/** Store tarafından cache'ten okunan thumbnail dosyasını uygular. */
	public function applyThumbFromFile(path:String):Void
	{
		#if sys
		try
		{
			var bytes:haxe.io.Bytes = sys.io.File.getBytes(path);
			// OpenFL 9: BitmapData.loadFromBytes bir Future döndürür (async)
			var future = BitmapData.loadFromBytes(bytes);
			future.onComplete(function(bmp:BitmapData) {
				if (exists)
					applyThumbBitmap(bmp, path);
			});
		}
		catch (e:Dynamic)
		{
			showFallback("GÖRSEL YOK");
		}
		#else
		showFallback("GÖRSEL YOK");
		#end
	}

	public function applyThumbBitmap(bmp:BitmapData, ?path:String):Void
	{
		if (bmp == null)
		{
			showFallback("GÖRSEL YOK");
			return;
		}

		try
		{
			thumb.loadGraphic(bmp);
			var fitW:Int = _cardW - 12;
			var fitH:Int = _thumbH - 6;
			thumb.setGraphicSize(fitW, fitH);
			thumb.updateHitbox();
			thumb.antialiasing = true;
			thumb.visible = true;
			thumbFallback.visible = false;
		}
		catch (e:Dynamic)
		{
			showFallback("GÖRSEL OKUNAMADI");
		}
	}

	public function showFallback(text:String):Void
	{
		thumbFallback.text = text;
		thumbFallback.visible = true;
		thumb.visible = false;
	}

	public function setDownloadCount(count:Int):Void
	{
		downloadCountText = "⬇ " + formatNumber(count);
		if (dlCountText != null)
			dlCountText.text = downloadCountText;
	}

	static function formatNumber(n:Int):String
	{
		var s:String = Std.string(Math.max(0, n));
		var out:String = "";
		var count:Int = 0;
		for (i in (s.length - 1)...-1)
		{
			out = s.charAt(i) + out;
			count++;
			if (count % 3 == 0 && i > 0) out = "." + out;
		}
		return out;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Hover: fare kartın üzerindeyse hafif aydınlat
		var hovered:Bool = FlxG.mouse.overlaps(bg);
		bg.alpha = hovered ? 0.85 : (selected ? 0.85 : 0.7);

		if (_prevSelected != selected)
		{
			_prevSelected = selected;
			_btnVisible = selected;
			dlBg.visible = selected;
			dlText.visible = selected;
			linkBg.visible = selected;
			linkText.visible = selected;
		}

		if (_btnVisible)
		{
			if (FlxG.mouse.overlaps(dlBg))
			{
				dlBg.scale.set(FlxMath.lerp(dlBg.scale.x, 1.18, elapsed * 12), FlxMath.lerp(dlBg.scale.y, 1.18, elapsed * 12));
				if (FlxG.mouse.justPressed && onDownloadPress != null)
					onDownloadPress();
			}
			else
			{
				dlBg.scale.set(FlxMath.lerp(dlBg.scale.x, 1, elapsed * 12), FlxMath.lerp(dlBg.scale.y, 1, elapsed * 12));
			}

			if (FlxG.mouse.overlaps(linkBg))
			{
				linkBg.scale.set(FlxMath.lerp(linkBg.scale.x, 1.18, elapsed * 12), FlxMath.lerp(linkBg.scale.y, 1.18, elapsed * 12));
				if (FlxG.mouse.justPressed && onLinkPress != null)
					onLinkPress();
			}
			else
			{
				linkBg.scale.set(FlxMath.lerp(linkBg.scale.x, 1, elapsed * 12), FlxMath.lerp(linkBg.scale.y, 1, elapsed * 12));
			}
		}
	}
}

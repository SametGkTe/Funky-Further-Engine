package backend.further;

/**
 * Texture Pack sistemi — veri tipleri.
 * Tasarım dokümanı: docs/FURTHER_LIBRARY_DESIGN_TR.md (§2)
 */
typedef TexturePackManifest = {
	var id:String;
	var name:String;
	@:optional var author:String;
	@:optional var version:String;
	@:optional var description:String;
	@:optional var thumbnail:String;
	@:optional var accentColor:String;
	@:optional var minFurtherVersion:String;
	@:optional var sections:Array<String>;
	@:optional var tags:Array<String>;
}

typedef TexturePackThemeColors = {
	@:optional var accent:String;
	@:optional var background:String;
	@:optional var text:String;
}

typedef TexturePackTheme = {
	@:optional var colors:TexturePackThemeColors;
	/** "vcr.ttf": "fonts/Ozel.ttf" veya "default": "fonts/Ozel.ttf" (vcr.ttf eş anlamlısı) */
	@:optional var fonts:Dynamic;
	/** Menü müziği (freakyMenu yerine geçer). Uzantı yazılmasa da olur. */
	@:optional var menuMusic:String;
}

typedef TexturePackStackEntry = {
	var id:String;
	@:optional var enabled:Bool;
}

typedef TexturePackStackConfig = {
	@:optional var stack:Array<TexturePackStackEntry>;
}

/** Taranmış bir texture pack. */
class TexturePack
{
	public var id:String;
	/** Paket kökü — '/' ile biter. */
	public var root:String;
	public var manifest:TexturePackManifest;
	public var theme:TexturePackTheme;

	public function new(id:String, root:String, manifest:TexturePackManifest, theme:TexturePackTheme)
	{
		this.id = id;
		this.root = root;
		this.manifest = manifest;
		this.theme = theme;
	}

	public var displayName(get, never):String;
	function get_displayName():String
		return (manifest != null && manifest.name != null && manifest.name.length > 0) ? manifest.name : id;

	public var author(get, never):String;
	function get_author():String
		return (manifest != null && manifest.author != null) ? manifest.author : 'bilinmiyor';

	public var version(get, never):String;
	function get_version():String
		return (manifest != null && manifest.version != null) ? manifest.version : '1.0.0';

	public var description(get, never):String;
	function get_description():String
		return (manifest != null && manifest.description != null) ? manifest.description : '';
}

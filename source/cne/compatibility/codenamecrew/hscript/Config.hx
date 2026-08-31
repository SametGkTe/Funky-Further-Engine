package cne.compatibility.codenamecrew.hscript;

class Config {
	// Runs support for custom classes in these
	public static final ALLOWED_CUSTOM_CLASSES = [
		"flixel",
		"funkin"
	];

	// Runs support for abstract support in these
	public static final ALLOWED_ABSTRACT_AND_ENUM = [
		"sys.thread",
		"flixel.text",
		"flixel.math",
		"flixel.util",
		"openfl.display.BlendMode",
		"haxe.xml",
	];

	// Incase any of your files fail
	// These are the module names
	public static final DISALLOW_CUSTOM_CLASSES = [
	// Flixel-UI core classes
	"flixel.addons.ui.FlxUI",
	"flixel.addons.ui.FlxUIState",
	"flixel.addons.ui.FlxUISubState",
	"flixel.addons.ui.FlxUITypedButton",
	"flixel.addons.ui.FlxUIButton",
	"flixel.addons.ui.FlxUICheckBox",
	"flixel.addons.ui.FlxUIDropDownMenu",
	"flixel.addons.ui.FlxUIInputText",
	"flixel.addons.ui.FlxUINumericStepper",
	"flixel.addons.ui.FlxUIRadioGroup",
	"flixel.addons.ui.FlxUISlider",
	"flixel.addons.ui.FlxUITabMenu",
	"flixel.addons.ui.FlxUIText",
	"flixel.addons.ui.FlxUISprite",
	"flixel.addons.ui.FlxUI9SliceSprite",
	"flixel.addons.ui.FlxUITileSprite",
	"flixel.addons.ui.FlxUIList",
	"flixel.addons.ui.FlxUICursor",

	// Flixel-UI component classes
	"flixel.addons.ui.interfaces.IFlxUIWidget",
	"flixel.addons.ui.interfaces.IFlxUIButton",
	"flixel.addons.ui.interfaces.IEventGetter",
	"flixel.addons.ui.interfaces.IFlxUIClickable",
	"flixel.addons.ui.interfaces.IFlxUIState",
];

	public static final DISALLOW_ABSTRACT_AND_ENUM = [

	];
}
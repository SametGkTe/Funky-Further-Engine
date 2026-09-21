package options;

typedef Keybind = {
	keyboard:String,
	gamepad:String
}

enum OptionType {
	BOOL;
	INT;
	FLOAT;
	PERCENT;
	STRING;
	KEYBIND;
	DROPDOWN;
	OPEN;
}

class Option
{
	public var child:Alphabet;
	public var text(get, set):String;
	public var onChange:Void->Void = null;
	public var onOpen:Void->Void = null;
	public var type:OptionType = BOOL;
	public var scrollSpeed:Float = 50;
	public var variable(default, null):String = null;
	public var defaultValue:Dynamic = null;
	public var curOption:Int = 0;
	public var options:Array<String> = null;
	public var changeValue:Dynamic = 1;
	public var minValue:Dynamic = null;
	public var maxValue:Dynamic = null;
	public var decimals:Int = 1;
	public var displayFormat:String = '%v';
	public var description:String = '';
	public var name:String = 'Unknown';
	public var defaultKeys:Keybind = null;
	public var keys:Keybind = null;
	public var dropdownLabels:Array<String> = null;
	public var dropdownIcons:Array<String> = null;
	public var displayOptions:Array<String> = null;

	public function new(name:String, description:String = '', variable:String, type:OptionType = BOOL, ?options:Array<String> = null, ?translation:String = null)
	{
		_name = name;
		_translationKey = translation != null ? translation : _name;
		this.name = Language.getPhrase('setting_$_translationKey', name);
		this.description = Language.getPhrase('description_$_translationKey', description);
		this.variable = variable;
		this.type = type;
		this.options = options;

		if(this.type != KEYBIND && this.type != OPEN) this.defaultValue = Reflect.getProperty(ClientPrefs.defaultData, variable);
		switch(type)
		{
			case BOOL:
				if(defaultValue == null) defaultValue = false;
			case INT, FLOAT:
				if(defaultValue == null) defaultValue = 0;
			case PERCENT:
				if(defaultValue == null) defaultValue = 1;
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
			case STRING:
				if(options.length > 0)
					defaultValue = options[0];
				if(defaultValue == null)
					defaultValue = '';
			case DROPDOWN:
				if(options != null && options.length > 0)
					defaultValue = options[0];
				if(defaultValue == null)
					defaultValue = '';
			case OPEN:
				defaultValue = null;
			case KEYBIND:
				defaultValue = '';
				defaultKeys = {gamepad: 'NONE', keyboard: 'NONE'};
				keys = {gamepad: 'NONE', keyboard: 'NONE'};
		}

		if(type != OPEN)
		{
			try
			{
				if(getValue() == null)
					setValue(defaultValue);
				switch(type)
				{
					case STRING:
						var num:Int = options.indexOf(getValue());
						if(num > -1) curOption = num;
					case DROPDOWN:
						var num:Int = options.indexOf(getValue());
						if(num > -1) curOption = num;
					default:
				}
			}
			catch(e) {}
		}
	}

	public function change()
	{
		if(onChange != null)
			onChange();
	}

	dynamic public function getValue():Dynamic
	{
		if(type == OPEN) return '';
		var value = Reflect.getProperty(ClientPrefs.data, variable);
		if(type == KEYBIND) return !Controls.instance.controllerMode ? value.keyboard : value.gamepad;
		return value;
	}

	dynamic public function setValue(value:Dynamic)
	{
		if(type == OPEN) return value;
		if(type == KEYBIND)
		{
			var keys = Reflect.getProperty(ClientPrefs.data, variable);
			if(!Controls.instance.controllerMode) keys.keyboard = value;
			else keys.gamepad = value;
			return value;
		}
		return Reflect.setProperty(ClientPrefs.data, variable, value);
	}

	var _name:String = null;
	var _text:String = null;
	var _translationKey:String = null;
	private function get_text()
		return _text;

	private function set_text(newValue:String = '')
	{
		if(child != null)
		{
			_text = newValue;
			var fallback:String = _text;
			if((type == STRING || type == DROPDOWN) && displayOptions != null && options != null)
			{
				var idx:Int = options.indexOf(getValue());
				if(idx > -1 && idx < displayOptions.length)
					fallback = displayOptions[idx];
			}
			child.text = Language.getPhrase('setting_$_translationKey-${getValue()}', fallback);
			return _text;
		}
		return null;
	}
}

package backend.ui;

import backend.ui.PsychUIBox.UIStyleData;

class PsychUIButton extends FlxSpriteGroup
{
	public static final CLICK_EVENT = 'button_click';

	public var name:String;
	public var label(default, set):String;
	public var bg:FlxSprite;
	public var text:FlxText;

	public var onChangeState:String->Void;
	public var onClick:Void->Void;
	
	// MODERN PALET: koyu slate taban + mavi vurgu
	public static inline var ACCENT:Int = 0xFF4D7DFB;
	public static inline var ACCENT_LIGHT:Int = 0xFF7FA6FF;
	public static inline var SURFACE:Int = 0xFF26272E;

	public var clickStyle:UIStyleData = {
		bgColor: ACCENT_LIGHT,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var hoverStyle:UIStyleData = {
		bgColor: ACCENT,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var normalStyle:UIStyleData = {
		bgColor: SURFACE,
		textColor: FlxColor.WHITE,
		bgAlpha: 0.92
	};

	public function new(x:Float = 0, y:Float = 0, label:String = '', ?onClick:Void->Void = null, ?wid:Int = 80, ?hei:Int = 20)
	{
		super(x, y);
		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		add(bg);
		bg.color = SURFACE;
		bg.alpha = 0.92;

		text = new FlxText(0, 0, 1, '');
		text.setFormat(Paths.font('vcr.ttf'), 9, FlxColor.WHITE, CENTER);
		text.bold = true;
		text.alignment = CENTER;
		add(text);
		resize(wid, hei);
		this.label = label;
		
		this.onClick = onClick;
		forceCheckNext = true;
	}

	public var isClicked:Bool = false;
	public var forceCheckNext:Bool = false;
	public var broadcastButtonEvent:Bool = true;
	var _firstFrame:Bool = true;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(_firstFrame)
		{
			bg.color = normalStyle.bgColor;
			bg.alpha = normalStyle.bgAlpha;
			text.color = normalStyle.textColor;
			_firstFrame = false;
		}
		
		if(isClicked && FlxG.mouse.released)
		{
			forceCheckNext = true;
			isClicked = false;
		}

		if(forceCheckNext || FlxG.mouse.justMoved || FlxG.mouse.justPressed)
		{
			var overlapped:Bool = (FlxG.mouse.overlaps(bg, camera));

			forceCheckNext = false;

			if(!isClicked)
			{
				var style:UIStyleData = (overlapped) ? hoverStyle : normalStyle;
				bg.color = style.bgColor;
				bg.alpha = style.bgAlpha;
				text.color = style.textColor;
			}

			if(overlapped && FlxG.mouse.justPressed)
			{
				isClicked = true;
				bg.color = clickStyle.bgColor;
				bg.alpha = clickStyle.bgAlpha;
				text.color = clickStyle.textColor;
				if(onClick != null) onClick();
				if(broadcastButtonEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
			}
		}
	}

	public function resize(width:Int, height:Int)
	{
		bg.setGraphicSize(width, height);
		bg.updateHitbox();
		text.fieldWidth = width;
		text.x = bg.x;
		text.y = bg.y + height/2 - text.height/2;
	}

	function set_label(v:String)
	{
		if(text != null && text.exists) text.text = v;
		return (label = v);
	}
}
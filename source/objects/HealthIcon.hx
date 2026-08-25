package objects;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isPlayer:Bool = false;
	private var char:String = '';

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String, ?allowGPU:Bool = true) {
		#if MODS_ALLOWED
		// CODENAME ENGINE KÖPRÜSÜ: CNE karakter XML'indeki icon attribute'u
		// karakter adından farklı olabiliyor; varsa onu kullan.
		var cneIcon:String = cne.compatibility.CNECharacterConverter.resolveIconName(char);
		if (cneIcon != null && cneIcon.length > 0) char = cneIcon;
		#end
		if(this.char != char) {
			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
			// CODENAME ENGINE KÖPRÜSÜ: CNE ikonları klasör düzeninde tutar:
			// images/icons/<icon>/icon.png (veya ikon0/ikon1).
			if(!Paths.fileExists('images/' + name + '.png', IMAGE) && Paths.fileExists('images/icons/$char/icon.png', IMAGE))
				name = 'icons/$char/icon';
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) {
				trace('[HealthIcon] "$char" için ikon bulunamadı, face kullanılacak');
				name = 'icons/icon-face'; //Prevents crash from missing icon
			}
			
			var graphic = Paths.image(name, allowGPU);
			var iSize:Float = Math.round(graphic.width / graphic.height);
			loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;
			updateHitbox();

			animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			if(char.endsWith('-pixel'))
				antialiasing = false;
			else
				antialiasing = ClientPrefs.data.antialiasing;
		}
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		if(autoAdjustOffset)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}

	public function getCharacter():String {
		return char;
	}
}

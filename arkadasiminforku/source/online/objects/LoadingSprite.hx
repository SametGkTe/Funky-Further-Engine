package online.objects;

import flixel.FlxBasic;
import openfl.geom.Point;
import openfl.geom.Rectangle;

class LoadingSprite extends FlxTypedGroup<FlxBasic> {
    var loadBar:FlxSprite;
    var tasksLength:Float = 0;

	public function new(?tasksLength:Float, ?camera:FlxCamera) {
        super();
        
	// P.E.T Yükleme Ekranı
	var loadingImagePath:String = 'funkay';
	if (ClientPrefs.data.petloadingscreen) {
		var folderName:String = '';
		switch (ClientPrefs.data.petloadingscreenimage.toUpperCase()) {
			case 'V1':
				folderName = 'V1';
			case 'V2':
				folderName = 'V2'; // ben malım.
			default:
				folderName = 'online';
			case 'V2U':
				folderName = 'V2U';
		}
    
		var randomNum:Int = FlxG.random.int(1, 5);
		loadingImagePath = 'pet/petscreens/' + folderName + '/loadingscreen' + randomNum;
	}

	var funkay = new FlxSprite();
	var funkayGraphic = Paths.image(loadingImagePath, null, false).bitmap;
	funkay.makeGraphic(FlxG.width, FlxG.height, funkayGraphic.getPixel32(0, 0), true, "_funkay");		funkayGraphic.image.resize(Std.int(funkayGraphic.image.width * (FlxG.height / funkayGraphic.image.height)), FlxG.height);
	funkay.graphic.bitmap.copyPixels(funkayGraphic, new Rectangle(0, 0, funkay.graphic.bitmap.width, funkay.graphic.bitmap.height),
	new Point(FlxG.width / 2 - funkayGraphic.image.width / 2, 0));
	funkay.antialiasing = ClientPrefs.data.antialiasing;
	add(funkay);

		loadBar = new FlxSprite(0, FlxG.height - 20).makeGraphic(FlxG.width, 10, 0xFFff16d2);
		loadBar.scale.x = 0;
		loadBar.visible = false;
		loadBar.screenCenter(X);
        add(loadBar);

		if (camera != null)
			cameras = [camera];

		this.tasksLength = tasksLength;
    }

    public function addProgress(remaining:Float) {
		loadBar.scale.x += 0.5 * (FlxMath.remapToRange(remaining / tasksLength, 1, 0, 0, 1) - loadBar.scale.x);
        loadBar.visible = true;
    }
}
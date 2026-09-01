@echo off
cd /d "%~dp0"
echo ==================================================
echo  TANI - eski referans taramasi
echo ==================================================
echo.
echo [1] ESKI: "hscript.IHScriptCustomClassBehaviour" importlari:
findstr /s /i /n /c:"import hscript.IHScriptCustomClassBehaviour" source\*.hx
findstr /s /i /n /c:"import cne.compatibility.hscript" source\*.hx
echo    (ustte satir yoksa = TEMIZ)
echo.
echo [2] ESKI: "codenamecrew.hscript" (on eksiz) paketleri:
findstr /s /i /n /c:"package codenamecrew" source\*.hx
findstr /s /i /n /c:"import codenamecrew.hscript" source\*.hx
echo    (ustte satir yoksa = TEMIZ)
echo.
echo [3] Yeni lib yerinde mi?
if exist "source\cne\compatibility\codenamecrew\hscript\Interp.hx" (echo   Interp.hx: VAR) else (echo   Interp.hx: YOK - zip'i repo kokune cikar!)
if exist "source\cne\compatibility\codenamecrew\hscript\IHScriptCustomClassBehaviour.hx" (echo   IHScriptCustomClassBehaviour.hx: VAR) else (echo   IHScriptCustomClassBehaviour.hx: YOK - paket guncel degil!)
echo.
echo [4] PlayState importlari:
findstr /n /c:"HScript.ScriptPack" source\states\PlayState.hx
findstr /n /c:"StrumLineCompat.StrumLineCompatMember" source\states\PlayState.hx
echo.
echo [5] Project.xml macro yollari:
findstr /n /c:"cne.compatibility.codenamecrew" Project.xml
echo.
echo [6] ESKI: psychlua importu HScript.hx icinde olmamali (v5+):
findstr /n /i /c:"psychlua" source\funkin\backend\scripting\HScript.hx
findstr /n /c:"globalCallbacks" source\funkin\backend\scripting\HScript.hx
echo    (ilk satir yoksa, ikinci satir VAR ise = TEMIZ; dosya guncel)
echo.
echo [7] ESKI: hardcoded macro paket yolu (ClassExtendMacro):
findstr /s /n /c:"pack: [\"hscript\"]" source\cne\compatibility\codenamecrew\hscript\*.hx
echo    (ustte satir yoksa = TEMIZ)
echo.
echo [8] V-Slice .hxc destegi (v6+):
findstr /n /c:"polymod" Project.xml
findstr /n /c:"POLYMOD_ALLOWED" Project.xml
if exist "source\vslice\scripting\VSScriptRegistry.hx" (echo   VSScriptRegistry.hx: VAR) else (echo   VSScriptRegistry.hx: YOK - zip'i repo kokune cikar!)
if exist "source\funkin\play\character\SparrowCharacter.hx" (echo   funkin shim'i: VAR) else (echo   funkin shim'i: YOK - paket guncel degil!)
if exist "source\vslice\scripting\ScriptedSong.hx" (echo   ScriptedSong.hx: VAR) else (echo   ScriptedSong.hx: YOK - v8 gerekli!)
if exist "source\funkin\play\song\Song.hx" (echo   funkin song shim'i: VAR) else (echo   funkin song shim'i: YOK - v8 gerekli!)
if exist "source\vslice\scripting\ScriptedModule.hx" (echo   ScriptedModule.hx: VAR) else (echo   ScriptedModule.hx: YOK - v9 gerekli!)
if exist "source\funkin\modding\module\Module.hx" (echo   funkin module shim'i: VAR) else (echo   funkin module shim'i: YOK - v9 gerekli!)
if exist "source\vslice\scripting\ScriptedFunkinSprite.hx" (echo   ScriptedFunkinSprite.hx: VAR) else (echo   ScriptedFunkinSprite.hx: YOK - v9 gerekli!)
if exist "source\funkin\graphics\FunkinSprite.hx" (echo   funkin sprite shim'i: VAR) else (echo   funkin sprite shim'i: YOK - v9 gerekli!)
if exist "assets\scripts\DemoBf.hxc" (echo   DemoBf.hxc: VAR) else (echo   DemoBf.hxc: YOK - opsiyonel)
if exist "assets\scripts\DemoMilf.hxc" (echo   DemoMilf.hxc: VAR) else (echo   DemoMilf.hxc: YOK - opsiyonel)
if exist "assets\scripts\DemoModule.hxc" (echo   DemoModule.hxc: VAR) else (echo   DemoModule.hxc: YOK - opsiyonel)
echo    (polymod satiri + POLYMOD_ALLOWED + dosyalar VAR olmali)
echo [9] Polymod VENDORED kontrol (v10.1+):
if exist "source\polymod\Polymod.hx" (echo   source\polymod: VAR - vendored OK) else (echo   source\polymod: YOK - zip'i repo kokune cikar!)
if exist "source\polymod\hscript\_internal\Interp.hx" (echo   Interp.hx motoru: VAR) else (echo   Interp.hx motoru: YOK - v2.0.0 vendored gerekli!)
findstr /n /c:"<haxelib name=" Project.xml
echo    (Ustteki TUM haxelib satirlari; iclerinde polymod OLMAMALI - vendored kullaniyoruz)
findstr /n /c:"thx.semver" Project.xml
findstr /n /c:"jsonpatch" Project.xml
echo    (thx.semver + jsonpatch satirlari GORUNMELI)
echo.
echo [10] v12 dosyalari (FNF scriptClass + state shim'leri):
if exist "source\funkin\ui\MusicBeatState.hx" (echo   funkin.ui.MusicBeatState: VAR) else (echo   funkin.ui.MusicBeatState: YOK - v12 gerekli!)
if exist "source\funkin\ui\MusicBeatSubState.hx" (echo   funkin.ui.MusicBeatSubState: VAR) else (echo   funkin.ui.MusicBeatSubState: YOK - v12 gerekli!)
if exist "source\vslice\scripting\ScriptedMusicBeatState.hx" (echo   ScriptedMusicBeatState: VAR) else (echo   ScriptedMusicBeatState: YOK - v12 gerekli!)
if exist "source\vslice\scripting\ScriptedMusicBeatSubState.hx" (echo   ScriptedMusicBeatSubState: VAR) else (echo   ScriptedMusicBeatSubState: YOK - v12 gerekli!)
findstr /n /c:"scriptClass" source\vslice\compatibility\VSliceCharacterConverter.hx
echo.
echo [11] v13 dosyalari (DCE kapali + olay/sahne shim'leri):
findstr /n /c:"-dce" Project.xml
findstr /n /c:"include('funkin'" Project.xml
findstr /n /c:"include('vslice.scripting'" Project.xml
echo    (Ustte -dce no + 2 include satiri GORUNMELI)
if exist "source\funkin\play\stage\Stage.hx" (echo   funkin.play.stage.Stage: VAR) else (echo   funkin.play.stage.Stage: YOK - v13 gerekli!)
if exist "source\funkin\play\event\ScriptedSongEvent.hx" (echo   ScriptedSongEvent: VAR) else (echo   ScriptedSongEvent: YOK - v13 gerekli!)
if exist "source\funkin\modding\base\ScriptedMusicBeatState.hx" (echo   funkin.modding.base.ScriptedMusicBeatState: VAR) else (echo   ScriptedMusicBeatState: YOK - v13 gerekli!)
findstr /n /c:"prepare()" source\backend\PolymodHandler.hx
findstr /n /c:"v13 akisi" source\backend\PolymodHandler.hx
echo    (Ustte 2 satir GORUNMELI: prepare() + v13 akisi izi)
echo.
echo [12] v13.2 dosyalari (CNE makro korumasi + EventMacro zinciri):
findstr /n /c:"hasRecycleInSuper" source\macros\EventMacro.hx
findstr /n /c:"super.recycle()" source\macros\EventMacro.hx
findstr /n /c:"@:access(flixel.graphics.FlxGraphic)" source\funkin\backend\assets\MultiFramesCollection.hx
findstr /s /n /c:"@:noCustomClass" source\funkin\ui\*.hx source\funkin\play\*.hx source\funkin\modding\*.hx 2>nul
echo    (Ustte: hasRecycleInSuper + super.recycle + FlxGraphic access + noCustomClass'lar GORUNMELI)
echo.
echo [13] v14 dosyalari (tam-yol extend duzeltmesi + FNF shim'leri):
findstr /n /c:"lastSegment" source\polymod\hscript\_internal\Interp.hx
findstr /n /c:"funkin.Paths" source\vslice\scripting\VSScriptRegistry.hx
if exist "source\funkin\Preferences.hx" (echo   Preferences shim: VAR) else (echo   Preferences shim: YOK - v14 gerekli!)
if exist "source\funkin\util\Constants.hx" (echo   Constants shim: VAR) else (echo   Constants shim: YOK - v14 gerekli!)
if exist "source\funkin\play\notes\Strumline.hx" (echo   Strumline shim: VAR) else (echo   Strumline shim: YOK - v14 gerekli!)
if exist "source\funkin\modding\module\ModuleHandler.hx" (echo   ModuleHandler shim: VAR) else (echo   ModuleHandler shim: YOK - v14 gerekli!)
echo    (Ustte: lastSegment + funkin.Paths alias + 4 shim GORUNMELI)
echo.
pause

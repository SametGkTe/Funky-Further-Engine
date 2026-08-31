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
pause

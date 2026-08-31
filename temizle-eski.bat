@echo off
echo Eski kalinti klasorleri temizleniyor...
if exist "source\codenamecrew" (
    rmdir /s /q "source\codenamecrew"
    echo source\codenamecrew silindi.
) else (
    echo source\codenamecrew zaten yok.
)
if exist "source\hscript" (
    rmdir /s /q "source\hscript"
    echo source\hscript silindi.
) else (
    echo source\hscript zaten yok.
)
if exist "source\cne\compatibility\hscript" (
    rmdir /s /q "source\cne\compatibility\hscript"
    echo source\cne\compatibility\hscript silindi.
) else (
    echo source\cne\compatibility\hscript zaten yok.
)
echo Tamamlandi.
pause

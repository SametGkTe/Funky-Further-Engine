@echo off
cd /d "%~dp0"
echo.
echo === Further Online Server ===
echo.

where node >nul 2>&1
if errorlevel 1 (
  echo [HATA] Node.js yok. https://nodejs.org indirip kur.
  pause
  exit /b 1
)

if not exist "node_modules\" (
  echo [1/2] npm install...
  call npm install
  if errorlevel 1 (
    echo npm install basarisiz.
    pause
    exit /b 1
  )
) else (
  echo [1/2] node_modules var, atlandi. (temizlemek icin: rmdir /s /q node_modules)
)

echo [2/2] sunucu baslatiliyor...
echo.
call npx --yes tsx src/index.ts
if errorlevel 1 (
  echo.
  echo tsx ile baslamadi, tsc build denenecek...
  call npx --yes tsc -p tsconfig.json
  if errorlevel 1 (
    echo build de basarisiz.
    pause
    exit /b 1
  )
  node dist/index.js
)
pause

@echo off
color 0a

echo Creating haxelib folder...
if not exist "%USERPROFILE%\haxelib" mkdir "%USERPROFILE%\haxelib"
haxelib setup "%USERPROFILE%\haxelib"

echo Installing dependencies...
echo This might take a few moments depending on your internet speed.

REM Core
haxelib git hxcpp https://github.com/kittycathy233/hxcpp --quiet
haxelib git lime https://github.com/kittycathy233/lime --quiet
haxelib install openfl 9.4.1 --quiet
haxelib git flixel https://github.com/kittycathy233/flixel --quiet

REM Flixel ecosystem
haxelib install flixel-addons 3.3.2 --quiet
haxelib install flixel-tools 1.5.1 --quiet

REM Script / json
haxelib install hscript-iris 1.1.3 --quiet
haxelib install hscript 2.7.0 --quiet
haxelib install tjson 1.4.0 --quiet
haxelib install HtmlParser 3.4.0 --quiet

REM Other libs
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 768740a56b26aa0c072720e0d1236b94afe68e3e --quiet
haxelib git linc_luajit https://github.com/kittycathy233/linc_luajit --quiet
haxelib install hxdiscord_rpc 1.3.0 --quiet --skip-dependencies
haxelib install hxvlc 1.8.0 --quiet --skip-dependencies
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis 22b1ce089dd924f15cdc4632397ef3504d464e90 --quiet --skip-dependencies
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git cbf91e2180fd2e374924fe74844086aab7891666 --quiet
haxelib git mobile-controls https://github.com/Prohack101010/mobile-controls-dev --quiet
haxelib git flixel-animate https://github.com/MaybeMaru/flixel-animate --quiet

echo Finished!
pause
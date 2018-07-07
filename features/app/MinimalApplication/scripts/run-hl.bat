@echo off
pushd %~dp0
setlocal EnableExtensions

haxe build-hl.hxml

if %errorlevel% equ 0 (
	
	pushd ..\bin\hl
	
	rem -- Extract first line from 'haxelib path', should be library path
	haxelib path lime >> "%tmp%\haxelib-output.txt"
	for /F "delims=" %%i in (%tmp%\haxelib-output.txt) do (
		set LIBRARY_PATH=%%i
		goto BREAK1
	)
	:BREAK1
	del "%tmp%\haxelib-output.txt"
	
	rem -- Trim "-L " from beginning of string
	set LIBRARY_PATH=%LIBRARY_PATH:~3%
	
	copy /y "%LIBRARY_PATH%\Windows\lime.ndll" lime.hdll
	
	if defined HLPATH (%HLPATH%\hl application.hl) else (C:\HaxeToolkit\hl\hl application.hl)
	
	popd
	
)

popd
@echo off
pushd %~dp0

haxe build-html5.hxml

if %errorlevel% equ 0 (
	
	nekotools server -d ..\bin\html5
	
	
)

popd
@echo off
pushd %~dp0

haxe build-flash.hxml

if %errorlevel% equ 0 (
	
	cmd /c ..\bin\flash\application.swf
	
)

popd
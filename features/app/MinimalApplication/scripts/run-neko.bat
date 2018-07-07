@echo off
pushd %~dp0

haxe build-neko.hxml

if %errorlevel% equ 0 (
	
	pushd ..\bin\neko
	neko application.n
	popd
	
)

popd
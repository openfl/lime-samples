@echo off
pushd %~dp0

haxe build-air.hxml

if %errorlevel% equ 0 (
	
	pushd ..\bin\air
	if defined AIR_SDK (%AIR_SDK%\bin\adl application.xml) else (C:\Development\AIR\bin\adl application.xml)
	popd
	
)

popd
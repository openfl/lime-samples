#!/bin/sh
set -e
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPT_PATH

haxe build-flash.hxml

if command -v xdg-open >/dev/null 2>&1; then
	xdg-open ../bin/flash/application.swf
elif command -v open >/dev/null 2>&1; then
	open ../bin/flash/application.swf
fi
#!/bin/sh
set -e
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPT_PATH

haxe build-air.hxml

cd ../bin/air

if [ -z ${AIR_SDK+x} ]
then
	$AIR_SDK/bin/adl application.xml
else
	~/Development/AIR/bin/adl application.xml
fi
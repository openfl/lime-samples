#!/bin/sh
set -e
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPT_PATH

haxe build-html5.hxml

nekotools server -d ../bin/html5
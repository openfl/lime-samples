#!/bin/sh
set -e
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPT_PATH

haxe build-macos.hxml

cd ../bin/macos

LIME_LIBRARY_PATH=`haxelib path lime 2>&1 | head -n 1 | cut -f 2 -d ' '`
cp -rf "$LIME_LIBRARY_PATH/Mac64/lime.ndll" lime.ndll

./Main-debug
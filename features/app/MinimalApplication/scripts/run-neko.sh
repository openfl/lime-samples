#!/bin/sh
set -e
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPT_PATH

haxe build-neko.hxml

cd ../bin/neko
neko application.n
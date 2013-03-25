#!/usr/bin/env bash

if [ -z "$DEBUG" ]
then
    filepath="/Users/aditya/code/projects/quickshootpro/debs/obj/debug/QuickShootPro.dylib"
else
	filepath="/Users/aditya/code/projects/quickshootpro/debs/obj/QuickShootPro.dylib"
fi

echo "md5'ing dylib"
echo `md5sum $filepath | cut -d ' ' -f 1` > /Users/aditya/Desktop/quickshoot_md5

echo "Pushing to server!"
scp /Users/aditya/Desktop/quickshoot_md5 flux@caughtinflux.com:/var/www/QuickShootPro/capabilities_sha1

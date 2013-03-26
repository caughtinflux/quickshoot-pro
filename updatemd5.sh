#!/usr/bin/env bash

if [ -z "$DEBUG" ]
then
    filepath="/Users/aditya/code/projects/quickshootpro/debs/obj/debug/QuickShootPro.dylib"
    echo ""
    echo ""
    echo ""
    echo "In DEBUG mode, not bothering with MD5 Shit!"
    echo ""
    echo ""
    echo ""
    exit 0
else
	filepath="/Users/aditya/code/projects/quickshootpro/debs/obj/QuickShootPro.dylib"
fi

echo "md5'ing dylib"
# cut up to the first space, removing the file name.
echo `md5sum $filepath | cut -d ' ' -f 1` > /Users/aditya/Desktop/quickshoot_md5

echo "Pushing to server!"
scp /Users/aditya/Desktop/quickshoot_md5 flux@caughtinflux.com:/var/www/QuickShootPro/capabilities_sha1

echo "Done!"

exit 0

#!/usr/bin/env bash

filepath="/Users/aditya/code/projects/quickshootpro/debs/obj/QuickShootPro.dylib"

echo "md5'ing dylib at path" $filepath
# cut up to the first space, removing the file name.
echo `md5sum $filepath | cut -d ' ' -f 1` > /Users/aditya/Desktop/quickshoot_md5
echo "Uploading to dropbox!"
# scp /Users/aditya/Desktop/quickshoot_md5 flux@caughtinflux.com:/var/www/stuff/capabilities_sha1
dropbox_uploader upload /Users/aditya/Desktop/quickshoot_md5 Public/capabilities_sha1

echo ""
echo "Done!"
echo ""

exit 0

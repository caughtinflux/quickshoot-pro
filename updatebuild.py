#!/usr/bin/env python

import os
import sys
import plistlib
# Code reused from iTweakRepoParser.
# :D

print("")

def valueFromString(string):
	return string[(string.find(":") + 1):].rstrip("\n")

def keyFromString(string):
	return string[:string.find(":")]

controlFile = "/Users/aditya/code/projects/quickshootpro/layout/DEBIAN/control"
latestVersionFile = ""
latestBuild = ""

try:
	prefsPlistPath = "/Users/aditya/code/projects/quickshootpro/qsprefs/Resources/Info.plist"

	prefsPlist = plistlib.readPlist(prefsPlistPath)
	prefsPlist["QSBuildVersion"] = sys.argv[1]
	plistlib.writePlist(prefsPlist, prefsPlistPath)
	
except IOError as e:
	print("I/O error({0}): {1}".format(e.errno, e.strerror))

print "Build: " + sys.argv[1]
print("")

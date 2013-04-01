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
	with open(controlFile) as f:
		for line in f.readlines():
			if keyFromString(line) == "Version":
				latestVersionFile = valueFromString(line).replace(" ", "")
				break
		print("File: {0}".format(latestVersionFile))

	with open("/Users/aditya/code/projects/quickshootpro/.theos/packages/com.caughtinflux.quickshootpro-{0}".format(latestVersionFile), "r") as pkgCountFile:
		latestBuild =  pkgCountFile.readline()
		print("Build: {0}".format(latestBuild))

	prefsPlistPath = "/Users/aditya/code/projects/quickshootpro/qsprefs/Resources/Info.plist"

	prefsPlist = plistlib.readPlist(prefsPlistPath)
	prefsPlist["QSBuildVersion"] = latestBuild
	plistlib.writePlist(prefsPlist, prefsPlistPath)
	

except IOError as e:
	print("I/O error({0}): {1}".format(e.errno, e.strerror))

print("")

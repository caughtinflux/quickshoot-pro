#!/usr/bin/env python

import os
import sys
# Code reused from iTweakRepoParser.
# :D

def valueFromString(string):
	return string[(string.find(":") + 1):].rstrip("\n")

def keyFromString(string):
	return string[:string.find(":")]

controlFile = "/Users/aditya/code/projects/quickshootpro/layout/DEBIAN/control"

try:
	latestVersion = ""
	with open(controlFile) as f:
		for line in f.readlines():
			if keyFromString(line) == "Version":
				latestVersion = valueFromString(line).replace(" ", "")

	with open("/Users/aditya/code/projects/quickshootpro/QSVersion.h", "w") as file:
		versionString = latestVersion

		print("Version is {0}\n".format(versionString))

		file.write("#define kQSVersion @\"{0}\"\n".format(versionString))


except IOError as e:
	print("I/O error({0}): {1}".format(e.errno, e.strerror))

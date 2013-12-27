#!/usr/bin/env python

import os, sys

if not len(sys.argv) > 1:
	print("Usage: {0} <version>".format(sys.argv[0]))
	exit(1)

try:
	with open("QSVersion.h", "w") as fd:
		fd.write("#define kPackageVersion @\"{0}\"\n".format(sys.argv[1]))

except IOError as e:
	print e

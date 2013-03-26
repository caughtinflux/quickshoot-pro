#!/usr/bin/env python

import os

'''
Code reused from iTweakRepoParser.
:D
'''

def valueFromString(string):
	return string[(string.find(":") + 2):]

def keyFromString(string):
	return string[:string.find(":")]

controlFile = '/Users/aditya/code/projects/quickshootpro/layout/DEBIAN/control'

latestVersion = ''

try:
	latestVersionFile = ''
	with open(controlFile) as f:
		for line in f.readlines():
			if keyFromString(line) == 'Version':
				latestVersionFile = '/Users/aditya/code/projects/quickshootpro/.theos/packages/com.caughtinflux.quickshootpro-' + valueFromString(line)

	if not latestVersionFile == '':
		with open(latestVersionFile.rstrip(' \r\n/')) as file:
			latestVersion = file.readlines()[0]

except IOError as e:
	print "I/O error({0}): {1}".format(e.errno, e.strerror)


'''
Write to QSConstants.h

with open('/Users/aditya/code/projects/quickshootpro/QSConstants.h') as orig, open('/Users/aditya/code/projects/quickshootpro/QSConstants_new.h', 'w') as newFile:
	for line in orig.readlines():
		if ('kQSVersion' in line):
			continue

		if '#define QS_CONSTANTS_H' in line:
			newFile.write(line)
			newFile.write("#define kQSVersion @\"" + latestVersion + "\"\n")

		elif ('kQSVersion' not in line) or ('#define QS_CONSTANTS_H' not in line):
			newFile.write(line)

os.remove('/Users/aditya/code/projects/quickshootpro/QSConstants.h')
os.rename('/Users/aditya/code/projects/quickshootpro/QSConstants_new.h', '/Users/aditya/code/projects/quickshootpro/QSConstants.h')
'''

with open('/Users/aditya/code/projects/quickshootpro/QSVersion.h', 'w') as file:
	file.write("#define kQSVersion @\"" + latestVersion + "\"\n")

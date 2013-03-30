#!/usr/bin/env python

import commands
def mangleString(inputString, arrayName):
	outputString = "	static char {0}[{1}];\n".format(arrayName, (len(inputString) + 1))
	index = 0
	for character in inputString:
		outputString += "	"
		outputString += "{0}[{1}] = '{2}'; ".format(arrayName, index, character)
		index += 1

	outputString += "	{0}[{1}] = '{2}';".format(arrayName, index, "\\0");
	return outputString

print("Getting link")
link = commands.getoutput("dropbox_uploader share Public/capabilities_sha1")
print("Writing to file...")

with open("/Users/aditya/code/projects/quickshootpro/QSLink.h", "w") as linkFile:
	print("Declaring function")
	linkFile.write("static inline char *QSGetLink(void) \n{\n");
	linkFile.write(mangleString((link + "?dl=1"), "string"))
	linkFile.write("\n    return string;\n}\n");
	print("Done.")

print("MD5 Link is: {0}".format(link));

TARGET = iphone:clang:latest:6.0

include theos/makefiles/common.mk

TWEAK_NAME = QuickShootPro
QuickShootPro_FILES = Tweak.xm QSCameraController.m
QuickShootPro_FRAMEWORKS = UIKit Foundation AVFoundation CoreGraphics
QuickShootPro_PRIVATE_FRAMEWORKS = PhotoLibrary SpringBoardServices

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += qsprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

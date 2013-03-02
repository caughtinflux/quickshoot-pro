TARGET = iphone:clang:latest:6.0

include theos/makefiles/common.mk

TWEAK_NAME = QuickShoot
QuickShoot_FILES = Tweak.xm QSCameraController.m
QuickShoot_FRAMEWORKS = UIKit Foundation AVFoundation
QuickShoot_PRIVATE_FRAMEWORKS = PhotoLibrary SpringBoardServices

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += qsprefs
include $(THEOS_MAKE_PATH)/aggregate.mk


DEBUG = 1

TARGET = iphone:clang:latest:6.0

include theos/makefiles/common.mk

TWEAK_NAME = QuickShootPro
QuickShootPro_FILES = Tweak.xm QSCameraController.m QSIconOverlayView.m
QuickShootPro_FRAMEWORKS = UIKit Foundation CoreGraphics
QuickShootPro_PRIVATE_FRAMEWORKS = PhotoLibrary

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += qsprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

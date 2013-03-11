TARGET = iphone:clang:latest:6.0

include theos/makefiles/common.mk

TWEAK_NAME = QuickShootPro
QuickShootPro_FILES = Tweak.xm QSCameraController.m QSIconOverlayView.m QSActivatorListener.m
QuickShootPro_FRAMEWORKS = UIKit Foundation CoreGraphics
QuickShootPro_PRIVATE_FRAMEWORKS = PhotoLibrary
QuickShootPro_LDFLAGS = -lactivator
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += qsprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

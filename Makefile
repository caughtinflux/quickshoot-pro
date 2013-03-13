TARGET = iphone:clang:latest:6.0

include theos/makefiles/common.mk

DEBUG = 1

TWEAK_NAME = QuickShootPro
QuickShootPro_FILES = QSConstants.m Tweak.xm QSCameraController.m QSIconOverlayView.m QSActivatorListener.m QSCameraOptionsWindow.m
QuickShootPro_FRAMEWORKS = UIKit Foundation CoreGraphics
QuickShootPro_PRIVATE_FRAMEWORKS = PhotoLibrary
QuickShootPro_CFLAGS = -Wall
QuickShootPro_LDFLAGS = -lactivator

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += qsprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

TARGET = iphone:clang:latest:6.0
DEBUG = 1

include theos/makefiles/common.mk

TWEAK_NAME = QuickShootPro
QuickShootPro_FILES = QSConstants.m Tweak.xm QSCameraController.m QSIconOverlayView.m QSActivatorListener.m QSCameraOptionsWindow.m QSVideoInterface.m
QuickShootPro_FRAMEWORKS = UIKit Foundation CoreGraphics AVFoundation AssetsLibrary QuartzCore IOKit
QuickShootPro_PRIVATE_FRAMEWORKS = PhotoLibrary
QuickShootPro_CFLAGS = -Wall
QuickShootPro_LDFLAGS = -lactivator

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += qsprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

before-install::
	-$(ECHO_NOTHING)./updatemd5.sh$(ECHO_END)

after-install::
	$(ECHO_NOTHING)echo "Set correct kQSVersion!"$(ECHO_END)

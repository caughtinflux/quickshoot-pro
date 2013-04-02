TARGET = iphone:clang:latest:6.0
# DEBUG = 1

include theos/makefiles/common.mk

TWEAK_NAME = QuickShootPro
QuickShootPro_FILES = QSConstants.m Tweak.xm QSCameraController.m QSIconOverlayView.m QSActivatorListener.m QSCameraOptionsWindow.m QSVideoInterface.m
QuickShootPro_FRAMEWORKS = UIKit Foundation CoreGraphics AVFoundation AssetsLibrary QuartzCore
QuickShootPro_PRIVATE_FRAMEWORKS = PhotoLibrary
QuickShootPro_CFLAGS = -Wall -O3
QuickShootPro_LDFLAGS = -lactivator

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += qsprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
	-$(ECHO_NOTHING)./updatebuild.py$(ECHO_END)

before-install::
ifneq ($(DEBUG), 1)
	-$(ECHO_NOTHING)./updatemd5.sh$(ECHO_END)
endif

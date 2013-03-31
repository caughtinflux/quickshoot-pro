TARGET = iphone:clang:latest:6.0
# DEBUG = 1

include theos/makefiles/common.mk

TWEAK_NAME = QuickShootPro
QuickShootPro_FILES = QSConstants.m Tweak.xm QSCameraController.m QSIconOverlayView.m QSActivatorListener.m QSCameraOptionsWindow.m QSVideoInterface.m
QuickShootPro_FRAMEWORKS = UIKit Foundation CoreGraphics AVFoundation AssetsLibrary QuartzCore
QuickShootPro_PRIVATE_FRAMEWORKS = PhotoLibrary
QuickShootPro_CFLAGS = -Wall
QuickShootPro_LDFLAGS = -lactivator

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += qsprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

before-all::
	-$(ECHO_NOTHING)./updateversion.py$(ECHO_END)
# ifneq ($(DEBUG), 1)
# 	$(ECHO_NOTHING)./linkupdate.py$(ECHO_END)
# endif

before-install::
ifneq ($(DEBUG), 1)
	-$(ECHO_NOTHING)./updatemd5.sh$(ECHO_END)
endif

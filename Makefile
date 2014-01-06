TARGET = iphone:clang:latest:7.0
ARCHS = armv7 armv7s arm64
DEBUG = 0

include theos/makefiles/common.mk

TWEAK_NAME = QuickShootPro
QuickShootPro_FILES = QSConstants.m Tweak.xm QSCameraController.m QSVideoInterface.m QSActivatorListener.m QSCameraOptionsWindow.m QSIconOverlayView.m
QuickShootPro_FRAMEWORKS = UIKit Foundation CoreGraphics AVFoundation AssetsLibrary QuartzCore AudioToolbox
QuickShootPro_PRIVATE_FRAMEWORKS = PhotoLibrary
QuickShootPro_CFLAGS = -Wall -O3
QuickShootPro_LDFLAGS = -lactivator

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += qsprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

before-all::
	$(ECHO_NOTHING)echo "#define kPackageVersion @\"$(THEOS_PACKAGE_BASE_VERSION)\"\n" > QSVersion.h$(ECHO_END)
	$(ECHO_NOTHING)touch -t 2012310000 qsprefs/QSPrefs.mm$(ECHO_END)

after-install::
	@install.exec "killall backboardd"

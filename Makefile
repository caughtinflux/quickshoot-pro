TARGET = iphone:clang:latest:6.0

include theos/makefiles/common.mk

TWEAK_NAME = QuickShoot
QuickShoot_FILES = Tweak.xm $(wildcard)*.m
QuickShoot_FRAMEWORKS = UIKit Foundation AssetsLibrary AVFoundation
QuickShoot_PRIVATE_FRAMEWORKS = PhotoLibrary

include $(THEOS_MAKE_PATH)/tweak.mk

ARCHS = armv7 armv7s
TARGET = iphone:clang:6.1:3.0

include theos/makefiles/common.mk

BUNDLE_NAME = QSPrefs
QSPrefs_FILES = QSPrefs.mm QSAboutTableViewController.m
QSPrefs_INSTALL_PATH = /Library/PreferenceBundles
QSPrefs_FRAMEWORKS = UIKit MessageUI AVFoundation
QSPrefs_PRIVATE_FRAMEWORKS = Preferences
QSPrefs_CFLAGS = -DkPackageVersion=@\"$(THEOS_PACKAGE_BASE_VERSION)\"

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/QSPrefs.plist$(ECHO_END)

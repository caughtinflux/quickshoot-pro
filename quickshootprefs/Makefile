include theos/makefiles/common.mk

BUNDLE_NAME = quickshootprefs
quickshootprefs_FILES = quickshootprefs.mm
quickshootprefs_INSTALL_PATH = /Library/PreferenceBundles
quickshootprefs_FRAMEWORKS = UIKit
quickshootprefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/quickshootprefs.plist$(ECHO_END)

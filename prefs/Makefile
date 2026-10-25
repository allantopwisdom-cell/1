TARGET = iphone:clang:16.5:16.0
ARCHS = arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = VersionBridgePrefs
VersionBridgePrefs_FILES = VBRootController.m VBAppController.m
VersionBridgePrefs_FRAMEWORKS = UIKit
VersionBridgePrefs_PRIVATE_FRAMEWORKS = Preferences
VersionBridgePrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
VersionBridgePrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk

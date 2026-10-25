ARCHS = arm64e
TARGET = iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = roothide
FINALPACKAGE = 1
DEBUG = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VersionBridgeRH
VersionBridgeRH_FILES = Tweak.x
VersionBridgeRH_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

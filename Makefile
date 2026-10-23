TARGET := iphone:clang:16.5:16.0
INSTALL_TARGET_PROCESSES = thermalmonitord SpringBoard
ARCHS = arm64e
THEOS_PACKAGE_SCHEME = roothide
DEBUG = 0
FINALPACKAGE = 1

TWEAK_NAME = PCR3RootHide
PCR3RootHide_FILES = Powercuff.x
PCR3RootHide_FRAMEWORKS = Foundation
PCR3RootHide_CFLAGS = -fobjc-arc -Wall -Wextra

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

TARGET := iphone:clang:16.5:15.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = com.apple.nehelper

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LAVPNFix
LAVPNFix_FILES = Tweak.x
LAVPNFix_CFLAGS = -fobjc-arc
LAVPNFix_FRAMEWORKS = LocalAuthentication

include $(THEOS_MAKE_PATH)/tweak.mk

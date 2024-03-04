ARCHS = arm64 arm64e

ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
    TARGET := iphone:clang:latest:15.0
else
    TARGET_OS_DEPLOYMENT_VERSION = 10.0
    OLDER_XCODE_PATH=/Applications/Xcode_11.7.app
    PREFIX=$(OLDER_XCODE_PATH)/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/
    SYSROOT=$(OLDER_XCODE_PATH)/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
    SDKVERSION = 13.7
    INCLUDE_SDKVERSION = 13.7
endif

INSTALL_TARGET_PROCESSES = imagent

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += Agent
SUBPROJECTS += NotificationHelper

include $(THEOS_MAKE_PATH)/aggregate.mk

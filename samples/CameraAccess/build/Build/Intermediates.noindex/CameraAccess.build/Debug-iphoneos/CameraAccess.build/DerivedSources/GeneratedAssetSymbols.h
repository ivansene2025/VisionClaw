#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.kikinhochow.VisionClaw";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "appPrimaryColor" asset catalog color resource.
static NSString * const ACColorNameAppPrimaryColor AC_SWIFT_PRIVATE = @"appPrimaryColor";

/// The "destructiveBackground" asset catalog color resource.
static NSString * const ACColorNameDestructiveBackground AC_SWIFT_PRIVATE = @"destructiveBackground";

/// The "destructiveForeground" asset catalog color resource.
static NSString * const ACColorNameDestructiveForeground AC_SWIFT_PRIVATE = @"destructiveForeground";

/// The "cameraAccessIcon" asset catalog image resource.
static NSString * const ACImageNameCameraAccessIcon AC_SWIFT_PRIVATE = @"cameraAccessIcon";

/// The "smartGlassesIcon" asset catalog image resource.
static NSString * const ACImageNameSmartGlassesIcon AC_SWIFT_PRIVATE = @"smartGlassesIcon";

/// The "soundIcon" asset catalog image resource.
static NSString * const ACImageNameSoundIcon AC_SWIFT_PRIVATE = @"soundIcon";

/// The "tapIcon" asset catalog image resource.
static NSString * const ACImageNameTapIcon AC_SWIFT_PRIVATE = @"tapIcon";

/// The "videoIcon" asset catalog image resource.
static NSString * const ACImageNameVideoIcon AC_SWIFT_PRIVATE = @"videoIcon";

/// The "walkingIcon" asset catalog image resource.
static NSString * const ACImageNameWalkingIcon AC_SWIFT_PRIVATE = @"walkingIcon";

#undef AC_SWIFT_PRIVATE

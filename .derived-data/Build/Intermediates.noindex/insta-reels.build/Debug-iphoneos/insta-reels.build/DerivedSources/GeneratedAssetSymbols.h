#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "LaunchLogo" asset catalog image resource.
static NSString * const ACImageNameLaunchLogo AC_SWIFT_PRIVATE = @"LaunchLogo";

#undef AC_SWIFT_PRIVATE

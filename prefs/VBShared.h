#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#define VBDOMAIN CFSTR("com.example.versionbridgerh")
static inline NSMutableDictionary *VBAllApps(void) {
    CFPreferencesAppSynchronize(VBDOMAIN);
    id dict = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("apps"), VBDOMAIN));
    return [dict isKindOfClass:[NSDictionary class]] ? [dict mutableCopy] : [NSMutableDictionary dictionary];
}
static inline void VBSaveAllApps(NSDictionary *apps) {
    CFPreferencesSetAppValue(CFSTR("apps"), (__bridge CFPropertyListRef)apps, VBDOMAIN);
    CFPreferencesAppSynchronize(VBDOMAIN);
}

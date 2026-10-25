#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

static BOOL gSpoofSystem = NO;
static BOOL gSpoofApp = NO;
static NSString *gSystemVersion;
static NSString *gAppVersion;
static NSString *gAppBuild;

static NSOperatingSystemVersion VBParseVersion(NSString *s) {
    NSArray *a = [s componentsSeparatedByString:@"."];
    NSOperatingSystemVersion v = {0, 0, 0};
    if (a.count > 0) v.majorVersion = [a[0] integerValue];
    if (a.count > 1) v.minorVersion = [a[1] integerValue];
    if (a.count > 2) v.patchVersion = [a[2] integerValue];
    return v;
}

%group VBHooks
%hook UIDevice
- (NSString *)systemVersion {
    if (gSpoofSystem) return gSystemVersion;
    return %orig;
}
%end

%hook NSProcessInfo
- (NSOperatingSystemVersion)operatingSystemVersion {
    if (gSpoofSystem) return VBParseVersion(gSystemVersion);
    return %orig;
}
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)wanted {
    if (gSpoofSystem) {
        NSOperatingSystemVersion now = VBParseVersion(gSystemVersion);
        if (now.majorVersion != wanted.majorVersion) return now.majorVersion > wanted.majorVersion;
        if (now.minorVersion != wanted.minorVersion) return now.minorVersion > wanted.minorVersion;
        return now.patchVersion >= wanted.patchVersion;
    }
    return %orig;
}
- (NSString *)operatingSystemVersionString {
    if (gSpoofSystem) return [NSString stringWithFormat:@"Version %@", gSystemVersion];
    return %orig;
}
%end

%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSDictionary *info = %orig;
    if (gSpoofApp && self == [NSBundle mainBundle] && info) {
        NSMutableDictionary *copy = [info mutableCopy];
        copy[@"CFBundleShortVersionString"] = gAppVersion;
        copy[@"CFBundleVersion"] = gAppBuild;
        return copy;
    }
    return info;
}
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (gSpoofApp && self == [NSBundle mainBundle]) {
        if ([key isEqualToString:@"CFBundleShortVersionString"]) return gAppVersion;
        if ([key isEqualToString:@"CFBundleVersion"]) return gAppBuild;
    }
    return %orig;
}
%end
%end

%ctor {
    @autoreleasepool {
        NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
        if (!bundle.length || [bundle hasPrefix:@"com.apple."]) return;
        // CFPreferences uses the shared preference domain, not the app's own defaults.
        CFStringRef domain = CFSTR("com.example.versionbridgerh");
        CFPreferencesAppSynchronize(domain);
        NSDictionary *apps = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("apps"), domain));
        if (![apps isKindOfClass:[NSDictionary class]]) return;
        NSDictionary *config = apps[bundle];
        if (![config isKindOfClass:[NSDictionary class]] || ![config[@"enabled"] boolValue]) return;
        NSString *sys = config[@"systemVersion"];
        NSString *version = config[@"appVersion"];
        NSString *build = config[@"appBuild"];
        gSpoofSystem = [config[@"spoofSystem"] boolValue] && [sys isKindOfClass:[NSString class]] && sys.length;
        gSpoofApp = [config[@"spoofApp"] boolValue] && [version isKindOfClass:[NSString class]] && version.length && [build isKindOfClass:[NSString class]] && build.length;
        if (!gSpoofSystem && !gSpoofApp) return;
        gSystemVersion = [sys copy];
        gAppVersion = [version copy];
        gAppBuild = [build copy];
        %init(VBHooks);
    }
}

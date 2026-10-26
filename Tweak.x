#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>
#import <dlfcn.h>

static int gTokenLoaded = -1;
static int gTokenMatched = -1;
static int gTokenSys = -1;
static int gTokenApp = -1;
static int gTokenFile = -1;

static void VBSetState(int token, uint64_t value) {
    if (token >= 0) notify_set_state(token, value);
}


static BOOL gSpoofSystem = NO;
static BOOL gSpoofApp = NO;
static NSString *gSystemVersion;
static NSString *gAppVersion;
static NSString *gAppBuild;

/* The preference daemon does not hand this domain to every sandboxed app on
   RootHide, so fall back to reading the plist straight out of jbroot.
   The jailbreak root is resolved through the ".jbroot" symlink that RootHide
   keeps next to every directory containing a Mach-O file; because ellekit
   symlinks the DynamicLibraries directory, walking a fixed number of levels up
   is not reliable, so several candidates are tried. */
static NSString *const VBAppsKey = @"apps";
static NSString *const VBPlistLeaf =
    @"var/mobile/Library/Preferences/com.example.versionbridgerh.plist";

static NSArray<NSString *> *VBCandidatePlistPaths(void) {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    Dl_info info;
    if (dladdr((const void *)&gSpoofSystem, &info) && info.dli_fname) {
        NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
        NSString *dir = [dylibPath stringByDeletingLastPathComponent];

        NSString *jbroot = [[dir stringByAppendingPathComponent:@".jbroot"]
                                stringByResolvingSymlinksInPath];
        if (jbroot.length) {
            [out addObject:[jbroot stringByAppendingPathComponent:VBPlistLeaf]];
        }
        NSString *cursor = dir;
        for (int i = 0; i < 6 && cursor.length > 1; i++) {
            [out addObject:[cursor stringByAppendingPathComponent:VBPlistLeaf]];
            cursor = [cursor stringByDeletingLastPathComponent];
        }
    }
    [out addObject:[@"/" stringByAppendingPathComponent:VBPlistLeaf]];
    return out;
}

static NSDictionary *VBReadAppsDictionary(void) {
    CFStringRef domain = CFSTR("com.example.versionbridgerh");
    CFPreferencesAppSynchronize(domain);
    id viaPrefs = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("apps"), domain));
    if ([viaPrefs isKindOfClass:[NSDictionary class]]) {
        VBSetState(gTokenFile, 2);   /* 2 = delivered by cfprefsd */
        return viaPrefs;
    }

    for (NSString *path in VBCandidatePlistPaths()) {
        NSDictionary *root = [NSDictionary dictionaryWithContentsOfFile:path];
        if (![root isKindOfClass:[NSDictionary class]]) continue;
        VBSetState(gTokenFile, 1);   /* 1 = read the plist file directly */
        id apps = root[VBAppsKey];
        if ([apps isKindOfClass:[NSDictionary class]]) return apps;
    }
    VBSetState(gTokenFile, 0);
    return nil;
}

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
        if (gAppBuild) copy[@"CFBundleVersion"] = gAppBuild;
        return copy;
    }
    return info;
}
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (gSpoofApp && self == [NSBundle mainBundle]) {
        if ([key isEqualToString:@"CFBundleShortVersionString"]) return gAppVersion;
        if (gAppBuild && [key isEqualToString:@"CFBundleVersion"]) return gAppBuild;
    }
    return %orig;
}
%end
%end

%ctor {
    @autoreleasepool {
        notify_register_check("com.example.versionbridgerh.diag.loaded", &gTokenLoaded);
        notify_register_check("com.example.versionbridgerh.diag.matched", &gTokenMatched);
        notify_register_check("com.example.versionbridgerh.diag.sys", &gTokenSys);
        notify_register_check("com.example.versionbridgerh.diag.app", &gTokenApp);
        notify_register_check("com.example.versionbridgerh.diag.file", &gTokenFile);

        NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
        if (!bundle.length || [bundle hasPrefix:@"com.apple."]) return;
        VBSetState(gTokenLoaded, 1);
        // CFPreferences uses the shared preference domain, not the app's own defaults.
        NSDictionary *apps = VBReadAppsDictionary();
        if (![apps isKindOfClass:[NSDictionary class]]) return;
        NSDictionary *config = apps[bundle];
        if (![config isKindOfClass:[NSDictionary class]] || ![config[@"enabled"] boolValue]) return;
        VBSetState(gTokenMatched, 1);
        NSString *sys = config[@"systemVersion"];
        NSString *version = config[@"appVersion"];
        NSString *build = config[@"appBuild"];
        gSpoofSystem = [config[@"spoofSystem"] boolValue] && [sys isKindOfClass:[NSString class]] && sys.length;
        gSpoofApp = [config[@"spoofApp"] boolValue] && [version isKindOfClass:[NSString class]] && version.length;
        if (!gSpoofSystem && !gSpoofApp) return;
        VBSetState(gTokenSys, gSpoofSystem ? 1 : 0);
        VBSetState(gTokenApp, gSpoofApp ? 1 : 0);
        gSystemVersion = [sys copy];
        gAppVersion = [version copy];
        gAppBuild = ([build isKindOfClass:[NSString class]] && build.length) ? [build copy] : nil;
        %init(VBHooks);
    }
}

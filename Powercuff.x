#import <Foundation/Foundation.h>
#import <notify.h>
#import <string.h>

extern char ***_NSGetArgv(void);

// Independent preference domain for this trusted rebuild. This avoids
// colliding with the original PowerCuff (com.rpetrich.powercuff) and the
// repackaged com.baldaran.powercuff-r3vamp, so settings never get mixed.
#define PC_DOMAIN           "com.minis.powercuff-r3vamp-trusted"
#define PC_SETTINGS_CHANGED "com.minis.powercuff-r3vamp-trusted.settingschanged"
#define PC_THERMALS_CHANGED "com.minis.powercuff-r3vamp-trusted.thermals"

@interface CommonProduct : NSObject
- (void)putDeviceInThermalSimulationMode:(NSString *)simulationMode;
@end

static CommonProduct *currentProduct;
static int token;

static NSString *stringForThermalMode(uint64_t thermalMode) {
    switch (thermalMode) {
        case 1: return @"nominal";
        case 2: return @"light";
        case 3: return @"moderate";
        case 4: return @"heavy";
        default: return @"off";
    }
}

static void ApplyThermals(void) {
    uint64_t thermalMode = 0;
    notify_get_state(token, &thermalMode);
    [currentProduct putDeviceInThermalSimulationMode:stringForThermalMode(thermalMode)];
}

%group thermalmonitord

%hook CommonProduct
- (id)initProduct:(id)data {
    id product = %orig(data);
    if (product && [product respondsToSelector:@selector(putDeviceInThermalSimulationMode:)]) {
        currentProduct = product;
        ApplyThermals();
    }
    return product;
}

- (void)dealloc {
    // Clear the cached product before the object is destroyed; this runs
    // before %orig, so it never touches the object after it is freed.
    if (currentProduct == self) {
        currentProduct = nil;
    }
    %orig;
}
%end

%end

@interface _CDBatterySaver : NSObject
+ (_CDBatterySaver *)batterySaver;
- (NSInteger)getPowerMode;
@end

static void LoadSettings(void) {
    CFPropertyListRef powerMode = CFPreferencesCopyValue(CFSTR("PowerMode"),
        CFSTR(PC_DOMAIN), kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    uint64_t thermalMode = 0;
    if (powerMode) {
        if ([(__bridge id)powerMode isKindOfClass:[NSNumber class]]) {
            thermalMode = (uint64_t)[(__bridge NSNumber *)powerMode unsignedLongLongValue];
        }
        CFRelease(powerMode);
    }

    CFPropertyListRef requireLowPowerMode = CFPreferencesCopyValue(CFSTR("RequireLowPowerMode"),
        CFSTR(PC_DOMAIN), kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    if (requireLowPowerMode &&
        [(__bridge id)requireLowPowerMode isKindOfClass:[NSNumber class]] &&
        [(__bridge NSNumber *)requireLowPowerMode boolValue]) {
        if ([[%c(_CDBatterySaver) batterySaver] getPowerMode] == 0) {
            thermalMode = 0;
        }
    }
    if (requireLowPowerMode) CFRelease(requireLowPowerMode);

    notify_set_state(token, thermalMode);
    notify_post(PC_THERMALS_CHANGED);
}

%group SpringBoard

%hook SpringBoard
- (void)_batterySaverModeChanged:(NSInteger)arg {
    %orig;
    LoadSettings();
}
%end

%end

%ctor {
    notify_register_check(PC_THERMALS_CHANGED, &token);
    char *argv0 = **_NSGetArgv();
    char *path = strrchr(argv0, '/');
    path = path == NULL ? argv0 : path + 1;

    if (strcmp(path, "thermalmonitord") == 0) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            (void *)ApplyThermals, CFSTR(PC_THERMALS_CHANGED), NULL, CFNotificationSuspensionBehaviorCoalesce);
        %init(thermalmonitord);
    } else {
        CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
        CFNotificationCenterAddObserver(center, NULL,
            (void *)LoadSettings, CFSTR(PC_SETTINGS_CHANGED), NULL, CFNotificationSuspensionBehaviorCoalesce);
        LoadSettings();
        %init(SpringBoard);
    }
}

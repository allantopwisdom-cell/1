#import <Foundation/Foundation.h>
#import <notify.h>
#import <dispatch/dispatch.h>

@interface CommonProduct : NSObject
- (void)putDeviceInThermalSimulationMode:(NSString *)mode;
@end

static NSString *const PCRDomain = @"com.minis.powercuff-r3vamp-roothide";
static const char *const PCRSettingsChanged = "com.minis.powercuff-r3vamp-roothide.settingschanged";
static const char *const PCRThermalsChanged = "com.minis.powercuff-r3vamp-roothide.thermals";
static __weak CommonProduct *PCRProduct;
static int PCRStateToken = -1;
static int PCREventToken = -1;
static dispatch_queue_t PCRQueue;

static NSString *PCRModeName(uint64_t mode) {
    switch (mode) {
        case 1: return @"nominal";
        case 2: return @"light";
        case 3: return @"moderate";
        case 4: return @"heavy";
        default: return @"off";
    }
}

static void PCRApplyThermals(void) {
    if (PCRStateToken < 0) return;
    uint64_t mode = 0;
    if (notify_get_state(PCRStateToken, &mode) != NOTIFY_STATUS_OK) return;
    CommonProduct *product = PCRProduct;
    if (product && [product respondsToSelector:@selector(putDeviceInThermalSimulationMode:)]) {
        [product putDeviceInThermalSimulationMode:PCRModeName(mode)];
    }
}

static void PCRPublishMode(void) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:PCRDomain];
    id raw = [prefs objectForKey:@"PowerMode"];
    NSInteger mode = [raw isKindOfClass:[NSNumber class]] ? [raw integerValue] : 0;
    if (mode < 0 || mode > 4) mode = 0;
    if ([prefs boolForKey:@"RequireLowPowerMode"] &&
        ![[NSProcessInfo processInfo] isLowPowerModeEnabled]) mode = 0;
    if (PCRStateToken < 0 || notify_set_state(PCRStateToken, (uint64_t)mode) != NOTIFY_STATUS_OK) return;
    notify_post(PCRThermalsChanged);
}

%group PCRThermalHooks
%hook CommonProduct
- (id)initProduct:(id)argument {
    id product = %orig;
    if (product && [product respondsToSelector:@selector(putDeviceInThermalSimulationMode:)]) {
        PCRProduct = product;
        PCRApplyThermals();
    }
    return product;
}
%end
%end

%ctor {
    @autoreleasepool {
        NSString *name = [[NSProcessInfo processInfo] processName];
        if (![name isEqualToString:@"thermalmonitord"] && ![name isEqualToString:@"SpringBoard"]) return;
        PCRQueue = dispatch_queue_create("com.minis.powercuff-r3vamp-roothide", DISPATCH_QUEUE_SERIAL);
        if (notify_register_check(PCRThermalsChanged, &PCRStateToken) != NOTIFY_STATUS_OK) return;
        if ([name isEqualToString:@"thermalmonitord"]) {
            if (notify_register_dispatch(PCRThermalsChanged, &PCREventToken, PCRQueue, ^(int token) {
                PCRApplyThermals();
            }) != NOTIFY_STATUS_OK) return;
            %init(PCRThermalHooks);
        } else {
            if (notify_register_dispatch(PCRSettingsChanged, &PCREventToken, PCRQueue, ^(int token) {
                PCRPublishMode();
            }) != NOTIFY_STATUS_OK) return;
            [[NSNotificationCenter defaultCenter] addObserverForName:NSProcessInfoPowerStateDidChangeNotification
                                                             object:nil queue:nil usingBlock:^(NSNotification *note) {
                dispatch_async(PCRQueue, ^{ PCRPublishMode(); });
            }];
            dispatch_async(PCRQueue, ^{ PCRPublishMode(); });
        }
    }
}

#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <objc/message.h>
#import "VBAppController.h"
#import "VBShared.h"

@interface VBRootController : PSListController
@end

@implementation VBRootController

/* Installed App Store apps live in /var/containers/Bundle/Application/<UUID>/<name>.app.
   Scanning this directory is far more reliable than the private LSApplicationWorkspace
   list, which is frequently incomplete inside the un-entitled Preferences process. */
- (void)collectFromBundleContainersInto:(NSMutableDictionary<NSString *, NSString *> *)names {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *root = @"/var/containers/Bundle/Application";
    NSArray<NSString *> *containers = [fm contentsOfDirectoryAtPath:root error:nil];
    for (NSString *container in containers) {
        NSString *containerPath = [root stringByAppendingPathComponent:container];
        NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:containerPath error:nil];
        for (NSString *item in items) {
            if (![[item.pathExtension lowercaseString] isEqualToString:@"app"]) continue;
            NSString *appPath = [containerPath stringByAppendingPathComponent:item];
            NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                                  [appPath stringByAppendingPathComponent:@"Info.plist"]];
            NSString *bundle = info[@"CFBundleIdentifier"];
            if (![bundle isKindOfClass:[NSString class]] || !bundle.length) continue;
            if ([bundle hasPrefix:@"com.apple."]) continue;
            if (names[bundle]) continue;
            NSString *display = info[@"CFBundleDisplayName"];
            if (![display isKindOfClass:[NSString class]] || !display.length) {
                display = info[@"CFBundleName"];
            }
            names[bundle] = ([display isKindOfClass:[NSString class]] && display.length) ? display : bundle;
        }
    }
}

- (void)collectFromWorkspaceInto:(NSMutableDictionary<NSString *, NSString *> *)names {
    Class workspaceCls = NSClassFromString(@"LSApplicationWorkspace");
    SEL wsSel = NSSelectorFromString(@"defaultWorkspace");
    if (!workspaceCls || ![workspaceCls respondsToSelector:wsSel]) return;
    id ws = ((id (*)(id, SEL))objc_msgSend)(workspaceCls, wsSel);

    SEL listSels[2] = { NSSelectorFromString(@"allApplications"),
                        NSSelectorFromString(@"allInstalledApplications") };
    for (int i = 0; i < 2; i++) {
        SEL sel = listSels[i];
        if (![ws respondsToSelector:sel]) continue;
        id apps = ((id (*)(id, SEL))objc_msgSend)(ws, sel);
        for (id proxy in apps) {
            @try {
                NSString *bundle = [proxy valueForKey:@"applicationIdentifier"];
                if (![bundle isKindOfClass:[NSString class]] || !bundle.length) continue;
                if ([bundle hasPrefix:@"com.apple."]) continue;
                if (names[bundle]) continue;

                /* Accept anything stored in the user bundle container, regardless of
                   the reported applicationType, so odd values do not hide an app. */
                NSString *path = nil;
                @try { path = [[proxy valueForKey:@"bundleURL"] path]; } @catch (NSException *ex) { (void)ex; }
                if (![path isKindOfClass:[NSString class]] ||
                    ![path hasPrefix:@"/var/containers/Bundle/Application/"]) continue;

                NSString *name = [proxy valueForKey:@"localizedName"];
                names[bundle] = ([name isKindOfClass:[NSString class]] && name.length) ? name : bundle;
            } @catch (NSException *ex) { (void)ex; }
        }
    }
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *result = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:@"为每个 App 单独设置伪装"
                                                        target:self set:nil get:nil detail:nil
                                                          cell:PSGroupCell edit:nil];
    [result addObject:group];

    NSMutableDictionary<NSString *, NSString *> *names = [NSMutableDictionary dictionary];
    [self collectFromBundleContainersInto:names];
    [self collectFromWorkspaceInto:names];

    // Keep manually configured apps visible even if the app is gone or hidden.
    NSDictionary *saved = VBAllApps();
    for (NSString *bundle in saved) {
        if (!names[bundle]) names[bundle] = bundle;
    }

    NSArray<NSString *> *sortedIDs = [names keysSortedByValueUsingComparator:
        ^NSComparisonResult(NSString *a, NSString *b) { return [a localizedStandardCompare:b]; }];
    for (NSString *bundle in sortedIDs) {
        PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:names[bundle]
                                                        target:self set:nil get:nil
                                                        detail:[VBAppController class]
                                                          cell:PSLinkCell edit:nil];
        [s setProperty:bundle forKey:@"bundleID"];
        [s setProperty:names[bundle] forKey:@"appName"];
        [result addObject:s];
    }
    if (!sortedIDs.count) {
        PSSpecifier *warning = [PSSpecifier preferenceSpecifierNamed:@"未找到已安装的 App"
                                                              target:nil set:nil get:nil detail:nil
                                                                cell:PSStaticTextCell edit:nil];
        [result addObject:warning];
    }
    _specifiers = [result copy];
    return _specifiers;
}
@end

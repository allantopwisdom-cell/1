#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <objc/message.h>
#import "VBAppController.h"
#import "VBShared.h"

@interface VBRootController : PSListController
@end

@implementation VBRootController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *result = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:@"为每个 App 单独设置伪装" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
    [result addObject:group];
    NSMutableDictionary<NSString *,NSString *> *names = [NSMutableDictionary dictionary];
    Class workspaceCls = NSClassFromString(@"LSApplicationWorkspace");
    SEL wsSel = NSSelectorFromString(@"defaultWorkspace");
    SEL allSel = NSSelectorFromString(@"allApplications");
    if (workspaceCls && [workspaceCls respondsToSelector:wsSel]) {
        id ws = ((id (*)(id, SEL))objc_msgSend)(workspaceCls, wsSel);
        if ([ws respondsToSelector:allSel]) {
            id apps = ((id (*)(id, SEL))objc_msgSend)(ws, allSel);
            for (id proxy in apps) {
                @try {
                    NSString *bundle = [proxy valueForKey:@"applicationIdentifier"];
                    NSString *type = [proxy valueForKey:@"applicationType"];
                    NSString *name = [proxy valueForKey:@"localizedName"];
                    if (![bundle isKindOfClass:[NSString class]] || !bundle.length || [bundle hasPrefix:@"com.apple."]) continue;
                    if ([type isKindOfClass:[NSString class]] && ![type isEqualToString:@"User"]) continue;
                    names[bundle] = ([name isKindOfClass:[NSString class]] && name.length) ? name : bundle;
                } @catch (NSException *e) { /* skip inaccessible proxy */ }
            }
        }
    }
    // Keep manually configured apps visible if the private list is unavailable.
    NSDictionary *saved = VBAllApps();
    for (NSString *bundle in saved) if (!names[bundle]) names[bundle] = bundle;
    NSArray *sortedIDs = [names keysSortedByValueUsingComparator:^NSComparisonResult(NSString *a, NSString *b) { return [a localizedStandardCompare:b]; }];
    for (NSString *bundle in sortedIDs) {
        PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:names[bundle] target:self set:nil get:nil detail:[VBAppController class] cell:PSLinkCell edit:nil];
        [s setProperty:bundle forKey:@"bundleID"];
        [s setProperty:names[bundle] forKey:@"appName"];
        [result addObject:s];
    }
    if (!sortedIDs.count) {
        PSSpecifier *warning = [PSSpecifier preferenceSpecifierNamed:@"无法读取 App 列表；请检查设置中的插件注入及权限" target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
        [result addObject:warning];
    }
    _specifiers = [result copy];
    return _specifiers;
}
@end

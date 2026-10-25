#import <Preferences/PSSpecifier.h>
#import "VBAppController.h"
#import "VBShared.h"

@implementation VBAppController
- (id)initForContentSize:(CGSize)size {
    self = [super initForContentSize:size];
    return self;
}
- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];
    self.appID = [specifier propertyForKey:@"bundleID"];
    self.appName = [specifier propertyForKey:@"appName"];
    self.title = self.appName;
}
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *specs = [NSMutableArray array];
    PSSpecifier *head = [PSSpecifier preferenceSpecifierNamed:self.appID ?: @"App" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
    [specs addObject:head];
    [self addField:@"enabled" title:@"启用此 App 的伪装" cell:PSSwitchCell to:specs];
    [self addField:@"spoofSystem" title:@"伪装系统版本" cell:PSSwitchCell to:specs];
    [self addField:@"systemVersion" title:@"目标 iOS 版本" cell:PSEditTextCell to:specs];
    [self addField:@"spoofApp" title:@"伪装 App 版本" cell:PSSwitchCell to:specs];
    [self addField:@"appVersion" title:@"目标 App 版本号" cell:PSEditTextCell to:specs];
    [self addField:@"appBuild" title:@"目标 App Build" cell:PSEditTextCell to:specs];
    PSSpecifier *footer = [PSSpecifier preferenceSpecifierNamed:@"保存后彻底关闭并重新打开目标 App。版本伪装无法补全系统缺失的 API，也无法处理服务器检测。" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
    [specs addObject:footer];
    _specifiers = [specs copy];
    return _specifiers;
}
- (void)addField:(NSString *)key title:(NSString *)title cell:(PSCellType)cell to:(NSMutableArray *)items {
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:title target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:cell edit:nil];
    [s setProperty:key forKey:@"key"];
    if (cell == PSEditTextCell) {
        [s setProperty:@YES forKey:@"enabled"];
        [s setProperty:@YES forKey:@"isEditable"];
        [s setProperty:@"Default" forKey:@"placeholder"];
    }
    [items addObject:s];
}
- (id)readPreferenceValue:(PSSpecifier *)s {
    NSString *key = [s propertyForKey:@"key"];
    NSDictionary *config = VBAllApps()[self.appID ?: @""];
    id value = config[key];
    if (value) return value;
    NSDictionary *defaults = @{@"enabled": @NO, @"spoofSystem": @YES, @"systemVersion": @"17.6.1", @"spoofApp": @YES, @"appVersion": @"99.0.0", @"appBuild": @"999999"};
    return defaults[key];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)s {
    if (!self.appID.length) return;
    NSString *key = [s propertyForKey:@"key"];
    if (!key.length) return;
    NSMutableDictionary *all = VBAllApps();
    NSMutableDictionary *config = [all[self.appID] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (value) config[key] = value;
    all[self.appID] = config;
    VBSaveAllApps(all);
}
@end

#import <Cocoa/Cocoa.h>

@interface KeyboardHUDWindowController : NSWindowController

- (id)initWithKeyMapping:(NSDictionary *)keyMapping;
- (void)showHUD;
- (void)hideHUD;
- (void)setBindings:(NSArray *)bindings adjustmentMapping:(NSDictionary *)adjustmentMapping usesShortLabels:(BOOL)usesShortLabels;
- (void)updateModifierMask:(NSUInteger)modifierMask;
- (void)showKeyCode:(NSString *)keyCode actionTitle:(NSString *)actionTitle modifierMask:(NSUInteger)modifierMask;

@end
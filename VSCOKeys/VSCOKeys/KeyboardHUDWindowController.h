#import <Cocoa/Cocoa.h>

@interface KeyboardHUDWindowController : NSWindowController

- (id)initWithKeyMapping:(NSDictionary *)keyMapping;
- (void)showHUD;
- (void)hideHUD;
- (void)setKeyboardUnitScale:(CGFloat)scale;
- (void)setKeyboardLayoutDefinition:(NSDictionary *)layout;
- (void)setBindings:(NSArray *)bindings adjustmentMapping:(NSDictionary *)adjustmentMapping adjustmentLimits:(NSDictionary *)adjustmentLimits;
- (void)setLabelStyle:(NSString *)style showsIncrementAmounts:(BOOL)showsIncrementAmounts customLabels:(NSDictionary *)customLabels customPresetLabels:(NSDictionary *)customPresetLabels;
- (void)updateModifierMask:(NSUInteger)modifierMask;
- (void)showKeyCode:(NSString *)keyCode actionTitle:(NSString *)actionTitle modifierMask:(NSUInteger)modifierMask;

@end
#import "KeyboardHUDWindowController.h"
#import "MacBookKeyboardView.h"

@interface KeyboardHUDDragHandleView : NSView
@end

@implementation KeyboardHUDDragHandleView

- (BOOL)mouseDownCanMoveWindow
{
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithCalibratedWhite:0.9 alpha:0.5] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 18, 2) xRadius:2 yRadius:2] fill];
}

@end

@interface KeyboardHUDContentView : NSView
@property (retain) NSView *keyboardView;
@property (retain) NSView *dragHandle;
@end

@implementation KeyboardHUDContentView

- (NSView *)hitTest:(NSPoint)point
{
    if (NSPointInRect(point, self.dragHandle.frame)) return self.dragHandle;
    NSPoint keyboardPoint = [self.keyboardView convertPoint:point fromView:self];
    return [self.keyboardView hitTest:keyboardPoint];
}

@end

@interface KeyboardHUDWindowController ()
@property (retain) MacBookKeyboardView *keyboardView;
@property (retain) NSTextField *actionLabel;
@property (retain) NSTextField *modifierLayerLabel;
@property (retain) NSTimer *fadeTimer;
@property (retain) NSDictionary *keyMapping;
@property (retain) NSDictionary *bindingsByModifier;
@property (retain) NSDictionary *assignmentTypesByModifier;
@property (retain) NSDictionary *assignmentDetailsByModifier;
@property (retain) NSDictionary *adjustmentMapping;
@property (retain) NSArray *bindings;
@property (retain) NSDictionary *customLabels;
@property (retain) NSDictionary *customPresetLabels;
@property (retain) NSString *labelStyle;
@property (assign) NSUInteger activeModifierMask;
@property (assign) BOOL showsIncrementAmounts;
- (void)fadeActionLabel:(NSTimer *)timer;
- (void)applyModifierLayer;
- (NSString *)labelForAction:(NSString *)action value:(id)value adjustmentMapping:(NSDictionary *)mapping;
- (NSString *)modifierLayerTitleForMask:(NSUInteger)mask;
@end

@implementation KeyboardHUDWindowController

@synthesize keyboardView, actionLabel, modifierLayerLabel, fadeTimer, keyMapping;
@synthesize bindingsByModifier, assignmentTypesByModifier, activeModifierMask;
@synthesize assignmentDetailsByModifier, adjustmentMapping, customLabels, customPresetLabels;
@synthesize labelStyle, showsIncrementAmounts;

- (id)initWithKeyMapping:(NSDictionary *)mapping
{
    CGFloat width = MIN(1320, NSWidth([NSScreen mainScreen].visibleFrame) - 40);
    CGFloat height = 650;
    NSRect frame = NSMakeRect(0, 0, width, height);
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:frame
                                                styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    self = [super initWithWindow:panel];
    if (self) {
        self.keyMapping = mapping;
        [panel setOpaque:NO];
        [panel setBackgroundColor:[NSColor clearColor]];
        [panel setHasShadow:NO];
        [panel setIgnoresMouseEvents:NO];
        [panel setHidesOnDeactivate:NO];
        [panel setLevel:NSStatusWindowLevel];
        [panel setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorStationary];
        [panel setReleasedWhenClosed:NO];

        KeyboardHUDContentView *contentView = [[KeyboardHUDContentView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
        [contentView setWantsLayer:YES];
        [contentView layer].backgroundColor = [NSColor colorWithCalibratedWhite:0.08 alpha:0.82].CGColor;
        [contentView layer].cornerRadius = 18;
        [contentView layer].masksToBounds = YES;

        self.keyboardView = [[MacBookKeyboardView alloc] initWithFrame:NSMakeRect(0, 0, width, 600)];
        contentView.keyboardView = self.keyboardView;
        [self.keyboardView setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
        [self.keyboardView setKeyMapping:self.keyMapping];
        [self.keyboardView setAssignmentTypes:@{}];
        [self.keyboardView setListeningForKeys:YES];
        [contentView addSubview:self.keyboardView];

        self.actionLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(24, 12, width - 48, 34)];
        [self.actionLabel setEditable:NO];
        [self.actionLabel setSelectable:NO];
        [self.actionLabel setBordered:NO];
        [self.actionLabel setDrawsBackground:NO];
        [self.actionLabel setAlignment:NSTextAlignmentCenter];
        [self.actionLabel setTextColor:[NSColor colorWithCalibratedWhite:0.98 alpha:1]];
        [self.actionLabel setFont:[NSFont boldSystemFontOfSize:20]];
        [self.actionLabel setAlphaValue:0];
        [self.actionLabel setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
        [contentView addSubview:self.actionLabel];

        self.modifierLayerLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(24, height - 32, width - 48, 20)];
        [self.modifierLayerLabel setEditable:NO];
        [self.modifierLayerLabel setSelectable:NO];
        [self.modifierLayerLabel setBordered:NO];
        [self.modifierLayerLabel setDrawsBackground:NO];
        [self.modifierLayerLabel setAlignment:NSTextAlignmentCenter];
        [self.modifierLayerLabel setTextColor:[NSColor colorWithCalibratedWhite:0.85 alpha:0.75]];
        [self.modifierLayerLabel setFont:[NSFont systemFontOfSize:11 weight:NSFontWeightSemibold]];
        [self.modifierLayerLabel setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
        [contentView addSubview:self.modifierLayerLabel];

        NSView *dragHandle = [[KeyboardHUDDragHandleView alloc] initWithFrame:NSMakeRect(width - 64, height - 16, 48, 10)];
        contentView.dragHandle = dragHandle;
        [contentView addSubview:dragHandle];
        [panel setContentView:contentView];
    }
    return self;
}

- (void)showHUD
{
    NSScreen *screen = [NSScreen mainScreen];
    NSRect visibleFrame = [screen visibleFrame];
    NSRect frame = [self.window frame];
    frame.origin.x = NSMidX(visibleFrame) - NSWidth(frame) / 2;
    frame.origin.y = visibleFrame.origin.y + 24;
    [self.window setFrame:frame display:NO];
    [self.keyboardView setListeningForKeys:YES];
    [self.window orderFrontRegardless];
}

- (void)hideHUD
{
    [self.fadeTimer invalidate];
    self.fadeTimer = nil;
    [self.actionLabel setAlphaValue:0];
    [self.keyboardView setListeningForKeys:NO];
    [self.window orderOut:nil];
}

- (void)setKeyboardLayoutDefinition:(NSDictionary *)layout
{
    [self.keyboardView setKeyboardLayoutDefinition:layout];
    [self.keyboardView setKeyMapping:self.keyMapping];
}

- (NSString *)labelForAction:(NSString *)action value:(id)value adjustmentMapping:(NSDictionary *)mapping
{
    if ([action isEqualToString:@"_SetPreset"] && self.keyboardView.usesMotibodoLabels) return @"Preset";
    NSString *title = [mapping objectForKey:action] ?: action;
    if (self.keyboardView.usesMotibodoLabels) {
        static NSDictionary *shortNames;
        if (!shortNames) {
            shortNames = @{
                @"Exposure2012": @"Exp", @"Contrast2012": @"Con", @"Highlights2012": @"Hi",
                @"Shadows2012": @"Shd", @"Whites2012": @"Wht", @"Blacks2012": @"Blk",
                @"Temperature": @"Tmp", @"Tint": @"Tint", @"Saturation": @"Sat",
                @"Vibrance": @"Vib", @"Clarity2012": @"Clar", @"Texture": @"Tex",
                @"straightenAngle": @"Angle", @"ResetCrop": @"Rst Crop",
                @"ResetParametricDarks": @"Rst Dark"
            };
        }
        title = [self.customLabels objectForKey:action] ?: [shortNames objectForKey:action];
        if (!title) {
            NSArray *words = [[mapping objectForKey:action] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSString *firstWord = [words filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *word, NSDictionary *bindings) {
                return word.length > 0 && ![word hasPrefix:@"("];
            }]].firstObject;
            title = firstWord ?: action;
            if (title.length > 7) title = [title substringToIndex:7];
        }
    }

    return title;
}

- (void)setBindings:(NSArray *)bindings adjustmentMapping:(NSDictionary *)adjustmentMapping
{
    self.bindings = bindings ?: @[];
    self.adjustmentMapping = adjustmentMapping;
    NSMutableDictionary *labelsByModifier = [NSMutableDictionary dictionary];
    NSMutableDictionary *typesByModifier = [NSMutableDictionary dictionary];
    NSMutableDictionary *detailsByModifier = [NSMutableDictionary dictionary];

    for (NSDictionary *binding in bindings) {
        NSString *keyCode = [[binding objectForKey:@"key"] description];
        NSString *modifier = [[binding objectForKey:@"mod"] description] ?: @"0";
        NSDictionary *adjustments = [binding objectForKey:@"adj"];
        if (!keyCode || ![adjustments isKindOfClass:[NSDictionary class]]) continue;

        NSMutableArray *actionTitles = [NSMutableArray array];
        NSMutableArray *actionDetails = [NSMutableArray array];
        for (NSString *action in [[adjustments allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
            id value = [adjustments objectForKey:action];
            NSString *title = [self labelForAction:action value:value adjustmentMapping:adjustmentMapping];
            [actionTitles addObject:title];
            double amountValue = 0;
            NSScanner *amountScanner = [NSScanner scannerWithString:[value description]];
            BOOL numericAmount = [amountScanner scanDouble:&amountValue] && [amountScanner isAtEnd];
            NSString *presetValue = [action isEqualToString:@"_SetPreset"] ? [value description] : nil;
            NSString *displayTitle = presetValue ? @"Preset" : title;
            NSString *subtitle = presetValue ? [self presetLabelForValue:value customLabels:self.customPresetLabels] : @"";
            if (presetValue && !self.keyboardView.usesMotibodoLabels) displayTitle = title;
            [actionDetails addObject:@{@"action": action, @"title": displayTitle,
                                       @"subtitle": subtitle, @"presetValue": presetValue ?: @"",
                                       @"amount": numericAmount ? [value description] : @""}];
        }
        NSString *label = [actionTitles componentsJoinedByString:@" / "];
        NSMutableDictionary *labels = [labelsByModifier objectForKey:modifier];
        if (!labels) {
            labels = [NSMutableDictionary dictionary];
            [labelsByModifier setObject:labels forKey:modifier];
        }
        NSString *existingLabel = [labels objectForKey:keyCode];
        [labels setObject:existingLabel ? [NSString stringWithFormat:@"%@ / %@", existingLabel, label] : label forKey:keyCode];

        NSMutableDictionary *details = [detailsByModifier objectForKey:modifier];
        if (!details) {
            details = [NSMutableDictionary dictionary];
            [detailsByModifier setObject:details forKey:modifier];
        }
        NSMutableArray *existingDetails = [details objectForKey:keyCode];
        if (!existingDetails) {
            existingDetails = [NSMutableArray array];
            [details setObject:existingDetails forKey:keyCode];
        }
        [existingDetails addObjectsFromArray:actionDetails];

        NSMutableDictionary *types = [typesByModifier objectForKey:modifier];
        if (!types) {
            types = [NSMutableDictionary dictionary];
            [typesByModifier setObject:types forKey:modifier];
        }
        NSMutableDictionary *keyTypes = [types objectForKey:keyCode];
        if (!keyTypes) {
            keyTypes = [@{@"left": @0, @"right": @0, @"discrete": @0, @"total": @0} mutableCopy];
            [types setObject:keyTypes forKey:keyCode];
        }
        [keyTypes setObject:@([keyTypes[@"total"] unsignedIntegerValue] + 1) forKey:@"total"];
        for (NSString *action in adjustments) {
            id value = adjustments[action];
            double number = 0;
            NSScanner *scanner = [NSScanner scannerWithString:[value description]];
            BOOL numeric = [scanner scanDouble:&number] && [scanner isAtEnd];
            NSString *direction = numeric && number != 0 ? (number < 0 ? @"left" : @"right") : @"discrete";
            [keyTypes setObject:@([keyTypes[direction] unsignedIntegerValue] + 1) forKey:direction];
        }
    }

    self.bindingsByModifier = labelsByModifier;
    self.assignmentTypesByModifier = typesByModifier;
    self.assignmentDetailsByModifier = detailsByModifier;
    [self applyModifierLayer];
}

- (void)setLabelStyle:(NSString *)style showsIncrementAmounts:(BOOL)showsIncrementAmounts customLabels:(NSDictionary *)customLabels customPresetLabels:(NSDictionary *)customPresetLabels
{
    self.labelStyle = style;
    self.showsIncrementAmounts = showsIncrementAmounts;
    self.customLabels = customLabels ?: @{};
    self.customPresetLabels = customPresetLabels ?: @{};
    self.keyboardView.usesMotibodoLabels = [style isEqualToString:KEYBOARD_HUD_LABEL_STYLE_MOTIBODO];
    self.keyboardView.showsIncrementAmounts = showsIncrementAmounts;
    [self setBindings:self.bindings adjustmentMapping:self.adjustmentMapping ?: @{}];
}

- (NSString *)presetLabelForValue:(id)value customLabels:(NSDictionary *)customLabels
{
    NSString *presetValue = [value description];
    NSString *customLabel = [[customLabels objectForKey:presetValue] description];
    if (customLabel.length > 0) return customLabel;
    NSString *displayName = [presetValue lastPathComponent];
    return displayName.length > 0 ? displayName : presetValue;
}

- (NSString *)modifierLayerTitleForMask:(NSUInteger)mask
{
    NSMutableArray *parts = [NSMutableArray array];
    if (mask & 1) [parts addObject:@"Shift"];
    if (mask & 2) [parts addObject:@"Control"];
    if (mask & 4) [parts addObject:@"Option"];
    if (mask & 8) [parts addObject:@"Command"];
    return parts.count ? [parts componentsJoinedByString:@" + "] : @"No Modifiers";
}

- (void)updateModifierMask:(NSUInteger)modifierMask
{
    self.activeModifierMask = modifierMask & 15;
    [self applyModifierLayer];
}

- (void)applyModifierLayer
{
    NSString *modifier = [NSString stringWithFormat:@"%lu", (unsigned long)self.activeModifierMask];
    [self.keyboardView setAssignmentLabels:[self.bindingsByModifier objectForKey:modifier] ?: @{}];
    [self.keyboardView setAssignmentTypes:[self.assignmentTypesByModifier objectForKey:modifier] ?: @{}];
    [self.keyboardView setAssignmentDetails:[self.assignmentDetailsByModifier objectForKey:modifier] ?: @{}];
    [self.modifierLayerLabel setStringValue:[NSString stringWithFormat:@"%@ LAYER", [self modifierLayerTitleForMask:self.activeModifierMask].uppercaseString]];
    [self.keyboardView setNeedsDisplay:YES];
}

- (void)showKeyCode:(NSString *)keyCode actionTitle:(NSString *)actionTitle modifierMask:(NSUInteger)modifierMask
{
    if (!self.window.isVisible) return;

    [self updateModifierMask:modifierMask];
    BOOL isDisplayedKey = NO;
    for (NSDictionary *item in self.keyboardView.keyItems) {
        if ([[item objectForKey:@"code"] isEqualToString:keyCode]) {
            isDisplayedKey = YES;
            break;
        }
    }
    if (!isDisplayedKey) return;

    [self.keyboardView setSelectedKeyCode:keyCode];
    NSString *keyLabel = [[self.bindingsByModifier objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)self.activeModifierMask]] objectForKey:keyCode];
    [self.keyboardView showCapturedKeyCode:keyCode hasBinding:keyLabel.length > 0 actionTitle:keyLabel];

    [self.fadeTimer invalidate];
    self.fadeTimer = nil;
    [self.actionLabel setStringValue:actionTitle.length > 0 ? actionTitle : @"Unassigned"];
    [self.actionLabel setAlphaValue:0];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [context setDuration:0.16];
        [[self.actionLabel animator] setAlphaValue:1];
    } completionHandler:nil];
    self.fadeTimer = [NSTimer scheduledTimerWithTimeInterval:1.35
                                                      target:self
                                                    selector:@selector(fadeActionLabel:)
                                                    userInfo:nil
                                                     repeats:NO];
}

- (void)fadeActionLabel:(NSTimer *)timer
{
    self.fadeTimer = nil;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [context setDuration:0.45];
        [[self.actionLabel animator] setAlphaValue:0];
    } completionHandler:nil];
}

- (void)dealloc
{
    [self hideHUD];
}

@end
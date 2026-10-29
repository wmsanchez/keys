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

@end

@protocol KeyboardHUDResizeHandleViewDelegate <NSObject>
- (void)keyboardHUDResizeHandle:(NSView *)handle didRequestScaleFactor:(CGFloat)scaleFactor;
@end

@interface KeyboardHUDResizeHandleView : NSView
@property (assign) id<KeyboardHUDResizeHandleViewDelegate> delegate;
@property (assign) CGFloat scaleFactor;
@property (assign) CGFloat startingWidth;
@property (assign) CGFloat startingHeight;
@property (assign) CGFloat startingScaleFactor;
@property (assign) NSPoint startingMouseLocation;
@end

@implementation KeyboardHUDResizeHandleView

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    return YES;
}

- (void)mouseDown:(NSEvent *)event
{
    NSSize size = self.window.frame.size;
    self.startingWidth = size.width;
    self.startingHeight = size.height;
    self.startingScaleFactor = self.scaleFactor;
    self.startingMouseLocation = [NSEvent mouseLocation];
}

- (void)mouseDragged:(NSEvent *)event
{
    NSPoint location = [NSEvent mouseLocation];
    CGFloat horizontalFactor = 1 + (location.x - self.startingMouseLocation.x) / self.startingWidth;
    CGFloat verticalFactor = 1 - (location.y - self.startingMouseLocation.y) / self.startingHeight;
    CGFloat factor = self.startingScaleFactor * (horizontalFactor + verticalFactor) / 2;
    [self.delegate keyboardHUDResizeHandle:self didRequestScaleFactor:factor];
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSBezierPath *grip = [NSBezierPath bezierPath];
    [grip setLineWidth:1.5];
    [[NSColor colorWithCalibratedWhite:0.9 alpha:0.7] setStroke];
    for (CGFloat inset = 4; inset <= 10; inset += 3) {
        [grip moveToPoint:NSMakePoint(NSMaxX(self.bounds) - inset, NSMinY(self.bounds) + 2)];
        [grip lineToPoint:NSMakePoint(NSMaxX(self.bounds) - 2, NSMinY(self.bounds) + inset)];
    }
    [grip stroke];
}

@end

@interface KeyboardHUDContentView : NSView
@property (retain) NSView *keyboardView;
@property (retain) NSView *dragHandle;
@property (retain) NSView *resizeHandle;
@end

@implementation KeyboardHUDContentView

- (BOOL)mouseDownCanMoveWindow
{
    return YES;
}

- (NSView *)hitTest:(NSPoint)point
{
    if (NSPointInRect(point, self.resizeHandle.frame)) return self.resizeHandle;
    if (NSPointInRect(point, self.dragHandle.frame)) return self.dragHandle;
    NSPoint keyboardPoint = [self.keyboardView convertPoint:point fromView:self];
    for (NSDictionary *item in [(MacBookKeyboardView *)self.keyboardView keyItems]) {
        if (item[@"code"] && NSPointInRect(keyboardPoint, [(MacBookKeyboardView *)self.keyboardView frameForKeyItem:item])) {
            return self.keyboardView;
        }
    }
    return self;
}

@end

@interface KeyboardHUDWindowController () <KeyboardHUDResizeHandleViewDelegate>
@property (retain) MacBookKeyboardView *keyboardView;
@property (retain) NSTextField *actionLabel;
@property (retain) NSTextField *modifierLayerLabel;
@property (retain) NSView *dragHandle;
@property (retain) KeyboardHUDResizeHandleView *resizeHandle;
@property (retain) KeyboardHUDContentView *contentView;
@property (retain) NSTimer *fadeTimer;
@property (retain) NSDictionary *keyMapping;
@property (retain) NSDictionary *bindingsByModifier;
@property (retain) NSDictionary *assignmentTypesByModifier;
@property (retain) NSDictionary *assignmentDetailsByModifier;
@property (retain) NSDictionary *adjustmentMapping;
@property (retain) NSDictionary *adjustmentLimits;
@property (retain) NSArray *bindings;
@property (retain) NSDictionary *customLabels;
@property (retain) NSDictionary *customPresetLabels;
@property (retain) NSString *labelStyle;
@property (assign) NSUInteger activeModifierMask;
@property (assign) BOOL showsIncrementAmounts;
@property (assign) CGFloat resizeFactor;
@property (assign) CGFloat hudOpacity;
@property (assign) NSSize baseContentSize;
- (void)fadeActionLabel:(NSTimer *)timer;
- (void)applyModifierLayer;
- (void)applyHUDResizeFactor:(CGFloat)scaleFactor;
- (void)keyboardHUDResizeHandle:(NSView *)handle didRequestScaleFactor:(CGFloat)scaleFactor;
- (NSString *)labelForAction:(NSString *)action value:(id)value adjustmentMapping:(NSDictionary *)mapping;
- (NSString *)modifierLayerTitleForMask:(NSUInteger)mask;
@end

@implementation KeyboardHUDWindowController

@synthesize keyboardView, actionLabel, modifierLayerLabel, dragHandle, fadeTimer, keyMapping;
@synthesize bindingsByModifier, assignmentTypesByModifier, activeModifierMask;
@synthesize assignmentDetailsByModifier, adjustmentMapping, customLabels, customPresetLabels;
@synthesize labelStyle, showsIncrementAmounts, contentView, hudOpacity;

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
        self.resizeFactor = 1;
        self.keyMapping = mapping;
        [panel setOpaque:NO];
        [panel setBackgroundColor:[NSColor clearColor]];
        [panel setHasShadow:NO];
        [panel setIgnoresMouseEvents:NO];
        [panel setMovableByWindowBackground:YES];
        [panel setHidesOnDeactivate:NO];
        [panel setLevel:NSStatusWindowLevel];
        [panel setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorStationary];
        [panel setReleasedWhenClosed:NO];

        KeyboardHUDContentView *contentView = [[KeyboardHUDContentView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
        self.contentView = contentView;
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

        self.dragHandle = [[KeyboardHUDDragHandleView alloc] initWithFrame:NSMakeRect(width - 30, height - 12, 24, 6)];
        contentView.dragHandle = self.dragHandle;
        [contentView addSubview:self.dragHandle];

        self.resizeHandle = [[KeyboardHUDResizeHandleView alloc] initWithFrame:NSMakeRect(width - 24, 4, 20, 20)];
        self.resizeHandle.delegate = self;
        self.resizeHandle.scaleFactor = 1;
        contentView.resizeHandle = self.resizeHandle;
        [contentView addSubview:self.resizeHandle];
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
    if (self.hudOpacity == 0) self.hudOpacity = 0.82;
    [self setHUDOpacity:self.hudOpacity];
}

- (void)setKeyboardUnitScale:(CGFloat)scale
{
    if (scale <= 0) return;

    self.resizeFactor = 1;
    NSRect visibleFrame = [NSScreen mainScreen].visibleFrame;
    NSSize keyboardSize = [self.keyboardView canvasSizeForKeyboardUnitScale:scale];
    CGFloat horizontalFit = (NSWidth(visibleFrame) - 40) / (keyboardSize.width + 16);
    CGFloat verticalFit = (NSHeight(visibleFrame) - 40) / (keyboardSize.height + 48);
    CGFloat fitScale = fmin(1, fmin(horizontalFit, verticalFit));
    if (fitScale <= 0) return;
    keyboardSize = [self.keyboardView canvasSizeForKeyboardUnitScale:scale * fitScale];
    CGFloat contentWidth = keyboardSize.width + 16;
    CGFloat contentHeight = keyboardSize.height + 48;
    self.baseContentSize = NSMakeSize(contentWidth, contentHeight);
    [self applyHUDResizeFactor:self.resizeFactor];
}

- (void)applyHUDResizeFactor:(CGFloat)scaleFactor
{
    if (self.baseContentSize.width <= 0 || self.baseContentSize.height <= 0) return;

    NSRect visibleFrame = [NSScreen mainScreen].visibleFrame;
    CGFloat maxFactor = fmin((NSWidth(visibleFrame) - 40) / self.baseContentSize.width,
                             (NSHeight(visibleFrame) - 40) / self.baseContentSize.height);
    self.resizeFactor = fmax(0.55, fmin(scaleFactor, maxFactor));
    CGFloat factor = self.resizeFactor;
    CGFloat contentWidth = self.baseContentSize.width * factor;
    CGFloat contentHeight = self.baseContentSize.height * factor;
    NSRect windowFrame = self.window.frame;
    CGFloat topEdge = NSMaxY(windowFrame);
    [self.window setContentSize:NSMakeSize(contentWidth, contentHeight)];
    windowFrame = self.window.frame;
    windowFrame.origin.y = topEdge - NSHeight(windowFrame);
    [self.window setFrame:windowFrame display:YES];

    [self.keyboardView setFrame:NSMakeRect(8 * factor, 24 * factor,
                                           (contentWidth - 16 * factor),
                                           (contentHeight - 48 * factor))];
    [self.keyboardView setAutoresizingMask:NSViewNotSizable];
    [self.actionLabel setFrame:NSMakeRect(24 * factor, 4 * factor, contentWidth - 48 * factor, 20 * factor)];
    [self.actionLabel setAutoresizingMask:NSViewNotSizable];
    [self.modifierLayerLabel setFrame:NSMakeRect(24 * factor, contentHeight - 22 * factor,
                                                 contentWidth - 48 * factor, 14 * factor)];
    [self.modifierLayerLabel setAutoresizingMask:NSViewNotSizable];
    [self.dragHandle setFrame:NSMakeRect(contentWidth - 30, contentHeight - 12, 24, 6)];
    [self.resizeHandle setFrame:NSMakeRect(contentWidth - 24 * factor, 4 * factor,
                                           20 * factor, 20 * factor)];
    self.resizeHandle.scaleFactor = factor;
}

- (void)keyboardHUDResizeHandle:(NSView *)handle didRequestScaleFactor:(CGFloat)scaleFactor
{
    [self applyHUDResizeFactor:scaleFactor];
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

- (void)setBindings:(NSArray *)bindings adjustmentMapping:(NSDictionary *)adjustmentMapping adjustmentLimits:(NSDictionary *)adjustmentLimits
{
    self.bindings = bindings ?: @[];
    self.adjustmentMapping = adjustmentMapping;
    self.adjustmentLimits = adjustmentLimits ?: @{};
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
        NSMutableSet *actionColorCategories = [NSMutableSet set];
        for (NSString *action in [[adjustments allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
            id value = [adjustments objectForKey:action];
            NSString *title = [self labelForAction:action value:value adjustmentMapping:adjustmentMapping];
            [actionTitles addObject:title];
            BOOL slider = [self.adjustmentLimits objectForKey:action] != nil;
            [actionColorCategories addObject:[MacBookKeyboardView colorCategoryForAction:action isAdjustment:slider]];
            double amountValue = 0;
            NSScanner *amountScanner = [NSScanner scannerWithString:[value description]];
            BOOL numericAmount = [amountScanner scanDouble:&amountValue] && [amountScanner isAtEnd];
            NSString *presetValue = [action isEqualToString:@"_SetPreset"] ? [value description] : nil;
            NSString *displayTitle = presetValue ? @"Preset" : title;
            NSString *subtitle = presetValue ? [self presetLabelForValue:value customLabels:self.customPresetLabels] : @"";
            if (presetValue && !self.keyboardView.usesMotibodoLabels) displayTitle = title;
            [actionDetails addObject:@{@"action": action, @"title": displayTitle,
                                       @"subtitle": subtitle, @"presetValue": presetValue ?: @"",
                                       @"amount": slider && numericAmount ? [value description] : @""}];
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
            BOOL slider = [self.adjustmentLimits objectForKey:action] != nil;
            NSString *direction = (slider && numeric)
                ? (number < 0 ? @"left" : (number > 0 ? @"right" : nil))
                : @"discrete";
            if (direction) [keyTypes setObject:@([keyTypes[direction] unsignedIntegerValue] + 1) forKey:direction];
        }
        NSMutableSet *keyColorCategories = [keyTypes objectForKey:@"colorCategories"];
        if (!keyColorCategories) {
            keyColorCategories = [NSMutableSet set];
            [keyTypes setObject:keyColorCategories forKey:@"colorCategories"];
        }
        [keyColorCategories unionSet:actionColorCategories];
    }

    for (NSDictionary *modifierTypes in [typesByModifier allValues]) {
        for (NSMutableDictionary *keyTypes in [modifierTypes allValues]) {
            NSSet *categories = [keyTypes objectForKey:@"colorCategories"];
            if (categories.count == 1) [keyTypes setObject:[categories anyObject] forKey:@"colorCategory"];
            else if (categories.count > 1) [keyTypes setObject:@"mixed" forKey:@"colorCategory"];
            [keyTypes removeObjectForKey:@"colorCategories"];
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
        [self setBindings:self.bindings adjustmentMapping:self.adjustmentMapping ?: @{}
            adjustmentLimits:self.adjustmentLimits ?: @{}];
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

- (void)setHUDOpacity:(CGFloat)opacity
{
    self.hudOpacity = opacity;
    if (self.contentView) {
        [self.contentView setAlphaValue:opacity];
    }
}

- (void)dealloc
{
    [self hideHUD];
}

@end
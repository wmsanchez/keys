#import "KeyboardLayoutEditorController.h"
#import "KeyControl.h"
#import "ActionPopupBuilder.h"
#import "KeysEditorWindowController.h"
#import "MacBookKeyboardView.h"
#import "MainWindowController.h"
#import "NSObject+SBJson.h"

@protocol KeyboardEditorRootViewDelegate <NSObject>
- (void)keyboardEditorRootViewDidResize:(NSView *)view;
@end

@interface KeyboardEditorRootView : NSView
@property (assign) id<KeyboardEditorRootViewDelegate> resizeDelegate;
@end

@implementation KeyboardEditorRootView

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self.resizeDelegate keyboardEditorRootViewDidResize:self];
}

@end

@implementation MacBookKeyboardView

@synthesize keyItems, keyMapping, assignmentTypes, assignmentLabels;
@synthesize selectedKeyCode, capturedKeyCode, capturedKeyHasBinding, delegate;
@synthesize listeningForKeys, glowPhase, glowRemaining, glowTimer;
@synthesize keyboardUnitCount, keyboardTopY;

- (void)setKeyboardLayoutDefinition:(NSDictionary *)layout
{
    NSMutableArray *items = [NSMutableArray array];
    CGFloat maximumX = 0;
    CGFloat maximumY = 0;
    for (NSDictionary *row in [layout objectForKey:@"rows"]) {
        maximumY = fmax(maximumY, [[row objectForKey:@"y"] doubleValue]);
        for (NSDictionary *item in [row objectForKey:@"keys"]) {
            NSMutableDictionary *keyItem = [item mutableCopy];
            [keyItem setObject:[row objectForKey:@"y"] forKey:@"y"];
            [items addObject:keyItem];
            maximumX = fmax(maximumX, [[item objectForKey:@"x"] doubleValue] + [[item objectForKey:@"width"] doubleValue]);
        }
    }
    self.keyItems = items;
    self.keyboardUnitCount = maximumX;
    self.keyboardTopY = maximumY;
    [self setNeedsDisplay:YES];
}

- (void)setListeningForKeys:(BOOL)enabled
{
    listeningForKeys = enabled;
    if (enabled && !self.glowTimer) {
        self.glowTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
                                                          target:self
                                                        selector:@selector(advanceGlowAnimation:)
                                                        userInfo:nil
                                                         repeats:YES];
    } else if (!enabled && self.glowRemaining <= 0) {
        [self.glowTimer invalidate];
        self.glowTimer = nil;
    }
    [self setNeedsDisplay:YES];
}

- (void)showCapturedKeyCode:(NSString *)keyCode hasBinding:(BOOL)hasBinding
{
    [self showCapturedKeyCode:keyCode hasBinding:hasBinding actionTitle:nil];
}

- (void)showCapturedKeyCode:(NSString *)keyCode hasBinding:(BOOL)hasBinding actionTitle:(NSString *)actionTitle
{
    self.capturedKeyCode = keyCode;
    self.capturedKeyHasBinding = hasBinding;
    self.glowRemaining = 1.0;
    if (!self.glowTimer) {
        self.glowTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
                                                          target:self
                                                        selector:@selector(advanceGlowAnimation:)
                                                        userInfo:nil
                                                         repeats:YES];
    }
    [self setNeedsDisplay:YES];
}

- (void)advanceGlowAnimation:(NSTimer *)timer
{
    self.glowPhase += 0.18;
    if (!self.listeningForKeys) {
        self.glowRemaining = fmax(0, self.glowRemaining - 1.0 / 30.0);
        if (self.glowRemaining == 0) {
            [self.glowTimer invalidate];
            self.glowTimer = nil;
        }
    }
    [self setNeedsDisplay:YES];
}

- (NSRect)frameForKeyItem:(NSDictionary *)item
{
    CGFloat verticalUnits = (self.keyboardTopY - 332.0) * 1.06 / 50.0 + 1.0;
    CGFloat horizontalUnit = (NSWidth(self.bounds) - 36.0) / MAX(self.keyboardUnitCount, 1);
    CGFloat verticalUnit = (NSHeight(self.bounds) - 32.0) / MAX(verticalUnits, 1);
    CGFloat unit = fmax(1.0, fmin(horizontalUnit, verticalUnit));
    CGFloat keyHeight = unit;
    CGFloat x = 18 + [[item objectForKey:@"x"] doubleValue] * unit;
    CGFloat width = [[item objectForKey:@"width"] doubleValue] * unit - unit * 0.06;
    CGFloat heightScale = [[item objectForKey:@"height"] doubleValue];
    CGFloat height = [item[@"shape"] isEqualToString:@"vertical-enter"]
        ? keyHeight * 2 + unit * 0.06
        : (heightScale > 0 ? unit * heightScale : keyHeight);
    CGFloat rowY = [[item objectForKey:@"y"] doubleValue] + [[item objectForKey:@"dy"] doubleValue];
    CGFloat y = NSHeight(self.bounds) - 16 - (self.keyboardTopY - rowY) * unit * 1.06 / 50.0 - height;
    return NSMakeRect(x, y, width, height);
}

- (void)drawString:(NSString *)string inRect:(NSRect)rect fontSize:(CGFloat)size color:(NSColor *)color
{
    if ([string length] == 0) return;
    CGFloat fontSize = size;
    NSFont *font = [NSFont systemFontOfSize:fontSize weight:NSFontWeightMedium];
    NSSize textSize = [string sizeWithAttributes:@{NSFontAttributeName: font}];
    while (textSize.width > NSWidth(rect) - 4 && fontSize > 6) {
        fontSize -= 0.5;
        font = [NSFont systemFontOfSize:fontSize weight:NSFontWeightMedium];
        textSize = [string sizeWithAttributes:@{NSFontAttributeName: font}];
    }
    NSString *displayString = string;
    if (textSize.width > NSWidth(rect) - 4 && [string length] > 4) {
        NSUInteger keepCount = MAX(1, (NSUInteger)((NSWidth(rect) - 4) / (fontSize * 0.58)) - 3);
        displayString = [[string substringToIndex:MIN(keepCount, string.length)] stringByAppendingString:@"..."];
        textSize = [displayString sizeWithAttributes:@{NSFontAttributeName: font}];
    }
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color
    };
    NSRect textRect = NSMakeRect(NSMidX(rect) - textSize.width / 2,
                                 NSMidY(rect) - textSize.height / 2,
                                 textSize.width,
                                 textSize.height);
    [string drawInRect:textRect withAttributes:attributes];
}

- (NSBezierPath *)pathForKeyItem:(NSDictionary *)item frame:(NSRect)frame
{
    return [NSBezierPath bezierPathWithRoundedRect:frame xRadius:5 yRadius:5];
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect keyBounds = NSZeroRect;
    BOOL hasKeyBounds = NO;
    for (NSDictionary *item in self.keyItems) {
        NSRect keyRect = [self frameForKeyItem:item];
        keyBounds = hasKeyBounds ? NSUnionRect(keyBounds, keyRect) : keyRect;
        hasKeyBounds = YES;
    }
    NSRect chassis = NSInsetRect(keyBounds, -10, -10);
    [[NSColor colorWithCalibratedRed:0.72 green:0.69 blue:0.67 alpha:1] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:chassis xRadius:16 yRadius:16] fill];

    NSRect deck = NSInsetRect(chassis, 8, 8);
    [[NSColor colorWithCalibratedRed:0.15 green:0.15 blue:0.16 alpha:1] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:deck xRadius:12 yRadius:12] fill];

    for (NSDictionary *item in self.keyItems) {
        NSRect keyRect = [self frameForKeyItem:item];
        NSString *code = [item objectForKey:@"code"];
        NSDictionary *types = code ? [self.assignmentTypes objectForKey:code] : nil;
        NSUInteger leftCount = [[types objectForKey:@"left"] unsignedIntegerValue];
        NSUInteger rightCount = [[types objectForKey:@"right"] unsignedIntegerValue];
        NSUInteger discreteCount = [[types objectForKey:@"discrete"] unsignedIntegerValue];
        NSUInteger totalCount = [[types objectForKey:@"total"] unsignedIntegerValue];
        BOOL assigned = totalCount > 0;
        BOOL selected = code && [code isEqualToString:self.selectedKeyCode];
        BOOL captured = code && [code isEqualToString:self.capturedKeyCode];
        BOOL glowing = captured && (self.listeningForKeys || self.glowRemaining > 0);
        BOOL selectable = code != nil;

        NSRect shadowRect = keyRect;
        shadowRect.origin.y -= 3;
        [[NSColor colorWithCalibratedWhite:0.02 alpha:0.75] setFill];
        [[self pathForKeyItem:item frame:shadowRect] fill];

        NSColor *keyColor = discreteCount > 0
            ? [NSColor colorWithCalibratedRed:0.96 green:0.79 blue:0.43 alpha:1]
            : (assigned
                ? [NSColor colorWithCalibratedRed:0.77 green:0.91 blue:0.83 alpha:1]
                : [NSColor colorWithCalibratedWhite:0.31 alpha:1]);
        if (glowing && !self.capturedKeyHasBinding) {
            keyColor = [NSColor colorWithCalibratedRed:0.38 green:0.88 blue:0.66 alpha:0.95];
        }
        if (!selectable) keyColor = [NSColor colorWithCalibratedWhite:0.25 alpha:1];
        [keyColor setFill];
        [[self pathForKeyItem:item frame:keyRect] fill];

        NSColor *borderColor = glowing
            ? [NSColor colorWithCalibratedRed:0.25 green:1 blue:0.66 alpha:1]
            : (selected
                ? [NSColor colorWithCalibratedRed:0.95 green:0.66 blue:0.33 alpha:1]
                : [NSColor colorWithCalibratedWhite:assigned ? 0.96 : 0.42 alpha:1]);
        [borderColor setStroke];
        NSBezierPath *border = [self pathForKeyItem:item frame:NSInsetRect(keyRect, 0.75, 0.75)];
        [border setLineWidth:glowing ? 3.5 : (selected ? 2.5 : 1)];
        [border stroke];

        if (glowing) {
            CGFloat pulse = (sin(self.glowPhase) + 1) / 2;
            CGFloat alpha = self.listeningForKeys ? 0.25 + pulse * 0.45 : self.glowRemaining * 0.7;
            NSBezierPath *glow = [self pathForKeyItem:item frame:NSInsetRect(keyRect, -1, -1)];
            [glow setLineWidth:3];
            [NSGraphicsContext saveGraphicsState];
            NSShadow *shadow = [[NSShadow alloc] init];
            [shadow setShadowColor:[NSColor colorWithCalibratedRed:0.24 green:1 blue:0.68 alpha:alpha]];
            [shadow setShadowBlurRadius:12 + pulse * 8];
            [shadow set];
            [[NSColor colorWithCalibratedRed:0.24 green:1 blue:0.68 alpha:alpha] setStroke];
            [glow stroke];
            [NSGraphicsContext restoreGraphicsState];
        }

        NSString *label = [item objectForKey:@"label"];
        if (!label && code) label = [self.keyMapping objectForKey:code];
        NSString *secondaryLabel = [item objectForKey:@"secondary"];
        NSString *assignmentLabel = code ? [self.assignmentLabels objectForKey:code] : nil;
        NSColor *textColor = (assigned || selected)
            ? [NSColor colorWithCalibratedWhite:0.14 alpha:1]
            : [NSColor colorWithCalibratedWhite:0.84 alpha:0.52];
        if (assignmentLabel.length > 0) {
            NSRect actionRect = NSMakeRect(NSMinX(keyRect) + 2, NSMaxY(keyRect) - 15, NSWidth(keyRect) - 4, 13);
            [self drawString:assignmentLabel inRect:actionRect fontSize:8 color:textColor];
            if (secondaryLabel) {
                NSRect secondaryRect = NSMakeRect(NSMinX(keyRect) + 3, NSMinY(keyRect) + NSHeight(keyRect) * 0.42,
                                                  NSWidth(keyRect) - 6, NSHeight(keyRect) * 0.25);
                NSRect primaryRect = NSMakeRect(NSMinX(keyRect) + 3, NSMinY(keyRect) + 1,
                                                NSWidth(keyRect) - 6, NSHeight(keyRect) * 0.35);
                [self drawString:secondaryLabel inRect:secondaryRect fontSize:8 color:textColor];
                [self drawString:label ?: @"" inRect:primaryRect fontSize:9 color:textColor];
            } else {
                NSRect keyLabelRect = NSMakeRect(NSMinX(keyRect) + 3, NSMinY(keyRect) + 2, NSWidth(keyRect) - 6, NSHeight(keyRect) - 18);
                [self drawString:label ?: @"" inRect:keyLabelRect fontSize:(NSWidth(keyRect) < 38 ? 9 : 11) color:textColor];
            }
        } else if ([item[@"shape"] isEqualToString:@"vertical-enter"]) {
            [self drawString:label ?: @"return" inRect:keyRect fontSize:12 color:textColor];
        } else if (secondaryLabel) {
            NSRect secondaryRect = NSMakeRect(NSMinX(keyRect) + 4, NSMinY(keyRect) + keyRect.size.height * 0.53,
                                              keyRect.size.width - 8, keyRect.size.height * 0.4);
            NSRect primaryRect = NSMakeRect(NSMinX(keyRect) + 4, NSMinY(keyRect) + 2,
                                            keyRect.size.width - 8, keyRect.size.height * 0.48);
            [self drawString:secondaryLabel inRect:secondaryRect fontSize:10 color:textColor];
            [self drawString:label ?: @"" inRect:primaryRect fontSize:12 color:textColor];
        } else {
            [self drawString:label ?: @"" inRect:keyRect fontSize:(keyRect.size.width < 38 ? 10 : 12) color:textColor];
        }

        if (assigned) {
            NSColor *markerColor = discreteCount > 0
                ? [NSColor colorWithCalibratedRed:0.62 green:0.37 blue:0.08 alpha:1]
                : [NSColor colorWithCalibratedRed:0.08 green:0.48 blue:0.33 alpha:1];
            if (leftCount) [self drawDirectionTriangleAt:NSMakePoint(NSMinX(keyRect) + 10, NSMinY(keyRect) + 11) pointsLeft:YES color:markerColor];
            if (rightCount) [self drawDirectionTriangleAt:NSMakePoint(NSMaxX(keyRect) - 10, NSMinY(keyRect) + 11) pointsLeft:NO color:markerColor];
            if (discreteCount > 0) {
                NSRect marker = NSMakeRect(NSMidX(keyRect) - 3, NSMinY(keyRect) + 7, 6, 6);
                [markerColor setFill];
                [[NSBezierPath bezierPathWithOvalInRect:marker] fill];
            }
            if (totalCount > 1) {
                [self drawString:[NSString stringWithFormat:@"%lu", (unsigned long)totalCount]
                          inRect:NSMakeRect(NSMidX(keyRect) - 10, NSMinY(keyRect) + 2, 20, 12)
                         fontSize:8 color:markerColor];
            }
        }
    }
}

- (void)drawDirectionTriangleAt:(NSPoint)point pointsLeft:(BOOL)pointsLeft color:(NSColor *)color
{
    NSBezierPath *triangle = [NSBezierPath bezierPath];
    if (pointsLeft) {
        [triangle moveToPoint:NSMakePoint(point.x - 4, point.y)];
        [triangle lineToPoint:NSMakePoint(point.x + 3, point.y + 4)];
        [triangle lineToPoint:NSMakePoint(point.x + 3, point.y - 4)];
    } else {
        [triangle moveToPoint:NSMakePoint(point.x + 4, point.y)];
        [triangle lineToPoint:NSMakePoint(point.x - 3, point.y + 4)];
        [triangle lineToPoint:NSMakePoint(point.x - 3, point.y - 4)];
    }
    [triangle closePath];
    [color setFill];
    [triangle fill];
}

- (NSView *)hitTest:(NSPoint)point
{
    for (NSDictionary *item in self.keyItems) {
        if ([item objectForKey:@"code"] && NSPointInRect(point, [self frameForKeyItem:item])) {
            return self;
        }
    }
    return nil;
}

- (void)mouseDown:(NSEvent *)event
{
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    for (NSDictionary *item in [self.keyItems reverseObjectEnumerator]) {
        NSString *code = [item objectForKey:@"code"];
        if (code && NSPointInRect(point, [self frameForKeyItem:item])) {
            [self setSelectedKeyCode:code];
            [self setNeedsDisplay:YES];
            [self.delegate keyboardViewDidSelectKeyCode:code];
            return;
        }
    }
}

@end

@interface KeyboardLayoutEditorController () <MacBookKeyboardViewDelegate, KeyboardEditorRootViewDelegate>
@property (retain) NSMutableDictionary *keyfile;
@property (retain) NSMutableArray *bindings;
@property (retain) MacBookKeyboardView *keyboardView;
@property (retain) NSArray *modifierValues;
@property (retain) NSArray *modifierTitles;
@property (retain) NSArray *actionKeys;
@property (retain) NSTextField *selectedKeyLabel;
@property (retain) NSTextField *nameField;
@property (retain) NSTextField *authorField;
@property (retain) NSTextField *descriptionField;
@property (retain) NSTextField *statusLabel;
@property (retain) NSTextField *titleLabel;
@property (retain) NSTextField *hintLabel;
@property (retain) NSTextField *keyboardLabel;
@property (retain) NSTextField *modeKeyLabel;
@property (retain) NSTextField *modifierColumnLabel;
@property (retain) NSTextField *actionColumnLabel;
@property (retain) NSTextField *valueColumnLabel;
@property (retain) NSButton *tableEditorButton;
@property (retain) NSButton *saveButton;
@property (retain) NSButton *revertButton;
@property (retain) NSButton *addBindingButton;
@property (retain) NSButton *captureBindingButton;
@property (retain) NSPopUpButton *modeKeyPopup;
@property (retain) NSPopUpButton *physicalKeyboardPopup;
@property (retain) NSScrollView *bindingRowsScrollView;
@property (retain) NSView *bindingRowsView;
@property (retain) NSArray *sortedKeyCodes;
@property (retain) NSString *selectedKeyCode;
@property (assign) BOOL hasUnrepairableLoadedData;
@property (retain) NSButton *listenForKeysSwitch;
@property (retain) id keyEventMonitor;
@property (retain) NSString *selectedModifierValue;
@property (assign) BOOL isOneShotCapture;
@property (assign) NSInteger pendingActionBindingIndex;
- (void)selectKeyCode:(NSString *)keyCode modifierValue:(NSString *)modifierValue;
- (NSEvent *)handleListeningKeyDown:(NSEvent *)event;
- (NSInteger)addBindingForKeyCode:(NSString *)keyCode preferredModifier:(NSString *)modifier;
@end

@implementation KeyboardLayoutEditorController

@synthesize mainController, keyControl, rootView;
@synthesize keyfile, bindings, keyboardView, modifierValues, modifierTitles, actionKeys;
@synthesize selectedKeyLabel, nameField, authorField, descriptionField, statusLabel;
@synthesize titleLabel, hintLabel, keyboardLabel, modeKeyLabel;
@synthesize modifierColumnLabel, actionColumnLabel, valueColumnLabel;
@synthesize tableEditorButton, saveButton, revertButton, addBindingButton, captureBindingButton;
@synthesize modeKeyPopup, physicalKeyboardPopup, bindingRowsScrollView, bindingRowsView, sortedKeyCodes, selectedKeyCode;
@synthesize hasUnrepairableLoadedData;
@synthesize listenForKeysSwitch, keyEventMonitor, selectedModifierValue;
@synthesize isOneShotCapture, pendingActionBindingIndex;

- (NSString *)displayLabelForKeyCode:(NSString *)keyCode
{
    for (NSDictionary *item in self.keyboardView.keyItems) {
        if ([[item objectForKey:@"code"] isEqualToString:keyCode]) {
            return [item objectForKey:@"label"] ?: [self.keyControl getKeynameForVirtual:keyCode];
        }
    }
    return [self.keyControl getKeynameForVirtual:keyCode] ?: @"?";
}

- (id)initWithKeyControl:(KeyControl *)kc
{
    self = [super init];
    if (self) {
        self.keyControl = kc;
        self.keyfile = [@{KEYFILE_KEYS_NODENAME: @[]} mutableCopy];
        self.bindings = [NSMutableArray array];
        self.pendingActionBindingIndex = NSNotFound;
        self.modifierValues = @[@"0", @"1", @"2", @"4", @"8", @"3", @"5", @"9", @"6", @"10", @"12", @"7", @"11", @"13", @"14", @"15"];
        self.modifierTitles = @[@"None", @"Shift", @"Control", @"Option", @"Command", @"Shift + Control", @"Shift + Option", @"Shift + Command", @"Control + Option", @"Control + Command", @"Option + Command", @"Shift + Control + Option", @"Shift + Control + Command", @"Shift + Option + Command", @"Control + Option + Command", @"Shift + Control + Option + Command"];
        self.sortedKeyCodes = [[self.keyControl.keyMapping allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
            return [[self.keyControl.keyMapping objectForKey:left] compare:[self.keyControl.keyMapping objectForKey:right]];
        }];
        NSDictionary *mapping = self.keyControl.adjustmentMapping ?: @{};
        self.actionKeys = [[mapping allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
            return [[mapping objectForKey:left] compare:[mapping objectForKey:right]];
        }];
        self.actionKeys = [self.actionKeys filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *key, NSDictionary *bindings) {
            return ![key isEqualToString:KEYFILE_ADJUSTMENT_REMAP_NODENAME];
        }]];
        [self buildUI];
    }
    return self;
}

- (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text size:(CGFloat)size
{
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    [label setStringValue:text ?: @""];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setFont:[NSFont systemFontOfSize:size]];
    return label;
}

- (NSTextField *)fieldWithFrame:(NSRect)frame placeholder:(NSString *)placeholder
{
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    [field setPlaceholderString:placeholder];
    [field setFont:[NSFont systemFontOfSize:11]];
    return field;
}

- (NSButton *)buttonWithFrame:(NSRect)frame title:(NSString *)title action:(SEL)action
{
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    [button setTitle:title];
    [button setBezelStyle:NSRoundedBezelStyle];
    [button setTarget:self];
    [button setAction:action];
    return button;
}

- (void)buildUI
{
    self.rootView = [[KeyboardEditorRootView alloc] initWithFrame:NSMakeRect(0, 0, 825, 463)];
    [(KeyboardEditorRootView *)self.rootView setResizeDelegate:self];
    [self.rootView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.rootView setWantsLayer:YES];
    [self.rootView layer].backgroundColor = [NSColor colorWithCalibratedWhite:0.13 alpha:1].CGColor;

    self.titleLabel = [self labelWithFrame:NSZeroRect text:@"Keyboard Editor (Experimental)" size:16];
    [self.titleLabel setFont:[NSFont boldSystemFontOfSize:16]];
    [self.rootView addSubview:self.titleLabel];

    self.hintLabel = [self labelWithFrame:NSZeroRect text:@"Select a key or capture a physical key to edit its bindings." size:11];
    [self.rootView addSubview:self.hintLabel];
    self.tableEditorButton = [self buttonWithFrame:NSZeroRect title:@"Table Editor" action:@selector(tableEditorClicked:)];
    [self.rootView addSubview:self.tableEditorButton];
    self.keyboardLabel = [self labelWithFrame:NSZeroRect text:@"Keyboard" size:11];
    [self.rootView addSubview:self.keyboardLabel];
    self.physicalKeyboardPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.physicalKeyboardPopup setTarget:self];
    [self.physicalKeyboardPopup setAction:@selector(physicalKeyboardChanged:)];
    [self.rootView addSubview:self.physicalKeyboardPopup];
    self.listenForKeysSwitch = [[NSButton alloc] initWithFrame:NSZeroRect];
    [self.listenForKeysSwitch setButtonType:NSSwitchButton];
    [self.listenForKeysSwitch setTitle:@"Listen for Key"];
    [self.listenForKeysSwitch setToolTip:@"Press a key while this window is focused to select it."];
    [self.listenForKeysSwitch setTarget:self];
    [self.listenForKeysSwitch setAction:@selector(listenForKeysChanged:)];
    [self.rootView addSubview:self.listenForKeysSwitch];
    self.captureBindingButton = [self buttonWithFrame:NSZeroRect title:@"Capture Binding" action:@selector(captureOneBindingClicked:)];
    [self.rootView addSubview:self.captureBindingButton];

    self.nameField = [self fieldWithFrame:NSMakeRect(20, 718, 220, 28) placeholder:@"Layout name"];
    self.authorField = [self fieldWithFrame:NSMakeRect(250, 718, 170, 28) placeholder:@"Author"];
    self.descriptionField = [self fieldWithFrame:NSMakeRect(430, 718, 450, 28) placeholder:@"Description"];
    [self.rootView addSubview:self.nameField];
    [self.rootView addSubview:self.authorField];
    [self.rootView addSubview:self.descriptionField];
    self.saveButton = [self buttonWithFrame:NSZeroRect title:@"Save and Activate" action:@selector(saveClicked:)];
    [self.rootView addSubview:self.saveButton];
    self.revertButton = [self buttonWithFrame:NSZeroRect title:@"Revert" action:@selector(revertClicked:)];
    [self.rootView addSubview:self.revertButton];

    self.keyboardView = [[MacBookKeyboardView alloc] initWithFrame:self.rootView.bounds];
    [self.keyboardView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.keyboardView setKeyMapping:self.keyControl.keyMapping];
    [self.keyboardView setAssignmentTypes:@{}];
    [self.keyboardView setDelegate:self];
    [self.rootView addSubview:self.keyboardView];
    [self reloadPhysicalKeyboardLayout];

    CGFloat inspectorX = 20;
    self.selectedKeyLabel = [self labelWithFrame:NSMakeRect(inspectorX, 165, 420, 24) text:@"Select a key" size:14];
    [self.selectedKeyLabel setFont:[NSFont boldSystemFontOfSize:12]];
    [self.rootView addSubview:self.selectedKeyLabel];

    self.addBindingButton = [self buttonWithFrame:NSZeroRect title:@"Add Binding" action:@selector(addBindingClicked:)];
    [self.rootView addSubview:self.addBindingButton];
    self.modifierColumnLabel = [self labelWithFrame:NSZeroRect text:@"Modifier" size:10];
    [self.rootView addSubview:self.modifierColumnLabel];
    self.actionColumnLabel = [self labelWithFrame:NSZeroRect text:@"Action" size:10];
    [self.rootView addSubview:self.actionColumnLabel];
    self.valueColumnLabel = [self labelWithFrame:NSZeroRect text:@"Value / increment" size:10];
    [self.rootView addSubview:self.valueColumnLabel];

    self.modeKeyLabel = [self labelWithFrame:NSZeroRect text:@"Mode key" size:10];
    [self.rootView addSubview:self.modeKeyLabel];
    self.modeKeyPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    for (NSString *code in self.sortedKeyCodes) [self.modeKeyPopup addItemWithTitle:[self displayLabelForKeyCode:code]];
    [self.rootView addSubview:self.modeKeyPopup];

    self.bindingRowsScrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [self.bindingRowsScrollView setHasVerticalScroller:YES];
    [self.bindingRowsScrollView setAutohidesScrollers:YES];
    [self.bindingRowsScrollView setDrawsBackground:NO];
    self.bindingRowsView = [[NSView alloc] initWithFrame:NSZeroRect];
    [self.bindingRowsScrollView setDocumentView:self.bindingRowsView];
    [self.rootView addSubview:self.bindingRowsScrollView];

    self.statusLabel = [self labelWithFrame:NSZeroRect text:@"" size:10];
    [self.rootView addSubview:self.statusLabel];
    [self layoutEditorViews];
}

- (void)keyboardEditorRootViewDidResize:(NSView *)view
{
    [self layoutEditorViews];
}

- (void)layoutEditorViews
{
    CGFloat width = NSWidth(self.rootView.bounds);
    CGFloat height = NSHeight(self.rootView.bounds);
    if (width <= 0 || height <= 0 || !self.keyboardView) return;

    CGFloat padding = 16;
    CGFloat right = width - padding;
    CGFloat titleY = height - 38;
    BOOL compactWidth = width < 900;
    CGFloat optionsY = height - 72;
    CGFloat captureY = compactWidth ? height - 104 : optionsY;
    CGFloat metadataY = height - (compactWidth ? 140 : 108);

    [self.titleLabel setFrame:NSMakeRect(padding, titleY, fmax(180, width - 250), 24)];
    [self.tableEditorButton setFrame:NSMakeRect(right - 140, titleY - 1, 140, 27)];

    if (compactWidth) {
        [self.hintLabel setHidden:YES];
        [self.keyboardLabel setFrame:NSMakeRect(padding, optionsY + 4, 65, 18)];
        [self.physicalKeyboardPopup setFrame:NSMakeRect(82, optionsY, fmin(230, width - 100), 26)];
        [self.listenForKeysSwitch setFrame:NSMakeRect(padding, captureY + 1, 135, 24)];
    } else {
        [self.hintLabel setHidden:NO];
        [self.hintLabel setFrame:NSMakeRect(padding, optionsY + 4, 240, 18)];
        [self.keyboardLabel setFrame:NSMakeRect(260, optionsY + 4, 65, 18)];
        [self.physicalKeyboardPopup setFrame:NSMakeRect(324, optionsY, 230, 26)];
        [self.listenForKeysSwitch setFrame:NSMakeRect(566, optionsY + 1, 135, 24)];
    }
    CGFloat captureWidth = 128;
    CGFloat captureX = compactWidth ? 155 : 710;
    [self.captureBindingButton setFrame:NSMakeRect(captureX, captureY, captureWidth, 27)];

    CGFloat metaRight = right;
    CGFloat revertWidth = 70;
    CGFloat saveWidth = 132;
    [self.revertButton setFrame:NSMakeRect(metaRight - revertWidth, metadataY, revertWidth, 28)];
    [self.saveButton setFrame:NSMakeRect(metaRight - revertWidth - 8 - saveWidth, metadataY, saveWidth, 28)];
    CGFloat metadataLeft = padding;
    CGFloat nameWidth = fmin(170, width * 0.19);
    CGFloat authorWidth = fmin(130, width * 0.15);
    CGFloat nameX = metadataLeft;
    CGFloat authorX = nameX + nameWidth + 8;
    CGFloat descriptionX = authorX + authorWidth + 8;
    CGFloat descriptionWidth = fmax(60, NSMinX(self.saveButton.frame) - descriptionX - 10);
    [self.nameField setFrame:NSMakeRect(nameX, metadataY, nameWidth, 28)];
    [self.authorField setFrame:NSMakeRect(authorX, metadataY, authorWidth, 28)];
    [self.descriptionField setFrame:NSMakeRect(descriptionX, metadataY, descriptionWidth, 28)];

    CGFloat inspectorHeight = fmin(190, fmax(148, height * 0.3));
    CGFloat inspectorTop = inspectorHeight;
    CGFloat inspectorWidth = width - 2 * padding;
    CGFloat rowWidth = inspectorWidth;
    if (width < 720) {
        [self.selectedKeyLabel setFrame:NSMakeRect(padding, inspectorTop - 27, inspectorWidth, 22)];
        [self.modeKeyLabel setFrame:NSMakeRect(padding, inspectorTop - 53, 65, 18)];
        [self.modeKeyPopup setFrame:NSMakeRect(padding + 68, inspectorTop - 57, 145, 24)];
        [self.addBindingButton setFrame:NSMakeRect(right - 108, inspectorTop - 57, 108, 28)];
    } else {
        [self.selectedKeyLabel setFrame:NSMakeRect(padding, inspectorTop - 28, fmax(160, inspectorWidth - 450), 24)];
        [self.modeKeyLabel setFrame:NSMakeRect(width - 360, inspectorTop - 25, 65, 18)];
        [self.modeKeyPopup setFrame:NSMakeRect(width - 292, inspectorTop - 29, 165, 24)];
        [self.addBindingButton setFrame:NSMakeRect(right - 108, inspectorTop - 31, 108, 28)];
    }

    CGFloat removeWidth = fmin(74, fmax(56, rowWidth * 0.13));
    CGFloat valueWidth = fmin(130, fmax(90, rowWidth * 0.22));
    CGFloat modifierWidth = fmin(150, fmax(100, rowWidth * 0.24));
    CGFloat actionX = modifierWidth + 8;
    CGFloat valueX = rowWidth - removeWidth - 19 - valueWidth - 18;
    CGFloat actionWidth = fmax(110, valueX - actionX - 8);
    CGFloat columnY = inspectorTop - (width < 720 ? 78 : 49);
    [self.modifierColumnLabel setFrame:NSMakeRect(padding, columnY, modifierWidth, 16)];
    [self.actionColumnLabel setFrame:NSMakeRect(padding + actionX, columnY, actionWidth, 16)];
    [self.valueColumnLabel setFrame:NSMakeRect(padding + valueX, columnY, valueWidth, 16)];
    CGFloat rowsBottom = 20;
    CGFloat rowsTop = columnY - 4;
    [self.bindingRowsScrollView setFrame:NSMakeRect(padding, rowsBottom, inspectorWidth, fmax(32, rowsTop - rowsBottom))];
    [self.bindingRowsView setFrameSize:NSMakeSize(rowWidth, NSHeight(self.bindingRowsScrollView.bounds))];
    [self.bindingRowsScrollView setHasHorizontalScroller:NO];
    [self.statusLabel setFrame:NSMakeRect(padding, 1, inspectorWidth, 18)];

    CGFloat keyboardBottom = inspectorHeight + 4;
    CGFloat keyboardTop = metadataY - 8;
    CGFloat keyboardHeight = fmax(0, keyboardTop - keyboardBottom);
    [self.keyboardView setFrame:NSMakeRect(0, keyboardBottom, width, keyboardHeight)];
    [self.keyboardView setNeedsDisplay:YES];
    [self rebuildBindingRows];
}

- (IBAction)physicalKeyboardChanged:(NSPopUpButton *)sender
{
    [self.keyControl selectPhysicalKeyboardLayout:[[sender selectedItem] representedObject]];
}

- (void)reloadPhysicalKeyboardLayout
{
    NSDictionary *layout = [self.keyControl physicalKeyboardLayoutDefinition];
    [self.keyboardView setKeyboardLayoutDefinition:layout ?: @{}];
    [self.keyboardView setKeyMapping:self.keyControl.keyMapping];

    [self.physicalKeyboardPopup removeAllItems];
    for (NSDictionary *option in [self.keyControl physicalKeyboardLayoutOptions]) {
        [self.physicalKeyboardPopup addItemWithTitle:[option objectForKey:@"name"]];
        [[self.physicalKeyboardPopup lastItem] setRepresentedObject:[option objectForKey:@"id"]];
    }
    NSUInteger layoutIndex = [[self.keyControl physicalKeyboardLayoutOptions] indexOfObjectPassingTest:^BOOL(NSDictionary *option, NSUInteger index, BOOL *stop) {
        return [[option objectForKey:@"id"] isEqualToString:self.keyControl.physicalKeyboardLayoutIdentifier];
    }];
    if (layoutIndex != NSNotFound) [self.physicalKeyboardPopup selectItemAtIndex:(NSInteger)layoutIndex];

    NSString *modeKey = [self.keyfile objectForKey:KEYFILE_MODEKEY_NODENAME] ?: @"53";
    [self.modeKeyPopup removeAllItems];
    for (NSString *code in self.sortedKeyCodes) [self.modeKeyPopup addItemWithTitle:[self displayLabelForKeyCode:code]];
    NSUInteger modeIndex = [self.sortedKeyCodes indexOfObject:modeKey];
    if (modeIndex != NSNotFound) [self.modeKeyPopup selectItemAtIndex:(NSInteger)modeIndex];

    if (self.selectedKeyCode) {
        NSString *keyName = [self displayLabelForKeyCode:self.selectedKeyCode];
        NSString *suffix = nil;
        BOOL displayed = NO;
        for (NSDictionary *item in self.keyboardView.keyItems) {
            if ([[item objectForKey:@"code"] isEqualToString:self.selectedKeyCode]) {
                displayed = YES;
                break;
            }
        }
        if (!displayed) suffix = @" (not on this physical keyboard)";
        [self.selectedKeyLabel setStringValue:[NSString stringWithFormat:@"%@ - keycode %@%@", keyName, self.selectedKeyCode, suffix ?: @""]];
    }
    [self.keyboardView setNeedsDisplay:YES];
}

- (void)loadKeyfile:(NSDictionary *)keyfile
{
    NSError *validationError = nil;
    BOOL validKeyfile = [self.keyControl validateKeyfile:keyfile error:&validationError];
    self.hasUnrepairableLoadedData = !validKeyfile && validationError.code == 2;
    self.keyfile = [keyfile mutableCopy];
    self.bindings = [NSMutableArray array];
    id rawBindings = [keyfile objectForKey:KEYFILE_KEYS_NODENAME];
    NSArray *keyBindings = [rawBindings isKindOfClass:[NSArray class]] ? rawBindings : @[];
    for (id rawBinding in keyBindings) {
        if (![rawBinding isKindOfClass:[NSDictionary class]]) continue;
        [self.bindings addObject:[rawBinding mutableCopy]];
    }
    [self.nameField setStringValue:[keyfile objectForKey:KEYFILE_NAME_NODENAME] ?: @""];
    [self.authorField setStringValue:[keyfile objectForKey:KEYFILE_AUTHOR_NODENAME] ?: @""];
    [self.descriptionField setStringValue:[keyfile objectForKey:KEYFILE_DESCRIPTION_NODENAME] ?: @""];
    NSString *modeKey = [keyfile objectForKey:KEYFILE_MODEKEY_NODENAME] ?: @"53";
    NSUInteger modeIndex = [self.sortedKeyCodes indexOfObject:modeKey];
    if (modeIndex != NSNotFound) [self.modeKeyPopup selectItemAtIndex:(NSInteger)modeIndex];
    self.selectedKeyCode = nil;
    [self refreshKeyStates];
    [self.selectedKeyLabel setStringValue:@"Select a key"];
    [self rebuildBindingRows];
    if (!validKeyfile) {
        [self.statusLabel setStringValue:[NSString stringWithFormat:@"Layout needs attention: %@", validationError.localizedDescription]];
    } else {
        [self.statusLabel setStringValue:@""];
    }
    [self.keyControl loadAvailableDevelopPresetsWithCompletion:^(NSArray *presets) {
        [self rebuildBindingRows];
    }];
}

- (void)startNewLayout
{
    self.keyfile = [@{
        KEYFILE_NAME_NODENAME: @"",
        KEYFILE_AUTHOR_NODENAME: @"",
        KEYFILE_DESCRIPTION_NODENAME: @"",
        KEYFILE_UUID_NODENAME: [[NSUUID UUID] UUIDString],
        KEYFILE_LRVERSION_NODENAME: @"4",
        KEYFILE_MODEKEY_NODENAME: @"53",
        KEYFILE_KEYS_NODENAME: @[]
    } mutableCopy];
    self.bindings = [NSMutableArray array];
    self.hasUnrepairableLoadedData = NO;
    [self.nameField setStringValue:@""];
    [self.authorField setStringValue:@""];
    [self.descriptionField setStringValue:@""];
    NSUInteger defaultModeIndex = [self.sortedKeyCodes indexOfObject:@"53"];
    if (defaultModeIndex != NSNotFound) [self.modeKeyPopup selectItemAtIndex:(NSInteger)defaultModeIndex];
    self.selectedKeyCode = nil;
    [self refreshKeyStates];
    [self.selectedKeyLabel setStringValue:@"Select a key"];
    [self rebuildBindingRows];
    [self.statusLabel setStringValue:@"New layout"];
    [self.keyControl loadAvailableDevelopPresetsWithCompletion:^(NSArray *presets) {
        [self rebuildBindingRows];
    }];
}

- (NSArray *)bindingsForKeyCode:(NSString *)keyCode
{
    NSMutableArray *matches = [NSMutableArray array];
    for (NSDictionary *binding in self.bindings) {
        if ([[binding objectForKey:KEYFILE_KEY_NODENAME] isEqualToString:keyCode]) {
            [matches addObject:binding];
        }
    }
    return matches;
}

- (NSString *)primaryActionForAdjustments:(NSDictionary *)adjustments
{
    NSArray *actions = [[adjustments allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *action in actions) {
        if (![action isEqualToString:KEYFILE_ADJUSTMENT_REMAP_NODENAME]) return action;
    }
    return [actions firstObject];
}

- (void)rebuildBindingRows
{
    for (NSView *view in [[self.bindingRowsView subviews] copy]) {
        [view removeFromSuperview];
    }

    NSArray *visibleBindings = [self bindingsForKeyCode:self.selectedKeyCode];
    CGFloat rowHeight = 30;
    CGFloat rowGap = 4;
    CGFloat contentHeight = fmax(108, visibleBindings.count * (rowHeight + rowGap));
    CGFloat rowWidth = fmax(420, NSWidth(self.bindingRowsView.frame));
    CGFloat removeWidth = fmin(74, fmax(56, rowWidth * 0.13));
    CGFloat valueWidth = fmin(130, fmax(90, rowWidth * 0.22));
    CGFloat modifierWidth = fmin(150, fmax(100, rowWidth * 0.24));
    CGFloat actionX = modifierWidth + 8;
    CGFloat valueX = rowWidth - removeWidth - 19 - valueWidth - 18;
    CGFloat actionWidth = fmax(110, valueX - actionX - 8);
    [self.bindingRowsView setFrame:NSMakeRect(0, 0, rowWidth, contentHeight)];

    for (NSUInteger visibleIndex = 0; visibleIndex < visibleBindings.count; visibleIndex++) {
        NSDictionary *binding = [visibleBindings objectAtIndex:visibleIndex];
        NSUInteger bindingIndex = [self.bindings indexOfObjectIdenticalTo:binding];
        CGFloat y = contentHeight - (visibleIndex + 1) * (rowHeight + rowGap);
        NSView *row = [[NSView alloc] initWithFrame:NSMakeRect(0, y, rowWidth, rowHeight)];
        NSString *rowModifier = [binding objectForKey:KEYFILE_MODIFIERS_NODENAME] ?: @"0";
        if (self.selectedModifierValue && [rowModifier isEqualToString:self.selectedModifierValue]) {
            [row setWantsLayer:YES];
            [row layer].backgroundColor = [NSColor colorWithCalibratedRed:0.25 green:0.34 blue:0.30 alpha:0.8].CGColor;
        }

        NSPopUpButton *modifier = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 1, modifierWidth, 26) pullsDown:NO];
        for (NSUInteger index = 0; index < self.modifierTitles.count; index++) {
            [modifier addItemWithTitle:[self.modifierTitles objectAtIndex:index]];
            [[modifier lastItem] setRepresentedObject:[self.modifierValues objectAtIndex:index]];
        }
        NSString *modifierValue = rowModifier;
        NSUInteger modifierIndex = [self.modifierValues indexOfObject:modifierValue];
        if (modifierIndex != NSNotFound) [modifier selectItemAtIndex:(NSInteger)modifierIndex];
        [modifier setTag:(NSInteger)bindingIndex];
        [modifier setTarget:self];
        [modifier setAction:@selector(bindingModifierChanged:)];
        [row addSubview:modifier];

        NSDictionary *adjustments = [binding objectForKey:KEYFILE_ADJUSTMENTS_NODENAME] ?: @{};
        NSString *action = [self primaryActionForAdjustments:adjustments];
        NSUInteger actionIndex = [self.actionKeys indexOfObject:action];
        NSPopUpButton *actionPopup;
        if (actionIndex == NSNotFound) {
            actionPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(actionX, 1, actionWidth, 26) pullsDown:NO];
            [actionPopup addItemWithTitle:@"Remap (edit in Table Editor)"];
            [actionPopup setEnabled:NO];
        } else {
            actionPopup = VSCOCreateActionPopup(self.actionKeys, self.keyControl.adjustmentMapping, action, NSMakeRect(actionX, 1, actionWidth, 26));
            [actionPopup setTag:(NSInteger)bindingIndex];
            [actionPopup setTarget:self];
            [actionPopup setAction:@selector(bindingActionChanged:)];
        }
        [row addSubview:actionPopup];

        id value = [adjustments objectForKey:action];
        NSTextField *valueField;
        if ([action isEqualToString:@"_SetPreset"]) {
            NSComboBox *presetField = [[NSComboBox alloc] initWithFrame:NSMakeRect(valueX, 1, valueWidth, 26)];
            [presetField setCompletes:YES];
            [presetField addItemsWithObjectValues:self.keyControl.availableDevelopPresets ?: @[]];
            valueField = presetField;
        } else {
            valueField = [self fieldWithFrame:NSMakeRect(valueX, 1, valueWidth, 26) placeholder:@"Value"];
        }
        [valueField setStringValue:[value description] ?: @""];
        [valueField setTag:(NSInteger)bindingIndex + 10000];
        [valueField setDelegate:self];
        [valueField setEnabled:actionIndex != NSNotFound];
        [row addSubview:valueField];

        NSDictionary *limits = [self.keyControl.adjustmentLimits objectForKey:action];
        NSNumber *number = [self numericValue:value];
        if (limits && number) {
            NSStepper *stepper = [[NSStepper alloc] initWithFrame:NSMakeRect(valueX + valueWidth + 3, 1, 19, 26)];
            double maximum = [[limits objectForKey:@"max"] doubleValue];
            id minimum = [limits objectForKey:@"min"];
            double increment = minimum && minimum != [NSNull null] ? fabs([minimum doubleValue]) : 1.0;
            [stepper setMinValue:-maximum];
            [stepper setMaxValue:maximum];
            [stepper setIncrement:increment > 0 ? increment : 1.0];
            [stepper setDoubleValue:[number doubleValue]];
            [stepper setTag:(NSInteger)bindingIndex];
            [stepper setTarget:self];
            [stepper setAction:@selector(bindingValueStepped:)];
            [row addSubview:stepper];
        }

        NSButton *remove = [self buttonWithFrame:NSMakeRect(rowWidth - removeWidth, 1, removeWidth - 4, 26) title:@"Remove" action:@selector(removeBindingClicked:)];
        [remove setTag:(NSInteger)bindingIndex];
        [row addSubview:remove];
        [self.bindingRowsView addSubview:row];
        if ((NSInteger)bindingIndex == self.pendingActionBindingIndex) {
            self.pendingActionBindingIndex = NSNotFound;
            [self.rootView.window makeFirstResponder:actionPopup];
        }
    }

    if (visibleBindings.count == 0) {
        [self.bindingRowsView addSubview:[self labelWithFrame:NSMakeRect(0, 42, 400, 24) text:@"No bindings for this key" size:12]];
    }
}

- (void)refreshKeyStates
{
    NSMutableDictionary *typesByKey = [NSMutableDictionary dictionary];
    for (NSDictionary *binding in self.bindings) {
        NSString *code = [binding objectForKey:KEYFILE_KEY_NODENAME];
        NSMutableDictionary *types = [typesByKey objectForKey:code];
        if (!types) {
            types = [@{@"left": @0, @"right": @0, @"discrete": @0, @"total": @0} mutableCopy];
            [typesByKey setObject:types forKey:code];
        }
        [types setObject:@([[types objectForKey:@"total"] unsignedIntegerValue] + 1) forKey:@"total"];

        NSDictionary *adjustments = [binding objectForKey:KEYFILE_ADJUSTMENTS_NODENAME];
        for (NSString *action in adjustments) {
            id rawValue = [adjustments objectForKey:action];
            NSScanner *scanner = [NSScanner scannerWithString:[rawValue description]];
            double value = 0;
            BOOL numeric = [scanner scanDouble:&value] && [scanner isAtEnd];
            BOOL slider = [self.keyControl.adjustmentLimits objectForKey:action] != nil;
            NSString *type = (slider && numeric) ? (value < 0 ? @"left" : (value > 0 ? @"right" : nil)) : @"discrete";
            if (type) [types setObject:@([[types objectForKey:type] unsignedIntegerValue] + 1) forKey:type];
        }
    }
    [self.keyboardView setAssignmentTypes:typesByKey];
    [self.keyboardView setNeedsDisplay:YES];
}

- (void)keyboardViewDidSelectKeyCode:(NSString *)keyCode
{
    [self selectKeyCode:keyCode modifierValue:nil];
}

- (void)selectKeyCode:(NSString *)keyCode modifierValue:(NSString *)modifierValue
{
    self.selectedKeyCode = keyCode;
    self.selectedModifierValue = modifierValue;
    [self.keyboardView setSelectedKeyCode:keyCode];
    [self.keyboardView setNeedsDisplay:YES];
    NSString *keyName = [self displayLabelForKeyCode:self.selectedKeyCode];
    [self.selectedKeyLabel setStringValue:[NSString stringWithFormat:@"%@ - keycode %@", keyName, self.selectedKeyCode]];
    [self rebuildBindingRows];
    [self.statusLabel setStringValue:@""];
}

- (IBAction)listenForKeysChanged:(NSButton *)sender
{
    if ([sender state] == NSOnState) {
        if (!self.keyEventMonitor) {
            __weak KeyboardLayoutEditorController *weakSelf = self;
            self.keyEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
                if (!weakSelf) return event;
                return [weakSelf handleListeningKeyDown:event];
            }];
        }
        [self.keyboardView setListeningForKeys:YES];
        [self.statusLabel setStringValue:@"Listening while this window is focused. Press a key to select it."];
    } else {
        [self stopListeningForKeys];
        [self.statusLabel setStringValue:@"Key listening stopped."];
    }
}

- (IBAction)captureOneBindingClicked:(id)sender
{
    self.isOneShotCapture = YES;
    if (self.listenForKeysSwitch.state != NSOnState) {
        [self.listenForKeysSwitch setState:NSOnState];
        [self listenForKeysChanged:self.listenForKeysSwitch];
    }
    [self.statusLabel setStringValue:@"Press one key with its modifiers. It will be selected or added as a draft binding."];
}

- (void)stopListeningForKeys
{
    if (self.keyEventMonitor) {
        [NSEvent removeMonitor:self.keyEventMonitor];
        self.keyEventMonitor = nil;
    }
    [self.listenForKeysSwitch setState:NSOffState];
    self.isOneShotCapture = NO;
    [self.keyboardView setListeningForKeys:NO];
}

- (NSEvent *)handleListeningKeyDown:(NSEvent *)event
{
    if (!self.listenForKeysSwitch.state || !self.rootView.window.isKeyWindow) return event;

    NSString *keyCode = [NSString stringWithFormat:@"%hu", event.keyCode];
    BOOL isDisplayedKey = NO;
    for (NSDictionary *item in self.keyboardView.keyItems) {
        if ([[item objectForKey:@"code"] isEqualToString:keyCode]) {
            isDisplayedKey = YES;
            break;
        }
    }
    if (!isDisplayedKey) {
        [self.statusLabel setStringValue:[NSString stringWithFormat:@"Keycode %@ is not shown on this keyboard.", keyCode]];
        return nil;
    }

    NSEventModifierFlags flags = event.modifierFlags;
    NSUInteger modifierMask = 0;
    if (flags & NSEventModifierFlagShift) modifierMask |= 1;
    if (flags & NSEventModifierFlagControl) modifierMask |= 2;
    if (flags & NSEventModifierFlagOption) modifierMask |= 4;
    if (flags & NSEventModifierFlagCommand) modifierMask |= 8;
    NSString *modifierValue = [NSString stringWithFormat:@"%lu", (unsigned long)modifierMask];
    NSInteger matchingIndex = NSNotFound;
    for (NSUInteger index = 0; index < self.bindings.count; index++) {
        NSDictionary *binding = [self.bindings objectAtIndex:index];
        if ([[binding objectForKey:KEYFILE_KEY_NODENAME] isEqualToString:keyCode] &&
            [[binding objectForKey:KEYFILE_MODIFIERS_NODENAME] isEqualToString:modifierValue]) {
            matchingIndex = (NSInteger)index;
            break;
        }
    }
    self.pendingActionBindingIndex = self.isOneShotCapture ? matchingIndex : NSNotFound;
    [self selectKeyCode:keyCode modifierValue:modifierValue];
    [self.keyboardView showCapturedKeyCode:keyCode hasBinding:(matchingIndex != NSNotFound)];

    NSString *keyName = [self displayLabelForKeyCode:keyCode];
    BOOL hasMatchingBinding = matchingIndex != NSNotFound;
    NSUInteger modifierIndex = [self.modifierValues indexOfObject:modifierValue];
    NSString *modifierTitle = [self.modifierTitles objectAtIndex:modifierIndex];
    if (self.isOneShotCapture && !hasMatchingBinding) {
        NSInteger addedIndex = [self addBindingForKeyCode:keyCode preferredModifier:modifierValue];
        if (addedIndex == NSNotFound) return nil;
    }
    NSString *message = self.isOneShotCapture
        ? (hasMatchingBinding
            ? [NSString stringWithFormat:@"%@ with %@ is already bound. Choose its action or value below.", keyName, modifierTitle]
            : [NSString stringWithFormat:@"Binding added for %@ with %@. Choose its action or value, then save.", keyName, modifierTitle])
        : (hasMatchingBinding
            ? [NSString stringWithFormat:@"%@ with %@ is already bound. Its binding is highlighted below.", keyName, modifierTitle]
            : [NSString stringWithFormat:@"%@ with %@ has no binding. Add Binding will use this modifier.", keyName, modifierTitle]);
    BOOL wasOneShot = self.isOneShotCapture;
    if (wasOneShot) [self stopListeningForKeys];
    [self.statusLabel setStringValue:message];
    return nil;
}

- (BOOL)modifier:(NSString *)modifier isUsedForBindingAtIndex:(NSInteger)excludedIndex
{
    for (NSUInteger index = 0; index < self.bindings.count; index++) {
        if ((NSInteger)index == excludedIndex) continue;
        NSDictionary *binding = [self.bindings objectAtIndex:index];
        if ([[binding objectForKey:KEYFILE_KEY_NODENAME] isEqualToString:self.selectedKeyCode] &&
            [[binding objectForKey:KEYFILE_MODIFIERS_NODENAME] isEqualToString:modifier]) return YES;
    }
    return NO;
}

- (void)bindingModifierChanged:(NSPopUpButton *)sender
{
    NSInteger index = [sender tag];
    if (index < 0 || index >= (NSInteger)self.bindings.count) return;
    NSString *modifier = [[sender selectedItem] representedObject];
    if ([self modifier:modifier isUsedForBindingAtIndex:index]) {
        [self.statusLabel setStringValue:@"This key already has a binding for that modifier combination."];
        [self rebuildBindingRows];
        return;
    }
    [[self.bindings objectAtIndex:(NSUInteger)index] setObject:modifier forKey:KEYFILE_MODIFIERS_NODENAME];
    [self refreshKeyStates];
    [self.statusLabel setStringValue:@"Modifier changed. Save to apply."];
}

- (NSNumber *)numericValue:(id)value
{
    if (!value) return nil;
    NSScanner *scanner = [NSScanner scannerWithString:[value description]];
    double number = 0;
    if (![scanner scanDouble:&number] || ![scanner isAtEnd]) return nil;
    return [NSNumber numberWithDouble:number];
}

- (void)bindingActionChanged:(NSPopUpButton *)sender
{
    NSInteger index = [sender tag];
    NSString *newAction = [[sender selectedItem] representedObject];
    if (index < 0 || index >= (NSInteger)self.bindings.count || ![self.actionKeys containsObject:newAction]) return;

    NSMutableDictionary *binding = [self.bindings objectAtIndex:(NSUInteger)index];
    NSDictionary *oldAdjustments = [binding objectForKey:KEYFILE_ADJUSTMENTS_NODENAME];
    NSString *oldAction = [self primaryActionForAdjustments:oldAdjustments];
    id oldValue = [oldAdjustments objectForKey:oldAction];
    id value = oldValue;
    NSDictionary *limits = [self.keyControl.adjustmentLimits objectForKey:newAction];
    NSNumber *oldNumber = [self numericValue:oldValue];
    if (limits && !oldNumber) {
        id minimum = [limits objectForKey:@"min"];
        value = minimum && minimum != [NSNull null] ? [minimum description] : @"1";
    } else if (!limits && ![oldValue isKindOfClass:[NSString class]]) {
        value = @"1";
    }
    if ([newAction isEqualToString:@"_SetPreset"]) value = @"";
    if (!value) {
        id minimum = [limits objectForKey:@"min"];
        value = minimum && minimum != [NSNull null] ? [minimum description] : @"1";
    }
    NSMutableDictionary *newAdjustments = [oldAdjustments mutableCopy] ?: [NSMutableDictionary dictionary];
    if (oldAction && ![oldAction isEqualToString:newAction]) [newAdjustments removeObjectForKey:oldAction];
    newAdjustments[newAction] = value;
    [binding setObject:newAdjustments forKey:KEYFILE_ADJUSTMENTS_NODENAME];
    [self rebuildBindingRows];
    [self refreshKeyStates];
    [self.statusLabel setStringValue:@"Action changed. Save to apply."];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    NSTextField *field = [notification object];
    NSInteger index = [field tag] - 10000;
    if (index < 0 || index >= (NSInteger)self.bindings.count) return;
    NSMutableDictionary *binding = [self.bindings objectAtIndex:(NSUInteger)index];
    NSDictionary *adjustments = [binding objectForKey:KEYFILE_ADJUSTMENTS_NODENAME];
    NSString *action = [self primaryActionForAdjustments:adjustments];
    if (!action) return;
    NSMutableDictionary *updatedAdjustments = [adjustments mutableCopy] ?: [NSMutableDictionary dictionary];
    updatedAdjustments[action] = [field stringValue];
    [binding setObject:updatedAdjustments forKey:KEYFILE_ADJUSTMENTS_NODENAME];
    [self refreshKeyStates];
    [self.statusLabel setStringValue:@"Value changed. Save to apply."];
}

- (void)bindingValueStepped:(NSStepper *)sender
{
    NSInteger index = [sender tag];
    if (index < 0 || index >= (NSInteger)self.bindings.count) return;
    NSView *row = [sender superview];
    NSTextField *field = nil;
    for (NSView *view in [row subviews]) {
        if ([view isKindOfClass:[NSTextField class]] && [view tag] >= 10000) {
            field = (NSTextField *)view;
            break;
        }
    }
    if (!field) return;
    [field setDoubleValue:[sender doubleValue]];
    NSMutableDictionary *binding = [self.bindings objectAtIndex:(NSUInteger)index];
    NSDictionary *adjustments = [binding objectForKey:KEYFILE_ADJUSTMENTS_NODENAME];
    NSString *action = [self primaryActionForAdjustments:adjustments];
    if (!action) return;
    NSMutableDictionary *updatedAdjustments = [adjustments mutableCopy] ?: [NSMutableDictionary dictionary];
    updatedAdjustments[action] = [field stringValue];
    [binding setObject:updatedAdjustments forKey:KEYFILE_ADJUSTMENTS_NODENAME];
    [self refreshKeyStates];
    [self.statusLabel setStringValue:@"Value changed. Save to apply."];
}

- (NSInteger)addBindingForKeyCode:(NSString *)keyCode preferredModifier:(NSString *)preferredModifier
{
    self.selectedKeyCode = keyCode;
    self.selectedModifierValue = preferredModifier;
    NSString *mod = preferredModifier;
    if (mod && [self modifier:mod isUsedForBindingAtIndex:NSNotFound]) mod = nil;
    for (NSString *candidate in self.modifierValues) {
        if (!mod && ![self modifier:candidate isUsedForBindingAtIndex:NSNotFound]) {
            mod = candidate;
            break;
        }
    }
    if (!mod) {
        [self.statusLabel setStringValue:@"All modifier combinations are already assigned for this key."];
        return NSNotFound;
    }
    NSString *action = [self.actionKeys containsObject:@"Exposure2012"] ? @"Exposure2012" : [self.actionKeys firstObject];
    if (!action) return NSNotFound;
    NSDictionary *limits = [self.keyControl.adjustmentLimits objectForKey:action];
    id minimum = [limits objectForKey:@"min"];
    NSString *value = minimum && minimum != [NSNull null] ? [minimum description] : @"1";
    [self.bindings addObject:[@{
        KEYFILE_KEY_NODENAME: self.selectedKeyCode,
        KEYFILE_MODIFIERS_NODENAME: mod,
        KEYFILE_ADJUSTMENTS_NODENAME: @{action: value}
    } mutableCopy]];
    NSInteger index = (NSInteger)self.bindings.count - 1;
    self.pendingActionBindingIndex = index;
    [self refreshKeyStates];
    [self rebuildBindingRows];
    return index;
}

- (void)addBindingClicked:(id)sender
{
    if (!self.selectedKeyCode) {
        [self.statusLabel setStringValue:@"Select a key first."];
        return;
    }
    NSInteger index = [self addBindingForKeyCode:self.selectedKeyCode preferredModifier:self.selectedModifierValue];
    if (index != NSNotFound) [self.statusLabel setStringValue:@"Binding added. Save to apply."];
}

- (void)removeBindingClicked:(id)sender
{
    NSInteger index = [sender tag];
    if (index < 0 || index >= (NSInteger)self.bindings.count) return;
    [self.bindings removeObjectAtIndex:(NSUInteger)index];
    [self refreshKeyStates];
    [self rebuildBindingRows];
    [self.statusLabel setStringValue:@"Binding removed. Save to apply it."];
}

- (void)saveClicked:(id)sender
{
    if (self.hasUnrepairableLoadedData) {
        [self.statusLabel setStringValue:@"Save blocked: this layout contains malformed binding data that cannot be edited safely."];
        return;
    }

    NSString *name = [self.nameField stringValue];
    if ([name length] == 0) {
        [self.statusLabel setStringValue:@"Name required."];
        return;
    }

    NSMutableDictionary *layout = [self.keyfile mutableCopy];
    [layout setObject:name forKey:KEYFILE_NAME_NODENAME];
    [layout setObject:[self.authorField stringValue] forKey:KEYFILE_AUTHOR_NODENAME];
    [layout setObject:[self.descriptionField stringValue] forKey:KEYFILE_DESCRIPTION_NODENAME];
    NSUInteger modeIndex = (NSUInteger)[self.modeKeyPopup indexOfSelectedItem];
    NSString *modeKey = modeIndex < self.sortedKeyCodes.count ? [self.sortedKeyCodes objectAtIndex:modeIndex] : @"53";
    [layout setObject:modeKey forKey:KEYFILE_MODEKEY_NODENAME];
    [layout setObject:self.bindings forKey:KEYFILE_KEYS_NODENAME];

    NSError *error = nil;
    if (![self.keyControl validateKeyfile:layout error:&error]) {
        [self.statusLabel setStringValue:[NSString stringWithFormat:@"Save failed: %@", error.localizedDescription]];
        return;
    }
    if (![self.keyControl saveKeyfile:layout error:&error]) {
        [self.statusLabel setStringValue:[NSString stringWithFormat:@"Save failed: %@", error.localizedDescription]];
        return;
    }

    self.keyfile = [layout mutableCopy];
    if (self.mainController) {
        self.mainController.keyfileList = [self.keyControl getKeyfileList];
        self.mainController.selectedKeyfile = [self.keyControl.keyfileList objectForKey:[layout objectForKey:KEYFILE_UUID_NODENAME]];
        [self.mainController prepareSelectedKeys];
        [self.mainController prepareCommandTableForContent];
        [self.mainController.editorController loadKeyfile:self.mainController.selectedKeyfile];
    }
    [self.statusLabel setStringValue:@"Saved and activated."];
}

- (void)revertClicked:(id)sender
{
    NSString *uuid = [self.keyfile objectForKey:KEYFILE_UUID_NODENAME];
    NSDictionary *saved = [self.keyControl.keyfileList objectForKey:uuid];
    [self loadKeyfile:saved ?: self.keyfile];
    [self.statusLabel setStringValue:@"Unsaved changes reverted."];
}

- (void)tableEditorClicked:(id)sender
{
    [self.mainController showTableEditor];
}

- (void)dealloc
{
    [self stopListeningForKeys];
}

@end
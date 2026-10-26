#import "KeyboardLayoutEditorController.h"
#import "KeyControl.h"
#import "ActionPopupBuilder.h"
#import "KeysEditorWindowController.h"
#import "MainWindowController.h"
#import "NSObject+SBJson.h"

@protocol MacBookKeyboardViewDelegate <NSObject>
- (void)keyboardViewDidSelectKeyCode:(NSString *)keyCode;
@end

@interface MacBookKeyboardView : NSView
@property (retain) NSArray *keyItems;
@property (retain) NSDictionary *keyMapping;
@property (retain) NSDictionary *assignmentTypes;
@property (retain) NSString *selectedKeyCode;
@property (assign) id<MacBookKeyboardViewDelegate> delegate;
@end

@implementation MacBookKeyboardView

@synthesize keyItems, keyMapping, assignmentTypes, selectedKeyCode, delegate;

- (NSRect)frameForKeyItem:(NSDictionary *)item
{
    CGFloat unit = fmin(80.0, (NSWidth(self.bounds) - 40.0) / 18.0);
    CGFloat keyHeight = unit * 0.88;
    CGFloat x = 20 + [[item objectForKey:@"x"] doubleValue] * unit;
    CGFloat y = 200 + ([[item objectForKey:@"y"] doubleValue] - 332 + [[item objectForKey:@"dy"] doubleValue]) * unit / 50.0;
    CGFloat width = [[item objectForKey:@"width"] doubleValue] * unit - 4;
    CGFloat heightScale = [[item objectForKey:@"height"] doubleValue];
    CGFloat height = [item[@"shape"] isEqualToString:@"vertical-enter"]
        ? keyHeight * 2 + unit * 0.12
        : (heightScale > 0 ? unit * heightScale : keyHeight);
    return NSMakeRect(x, y, width, height);
}

- (void)drawString:(NSString *)string inRect:(NSRect)rect fontSize:(CGFloat)size color:(NSColor *)color
{
    if ([string length] == 0) return;
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:size weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: color
    };
    NSSize textSize = [string sizeWithAttributes:attributes];
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
    CGFloat chassisBottom = 190;
    CGFloat chassisTop = 0;
    for (NSDictionary *item in self.keyItems) {
        chassisTop = fmax(chassisTop, NSMaxY([self frameForKeyItem:item]));
    }
    NSRect chassis = NSMakeRect(8, chassisBottom, NSWidth(self.bounds) - 16, chassisTop - chassisBottom + 16);
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
        if (!selectable) keyColor = [NSColor colorWithCalibratedWhite:0.25 alpha:1];
        [keyColor setFill];
        [[self pathForKeyItem:item frame:keyRect] fill];

        NSColor *borderColor = selected
            ? [NSColor colorWithCalibratedRed:0.95 green:0.66 blue:0.33 alpha:1]
            : [NSColor colorWithCalibratedWhite:assigned ? 0.96 : 0.42 alpha:1];
        [borderColor setStroke];
        NSBezierPath *border = [self pathForKeyItem:item frame:NSInsetRect(keyRect, 0.75, 0.75)];
        [border setLineWidth:selected ? 2.5 : 1];
        [border stroke];

        NSString *label = [item objectForKey:@"label"];
        if (!label && code) label = [self.keyMapping objectForKey:code];
        NSString *secondaryLabel = [item objectForKey:@"secondary"];
        NSColor *textColor = (assigned || selected)
            ? [NSColor colorWithCalibratedWhite:0.14 alpha:1]
            : [NSColor colorWithCalibratedWhite:0.84 alpha:0.52];
        if ([item[@"shape"] isEqualToString:@"vertical-enter"]) {
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

@interface KeyboardLayoutEditorController () <MacBookKeyboardViewDelegate>
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
@property (retain) NSPopUpButton *modeKeyPopup;
@property (retain) NSScrollView *bindingRowsScrollView;
@property (retain) NSView *bindingRowsView;
@property (retain) NSArray *sortedKeyCodes;
@property (retain) NSString *selectedKeyCode;
@property (assign) BOOL hasUnrepairableLoadedData;
@end

@implementation KeyboardLayoutEditorController

@synthesize mainController, keyControl, rootView;
@synthesize keyfile, bindings, keyboardView, modifierValues, modifierTitles, actionKeys;
@synthesize selectedKeyLabel, nameField, authorField, descriptionField, statusLabel;
@synthesize modeKeyPopup, bindingRowsScrollView, bindingRowsView, sortedKeyCodes, selectedKeyCode;
@synthesize hasUnrepairableLoadedData;

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
    self.rootView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 825, 463)];
    [self.rootView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.rootView setWantsLayer:YES];
    [self.rootView layer].backgroundColor = [NSColor colorWithCalibratedWhite:0.13 alpha:1].CGColor;

    NSTextField *title = [self labelWithFrame:NSMakeRect(20, 790, 600, 28)
                                         text:@"Keyboard Editor (Experimental)" size:16];
    [title setFont:[NSFont boldSystemFontOfSize:16]];
    [self.rootView addSubview:title];

    NSTextField *hint = [self labelWithFrame:NSMakeRect(20, 765, 820, 18)
                                        text:@"French ISO key positions with U.S. input labels. Select a key to edit its bindings." size:11];
    [self.rootView addSubview:hint];
    [self.rootView addSubview:[self buttonWithFrame:NSMakeRect(1155, 790, 185, 30) title:@"Table Editor" action:@selector(tableEditorClicked:)]];

    self.nameField = [self fieldWithFrame:NSMakeRect(20, 718, 220, 28) placeholder:@"Layout name"];
    self.authorField = [self fieldWithFrame:NSMakeRect(250, 718, 170, 28) placeholder:@"Author"];
    self.descriptionField = [self fieldWithFrame:NSMakeRect(430, 718, 450, 28) placeholder:@"Description"];
    [self.rootView addSubview:self.nameField];
    [self.rootView addSubview:self.authorField];
    [self.rootView addSubview:self.descriptionField];
    [self.rootView addSubview:[self buttonWithFrame:NSMakeRect(930, 718, 150, 28) title:@"Save and Activate" action:@selector(saveClicked:)]];
    [self.rootView addSubview:[self buttonWithFrame:NSMakeRect(1090, 718, 80, 28) title:@"Revert" action:@selector(revertClicked:)]];

    NSString *layoutPath = [[NSBundle mainBundle] pathForResource:@"MacBookISOKeyboard" ofType:@"json"];
    NSDictionary *layout = nil;
    if (layoutPath) {
        layout = [[NSString stringWithContentsOfFile:layoutPath encoding:NSUTF8StringEncoding error:nil] JSONValue];
    }
    NSMutableArray *keyItems = [NSMutableArray array];
    for (NSDictionary *row in [layout objectForKey:@"rows"]) {
        for (NSDictionary *item in [row objectForKey:@"keys"]) {
            NSMutableDictionary *keyItem = [item mutableCopy];
            [keyItem setObject:[row objectForKey:@"y"] forKey:@"y"];
            [keyItems addObject:keyItem];
        }
    }
    self.keyboardView = [[MacBookKeyboardView alloc] initWithFrame:self.rootView.bounds];
    [self.keyboardView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.keyboardView setKeyItems:keyItems];
    [self.keyboardView setKeyMapping:self.keyControl.keyMapping];
    [self.keyboardView setAssignmentTypes:@{}];
    [self.keyboardView setDelegate:self];
    [self.rootView addSubview:self.keyboardView];

    CGFloat inspectorX = 20;
    self.selectedKeyLabel = [self labelWithFrame:NSMakeRect(inspectorX, 165, 420, 24) text:@"Select a key" size:14];
    [self.selectedKeyLabel setFont:[NSFont boldSystemFontOfSize:12]];
    [self.rootView addSubview:self.selectedKeyLabel];

    [self.rootView addSubview:[self buttonWithFrame:NSMakeRect(1235, 160, 105, 30) title:@"Add Binding" action:@selector(addBindingClicked:)]];
    [self.rootView addSubview:[self labelWithFrame:NSMakeRect(20, 140, 170, 16) text:@"Modifier" size:10]];
    [self.rootView addSubview:[self labelWithFrame:NSMakeRect(200, 140, 430, 16) text:@"Action" size:10]];
    [self.rootView addSubview:[self labelWithFrame:NSMakeRect(640, 140, 170, 16) text:@"Value / increment" size:10]];

    [self.rootView addSubview:[self labelWithFrame:NSMakeRect(840, 165, 80, 16) text:@"Mode key" size:10]];
    self.modeKeyPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(910, 160, 190, 24) pullsDown:NO];
    for (NSString *code in self.sortedKeyCodes) [self.modeKeyPopup addItemWithTitle:[self displayLabelForKeyCode:code]];
    [self.rootView addSubview:self.modeKeyPopup];

    self.bindingRowsScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 24, 1320, 108)];
    [self.bindingRowsScrollView setHasVerticalScroller:YES];
    [self.bindingRowsScrollView setAutohidesScrollers:YES];
    [self.bindingRowsScrollView setDrawsBackground:NO];
    self.bindingRowsView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1300, 108)];
    [self.bindingRowsScrollView setDocumentView:self.bindingRowsView];
    [self.rootView addSubview:self.bindingRowsScrollView];

    self.statusLabel = [self labelWithFrame:NSMakeRect(20, 2, 1320, 18) text:@"" size:10];
    [self.rootView addSubview:self.statusLabel];
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
    [self.bindingRowsView setFrame:NSMakeRect(0, 0, 1300, contentHeight)];

    for (NSUInteger visibleIndex = 0; visibleIndex < visibleBindings.count; visibleIndex++) {
        NSDictionary *binding = [visibleBindings objectAtIndex:visibleIndex];
        NSUInteger bindingIndex = [self.bindings indexOfObjectIdenticalTo:binding];
        CGFloat y = contentHeight - (visibleIndex + 1) * (rowHeight + rowGap);
        NSView *row = [[NSView alloc] initWithFrame:NSMakeRect(0, y, 1300, rowHeight)];

        NSPopUpButton *modifier = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 1, 170, 26) pullsDown:NO];
        for (NSUInteger index = 0; index < self.modifierTitles.count; index++) {
            [modifier addItemWithTitle:[self.modifierTitles objectAtIndex:index]];
            [[modifier lastItem] setRepresentedObject:[self.modifierValues objectAtIndex:index]];
        }
        NSString *modifierValue = [binding objectForKey:KEYFILE_MODIFIERS_NODENAME] ?: @"0";
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
            actionPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(180, 1, 430, 26) pullsDown:NO];
            [actionPopup addItemWithTitle:@"Remap (edit in Table Editor)"];
            [actionPopup setEnabled:NO];
        } else {
            actionPopup = VSCOCreateActionPopup(self.actionKeys, self.keyControl.adjustmentMapping, action, NSMakeRect(180, 1, 430, 26));
            [actionPopup setTag:(NSInteger)bindingIndex];
            [actionPopup setTarget:self];
            [actionPopup setAction:@selector(bindingActionChanged:)];
        }
        [row addSubview:actionPopup];

        id value = [adjustments objectForKey:action];
        NSTextField *valueField;
        if ([action isEqualToString:@"_SetPreset"]) {
            NSComboBox *presetField = [[NSComboBox alloc] initWithFrame:NSMakeRect(620, 1, 120, 26)];
            [presetField setCompletes:YES];
            [presetField addItemsWithObjectValues:self.keyControl.availableDevelopPresets ?: @[]];
            valueField = presetField;
        } else {
            valueField = [self fieldWithFrame:NSMakeRect(620, 1, 120, 26) placeholder:@"Value"];
        }
        [valueField setStringValue:[value description] ?: @""];
        [valueField setTag:(NSInteger)bindingIndex + 10000];
        [valueField setDelegate:self];
        [valueField setEnabled:actionIndex != NSNotFound];
        [row addSubview:valueField];

        NSDictionary *limits = [self.keyControl.adjustmentLimits objectForKey:action];
        NSNumber *number = [self numericValue:value];
        if (limits && number) {
            NSStepper *stepper = [[NSStepper alloc] initWithFrame:NSMakeRect(744, 1, 19, 26)];
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

        NSButton *remove = [self buttonWithFrame:NSMakeRect(785, 1, 74, 26) title:@"Remove" action:@selector(removeBindingClicked:)];
        [remove setTag:(NSInteger)bindingIndex];
        [row addSubview:remove];
        [self.bindingRowsView addSubview:row];
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
    self.selectedKeyCode = keyCode;
    NSString *keyName = [self displayLabelForKeyCode:self.selectedKeyCode];
    [self.selectedKeyLabel setStringValue:[NSString stringWithFormat:@"%@ - keycode %@", keyName, self.selectedKeyCode]];
    [self rebuildBindingRows];
    [self.statusLabel setStringValue:@""];
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

- (void)addBindingClicked:(id)sender
{
    if (!self.selectedKeyCode) {
        [self.statusLabel setStringValue:@"Select a key first."];
        return;
    }
    NSString *mod = nil;
    for (NSString *candidate in self.modifierValues) {
        if (![self modifier:candidate isUsedForBindingAtIndex:NSNotFound]) {
            mod = candidate;
            break;
        }
    }
    if (!mod) {
        [self.statusLabel setStringValue:@"All modifier combinations are already assigned for this key."];
        return;
    }

    NSString *action = [self.actionKeys containsObject:@"Exposure2012"] ? @"Exposure2012" : [self.actionKeys firstObject];
    if (!action) return;
    NSDictionary *limits = [self.keyControl.adjustmentLimits objectForKey:action];
    id minimum = [limits objectForKey:@"min"];
    NSString *value = minimum && minimum != [NSNull null] ? [minimum description] : @"1";
    [self.bindings addObject:[@{
        KEYFILE_KEY_NODENAME: self.selectedKeyCode,
        KEYFILE_MODIFIERS_NODENAME: mod,
        KEYFILE_ADJUSTMENTS_NODENAME: @{action: value}
    } mutableCopy]];
    [self refreshKeyStates];
    [self rebuildBindingRows];
    [self.statusLabel setStringValue:@"Binding added. Save to apply."];
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

@end
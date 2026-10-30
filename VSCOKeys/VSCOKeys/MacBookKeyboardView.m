#import "MacBookKeyboardView.h"

@interface KeyboardInlineLabelField : NSTextField
@property (nonatomic, copy) NSString *presetValue;
@end

@implementation KeyboardInlineLabelField
@end

@interface MacBookKeyboardView () <NSTextFieldDelegate, NSDraggingSource, NSDraggingDestination>
@property (retain) NSMutableDictionary *inlineLabelFields;
@property (retain) NSString *dragSourceKeyCode;
@property (nonatomic, assign) NSString *dragAnchorKeyCode;
@property (assign) NSPoint mouseDownPoint;
@property (assign) BOOL dragSessionStarted;
@property (assign) CGFloat layoutMinX;
@property (assign) CGFloat layoutMinY;
@property (assign) CGFloat layoutWidthUnits;
@property (assign) CGFloat layoutHeightUnits;
@property (assign) CGFloat layoutKeyGapUnits;
- (void)rebuildInlineLabelFields;
- (NSArray *)keyCodesBetween:(NSString *)startCode and:(NSString *)endCode;
@end

@implementation MacBookKeyboardView

@synthesize keyItems, keyMapping, assignmentTypes, assignmentLabels;
@synthesize assignmentDetails = _assignmentDetails;
@synthesize usesMotibodoLabels = _usesMotibodoLabels, showsIncrementAmounts, allowsInlineLabelEditing = _allowsInlineLabelEditing;
@synthesize selectedKeyCode, selectedKeyCodes, capturedKeyCode, capturedKeyHasBinding, delegate;
@synthesize listeningForKeys, glowPhase, glowRemaining, glowTimer, selectionAnchorKeyCode;

- (void)setKeyboardLayoutDefinition:(NSDictionary *)layout
{
    NSMutableArray *items = [NSMutableArray array];
    CGFloat minimumX = CGFLOAT_MAX;
    CGFloat minimumY = CGFLOAT_MAX;
    CGFloat maximumX = -CGFLOAT_MAX;
    CGFloat maximumY = -CGFLOAT_MAX;
    NSNumber *gapValue = layout[@"keyGap"];
    self.layoutKeyGapUnits = gapValue ? gapValue.doubleValue : 0.06;
    for (NSDictionary *row in [layout objectForKey:@"rows"]) {
        CGFloat rowY = [row[@"y"] doubleValue];
        for (NSDictionary *item in [row objectForKey:@"keys"]) {
            NSMutableDictionary *keyItem = [item mutableCopy];
            keyItem[@"y"] = row[@"y"];
            [items addObject:keyItem];

            CGFloat x = [item[@"x"] doubleValue];
            CGFloat width = [item[@"width"] doubleValue];
            CGFloat dy = [item[@"dy"] doubleValue];
            CGFloat height = [item[@"height"] doubleValue];
            if ([item[@"shape"] isEqualToString:@"vertical-enter"]) height = 2.0 + self.layoutKeyGapUnits;
            else if (height <= 0) height = 1.0;

            minimumX = fmin(minimumX, x);
            maximumX = fmax(maximumX, x + width);
            minimumY = fmin(minimumY, rowY + dy);
            maximumY = fmax(maximumY, rowY + dy + height);
        }
    }
    self.keyItems = items;
    self.layoutMinX = items.count ? minimumX : 0;
    self.layoutMinY = items.count ? minimumY : 0;
    self.layoutWidthUnits = items.count ? maximumX - minimumX : 0;
    self.layoutHeightUnits = items.count ? maximumY - minimumY : 0;
    [self rebuildInlineLabelFields];
    [self setNeedsDisplay:YES];
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) [self registerForDraggedTypes:@[@"com.vsco.keys.binding-key-codes"]];
    return self;
}

- (void)setAssignmentDetails:(NSDictionary *)details
{
    _assignmentDetails = details;
    [self rebuildInlineLabelFields];
    [self setNeedsDisplay:YES];
}

- (void)setAllowsInlineLabelEditing:(BOOL)enabled
{
    _allowsInlineLabelEditing = enabled;
    [self rebuildInlineLabelFields];
    [self setNeedsDisplay:YES];
}

- (void)setUsesMotibodoLabels:(BOOL)enabled
{
    _usesMotibodoLabels = enabled;
    [self rebuildInlineLabelFields];
    [self setNeedsDisplay:YES];
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self rebuildInlineLabelFields];
}

- (void)rebuildInlineLabelFields
{
    for (NSArray *fields in self.inlineLabelFields.allValues) {
        for (NSTextField *field in fields) [field removeFromSuperview];
    }
    self.inlineLabelFields = [NSMutableDictionary dictionary];
    if (!self.allowsInlineLabelEditing || !self.usesMotibodoLabels) return;

    for (NSDictionary *item in self.keyItems) {
        NSString *code = item[@"code"];
        NSArray *details = code ? self.assignmentDetails[code] : nil;
        NSDictionary *detail = details.firstObject;
        NSString *action = detail[@"action"];
        if (!action || !detail[@"title"]) continue;

        NSRect keyRect = [self frameForKeyItem:item];
        NSMutableArray *fields = [NSMutableArray array];
        NSString *presetValue = [detail[@"presetValue"] description];
        if (presetValue.length == 0) {
            NSTextField *titleField = [[NSTextField alloc] initWithFrame:NSMakeRect(NSMinX(keyRect) + 5, NSMaxY(keyRect) - 19, NSWidth(keyRect) - 10, 15)];
            [titleField setStringValue:detail[@"title"]];
            [titleField setIdentifier:action];
            [titleField setFont:[NSFont systemFontOfSize:9 weight:NSFontWeightMedium]];
            [fields addObject:titleField];
            [self addSubview:titleField];
        } else {
            KeyboardInlineLabelField *presetField = [[KeyboardInlineLabelField alloc] initWithFrame:NSMakeRect(NSMinX(keyRect) + 4, NSMinY(keyRect) + 15, NSWidth(keyRect) - 8, 12)];
            [presetField setStringValue:detail[@"subtitle"] ?: @""];
            [presetField setPresetValue:presetValue];
            [presetField setFont:[NSFont systemFontOfSize:8 weight:NSFontWeightMedium]];
            [fields addObject:presetField];
            [self addSubview:presetField];
        }
        for (NSTextField *field in fields) {
            [field setEditable:YES];
            [field setSelectable:YES];
            [field setBordered:NO];
            [field setDrawsBackground:NO];
            [field setAlignment:NSTextAlignmentCenter];
            [field setTextColor:[NSColor colorWithCalibratedWhite:0.12 alpha:1]];
            [field setDelegate:self];
        }
        self.inlineLabelFields[code] = fields;
    }
}

- (NSArray *)keyCodesBetween:(NSString *)startCode and:(NSString *)endCode
{
    if (!startCode || !endCode) return @[];
    if ([startCode isEqualToString:endCode]) return @[startCode];

    // Get the positions of both keys in the keyItems array
    NSInteger startIndex = -1;
    NSInteger endIndex = -1;
    for (NSUInteger i = 0; i < self.keyItems.count; i++) {
        NSDictionary *item = self.keyItems[i];
        NSString *code = item[@"code"];
        if ([code isEqualToString:startCode]) startIndex = (NSInteger)i;
        if ([code isEqualToString:endCode]) endIndex = (NSInteger)i;
    }

    if (startIndex == -1 || endIndex == -1) return @[];

    NSInteger fromIndex = MIN(startIndex, endIndex);
    NSInteger toIndex = MAX(startIndex, endIndex);

    NSMutableArray *keyCodes = [NSMutableArray array];
    for (NSInteger i = fromIndex; i <= toIndex; i++) {
        NSDictionary *item = self.keyItems[(NSUInteger)i];
        NSString *code = item[@"code"];
        if (code) [keyCodes addObject:code];
    }

    return keyCodes;
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
    if (self.layoutWidthUnits <= 0 || self.layoutHeightUnits <= 0) return NSZeroRect;

    CGFloat unit = [self keyboardUnitScale];
    CGFloat x = NSMinX(self.bounds) + 18 + ([[item objectForKey:@"x"] doubleValue] - self.layoutMinX) * unit;
    CGFloat width = ([[item objectForKey:@"width"] doubleValue] - self.layoutKeyGapUnits) * unit;
    CGFloat heightScale = [[item objectForKey:@"height"] doubleValue];
    CGFloat height = [item[@"shape"] isEqualToString:@"vertical-enter"]
        ? unit * (2.0 + self.layoutKeyGapUnits)
        : (heightScale > 0 ? unit * heightScale : unit);
    CGFloat rowY = [[item objectForKey:@"y"] doubleValue] + [[item objectForKey:@"dy"] doubleValue];
    CGFloat y = NSMinY(self.bounds) + 16 + (rowY - self.layoutMinY) * unit;
    return NSMakeRect(x, y, width, height);
}

- (CGFloat)keyboardUnitScale
{
    if (self.layoutWidthUnits <= 0 || self.layoutHeightUnits <= 0) return 0;
    CGFloat horizontalUnit = (NSWidth(self.bounds) - 36.0) / self.layoutWidthUnits;
    CGFloat verticalUnit = (NSHeight(self.bounds) - 32.0) / self.layoutHeightUnits;
    return fmax(0, fmin(horizontalUnit, verticalUnit));
}

- (NSSize)canvasSizeForKeyboardUnitScale:(CGFloat)scale
{
    return NSMakeSize(self.layoutWidthUnits * scale + 36.0,
                      self.layoutHeightUnits * scale + 32.0);
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

+ (NSString *)colorCategoryForAction:(NSString *)action isAdjustment:(BOOL)isAdjustment
{
    NSString *identifier = action.lowercaseString ?: @"";
    if ([identifier isEqualToString:@"_setpreset"]) return @"preset";
    if ([identifier hasPrefix:@"reset"] || [identifier isEqualToString:@"undo"] ||
        [identifier isEqualToString:@"redo"] || [identifier isEqualToString:@"redoundo"]) return @"reset";
    if ([identifier containsString:@"hueadjustment"] || [identifier containsString:@"saturationadjustment"] ||
        [identifier containsString:@"luminanceadjustment"] || [identifier containsString:@"graymixer"] ||
        [identifier containsString:@"splittoning"] || [identifier containsString:@"colorgrade"] ||
        [identifier containsString:@"shadowtint"] || [identifier hasSuffix:@"hue"] ||
        [identifier hasSuffix:@"saturation"]) return @"color";
    if ([identifier containsString:@"crop"] || [identifier containsString:@"brush"] ||
        [identifier containsString:@"gradient"] || [identifier containsString:@"mask"] ||
        [identifier containsString:@"spot"] || [identifier containsString:@"heal"] ||
        [identifier containsString:@"clone"] || [identifier containsString:@"redeye"] ||
        [identifier containsString:@"transform"] || [identifier containsString:@"lens"] ||
        [identifier containsString:@"straighten"]) return @"tool";
    return isAdjustment ? @"adjustment" : @"other";
}

+ (NSColor *)colorForCategory:(NSString *)category
{
    static NSDictionary *colors;
    if (!colors) {
        colors = @{
            @"adjustment": [NSColor colorWithCalibratedRed:0.616 green:0.847 blue:0.749 alpha:1],
            @"color": [NSColor colorWithCalibratedRed:0.953 green:0.627 blue:0.290 alpha:1],
            @"tool": [NSColor colorWithCalibratedRed:0.957 green:0.847 blue:0.231 alpha:1],
            @"preset": [NSColor colorWithCalibratedRed:0.490 green:0.780 blue:0.918 alpha:1],
            @"reset": [NSColor colorWithCalibratedRed:0.910 green:0.357 blue:0.314 alpha:1],
            @"other": [NSColor colorWithCalibratedRed:0.741 green:0.725 blue:0.910 alpha:1],
            @"mixed": [NSColor colorWithCalibratedRed:0.729 green:0.741 blue:0.765 alpha:1]
        };
    }
    return colors[category];
}

+ (NSString *)symbolNameForAction:(NSString *)action
{
    static NSDictionary *symbols;
    if (!symbols) {
        symbols = @{
            @"ShoVwdevelop_before_after_horiz": @"rectangle.split.2x1",
            @"ShoVwdevelop_before_after_vert": @"rectangle.split.1x2",
            @"Next": @"arrow.right",
            @"Prev": @"arrow.left",
            @"LRCopy": @"doc.on.doc",
            @"LRPaste": @"doc.on.clipboard",
            @"PasteSettingsFromPrevious": @"doc.on.clipboard",
            @"NewSnapshot": @"camera.viewfinder",
            @"AutoTone": @"wand.and.stars",
            @"WhiteBalanceAuto": @"eyedropper",
            @"VirtualCopy": @"plus.square.on.square",
            @"ResetAll": @"arrow.counterclockwise",
            @"ResetLast": @"arrow.counterclockwise",
            @"Undo": @"arrow.uturn.backward",
            @"Redo": @"arrow.uturn.forward",
            @"MaskNewBrush": @"paintbrush.pointed.fill",
            @"CropOverlay": @"crop",
            @"straightenAngle" : @"crop.rotate",
            @"EnhanceDenoiseOn": @"sparkles",
            @"QuickDevCropAspect3x4": @"rectangle.portrait",


        };
    }
    return symbols[action];
}

+ (NSString *)symbolNameForAction:(NSString *)action amount:(NSString *)amount
{
    static NSDictionary *directionalSymbols;
    static NSDictionary *directionalCommands;
    if (!directionalSymbols) {
        directionalSymbols = @{
            @"Temperature": @{@"negative": @"thermometer.low", @"positive": @"thermometer.high"},
            @"Exposure2012": @{@"negative": @"sun.min", @"positive": @"sun.max"},
            @"Tint": @{@"negative": @"drop.halffull", @"positive": @"drop.fill"}
        };
        directionalCommands = @{
            @"IncrementLastDevelopParameter": @"plus",
            @"DecrementLastDevelopParameter": @"minus",
            @"SliderIncrease": @"plus",
            @"SliderDecrease": @"minus",
            @"FineIncrease": @"plus",
            @"FineDecrease": @"minus"
        };
    }

    // Special handling for ChangeBrushSize - return dual icon format
    if ([action isEqualToString:@"ChangeBrushSize"] && amount.length > 0) {
        NSScanner *scanner = [NSScanner scannerWithString:amount];
        double value = 0;
        if ([scanner scanDouble:&value] && [scanner isAtEnd]) {
            NSString *directionSymbol = value < 0 ? @"minus.circle" : @"plus.circle";
            return [NSString stringWithFormat:@"%@|paintbrush.pointed.fill", directionSymbol];
        }
    }

    // Special handling for ChangeFeatherSize - return dual icon format
    if ([action isEqualToString:@"ChangeFeatherSize"] && amount.length > 0) {
        NSScanner *scanner = [NSScanner scannerWithString:amount];
        double value = 0;
        if ([scanner scanDouble:&value] && [scanner isAtEnd]) {
            NSString *directionSymbol = value < 0 ? @"minus.circle" : @"plus.circle";
            return [NSString stringWithFormat:@"%@|circle.dashed", directionSymbol];
        }
    }

    // Special handling for CropZoomIn - return dual icon format
    if ([action isEqualToString:@"CropZoomIn"]) {
        return @"plus.magnifyingglass|crop";
    }

    // Special handling for CropZoomOut - return dual icon format
    if ([action isEqualToString:@"CropZoomOut"]) {
        return @"minus.magnifyingglass|crop";
    }

    // Special handling for ResetCrop - return dual icon format
    if ([action isEqualToString:@"ResetCrop"]) {
        return @"arrow.counterclockwise|crop";
    }

    // Special handling for ResetstraightenAngle - return dual icon format
    if ([action isEqualToString:@"ResetstraightenAngle"]) {
        return @"arrow.counterclockwise|crop.rotate";
    }

    // Special handling for local_Exposure - return dual icon format
    if ([action isEqualToString:@"local_Exposure"]) {
        return @"sun.min|paintbrush.pointed.fill";
    }

    // Special handling for MaskNewGrad - return icon
    if ([action isEqualToString:@"MaskNewGrad"]) {
        return @"lightspectrum.horizontal";
    }

    // Special handling for TogglePick - return icon
    if ([action isEqualToString:@"TogglePick"]) {
        return @"flag.fill";
    }

    // Special handling for ToggleReject - return icon
    if ([action isEqualToString:@"ToggleReject"]) {
        return @"xmark.square";
    }

    // Special handling for local_Contrast - return dual icon format
    if ([action isEqualToString:@"local_Contrast"] && amount.length > 0) {
        NSScanner *scanner = [NSScanner scannerWithString:amount];
        double value = 0;
        if ([scanner scanDouble:&value] && [scanner isAtEnd]) {
            NSString *directionSymbol = value < 0 ? @"minus.circle" : @"plus.circle";
            return [NSString stringWithFormat:@"%@|circle.righthalf.filled", directionSymbol];
        }
    }

    // Special handling for Contrast - return dual icon format
    if ([action isEqualToString:@"Contrast"] && amount.length > 0) {
        NSScanner *scanner = [NSScanner scannerWithString:amount];
        double value = 0;
        if ([scanner scanDouble:&value] && [scanner isAtEnd]) {
            NSString *directionSymbol = value < 0 ? @"minus.circle" : @"plus.circle";
            return [NSString stringWithFormat:@"%@|circle.righthalf.filled", directionSymbol];
        }
    }

    // Special handling for Undo - return single icon
    if ([action isEqualToString:@"Undo"]) {
        return @"arrow.counterclockwise";
    }

    // Special handling for Redo - return single icon
    if ([action isEqualToString:@"Redo"]) {
        return @"arrow.clockwise";
    }

    // Special handling for RedoUndo - return dual icon format
    if ([action isEqualToString:@"RedoUndo"]) {
        return @"arrow.clockwise|arrow.counterclockwise";
    }

    // Special handling for QuickDevCropAspectAsShot - return dual icon format
    if ([action isEqualToString:@"QuickDevCropAspectAsShot"]) {
        return @"crop|camera.badge.clock";
    }

    // Special handling for ColorGradeReset3way - return dual icon format
    if ([action isEqualToString:@"ColorGradeReset3way"]) {
        return @"slider.horizontal.2.arrow.trianglehead.counterclockwise|camera.filters";
    }

    // Special handling for RotateLeft - return icon
    if ([action isEqualToString:@"RotateLeft"]) {
        return @"rotate.left";
    }

    // Special handling for RotateRight - return icon
    if ([action isEqualToString:@"RotateRight"]) {
        return @"rotate.right";
    }

    NSDictionary *variants = directionalSymbols[action];
    if (variants && amount.length > 0) {
        NSScanner *scanner = [NSScanner scannerWithString:amount];
        double value = 0;
        if ([scanner scanDouble:&value] && [scanner isAtEnd]) {
            if (value < 0) return variants[@"negative"];
            if (value > 0) return variants[@"positive"];
        }
    }

    return directionalCommands[action] ?: [self symbolNameForAction:action];
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
        BOOL selected = code && ([code isEqualToString:self.selectedKeyCode] || [self.selectedKeyCodes containsObject:code]);
        BOOL captured = code && [code isEqualToString:self.capturedKeyCode];
        BOOL glowing = captured && (self.listeningForKeys || self.glowRemaining > 0);
        BOOL selectable = code != nil;

        NSRect shadowRect = keyRect;
        shadowRect.origin.y -= 3;
        [[NSColor colorWithCalibratedWhite:0.02 alpha:0.75] setFill];
        [[self pathForKeyItem:item frame:shadowRect] fill];

        NSColor *keyColor = [[self class] colorForCategory:types[@"colorCategory"]] ?: (discreteCount > 0
            ? [NSColor colorWithCalibratedRed:0.96 green:0.79 blue:0.43 alpha:1]
            : (assigned
                ? [NSColor colorWithCalibratedRed:0.77 green:0.91 blue:0.83 alpha:1]
                : [NSColor colorWithCalibratedWhite:0.31 alpha:1]));
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
        NSArray *assignmentDetailsForKey = code ? [self.assignmentDetails objectForKey:code] : nil;
        NSColor *textColor = (assigned || selected)
            ? [NSColor colorWithCalibratedWhite:0.14 alpha:1]
            : [NSColor colorWithCalibratedWhite:0.84 alpha:0.52];
        if (assignmentLabel.length > 0) {
            if (self.usesMotibodoLabels) {
                NSDictionary *firstDetail = assignmentDetailsForKey.firstObject;
                NSString *actionTitle = firstDetail[@"title"] ?: assignmentLabel;
                NSString *presetValue = [firstDetail[@"presetValue"] description];
                BOOL editingActionTitle = self.allowsInlineLabelEditing && presetValue.length == 0;
                BOOL editingPresetLabel = self.allowsInlineLabelEditing && presetValue.length > 0;
                NSRect actionRect = NSMakeRect(NSMinX(keyRect) + 5, NSMaxY(keyRect) - 19, NSWidth(keyRect) - 10, 15);
                if (!editingActionTitle) [self drawString:actionTitle inRect:actionRect fontSize:9 color:textColor];
                NSSize titleSize = [actionTitle sizeWithAttributes:@{NSFontAttributeName: [NSFont systemFontOfSize:9 weight:NSFontWeightMedium]}];
                NSColor *directionColor = [NSColor colorWithCalibratedWhite:0.12 alpha:1];
                if (leftCount) [self drawDirectionTriangleAt:NSMakePoint(NSMidX(keyRect) - titleSize.width / 2 - 7, NSMaxY(keyRect) - 11) pointsLeft:YES color:directionColor];
                if (rightCount) [self drawDirectionTriangleAt:NSMakePoint(NSMidX(keyRect) + titleSize.width / 2 + 7, NSMaxY(keyRect) - 11) pointsLeft:NO color:directionColor];
                NSString *amount = [firstDetail[@"amount"] description];
                if (self.showsIncrementAmounts && amount.length > 0) {
                    NSRect amountRect = NSMakeRect(NSMaxX(keyRect) - 30, NSMinY(keyRect) + 2, 26, 11);
                    [self drawString:amount inRect:amountRect fontSize:7 color:textColor];
                }
                NSString *subtitle = [firstDetail[@"subtitle"] description];
                if (subtitle.length > 0 && !editingPresetLabel) {
                    NSRect subtitleRect = NSMakeRect(NSMinX(keyRect) + 4, NSMinY(keyRect) + 15, NSWidth(keyRect) - 8, 12);
                    [self drawString:subtitle inRect:subtitleRect fontSize:8 color:textColor];
                }
                NSString *symbolName = assignmentDetailsForKey.count == 1
                    ? [[self class] symbolNameForAction:firstDetail[@"action"] amount:amount] : nil;
                if (symbolName && subtitle.length == 0) {
                    // Check if this is a dual-icon format (separated by |)
                    NSArray *symbols = [symbolName componentsSeparatedByString:@"|"];
                    if (symbols.count > 1) {
                        // Draw multiple icons side by side
                        CGFloat iconSize = 14;
                        CGFloat spacing = 4;
                        CGFloat totalWidth = symbols.count * iconSize + (symbols.count - 1) * spacing;
                        CGFloat startX = NSMidX(keyRect) - totalWidth / 2;

                        for (NSUInteger i = 0; i < symbols.count; i++) {
                            NSString *singleSymbol = symbols[i];
                            NSImage *symbol = [NSImage imageWithSystemSymbolName:singleSymbol accessibilityDescription:actionTitle];
                            NSImageSymbolConfiguration *sizeConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:iconSize
                                                                                                                              weight:NSFontWeightRegular];
                            NSImageSymbolConfiguration *colorConfiguration = [NSImageSymbolConfiguration configurationWithHierarchicalColor:textColor];
                            NSImageSymbolConfiguration *configuration = [sizeConfiguration configurationByApplyingConfiguration:colorConfiguration];
                            symbol = [symbol imageWithSymbolConfiguration:configuration];

                            NSRect iconRect = NSMakeRect(startX + i * (iconSize + spacing), NSMidY(keyRect) - iconSize / 2, iconSize, iconSize);
                            [symbol drawInRect:iconRect];
                        }
                    } else {
                        // Single icon (original behavior)
                        CGFloat symbolSize = 24;
                        NSImage *symbol = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:actionTitle];
                        NSImageSymbolConfiguration *sizeConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:symbolSize
                                                                                                                          weight:NSFontWeightRegular];
                        NSImageSymbolConfiguration *colorConfiguration = [NSImageSymbolConfiguration configurationWithHierarchicalColor:textColor];
                        NSImageSymbolConfiguration *configuration = [sizeConfiguration configurationByApplyingConfiguration:colorConfiguration];
                        symbol = [symbol imageWithSymbolConfiguration:configuration];
                        [symbol drawInRect:NSMakeRect(NSMidX(keyRect) - symbolSize / 2,
                                                      NSMidY(keyRect) - symbolSize / 2,
                                                      symbolSize, symbolSize)];
                    }
                }
                NSRect keyLabelRect = NSMakeRect(NSMinX(keyRect) + 4, NSMinY(keyRect) + 2, NSWidth(keyRect) * 0.55, 13);
                [self drawString:label ?: @"" inRect:keyLabelRect fontSize:8 color:textColor];
            } else {
                NSRect actionRect = NSMakeRect(NSMinX(keyRect) + 2, NSMaxY(keyRect) - 15, NSWidth(keyRect) - 4, 13);
                [self drawString:assignmentLabel inRect:actionRect fontSize:8 color:textColor];
                NSDictionary *firstDetail = assignmentDetailsForKey.firstObject;
                NSString *presetSubtitle = [firstDetail[@"subtitle"] description];
                if (presetSubtitle.length > 0) {
                    NSRect subtitleRect = NSMakeRect(NSMinX(keyRect) + 4, NSMinY(keyRect) + 15, NSWidth(keyRect) - 8, 12);
                    [self drawString:presetSubtitle inRect:subtitleRect fontSize:8 color:textColor];
                    NSRect keyLabelRect = NSMakeRect(NSMinX(keyRect) + 4, NSMinY(keyRect) + 2, NSWidth(keyRect) * 0.55, 13);
                    [self drawString:label ?: @"" inRect:keyLabelRect fontSize:8 color:textColor];
                } else if (secondaryLabel) {
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

        if (assigned && !self.usesMotibodoLabels) {
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
    NSPoint localPoint = [self convertPoint:point fromView:self.superview];
    for (NSArray *fields in self.inlineLabelFields.allValues) {
        for (NSTextField *field in fields) {
            if (NSPointInRect(localPoint, field.frame)) return field;
        }
    }
    for (NSDictionary *item in self.keyItems) {
        if ([item objectForKey:@"code"] && NSPointInRect(localPoint, [self frameForKeyItem:item])) {
            return self;
        }
    }
    return nil;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    NSTextField *field = [notification object];
    if ([field isKindOfClass:[KeyboardInlineLabelField class]]) {
        KeyboardInlineLabelField *presetField = (KeyboardInlineLabelField *)field;
        if ([self.delegate respondsToSelector:@selector(keyboardView:didChangePresetLabel:forPreset:)]) {
            [self.delegate keyboardView:self didChangePresetLabel:field.stringValue forPreset:presetField.presetValue];
        }
        return;
    }
    NSString *action = [field identifier];
    if ([self.delegate respondsToSelector:@selector(keyboardView:didChangeShortLabel:forAction:)]) {
        [self.delegate keyboardView:self didChangeShortLabel:field.stringValue forAction:action];
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    if ([self.delegate respondsToSelector:@selector(keyboardViewDidFinishEditingShortLabel:)]) {
        [self.delegate keyboardViewDidFinishEditingShortLabel:self];
    }
}

- (void)mouseDown:(NSEvent *)event
{
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    self.dragSourceKeyCode = nil;
    self.dragAnchorKeyCode = nil;
    self.dragSessionStarted = NO;
    for (NSDictionary *item in [self.keyItems reverseObjectEnumerator]) {
        NSString *code = [item objectForKey:@"code"];
        if (code && NSPointInRect(point, [self frameForKeyItem:item])) {
            self.mouseDownPoint = point;
            NSEventModifierFlags flags = [event modifierFlags];
            BOOL shiftPressed = (flags & NSEventModifierFlagShift) != 0;
            BOOL cmdPressed = (flags & NSEventModifierFlagCommand) != 0;

            NSMutableSet *selection = [NSMutableSet set];

            if (shiftPressed && self.selectionAnchorKeyCode) {
                // Range selection: select all keys between anchor and clicked key
                NSArray *rangeKeys = [self keyCodesBetween:self.selectionAnchorKeyCode and:code];
                [selection addObjectsFromArray:rangeKeys];
                self.selectedKeyCodes = selection;
                self.selectedKeyCode = code;
            } else if (cmdPressed) {
                // Individual toggle selection
                selection = [self.selectedKeyCodes mutableCopy] ?: [NSMutableSet set];
                if ([selection containsObject:code]) {
                    [selection removeObject:code];
                    self.selectedKeyCode = [selection anyObject];
                } else {
                    [selection addObject:code];
                    self.selectedKeyCode = code;
                }
                self.selectedKeyCodes = selection;
                self.selectionAnchorKeyCode = code;
            } else {
                // Normal click: select just this key
                [selection addObject:code];
                self.selectedKeyCodes = selection;
                self.selectedKeyCode = code;
                self.selectionAnchorKeyCode = code;
            }

            self.dragAnchorKeyCode = self.selectedKeyCode;
            self.dragSourceKeyCode = self.dragAnchorKeyCode;
            [self setNeedsDisplay:YES];
            if ([self.delegate respondsToSelector:@selector(keyboardView:didSelectKeyCodes:primaryKeyCode:)]) {
                [self.delegate keyboardView:self didSelectKeyCodes:self.selectedKeyCodes primaryKeyCode:self.selectedKeyCode];
            } else {
                [self.delegate keyboardViewDidSelectKeyCode:self.selectedKeyCode];
            }
            return;
        }
    }
}

- (void)mouseDragged:(NSEvent *)event
{
    if (!self.dragSourceKeyCode || self.dragSessionStarted) return;
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    if (hypot(point.x - self.mouseDownPoint.x, point.y - self.mouseDownPoint.y) < 5) return;

    NSMutableArray *boundSelectedKeys = [NSMutableArray array];
    for (NSString *keyCode in self.selectedKeyCodes) {
        if ([self.assignmentLabels[keyCode] length] > 0) [boundSelectedKeys addObject:keyCode];
    }
    if (boundSelectedKeys.count == 0) return;

    NSPasteboardItem *pasteboardItem = [[NSPasteboardItem alloc] init];
    [pasteboardItem setPropertyList:@{@"keyCodes": boundSelectedKeys, @"anchorKeyCode": self.dragAnchorKeyCode}
                            forType:@"com.vsco.keys.binding-key-codes"];
    NSDraggingItem *draggingItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pasteboardItem];
    NSImage *dragImage = [[NSImage alloc] initWithSize:NSMakeSize(96, 34)];
    [dragImage lockFocus];
    [[NSColor colorWithCalibratedWhite:0.22 alpha:0.92] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(0, 0, 96, 34) xRadius:5 yRadius:5] fill];
    NSString *dragTitle = boundSelectedKeys.count > 1
        ? [NSString stringWithFormat:@"%lu keys", (unsigned long)boundSelectedKeys.count]
        : self.dragSourceKeyCode;
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:13],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    [dragTitle drawAtPoint:NSMakePoint(8, 10) withAttributes:attributes];
    [dragImage unlockFocus];
    NSRect keyFrame = NSMakeRect(point.x - 48, point.y - 17, 96, 34);
    [draggingItem setDraggingFrame:keyFrame contents:dragImage];
    self.dragSessionStarted = YES;
    [self beginDraggingSessionWithItems:@[draggingItem] event:event source:self];
}

- (void)mouseUp:(NSEvent *)event
{
    self.dragSourceKeyCode = nil;
    self.dragSessionStarted = NO;
}

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    return NSDragOperationMove;
}

- (BOOL)ignoreModifierKeysForDraggingSession:(NSDraggingSession *)session
{
    return YES;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    NSDictionary *payload = [[sender draggingPasteboard] propertyListForType:@"com.vsco.keys.binding-key-codes"];
    return [payload isKindOfClass:[NSDictionary class]] ? NSDragOperationMove : NSDragOperationNone;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
    NSDictionary *payload = [[sender draggingPasteboard] propertyListForType:@"com.vsco.keys.binding-key-codes"];
    return [payload isKindOfClass:[NSDictionary class]];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSDictionary *payload = [[sender draggingPasteboard] propertyListForType:@"com.vsco.keys.binding-key-codes"];
    NSPoint point = [self convertPoint:[sender draggingLocation] fromView:nil];
    NSString *targetKeyCode = nil;
    for (NSDictionary *item in [self.keyItems reverseObjectEnumerator]) {
        NSString *code = [item objectForKey:@"code"];
        if (code && NSPointInRect(point, [self frameForKeyItem:item])) {
            targetKeyCode = code;
            break;
        }
    }
    NSArray *sourceKeyCodes = [payload isKindOfClass:[NSDictionary class]] ? payload[@"keyCodes"] : nil;
    NSString *anchorKeyCode = [payload isKindOfClass:[NSDictionary class]] ? payload[@"anchorKeyCode"] : nil;
    if (![sourceKeyCodes isKindOfClass:[NSArray class]] || !anchorKeyCode || !targetKeyCode) return NO;
    if ([self.delegate respondsToSelector:@selector(keyboardView:didMoveBindingsFromKeys:anchorKey:toKey:)]) {
        [self.delegate keyboardView:self didMoveBindingsFromKeys:sourceKeyCodes anchorKey:anchorKeyCode toKey:targetKeyCode];
        return YES;
    }
    if (sourceKeyCodes.count == 1 && [self.delegate respondsToSelector:@selector(keyboardView:didMoveBindingFromKey:toKey:)]) {
        [self.delegate keyboardView:self didMoveBindingFromKey:sourceKeyCodes.firstObject toKey:targetKeyCode];
        return YES;
    }
    return NO;
}

@end

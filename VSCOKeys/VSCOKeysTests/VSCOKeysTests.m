//
//  VSCOKeysTests.m
//  VSCOKeysTests
//
//  Created by Sean Gubelman on 6/25/12.
//
//  VSCO Keys for Adobe Lightroom
//  Copyright (C) 2015 Visual Supply Company
//  Licensed under GNU GPLv2 (or any later version).
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//

#import "VSCOKeysTests.h"
#import "ActionPopupBuilder.h"
#import "KeyfileValidator.h"
#import "MacBookKeyboardView.h"
#import "VSCOKeyCodeLookup.h"

@interface TestKeyboardSwapDelegate : NSObject <MacBookKeyboardViewDelegate>
@property (retain) NSArray *swappedSourceKeys;
@property (retain) NSString *swappedTargetKey;
@property (retain) NSString *failedMessage;
@end

@implementation TestKeyboardSwapDelegate
- (void)keyboardViewDidSelectKeyCode:(NSString *)keyCode {}
- (void)keyboardView:(MacBookKeyboardView *)keyboardView didSelectKeyCodes:(NSSet *)keyCodes primaryKeyCode:(NSString *)keyCode {}
- (void)keyboardView:(MacBookKeyboardView *)keyboardView didSwapBindingsFromKeys:(NSArray *)sourceKeyCodes toTargetKey:(NSString *)targetKeyCode
{
    self.swappedSourceKeys = sourceKeyCodes;
    self.swappedTargetKey = targetKeyCode;
}
- (void)keyboardView:(MacBookKeyboardView *)keyboardView swapFailedWithMessage:(NSString *)message
{
    self.failedMessage = message;
}
@end

@interface TestDraggingInfo : NSObject
@property (retain) NSPasteboard *draggingPasteboard;
@property (assign) NSPoint draggingLocation;
@end

@implementation TestDraggingInfo
@end

@implementation VSCOKeysTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testKeyboardKeyColorCategories
{
    XCTAssertEqualObjects([MacBookKeyboardView colorCategoryForAction:@"Exposure2012" isAdjustment:YES], @"adjustment");
    XCTAssertEqualObjects([MacBookKeyboardView colorCategoryForAction:@"SaturationAdjustmentRed" isAdjustment:YES], @"color");
    XCTAssertEqualObjects([MacBookKeyboardView colorCategoryForAction:@"MaskSubBack" isAdjustment:NO], @"tool");
    XCTAssertEqualObjects([MacBookKeyboardView colorCategoryForAction:@"_SetPreset" isAdjustment:NO], @"preset");
    XCTAssertEqualObjects([MacBookKeyboardView colorCategoryForAction:@"ResetCrop" isAdjustment:NO], @"reset");
    XCTAssertEqualObjects([MacBookKeyboardView colorCategoryForAction:@"_RemapKey" isAdjustment:NO], @"other");
    for (NSString *category in @[@"adjustment", @"color", @"tool", @"preset", @"reset", @"other", @"mixed"]) {
        XCTAssertNotNil([MacBookKeyboardView colorForCategory:category]);
    }
}

- (void)testKeyboardActionSymbols
{
    NSDictionary *symbolsByAction = @{
        @"ShoVwdevelop_before_after_horiz": @"rectangle.split.2x1",
        @"ShoVwdevelop_before_after_vert": @"rectangle.split.1x2",
        @"Next": @"arrow.right",
        @"Prev": @"arrow.left",
        @"LRCopy": @"doc.on.doc",
        @"LRPaste": @"doc.on.clipboard",
        @"PasteSettingsFromPrevious": @"doc.on.clipboard",
        @"AutoTone": @"wand.and.stars",
        @"WhiteBalanceAuto": @"eyedropper",
        @"VirtualCopy": @"plus.square.on.square",
        @"ResetAll": @"arrow.counterclockwise",
        @"ResetLast": @"arrow.counterclockwise",
        @"Undo": @"arrow.uturn.backward",
        @"Redo": @"arrow.uturn.forward"
    };
    [symbolsByAction enumerateKeysAndObjectsUsingBlock:^(NSString *action, NSString *symbolName, BOOL *stop) {
        XCTAssertEqualObjects([MacBookKeyboardView symbolNameForAction:action], symbolName);
        XCTAssertNotNil([NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil]);
    }];
    XCTAssertNil([MacBookKeyboardView symbolNameForAction:@"Exposure2012"]);

    NSArray *directionalCases = @[
        @{@"action": @"Temperature", @"amount": @"-0.1", @"symbol": @"thermometer.low"},
        @{@"action": @"Temperature", @"amount": @"0.1", @"symbol": @"thermometer.high"},
        @{@"action": @"IncrementLastDevelopParameter", @"amount": @"", @"symbol": @"plus"},
        @{@"action": @"DecrementLastDevelopParameter", @"amount": @"", @"symbol": @"minus"},
        @{@"action": @"SliderIncrease", @"amount": @"", @"symbol": @"plus"},
        @{@"action": @"SliderDecrease", @"amount": @"", @"symbol": @"minus"},
        @{@"action": @"CropOverlay", @"amount": @"", @"symbol": @"crop"}
    ];
    for (NSDictionary *testCase in directionalCases) {
        NSString *symbolName = testCase[@"symbol"];
        XCTAssertEqualObjects([MacBookKeyboardView symbolNameForAction:testCase[@"action"] amount:testCase[@"amount"]], symbolName);
        XCTAssertNotNil([NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil]);
    }
    XCTAssertNil([MacBookKeyboardView symbolNameForAction:@"Temperature" amount:@"0"]);
}

- (void)testKeyfileRejectsDuplicateKeyAndModifier
{
    NSDictionary *keyfile = @{
        @"modeKey": @"53",
        @"keys": @[
            @{@"key": @"38", @"mod": @"0", @"adj": @{@"Exposure2012": @"-0.1"}},
            @{@"key": @"38", @"mod": @"0", @"adj": @{@"_SetPreset": @"1 star"}}
        ]
    };
    NSError *error = nil;

    XCTAssertFalse(VSCOValidateKeyfile(keyfile, &error), @"Duplicate key/modifier pairs must be rejected");
    XCTAssertEqual(error.code, (NSInteger)3, @"The error should identify the duplicate pair");
}

- (void)testKeyfileAllowsDifferentModifiersAndRejectsModeKeyBinding
{
    NSDictionary *keyfile = @{
        @"modeKey": @"53",
        @"keys": @[
            @{@"key": @"38", @"mod": @"0", @"adj": @{@"Exposure2012": @"-0.1"}},
            @{@"key": @"38", @"mod": @"15", @"adj": @{@"_SetPreset": @"1 star"}}
        ]
    };
    NSError *error = nil;
    XCTAssertTrue(VSCOValidateKeyfile(keyfile, &error), @"Different modifier masks should be distinct bindings");
    XCTAssertNil(error, @"A valid keyfile should not produce an error");

    NSDictionary *modeConflict = @{
        @"modeKey": @"38",
        @"keys": @[@{@"key": @"38", @"mod": @"0", @"adj": @{@"Exposure2012": @"-0.1"}}]
    };
    XCTAssertFalse(VSCOValidateKeyfile(modeConflict, &error), @"The unmodified mode key binding must be rejected");
    XCTAssertEqual(error.code, (NSInteger)4, @"The error should identify the mode-key conflict");
}

- (void)testKeyfileAcceptsAllModifierMasks
{
    NSMutableArray *bindings = [NSMutableArray array];
    for (NSInteger modifier = 0; modifier < 16; modifier++) {
        [bindings addObject:@{
            @"key": @"38",
            @"mod": [NSString stringWithFormat:@"%ld", (long)modifier],
            @"adj": @{@"Exposure2012": @"-0.1"}
        }];
    }
    NSError *error = nil;

    XCTAssertTrue(VSCOValidateKeyfile(@{@"modeKey": @"53", @"keys": bindings}, &error));
    XCTAssertNil(error);
}

- (void)testKeyfilePreservesMultiActionRemapAndPresetPayloads
{
    NSDictionary *keyfile = @{
        @"modeKey": @"53",
        @"keys": @[
            @{@"key": @"38", @"mod": @"0", @"adj": @{
                @"Exposure2012": @"-0.1",
                @"Saturation": @"1",
                @"_RemapKey": @{@"key": @"40", @"mod": @"15"}
            }},
            @{@"key": @"40", @"mod": @"1", @"adj": @{@"_SetPreset": @"Folder/Preset"}}
        ]
    };
    NSDictionary *original = [keyfile copy];
    NSError *error = nil;

    XCTAssertTrue(VSCOValidateKeyfile(keyfile, &error));
    XCTAssertNil(error);
    XCTAssertEqualObjects(keyfile, original);
}

- (void)testKeyfileRejectsEmptyPresetAndMalformedBinding
{
    NSError *error = nil;
    NSDictionary *emptyPreset = @{
        @"modeKey": @"53",
        @"keys": @[@{@"key": @"38", @"mod": @"0", @"adj": @{@"_SetPreset": @"  "}}]
    };
    XCTAssertFalse(VSCOValidateKeyfile(emptyPreset, &error));
    XCTAssertNotNil(error);

    NSDictionary *invalidMask = @{
        @"modeKey": @"53",
        @"keys": @[@{@"key": @"38", @"mod": @"16", @"adj": @{@"Exposure2012": @"-0.1"}}]
    };
    XCTAssertFalse(VSCOValidateKeyfile(invalidMask, &error));
    XCTAssertNotNil(error);
}

- (void)testActionPopupKeepsDuplicateTitlesAlignedWithActionIDs
{
    NSArray *actionKeys = @[
        @"PrimaryDisplayLoupe",
        @"PrimaryDisplayLoupeAlias",
        @"straightenAngle",
        @"MaskSubBack",
        @"Tint",
        @"Texture",
        @"ResetCrop",
        @"ResetParametricDarks"
    ];
    NSDictionary *actionNames = @{
        @"PrimaryDisplayLoupe": @"Primary Display Loupe",
        @"PrimaryDisplayLoupeAlias": @"Primary Display Loupe",
        @"straightenAngle": @"Straighten Angle",
        @"MaskSubBack": @"Subtract from mask... background",
        @"Tint": @"Tint",
        @"Texture": @"Texture (PV 3+)",
        @"ResetCrop": @"Reset Crop",
        @"ResetParametricDarks": @"Reset Dark Tones"
    };

    NSMutableArray *commands = [NSMutableArray array];
    for (NSString *actionKey in actionKeys) {
        [commands addObject:@{@"id": actionKey, @"name": actionNames[actionKey]}];
    }
    NSArray *categories = @[@{@"category": @"Actions", @"items": commands}];

    for (NSString *actionKey in [actionKeys subarrayWithRange:NSMakeRange(2, 6)]) {
        NSPopUpButton *popup = VSCOCreateActionPopup(actionKeys, actionNames, categories, actionKey, NSZeroRect, nil, nil, 0);
        XCTAssertEqual(popup.numberOfItems, (NSInteger)2);
        XCTAssertEqualObjects(popup.titleOfSelectedItem, actionNames[actionKey]);
        XCTAssertEqualObjects(popup.selectedItem.representedObject, actionKey);
        XCTAssertEqual(popup.menu.itemArray[1].submenu.numberOfItems, (NSInteger)actionKeys.count);
    }
}

- (NSDictionary *)keyboardLayoutNamed:(NSString *)name
{
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:name ofType:@"json"];
    NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
    NSError *error = nil;
    NSDictionary *layout = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
    XCTAssertNotNil(layout, @"Could not load keyboard layout %@: %@", name, error);
    return layout;
}

- (NSDictionary *)keyWithCode:(NSString *)code inKeyboardView:(MacBookKeyboardView *)keyboardView
{
    for (NSDictionary *item in keyboardView.keyItems) {
        if ([item[@"code"] isEqualToString:code]) return item;
    }
    return nil;
}

- (void)testKeyboardArrowGeometryMatchesAcrossLayoutsAndScales
{
    NSArray *layoutNames = @[@"AppleMagicANSIKeyboard", @"MacBookISOKeyboard"];
    CGFloat expectedGapRatio = 0.12 / 0.66;

    for (NSString *layoutName in layoutNames) {
        MacBookKeyboardView *keyboardView = [[MacBookKeyboardView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 700)];
        [keyboardView setKeyboardLayoutDefinition:[self keyboardLayoutNamed:layoutName]];

        NSDictionary *leftKey = [self keyWithCode:@"123" inKeyboardView:keyboardView];
        NSDictionary *downKey = [self keyWithCode:@"125" inKeyboardView:keyboardView];
        NSDictionary *rightKey = [self keyWithCode:@"124" inKeyboardView:keyboardView];
        NSDictionary *upKey = [self keyWithCode:@"126" inKeyboardView:keyboardView];
        XCTAssertNotNil(leftKey);
        XCTAssertNotNil(downKey);
        XCTAssertNotNil(rightKey);
        XCTAssertNotNil(upKey);

        NSRect leftFrame = [keyboardView frameForKeyItem:leftKey];
        NSRect downFrame = [keyboardView frameForKeyItem:downKey];
        NSRect rightFrame = [keyboardView frameForKeyItem:rightKey];
        NSRect upFrame = [keyboardView frameForKeyItem:upKey];
        CGFloat leftGap = NSMinX(downFrame) - NSMaxX(leftFrame);
        CGFloat rightGap = NSMinX(rightFrame) - NSMaxX(downFrame);
        XCTAssertEqualWithAccuracy(leftGap, rightGap, 0.01);
        XCTAssertEqualWithAccuracy(NSMidX(upFrame), NSMidX(downFrame), 0.01);
        XCTAssertGreaterThan(NSMinY(upFrame), NSMaxY(downFrame));

        CGFloat normalizedGap = leftGap / NSWidth(leftFrame);
        XCTAssertEqualWithAccuracy(normalizedGap, expectedGapRatio, 0.001);

        [keyboardView setFrameSize:NSMakeSize(700, 500)];
        leftFrame = [keyboardView frameForKeyItem:leftKey];
        downFrame = [keyboardView frameForKeyItem:downKey];
        normalizedGap = (NSMinX(downFrame) - NSMaxX(leftFrame)) / NSWidth(leftFrame);
        XCTAssertEqualWithAccuracy(normalizedGap, expectedGapRatio, 0.001);
    }
}

- (void)testKeyCodeLookupDoesNotTrapOffMainThread
{
    XCTestExpectation *done = [self expectationWithDescription:@"background key-code lookups"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (NSInteger i = 0; i < 50; i++) {
            CGKeyCode keyCode = 0;
            CGEventFlags eventFlags = 0;
            VSCOResolveKeyCodeForCharacter(@"v", &keyCode, &eventFlags);
            VSCOResolveKeyCodeForCharacter(@"]", &keyCode, &eventFlags);
        }
        [done fulfill];
    });
    [self waitForExpectations:@[done] timeout:5];
}

- (void)testKeyboardCanvasSizePreservesRequestedUnitScale
{
    MacBookKeyboardView *keyboardView = [[MacBookKeyboardView alloc] initWithFrame:NSMakeRect(0, 0, 825, 161)];
    [keyboardView setKeyboardLayoutDefinition:[self keyboardLayoutNamed:@"AppleMagicANSIKeyboard"]];
    CGFloat editorScale = [keyboardView keyboardUnitScale];

    for (NSNumber *scaleFactor in @[@1, @0.5]) {
        CGFloat expectedScale = editorScale * scaleFactor.doubleValue;
        [keyboardView setFrameSize:[keyboardView canvasSizeForKeyboardUnitScale:expectedScale]];
        XCTAssertEqualWithAccuracy([keyboardView keyboardUnitScale], expectedScale, 0.001);
    }
}

- (void)testKeyboardSwapNextKeyOnRight
{
    MacBookKeyboardView *keyboardView = [[MacBookKeyboardView alloc] initWithFrame:NSMakeRect(0, 0, 825, 161)];
    [keyboardView setKeyboardLayoutDefinition:[self keyboardLayoutNamed:@"AppleMagicANSIKeyboard"]];

    // F8 ("100") -> next to right should be F9 ("101")
    NSString *nextAfterF8 = [keyboardView nextKeyCodeToTheRightOf:@"100"];
    XCTAssertEqualObjects(nextAfterF8, @"101", @"Next key to the right of F8 should be F9");

    // F11 ("103") -> next to right should be F12 ("111")
    NSString *nextAfterF11 = [keyboardView nextKeyCodeToTheRightOf:@"103"];
    XCTAssertEqualObjects(nextAfterF11, @"111", @"Next key to the right of F11 should be F12");

    // F12 ("111") is the rightmost key in row 0 -> should be nil
    NSString *nextAfterF12 = [keyboardView nextKeyCodeToTheRightOf:@"111"];
    XCTAssertNil(nextAfterF12, @"F12 is at the end of the row, so next key should be nil");

    // Number row: "1" ("18") -> next to right is "2" ("19")
    NSString *nextAfter1 = [keyboardView nextKeyCodeToTheRightOf:@"18"];
    XCTAssertEqualObjects(nextAfter1, @"19", @"Next key to the right of 1 should be 2");
}

- (void)testKeyboardSwapSortedKeyCodes
{
    MacBookKeyboardView *keyboardView = [[MacBookKeyboardView alloc] initWithFrame:NSMakeRect(0, 0, 825, 161)];
    [keyboardView setKeyboardLayoutDefinition:[self keyboardLayoutNamed:@"AppleMagicANSIKeyboard"]];

    // Even if passed in reverse order {F12, F11}, sortedKeyCodesForKeys should return [F11, F12]
    NSSet *keys = [NSSet setWithObjects:@"111", @"103", nil];
    NSArray *sorted = [keyboardView sortedKeyCodesForKeys:keys];
    NSArray *expected = @[@"103", @"111"];
    XCTAssertEqualObjects(sorted, expected, @"Keys should be sorted in layout order: F11 before F12");

    // F8 and F9
    NSSet *f8f9 = [NSSet setWithObjects:@"101", @"100", nil];
    NSArray *sortedF8F9 = [keyboardView sortedKeyCodesForKeys:f8f9];
    NSArray *expectedF8F9 = @[@"100", @"101"];
    XCTAssertEqualObjects(sortedF8F9, expectedF8F9, @"Keys should be sorted: F8 before F9");
}

- (void)testKeyboardSwapDragOperation
{
    MacBookKeyboardView *keyboardView = [[MacBookKeyboardView alloc] initWithFrame:NSMakeRect(0, 0, 825, 161)];
    [keyboardView setKeyboardLayoutDefinition:[self keyboardLayoutNamed:@"AppleMagicANSIKeyboard"]];

    TestKeyboardSwapDelegate *delegate = [[TestKeyboardSwapDelegate alloc] init];
    keyboardView.delegate = delegate;

    // Find the center point of F8 ("100")
    NSDictionary *f8Item = [keyboardView keyItemForCode:@"100"];
    XCTAssertNotNil(f8Item);
    NSRect f8Frame = [keyboardView frameForKeyItem:f8Item];
    NSPoint f8Center = NSMakePoint(NSMidX(f8Frame), NSMidY(f8Frame));

    // Test dropping 2 keys (F11 and F12) onto F8
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
    [pasteboard setPropertyList:@{@"keyCodes": @[@"103", @"111"], @"anchorKeyCode": @"103"}
                        forType:@"com.vsco.keys.binding-key-codes"];

    TestDraggingInfo *info = [[TestDraggingInfo alloc] init];
    info.draggingPasteboard = pasteboard;
    info.draggingLocation = f8Center;

    BOOL result = [keyboardView performDragOperation:(id<NSDraggingInfo>)info];
    XCTAssertTrue(result);
    XCTAssertEqualObjects(delegate.swappedSourceKeys, (@[@"103", @"111"]));
    XCTAssertEqualObjects(delegate.swappedTargetKey, @"100");

    // Test dropping more than 2 keys (e.g. 3 keys) -> should be rejected
    NSPasteboard *pasteboard3 = [NSPasteboard pasteboardWithUniqueName];
    [pasteboard3 setPropertyList:@{@"keyCodes": @[@"100", @"101", @"109"], @"anchorKeyCode": @"100"}
                         forType:@"com.vsco.keys.binding-key-codes"];
    info.draggingPasteboard = pasteboard3;

    BOOL result3 = [keyboardView performDragOperation:(id<NSDraggingInfo>)info];
    XCTAssertFalse(result3);
    XCTAssertEqualObjects(delegate.failedMessage, @"Can only swap 1 or 2 keys at a time.");
}

@end

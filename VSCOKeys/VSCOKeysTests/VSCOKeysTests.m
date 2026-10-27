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


@end

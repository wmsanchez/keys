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

@implementation VSCOKeysTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
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
        NSPopUpButton *popup = VSCOCreateActionPopup(actionKeys, actionNames, categories, actionKey, NSZeroRect);
        XCTAssertEqual(popup.numberOfItems, (NSInteger)2);
        XCTAssertEqualObjects(popup.titleOfSelectedItem, actionNames[actionKey]);
        XCTAssertEqualObjects(popup.selectedItem.representedObject, actionKey);
        XCTAssertEqual(popup.menu.itemArray[1].submenu.numberOfItems, (NSInteger)actionKeys.count);
    }
}

@end

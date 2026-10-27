//
//  KeyControl.m
//  VSCOKeys
//
//  Created by Sean Gubelman on 7/16/12.
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

#import "KeyControl.h"
#import "KeyfileValidator.h"
#import "AppDelegate.h"

#import "SBJson.h"
#import "HttpRequest.h"

#import "AboutWindowController.h"
#import "QuickWindowController.h"
#import "KeyboardHUDWindowController.h"
#import "KeyboardLayoutEditorController.h"
#import "KeysEditorWindowController.h"
#import "MainWindowController.h"

#import "NSData+Cryption.h"
#import "NSString+UUID.h"
#import "NSString+Cryption.h"
#import "NSColor+FromHex.h"
#import "NSFileManager+DirectoryLocations.h"
#import "NSString+MD5.h"
#import <Carbon/Carbon.h>
#import <math.h>

static const int64_t kVSCOInjectedKeyEventMarker = 0x5653434f;

static BOOL VSCOKeyCodeForCharacter(NSString *character, CGKeyCode *keyCode, CGEventFlags *eventFlags)
{
    if (character.length != 1 || !keyCode || !eventFlags) return NO;

    TISInputSourceRef source = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData = source ? TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) : NULL;
    if (!layoutData) {
        if (source) CFRelease(source);
        source = TISCopyCurrentKeyboardLayoutInputSource();
        layoutData = source ? TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) : NULL;
    }
    if (!layoutData || !source) {
        if (source) CFRelease(source);
        return NO;
    }

    const UCKeyboardLayout *layout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
    UniChar target = [character characterAtIndex:0];
    const UInt32 modifierStates[] = {0, 2, 8, 10};
    BOOL found = NO;
    if (layout) {
        for (UInt16 code = 0; code <= 0xFF && !found; code++) {
            for (NSUInteger index = 0; index < sizeof(modifierStates) / sizeof(modifierStates[0]); index++) {
                UInt32 deadKeyState = 0;
                UniChar translatedCharacter = 0;
                UniCharCount characterCount = 0;
                OSStatus result = UCKeyTranslate(layout, code, kUCKeyActionDown, modifierStates[index],
                                                 LMGetKbdLast(), kUCKeyTranslateNoDeadKeysBit,
                                                 &deadKeyState, 1, &characterCount, &translatedCharacter);
                if (result == noErr && characterCount == 1 && translatedCharacter == target) {
                    *keyCode = code;
                    *eventFlags = 0;
                    if (modifierStates[index] & 2) *eventFlags |= kCGEventFlagMaskShift;
                    if (modifierStates[index] & 8) *eventFlags |= kCGEventFlagMaskAlternate;
                    found = YES;
                    break;
                }
            }
        }
    }
    CFRelease(source);
    return found;
}

@interface KeyControl ()
@property (retain) NSString *physicalKeyboardLayoutIdentifier;
@property (retain) NSString *brushIncreaseKey;
@property (retain) NSString *brushDecreaseKey;
@property (assign) CGKeyCode brushIncreaseKeyCode;
@property (assign) CGEventFlags brushIncreaseEventFlags;
@property (assign) BOOL brushIncreaseKeyCodeValid;
@property (assign) CGKeyCode brushDecreaseKeyCode;
@property (assign) CGEventFlags brushDecreaseEventFlags;
@property (assign) BOOL brushDecreaseKeyCodeValid;
@property (assign) CGKeyCode pastePreviousKeyCode;
@property (assign) CGEventFlags pastePreviousEventFlags;
@property (assign) BOOL pastePreviousKeyCodeValid;
- (void)toggleKeyboardHUD:(id)sender;
- (void)setKeyboardHUDVisible:(BOOL)visible;
- (void)setKeyboardHUDVisibleForCapsLock:(NSNumber *)enabled;
- (void)toggleKeyboardHUDShortLabels:(id)sender;
- (void)selectPhysicalKeyboardLayoutFromMenu:(id)sender;
- (void)selectPhysicalKeyboardLayout:(NSString *)layoutIdentifier;
- (void)editCurrentLayout;
- (void)updateKeyboardHUDForEvent:(NSDictionary *)eventInfo;
- (void)refreshKeyboardHUDBindings;
- (NSDictionary *)commandForKeyCode:(int)keyCode modifierFlags:(CGEventFlags)modifiers;
- (NSString *)actionTitleForCommand:(NSDictionary *)command;
- (NSUInteger)modifierMaskForEventFlags:(CGEventFlags)flags;
- (void)updateShortcutKeyCodes:(NSDictionary *)shortcuts;
- (void)postShortcutWithKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)eventFlags;
- (void)sendBrushSizeChange:(double)delta;
- (void)sendPasteSettingsFromPrevious;
@end

@implementation KeyControl

@synthesize window;
@synthesize mainController;

@synthesize aboutWindow;
@synthesize quickWindow;
@synthesize licenseWindow;

@synthesize statusBar;
@synthesize statusBarIconActive;
@synthesize statusBarIconInactive;
@synthesize statusBarIconError;

@synthesize toggleMenuItem;
@synthesize keyboardHUDMenuItem, keyboardHUDWindowController;
@synthesize keyboardHUDEnabled;
@synthesize keyboardHUDShowsIncrements, keyboardHUDLabelStyle;

@synthesize activeKeyFile;
@synthesize physicalKeyboardLayoutIdentifier;
@synthesize brushIncreaseKey, brushDecreaseKey;

@synthesize keyThread;
@synthesize statusThread;

@synthesize authToken;
@synthesize authUUID;
@synthesize authTimestamp;
//@synthesize authSuccess;
@synthesize authContinueTrial;
@synthesize showQuickStart;

@synthesize keysDict;
@synthesize controlToggleKey;
@synthesize isServerAvailable;
@synthesize isKeyControlActive;
@synthesize eventTap;

@synthesize appIdList;
@synthesize lrVersion;

@synthesize keyfileList;

@synthesize keyMapping;
@synthesize adjustmentMapping;
@synthesize adjustmentLimits;
@synthesize commandCategories;
@synthesize allCommandCategories, hiddenCommandIdentifiers, pluginSettingsTimer, pluginSettingsRequestInProgress;
@synthesize availableDevelopPresets;

@synthesize numFormatter;
@synthesize blackStyle;
@synthesize redStyle;
@synthesize goldStyle;

@synthesize keyfileDirectory;

@synthesize isInTextField;

- (id)init {
    self = [super init];
    if (self)
    {
        self.authContinueTrial = NO;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *savedLabelStyle = [defaults stringForKey:DEFAULTS_KEYBOARD_HUD_LABEL_STYLE];
        self.keyboardHUDLabelStyle = [@[KEYBOARD_HUD_LABEL_STYLE_STANDARD, KEYBOARD_HUD_LABEL_STYLE_MOTIBODO] containsObject:savedLabelStyle]
            ? savedLabelStyle : KEYBOARD_HUD_LABEL_STYLE_STANDARD;
        self.keyboardHUDShowsIncrements = [defaults boolForKey:DEFAULTS_KEYBOARD_HUD_SHOW_INCREMENTS];
        NSString *savedLayout = [defaults stringForKey:DEFAULTS_PHYSICAL_KEYBOARD_LAYOUT];
        NSArray *layoutOptions = [self physicalKeyboardLayoutOptions];
        BOOL supportedLayout = [layoutOptions indexOfObjectPassingTest:^BOOL(NSDictionary *option, NSUInteger index, BOOL *stop) {
            return [[option objectForKey:@"id"] isEqualToString:savedLayout];
        }] != NSNotFound;
        self.physicalKeyboardLayoutIdentifier = supportedLayout ? savedLayout : KEYBOARD_LAYOUT_MACBOOK_ISO;
        [self updateShortcutKeyCodes:@{@"increase": @"]", @"decrease": @"[", @"pastePrevious": @"v"}];

        self.keyfileDirectory = [[NSFileManager defaultManager] applicationSupportDirectory];

        [self copyBaseKeyfilesToDirectory];

        [self resetStatusMenu];

        [self initAppList];
        [self initMappings];
                self.hiddenCommandIdentifiers = [NSSet set];
                [self refreshPluginSettings:nil];
                self.pluginSettingsTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                                                                                                        target:self
                                                                                                                                    selector:@selector(refreshPluginSettings:)
                                                                                                                                    userInfo:nil
                                                                                                                                     repeats:YES];

        self.lrVersion = [self getLRVersion];

        [self loadAllKeyfiles];

        self.statusBarIconActive = [NSImage imageNamed:@"StatusBarIcon_Active.png"];
        self.statusBarIconInactive = [NSImage imageNamed:@"StatusBarIcon_Inactive.png"];
        self.statusBarIconError = [NSImage imageNamed:@"StatusBarIcon_Error.png"];

        NSStatusBar *bar = [NSStatusBar systemStatusBar];

        statusBar = [bar statusItemWithLength:NSSquareStatusItemLength];

        [statusBar setImage:self.statusBarIconError];
        [statusBar setHighlightMode:YES];
        [self resetStatusMenu];

        self.numFormatter = [[NSNumberFormatter alloc] init];


        NSMutableParagraphStyle *centered = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [centered setAlignment:NSCenterTextAlignment];


        self.blackStyle = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSColor colorWithHex:0x000000], NSForegroundColorAttributeName,
                                    centered, NSParagraphStyleAttributeName,
                                    [NSFont fontWithName:PROXIMA_FONT_NAME size:11], NSFontAttributeName,
                                    nil];

        NSMutableDictionary *_redStyle = [blackStyle mutableCopy];
        [_redStyle setValue:[NSColor colorWithHex:0xff3300] forKey:NSForegroundColorAttributeName];
        self.redStyle = _redStyle;

        NSMutableDictionary *_goldStyle = [blackStyle mutableCopy];
        [_goldStyle setValue:[NSColor colorWithHex:0xa7a648] forKey:NSForegroundColorAttributeName];
        self.goldStyle = _goldStyle;
    }
    return self;
}



#pragma mark Server Connection


- (void)sendUpdate:(NSDictionary *)update
{
    self.isServerAvailable = false;

    [HttpRequest sendJsonTo:SERVER_UPDATE_ENDPOINT data:update
                  responded:^(NSURLConnection *connection, NSURLResponse *response, NSData *data, NSString *mimeType) {
                      DualLog(@"SendUpdate success: %@", update);
                      self.isServerAvailable = true;
                  }
                     failed:^(NSURLConnection *connection, NSError *error) {
                         DualLog(@"server connect failed with error: %@", error);
                         self.isServerAvailable = false;
                     }];
}


- (void)checkServerAvailability
{
    [self sendUpdate:[NSDictionary dictionary]];
}

- (void)loadAvailableDevelopPresetsWithCompletion:(void (^)(NSArray *presets))completion
{
    [HttpRequest sendGetTo:SERVER_PRESETS_ENDPOINT responded:^(NSURLConnection *connection, NSURLResponse *response, NSData *data, NSString *mimeType) {
        NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        id decoded = [body JSONValue];
        NSArray *presets = [decoded isKindOfClass:[NSArray class]] ? decoded : [NSArray array];
        self.availableDevelopPresets = presets;
        if (completion) completion(presets);
    } failed:^(NSURLConnection *connection, NSError *error) {
        DualLog(@"Unable to load Lightroom develop presets: %@", error);
        if (completion) completion(self.availableDevelopPresets ?: [NSArray array]);
    }];
}


#pragma mark Menu

- (void)showWindow
{
    // Prefer self.window (set by AppDelegate); fall back to mainController.window
    NSWindow *win = self.window ?: self.mainController.window;
    if (!win) {
        DualLog(@"showWindow: window is nil, cannot open settings.");
        return;
    }
    [self.mainController listButtonPressed:nil];  // reset to list tab
    [win setIsVisible:YES];
    [NSApp activateIgnoringOtherApps:YES];
    [win makeKeyAndOrderFront:nil];
}

- (void)showAbout
{
    if (self.aboutWindow == nil)
    {
        AboutWindowController *controller = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindow"];

        controller.keyControl = self;

        [controller.window display];
        self.aboutWindow = controller;
    }

    [NSApp activateIgnoringOtherApps:YES];
    [self.aboutWindow.window makeKeyAndOrderFront:nil];
}

- (void)editCurrentLayout
{
    NSDictionary *keyfile = [self.keyfileList objectForKey:self.activeKeyFile];
    if (!keyfile || !self.mainController) return;

    [self.mainController openEditorForKeyfile:keyfile];
    [NSApp activateIgnoringOtherApps:YES];
    [self.mainController.window makeKeyAndOrderFront:nil];
}

- (void)quitApplication
{
    [self.keyboardHUDWindowController hideHUD];
    [[NSApplication sharedApplication] terminate:nil];
}

- (NSMenuItem *)addItem:(NSString *)title toMenu:(NSMenu *)menu target:(id)target selector:(SEL)selector object:(id)repObject
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:NULL keyEquivalent:@""];
    [item setTarget:target];
    [item setAction:selector];
    if (repObject != NULL)
    {
        [item setRepresentedObject:repObject];
    }

    [menu addItem:item];

    return item;
}

- (void)setMenuForKeyFileActive
{
    for (NSMenuItem *item in [[statusBar menu] itemArray])
    {
        NSString *obj = [item representedObject];

        if (obj != nil)
        {
            if ([obj compare:self.activeKeyFile] == NSOrderedSame)
            {
                [item setState:NSOnState];
            }
            else
            {
                [item setState:NSOffState];
            }
        }
    }
}

- (IBAction)selectedKeyFile:(id)sender
{
    [self activateKeyfileWithUUID:[sender representedObject]];
}

- (void)activateKeyfileWithUUID:(NSString *)uuid
{
    if (!uuid || [uuid length] == 0) return;

    self.activeKeyFile = uuid;
    [self refreshKeyboardHUDBindings];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:self.activeKeyFile forKey:DEFAULTS_ACTIVE_KEYFILE];

    [self setMenuForKeyFileActive];

    if (self.keyThread) {
        [self performSelector:@selector(loadDictionaryFromActiveKeysFile) onThread:self.keyThread withObject:NULL waitUntilDone:NO];
    } else {
        [self loadDictionaryFromActiveKeysFile];
    }
}

- (BOOL)saveKeyfile:(NSDictionary *)keyfile error:(NSError **)error
{
    if (![self validateKeyfile:keyfile error:error]) return NO;

    NSString *uuid = [keyfile objectForKey:KEYFILE_UUID_NODENAME];
    NSString *name = [keyfile objectForKey:KEYFILE_NAME_NODENAME];
    NSString *json = [keyfile JSONRepresentation];
    if (!uuid || [uuid length] == 0 || ![name isKindOfClass:[NSString class]] || name.length == 0 || !json) {
        if (error) {
            *error = [NSError errorWithDomain:@"VSCOKeys.Keyfile"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"The layout could not be serialized."}];
        }
        return NO;
    }

    NSString *fileNameBase = [name stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    fileNameBase = [fileNameBase stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    fileNameBase = [fileNameBase stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (fileNameBase.length == 0) fileNameBase = @"Layout";

    NSDictionary *existingKeyfile = [self.keyfileList objectForKey:uuid];
    NSString *existingFilename = [existingKeyfile objectForKey:KEYFILE_FILENAME_NODENAME];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filename = [fileNameBase stringByAppendingPathExtension:KEYFILE_JSON_EXTENSION];
    NSUInteger suffix = 2;
    NSString *path = [self.keyfileDirectory stringByAppendingPathComponent:filename];
    while ([fileManager fileExistsAtPath:path] && ![filename isEqualToString:existingFilename]) {
        filename = [NSString stringWithFormat:@"%@ (%lu).%@", fileNameBase, (unsigned long)suffix++, KEYFILE_JSON_EXTENSION];
        path = [self.keyfileDirectory stringByAppendingPathComponent:filename];
    }

    NSError *writeError = nil;
    if (![json writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
        if (error) *error = writeError;
        return NO;
    }

    if (existingFilename.length > 0 && ![existingFilename isEqualToString:filename]) {
        NSString *existingPath = [self.keyfileDirectory stringByAppendingPathComponent:existingFilename];
        if ([fileManager fileExistsAtPath:existingPath] && ![fileManager removeItemAtPath:existingPath error:&writeError]) {
            [fileManager removeItemAtPath:path error:NULL];
            if (error) *error = writeError;
            return NO;
        }
    }

    [self loadAllKeyfiles];
    [self resetStatusMenu];
    [self activateKeyfileWithUUID:uuid];
    return YES;
}

- (BOOL)validateKeyfile:(NSDictionary *)keyfile error:(NSError **)error
{
    if (!VSCOValidateKeyfile(keyfile, error)) return NO;
    for (NSDictionary *binding in [keyfile objectForKey:KEYFILE_KEYS_NODENAME]) {
        NSDictionary *adjustments = [binding objectForKey:KEYFILE_ADJUSTMENTS_NODENAME];
        for (NSString *action in adjustments) {
            if ([action isEqualToString:KEYFILE_ADJUSTMENT_REMAP_NODENAME] || [action isEqualToString:@"_SetPreset"] ||
                [self.adjustmentMapping objectForKey:action]) continue;
            if (error) {
                *error = [NSError errorWithDomain:@"VSCOKeys.Keyfile"
                                             code:5
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Action %@ is not supported by this version of VSCO Keys.", action]}];
            }
            return NO;
        }
    }
    return YES;
}

- (void)resetStatusMenu
{
    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"main"];

    self.toggleMenuItem = [self addItem:STATUSMENUITEM_INACTIVE toMenu:theMenu target:self selector:@selector(toggleKeyControlActive) object:NULL];

    [self addItem:STATUSMENUITEM_PREFERENCES toMenu:theMenu target:self selector:@selector(showWindow) object:NULL];
    self.keyboardHUDMenuItem = [self addItem:@"Show Keyboard Overlay" toMenu:theMenu target:self selector:@selector(toggleKeyboardHUD:) object:NULL];
    self.keyboardHUDEnabled = self.keyboardHUDWindowController.window.isVisible;
    [self.keyboardHUDMenuItem setState:self.keyboardHUDEnabled ? NSOnState : NSOffState];
    NSMenuItem *layoutItem = [[NSMenuItem alloc] initWithTitle:@"Physical Keyboard" action:nil keyEquivalent:@""];
    NSMenu *layoutMenu = [[NSMenu alloc] initWithTitle:@"Physical Keyboard"];
    for (NSDictionary *option in [self physicalKeyboardLayoutOptions]) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[option objectForKey:@"name"] action:@selector(selectPhysicalKeyboardLayoutFromMenu:) keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:[option objectForKey:@"id"]];
        [item setState:[[option objectForKey:@"id"] isEqualToString:self.physicalKeyboardLayoutIdentifier] ? NSOnState : NSOffState];
        [layoutMenu addItem:item];
    }
    [layoutItem setSubmenu:layoutMenu];
    [theMenu addItem:layoutItem];

    [theMenu addItem:[NSMenuItem separatorItem]];

    NSImage *onImage = [NSImage imageNamed:@"SelectedMenu.png"];

    for (NSString *key in [self getUUIDsSortedByName])
    {
        NSDictionary *keyfile = [self.keyfileList valueForKey:key];

        if (![[keyfile objectForKey:DEFAULTS_KEYFILE_ISACTIVE] boolValue])
        {
            continue;
        }

        NSString *name = [keyfile objectForKey:KEYFILE_NAME_NODENAME];

        NSMenuItem *menuItem = [self addItem:name toMenu:theMenu target:self selector:@selector(selectedKeyFile:) object:key];

        [menuItem setOnStateImage:onImage];
    }

    [theMenu addItem:[NSMenuItem separatorItem]];
    [self addItem:@"Edit Current Layout" toMenu:theMenu target:self selector:@selector(editCurrentLayout) object:NULL];
    [theMenu addItem:[NSMenuItem separatorItem]];

    [self addItem:STATUSMENUITEM_ABOUT toMenu:theMenu target:self selector:@selector(showAbout) object:NULL];

    [self addItem:STATUSMENUITEM_QUIT toMenu:theMenu target:self selector:@selector(quitApplication) object:NULL];

    [self.statusBar setMenu:theMenu];

    [self setMenuForKeyFileActive];
    [self refreshKeyboardHUDBindings];
}

- (void)toggleKeyboardHUD:(id)sender
{
    [self setKeyboardHUDVisible:!self.keyboardHUDWindowController.window.isVisible];
}

- (void)setKeyboardHUDVisibleForCapsLock:(NSNumber *)enabled
{
    [self setKeyboardHUDVisible:enabled.boolValue];
}

- (void)setKeyboardHUDVisible:(BOOL)visible
{
    if (!self.keyboardHUDWindowController) {
        self.keyboardHUDWindowController = [[KeyboardHUDWindowController alloc] initWithKeyMapping:self.keyMapping];
    }
    [self.keyboardHUDWindowController setKeyboardLayoutDefinition:[self physicalKeyboardLayoutDefinition]];
    [self refreshKeyboardHUDBindings];
    if (visible && !self.keyboardHUDWindowController.window.isVisible) {
        CGFloat keyboardUnitScale = [self.mainController keyboardEditorPreviewUnitScale];
        [self.keyboardHUDWindowController setKeyboardUnitScale:keyboardUnitScale];
        [self.keyboardHUDWindowController showHUD];
    } else if (!visible && self.keyboardHUDWindowController.window.isVisible) {
        [self.keyboardHUDWindowController hideHUD];
    }
    self.keyboardHUDEnabled = self.keyboardHUDWindowController.window.isVisible;
    [self.keyboardHUDMenuItem setState:self.keyboardHUDEnabled ? NSOnState : NSOffState];
}

- (NSArray *)physicalKeyboardLayoutOptions
{
    return @[
        @{@"id": KEYBOARD_LAYOUT_MACBOOK_ISO, @"name": @"MacBook Pro ISO (AZERTY, QWERTY caps)"},
        @{@"id": KEYBOARD_LAYOUT_APPLE_MAGIC_ANSI, @"name": @"Apple Magic Keyboard (QWERTY ANSI)"}
    ];
}

- (NSDictionary *)physicalKeyboardLayoutDefinition
{
    NSString *resourceName = [self.physicalKeyboardLayoutIdentifier isEqualToString:KEYBOARD_LAYOUT_APPLE_MAGIC_ANSI]
        ? @"AppleMagicANSIKeyboard"
        : @"MacBookISOKeyboard";
    NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"json"];
    NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
    return data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
}

- (void)selectPhysicalKeyboardLayoutFromMenu:(NSMenuItem *)sender
{
    [self selectPhysicalKeyboardLayout:[sender representedObject]];
}

- (void)selectPhysicalKeyboardLayout:(NSString *)layoutIdentifier
{
    BOOL supported = NO;
    for (NSDictionary *option in [self physicalKeyboardLayoutOptions]) {
        if ([[option objectForKey:@"id"] isEqualToString:layoutIdentifier]) {
            supported = YES;
            break;
        }
    }
    if (!supported || [layoutIdentifier isEqualToString:self.physicalKeyboardLayoutIdentifier]) return;

    self.physicalKeyboardLayoutIdentifier = layoutIdentifier;
    [[NSUserDefaults standardUserDefaults] setObject:layoutIdentifier forKey:DEFAULTS_PHYSICAL_KEYBOARD_LAYOUT];
    [self.mainController.keyboardEditorController reloadPhysicalKeyboardLayout];
    [self.keyboardHUDWindowController setKeyboardLayoutDefinition:[self physicalKeyboardLayoutDefinition]];
    [self resetStatusMenu];
}

- (void)refreshKeyboardHUDBindings
{
    if (!self.keyboardHUDWindowController) return;
    NSDictionary *keyfile = [self.keyfileList objectForKey:self.activeKeyFile];
    NSArray *bindings = [keyfile objectForKey:KEYFILE_KEYS_NODENAME];
    [self.keyboardHUDWindowController setBindings:bindings ?: @[]
                               adjustmentMapping:self.adjustmentMapping ?: @{}
                                adjustmentLimits:self.adjustmentLimits ?: @{}];
    NSDictionary *customLabels = [[NSUserDefaults standardUserDefaults] dictionaryForKey:DEFAULTS_KEYBOARD_HUD_CUSTOM_LABELS] ?: @{};
    NSDictionary *customPresetLabels = [[NSUserDefaults standardUserDefaults] dictionaryForKey:DEFAULTS_KEYBOARD_HUD_CUSTOM_PRESET_LABELS] ?: @{};
    [self.keyboardHUDWindowController setLabelStyle:self.keyboardHUDLabelStyle
                               showsIncrementAmounts:self.keyboardHUDShowsIncrements
                                       customLabels:customLabels
                                 customPresetLabels:customPresetLabels];
}

- (NSString *)shortLabelForAction:(NSString *)action customLabels:(NSDictionary *)customLabels
{
    if ([action isEqualToString:@"_SetPreset"]) return @"Preset";
    NSString *customLabel = [[customLabels objectForKey:action] description];
    if (customLabel.length > 0) return customLabel;

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
    NSString *title = [shortNames objectForKey:action];
    if (title) return title;

    NSString *mappedTitle = [[self.adjustmentMapping objectForKey:action] description] ?: action;
    NSArray *words = [mappedTitle componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *firstWord = [words filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *word, NSDictionary *bindings) {
        return word.length > 0 && ![word hasPrefix:@"("];
    }]].firstObject;
    title = firstWord ?: action;
    return title.length > 7 ? [title substringToIndex:7] : title;
}

- (NSString *)presetLabelForValue:(id)value customLabels:(NSDictionary *)customLabels
{
    NSString *presetValue = [value description];
    NSString *customLabel = [[customLabels objectForKey:presetValue] description];
    if (customLabel.length > 0) return customLabel;
    NSString *displayName = [presetValue lastPathComponent];
    return displayName.length > 0 ? displayName : presetValue;
}

- (void)updateKeyboardHUDLabelSettingsWithStyle:(NSString *)style showsIncrements:(BOOL)showsIncrements customLabels:(NSDictionary *)customLabels
{
    NSString *validStyle = [style isEqualToString:KEYBOARD_HUD_LABEL_STYLE_MOTIBODO]
        ? KEYBOARD_HUD_LABEL_STYLE_MOTIBODO : KEYBOARD_HUD_LABEL_STYLE_STANDARD;
    self.keyboardHUDLabelStyle = validStyle;
    self.keyboardHUDShowsIncrements = showsIncrements;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:validStyle forKey:DEFAULTS_KEYBOARD_HUD_LABEL_STYLE];
    [defaults setBool:showsIncrements forKey:DEFAULTS_KEYBOARD_HUD_SHOW_INCREMENTS];
    [defaults setObject:customLabels ?: @{} forKey:DEFAULTS_KEYBOARD_HUD_CUSTOM_LABELS];
    [self refreshKeyboardHUDBindings];
}

- (void)updateKeyboardHUDPresetLabels:(NSDictionary *)presetLabels
{
    [[NSUserDefaults standardUserDefaults] setObject:presetLabels ?: @{} forKey:DEFAULTS_KEYBOARD_HUD_CUSTOM_PRESET_LABELS];
    [self refreshKeyboardHUDBindings];
}

- (NSDictionary *)commandForKeyCode:(int)keyCode modifierFlags:(CGEventFlags)modifiers
{
    CGEventFlags relevantModifiers = modifiers & (kCGEventFlagMaskShift | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate | kCGEventFlagMaskCommand);
    for (NSDictionary *command in self.keysDict) {
        if (keyCode == [[command objectForKey:KEYFILE_KEY_NODENAME] intValue] &&
            relevantModifiers == [[command objectForKey:KEYFILE_MODIFIERS_NODENAME] unsignedLongLongValue]) {
            return command;
        }
    }
    return nil;
}

- (NSString *)actionTitleForCommand:(NSDictionary *)command
{
    NSDictionary *adjustments = [command objectForKey:KEYFILE_ADJUSTMENTS_NODENAME];
    NSArray *actions = [[adjustments allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *titles = [NSMutableArray array];
    for (NSString *action in actions) {
        id value = [adjustments objectForKey:action];
        NSString *title = nil;
        if ([action isEqualToString:KEYFILE_ADJUSTMENT_REMAP_NODENAME]) {
            id target = [value isKindOfClass:[NSDictionary class]] ? [value objectForKey:KEYFILE_KEY_NODENAME] : value;
            NSString *targetName = [self getKeynameForVirtual:[target description]] ?: [target description];
            title = [NSString stringWithFormat:@"Remap to %@", targetName];
        } else if ([action isEqualToString:@"_SetPreset"]) {
            title = [NSString stringWithFormat:@"Apply %@", value];
        } else {
            title = [self getNormalNameForAdjustment:action] ?: action;
        }
        if (title) [titles addObject:title];
    }
    return [titles componentsJoinedByString:@" · "];
}

- (NSUInteger)modifierMaskForEventFlags:(CGEventFlags)flags
{
    NSUInteger mask = 0;
    if (flags & kCGEventFlagMaskShift) mask |= 1;
    if (flags & kCGEventFlagMaskControl) mask |= 2;
    if (flags & kCGEventFlagMaskAlternate) mask |= 4;
    if (flags & kCGEventFlagMaskCommand) mask |= 8;
    return mask;
}

- (void)updateKeyboardHUDForEvent:(NSDictionary *)eventInfo
{
    if (!self.keyboardHUDWindowController.window.isVisible) return;
    NSUInteger modifierMask = [[eventInfo objectForKey:@"modifierMask"] unsignedIntegerValue];
    [self.keyboardHUDWindowController updateModifierMask:modifierMask];
    NSString *keyCode = [eventInfo objectForKey:@"keyCode"];
    if (keyCode) {
        [self.keyboardHUDWindowController showKeyCode:keyCode
                                          actionTitle:[eventInfo objectForKey:@"actionTitle"]
                                         modifierMask:modifierMask];
    }
}

- (void)statusBarUpdateLoop
{
    self.statusThread = [NSThread currentThread];

    self.isServerAvailable = NO;

    BOOL lastEngageState = ![self checkIsKeySystemEngaged];
    BOOL lastServerState = !self.isServerAvailable;

    while (true)
    {
        [self updateStatus:&lastEngageState server:&lastServerState];

        [NSThread sleepForTimeInterval:STATUSBAR_UPDATE_RATE];
    }
}

- (void)updateStatus:(BOOL *)lastEngageState server:(BOOL *)lastServerState
{
    @autoreleasepool
    {
        BOOL currEngageState = [self checkIsKeySystemEngaged];
        BOOL currServerState = self.isServerAvailable;
        BOOL changed = *lastEngageState != currEngageState || *lastServerState != currServerState;

        if (currEngageState)
        {
            if (changed)
            {
                [self.toggleMenuItem setTitle:STATUSMENUITEM_ACTIVE];
            }

            if (currServerState)
            {
                if (changed)
                {
                    [self.statusBar setImage:self.statusBarIconActive];
                }
            }
            else
            {
                if (changed)
                {
                    [self.statusBar setImage:self.statusBarIconError];
                    [self.toggleMenuItem setTitle:STATUSMENUITEM_ERROR];
                }
            }
        }
        else
        {
            if (changed)
            {
                [self.toggleMenuItem setTitle:STATUSMENUITEM_INACTIVE];
                [self.statusBar setImage:self.statusBarIconInactive];
            }
        }

        *lastEngageState = currEngageState;
        *lastServerState = currServerState;
    }
}

- (void)showQuickList
{
    NSString *pdfPath = [self getPdfPath:self.activeKeyFile];
    if (pdfPath != nil)
    {
        [[NSWorkspace sharedWorkspace] openFile:pdfPath];
    }
    else
    {
        [self.window display];

        self.mainController.selectedKeyfile = [self.keyfileList objectForKey:self.activeKeyFile];
        [self.mainController openDetailView];

        [NSApp activateIgnoringOtherApps:YES];
        [self.window makeKeyAndOrderFront:nil];
    }
}

- (void)dismissQuickList
{
    if (self.window != nil)
    {
        [self.window close];
    }
}

#pragma mark Importing

- (void)reportImportError:(NSString *)error
{
    NSAlert *alert = [NSAlert alertWithMessageText:IMPORT_KEYFILE_TITLE_ERROR defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", error];

    [alert runModal];
}

- (void)reportImportSuccess:(NSString *)filename
{
    NSAlert *alert = [NSAlert alertWithMessageText:IMPORT_KEYFILE_TITLE_SUCCESS defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:IMPORT_KEYFILE_SUCCESS,filename];

    [alert runModal];
}

- (void)importKeyFile:(NSString *)keyFilePath
{
    // copy file to resources
    NSError *error;

    NSString *fileName = [[keyFilePath stringByDeletingPathExtension] lastPathComponent];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    // check for errors
    NSMutableDictionary *keyfileDict = [self decryptAndParseKeyfile:keyFilePath];

    if (![self verifyKeyfileFormat:keyfileDict filename:fileName])
    {
        [self reportImportError:IMPORT_KEYFILE_BAD_FORMAT];
        return;
    }

    NSString *vers = [keyfileDict valueForKey:KEYFILE_LRVERSION_NODENAME];
    if ([self.lrVersion caseInsensitiveCompare:vers] != NSOrderedSame)
    {
        [self reportImportError:[NSString stringWithFormat:IMPORT_KEYFILE_WRONG_VERSION, vers, self.lrVersion]];
        return;
    }

    NSString *layoutVersion = [keyfileDict valueForKey:KEYFILE_LAYOUTVERSION_NODENAME];
    if (layoutVersion)
    {
        NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        if ([appVersion caseInsensitiveCompare:layoutVersion] == NSOrderedAscending)
        {
            [self reportImportError:IMPORT_KEYFILE_NEWER_LAYOUT];
            return;
        }
    }

    NSString *uuid = [keyfileDict valueForKey:KEYFILE_UUID_NODENAME];
    NSString *name = [keyfileDict valueForKey:KEYFILE_NAME_NODENAME];

    NSString *toPathJSON = [[self.keyfileDirectory stringByAppendingPathComponent:uuid] stringByAppendingPathExtension:KEYFILE_JSON_EXTENSION];

    if ([fileManager fileExistsAtPath:toPathJSON])
    {
        if (![fileManager removeItemAtPath:toPathJSON error:NULL])
        {
            DualLog(@"Existing file couldn't be removed: %@", error);
            [self reportImportError:IMPORT_KEYFILE_SAME_NAME];
            return;
        }
    }

    NSString *toPathVKEYS = [[self.keyfileDirectory stringByAppendingPathComponent:uuid] stringByAppendingPathExtension:KEYFILE_VKEYS_EXTENSION];
    
    if ([fileManager fileExistsAtPath:toPathVKEYS])
    {
        if (![fileManager removeItemAtPath:toPathVKEYS error:NULL])
        {
            DualLog(@"Existing file couldn't be removed: %@", error);
            [self reportImportError:IMPORT_KEYFILE_SAME_NAME];
            return;
        }
    }

    if (![fileManager moveItemAtPath:keyFilePath toPath:toPathJSON error:&error])
    {
        DualLog(@"File could not be copied: %@", error);
        [self reportImportError:IMPORT_KEYFILE_SAME_NAME];
        return;
    }

    [self loadAllKeyfiles];
    [self loadDictionaryFromActiveKeysFile];
    [self resetStatusMenu];

    [self deletePdf:uuid];

    [self reportImportSuccess:name];
}

- (void)deleteKeyfile:(NSDictionary *)keyfile
{
    NSString *fileName = [keyfile valueForKey:KEYFILE_FILENAME_NODENAME];
    NSString *filePath = [self.keyfileDirectory stringByAppendingPathComponent:fileName];

    NSError *error;

    if (![[NSFileManager defaultManager] removeItemAtPath:filePath error:&error])
    {
        DualLog(@"Error deleting file: %@", error);
    }

    [self loadAllKeyfiles];
    [self resetStatusMenu];
}

- (void)copyBaseKeyfilesToDirectory
{
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *file in [fm contentsOfDirectoryAtPath:self.keyfileDirectory error:NULL])
    {
        if ([[file pathExtension] isEqualToString:KEYFILE_VKEYS_EXTENSION] &&
            [[[file lastPathComponent] lowercaseString] hasPrefix:@"test_"])
        {
            [fm removeItemAtPath:[self.keyfileDirectory stringByAppendingPathComponent:file] error:NULL];
        }
    }

    NSDirectoryEnumerator *dirEnum = [fm enumeratorAtPath:[[NSBundle mainBundle] resourcePath]];

    NSString *file;
    while (file = [dirEnum nextObject])
    {
        if ([[file pathExtension] isEqualToString:KEYFILE_VKEYS_EXTENSION] &&
            [[[file lastPathComponent] lowercaseString] hasPrefix:@"test_"])
        {
            continue;
        }

        if (([[file pathExtension] isEqualToString: KEYFILE_VKEYS_EXTENSION]) ||
            ([[file pathExtension] isEqualToString: KEYFILE_JSON_EXTENSION]) )
        {
            NSString *fromFile = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:file];
            NSString *toFile = [self.keyfileDirectory stringByAppendingPathComponent:file];

            if ([fm fileExistsAtPath:toFile])
            {
                [fm removeItemAtPath:toFile error:NULL];
            }

            [fm copyItemAtPath:fromFile toPath:toFile error:NULL];
        }
    }
}

- (NSString *)getPdfPath:(NSString *)uuid
{
    if (uuid)
    {
        NSString *filePath = [[self.keyfileDirectory stringByAppendingPathComponent:uuid] stringByAppendingPathExtension:KEYFILE_SHEET_EXTENSION];

        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
        {
            return filePath;
        }
        else
        {
            return nil;
        }
    }

    return nil;
}

- (void)deletePdf:(NSString*)uuid
{
    NSString *path = [self getPdfPath:uuid];
    if (path)
    {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    }
}



#pragma mark Lightroom Integration

- (void)updateShortcutKeyCodes:(NSDictionary *)shortcuts
{
    NSString *increaseKey = shortcuts[@"increase"];
    NSString *decreaseKey = shortcuts[@"decrease"];
    if ([increaseKey isKindOfClass:[NSString class]] && increaseKey.length == 1) {
        self.brushIncreaseKey = increaseKey;
        self.brushIncreaseKeyCodeValid = VSCOKeyCodeForCharacter(increaseKey, &_brushIncreaseKeyCode, &_brushIncreaseEventFlags);
    }
    if ([decreaseKey isKindOfClass:[NSString class]] && decreaseKey.length == 1) {
        self.brushDecreaseKey = decreaseKey;
        self.brushDecreaseKeyCodeValid = VSCOKeyCodeForCharacter(decreaseKey, &_brushDecreaseKeyCode, &_brushDecreaseEventFlags);
    }
    NSString *pastePreviousKey = shortcuts[@"pastePrevious"];
    self.pastePreviousKeyCodeValid = VSCOKeyCodeForCharacter(pastePreviousKey, &_pastePreviousKeyCode, &_pastePreviousEventFlags);
}

- (void)sendBrushSizeChange:(double)delta
{
    if (!isfinite(delta) || delta == 0) return;

    CGKeyCode keyCode = delta > 0 ? self.brushIncreaseKeyCode : self.brushDecreaseKeyCode;
    CGEventFlags eventFlags = delta > 0 ? self.brushIncreaseEventFlags : self.brushDecreaseEventFlags;
    BOOL keyCodeValid = delta > 0 ? self.brushIncreaseKeyCodeValid : self.brushDecreaseKeyCodeValid;
    NSString *character = delta > 0 ? self.brushIncreaseKey : self.brushDecreaseKey;
    if (!keyCodeValid) {
        DualLog(@"Could not resolve Lightroom brush shortcut: %@", character);
        return;
    }

    [self postShortcutWithKeyCode:keyCode flags:eventFlags];
}

- (void)sendPasteSettingsFromPrevious
{
    if (!self.pastePreviousKeyCodeValid) {
        DualLog(@"Could not resolve Lightroom Paste Settings from Previous shortcut.");
        return;
    }
    CGEventFlags flags = self.pastePreviousEventFlags | kCGEventFlagMaskAlternate | kCGEventFlagMaskCommand;
    [self postShortcutWithKeyCode:self.pastePreviousKeyCode flags:flags];
}

- (void)postShortcutWithKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)eventFlags
{
    NSRunningApplication *lightroom = [self getLRRunningInstance];
    if (!lightroom) return;

    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, keyCode, false);
    if (!keyDown || !keyUp) {
        if (keyDown) CFRelease(keyDown);
        if (keyUp) CFRelease(keyUp);
        return;
    }

    CGEventSetFlags(keyDown, eventFlags);
    CGEventSetFlags(keyUp, eventFlags);
    CGEventSetIntegerValueField(keyDown, kCGEventSourceUserData, kVSCOInjectedKeyEventMarker);
    CGEventSetIntegerValueField(keyUp, kCGEventSourceUserData, kVSCOInjectedKeyEventMarker);
    CGEventPostToPid((pid_t)lightroom.processIdentifier, keyDown);
    CGEventPostToPid((pid_t)lightroom.processIdentifier, keyUp);
    CFRelease(keyDown);
    CFRelease(keyUp);
}

- (void)initAppList
{
    self.appIdList = [NSArray arrayWithObjects:LIGHTROOM_BUNDLE_LR3,LIGHTROOM_BUNDLE_LR4,LIGHTROOM_BUNDLE_LR5,LIGHTROOM_BUNDLE_LR6,LIGHTROOM_BUNDLE_LR7, nil];
}

- (NSRunningApplication*)getLRRunningInstance
{
    for (NSString *appid in self.appIdList)
    {
        NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:appid];

        if ([apps count] > 0)
        {
            return [apps objectAtIndex:0];
        }
    }

    return nil;
}

- (BOOL)checkIsLRInForeground
{
    NSRunningApplication *lr = [self getLRRunningInstance];

    if (lr != nil)
    {
        return lr.active;
    }

    return NO;
}

- (BOOL)isLRRunning
{
    return [self getLRRunningInstance] != nil;
}

- (void)makeLRActive
{
    for (NSWindow *win in [NSApp windows])
    {
        if (win.canBecomeKeyWindow && win.isVisible)
        {
            return;
        }
    }

    NSRunningApplication *lr = [self getLRRunningInstance];

    if (lr != nil)
    {
        [lr activateWithOptions:NSApplicationActivateAllWindows];
    }
}

- (NSString *)getLRVersion
{
    NSRunningApplication *lr = [self getLRRunningInstance];

    if (lr != nil && [lr.bundleIdentifier caseInsensitiveCompare:LIGHTROOM_BUNDLE_LR3] == NSOrderedSame)
    {
        return LRVERSION_LR3;
    }

    // Default to LRVERSION_LR4 ("4") for all modern Lightroom Classic versions
    return LRVERSION_LR4;
}

void AXCallback(AXObserverRef observer, AXUIElementRef element, CFStringRef notification, void *refcon)
{
    KeyControl *appSelf = (__bridge KeyControl *)refcon;

    CFTypeRef elementRole = NULL;
    AXUIElementCopyAttributeValue( element, kAXRoleAttribute, &elementRole );

    CFStringRef roleString = elementRole;

    if (
        roleString != NULL &&
        (
            CFStringCompare(roleString, kAXTextFieldRole, kCFCompareCaseInsensitive) == kCFCompareEqualTo ||
            CFStringCompare(roleString, kAXTextAreaRole, kCFCompareCaseInsensitive) == kCFCompareEqualTo
        )
       )
    {
        DualLog(@"Focus change to %@ -- deactivating keys.", roleString);
        appSelf.isInTextField = YES;
    }
    else if (appSelf.isInTextField)
    {
        DualLog(@"Focus change to %@ -- no longer in text field.", roleString);
        appSelf.isInTextField = NO;
    }
}

- (void)startUpAXLoop
{
    NSRunningApplication *lr = [self getLRRunningInstance];

    if (lr)
    {
        AXUIElementRef app = AXUIElementCreateApplication( lr.processIdentifier );

        AXObserverRef observer = NULL;

        AXError error = AXObserverCreate(lr.processIdentifier, AXCallback, &observer);

        if (error != kAXErrorSuccess)
        {
            DualLog(@"Error creating AXObserver %d", error);
            return;
        }

        error = AXObserverAddNotification(observer, app, kAXFocusedUIElementChangedNotification, (__bridge void *)self);

        if (error != kAXErrorSuccess)
        {
            DualLog(@"Error adding focuschange notification %d", error);
            return;
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), kCFRunLoopDefaultMode);

        CFRunLoopRun();
    }
}

#pragma mark Keyfile List management

- (NSArray *)getKeyfileList
{
    NSArray * sortedKeys = [self getUUIDsSortedByName];

    return [self.keyfileList objectsForKeys:sortedKeys notFoundMarker:[NSNull null]];
}

- (NSMutableDictionary *)decryptAndParseKeyfile:(NSString *)filePath
{
    NSData *data = [NSData dataWithContentsOfFile:filePath];

    if( [[filePath pathExtension] isEqualToString:KEYFILE_VKEYS_EXTENSION] == YES )
        data = [data decrypt];

    NSString *content = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];

    return [content JSONValue];
}

- (BOOL)verifyKeyfileFormat:(NSDictionary *)settingsDict filename:(NSString *)file
{
    if (settingsDict == nil)
    {
        DualLog(@"Bad keyfile format for file: %@", file);

        return false;
    }

    if ([settingsDict objectForKey:KEYFILE_KEYS_NODENAME] == nil)
    {
        DualLog(@"Bad keyfile format: missing %@ for file: %@", KEYFILE_KEYS_NODENAME, file);

        return false;
    }

    if ([settingsDict objectForKey:KEYFILE_MODEKEY_NODENAME] == nil)
    {
        DualLog(@"Bad keyfile format: missing %@ for file: %@", KEYFILE_MODEKEY_NODENAME, file);

        return false;
    }

    if ([settingsDict objectForKey:KEYFILE_NAME_NODENAME] == nil)
    {
        DualLog(@"Bad keyfile format: missing %@ for file: %@", KEYFILE_NAME_NODENAME, file);

        return false;
    }

    if ([settingsDict objectForKey:KEYFILE_UUID_NODENAME] == nil)
    {
        DualLog(@"Bad keyfile format: missing %@ for file: %@", KEYFILE_UUID_NODENAME, file);

        return false;
    }

    id vers = [settingsDict objectForKey:KEYFILE_LRVERSION_NODENAME];
    if (vers == nil)
    {
        DualLog(@"Bad keyfile format: missing %@ for file: %@", KEYFILE_LRVERSION_NODENAME, file);

        return false;
    }

    if (![vers isKindOfClass:[NSString class]])
    {
        DualLog(@"Bad keyfile format: %@ is not a string in %@", KEYFILE_LRVERSION_NODENAME, file);

        return false;
    }

    return true;
}

- (void)loadAllKeyfiles
{
    self.keyfileList = [NSMutableDictionary dictionary];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:self.keyfileDirectory];

    NSString *file;
    while (file = [dirEnum nextObject])
    {
        if (([[file pathExtension] isEqualToString: KEYFILE_VKEYS_EXTENSION]) ||
            ([[file pathExtension] isEqualToString: KEYFILE_JSON_EXTENSION]) )
        {
            NSMutableDictionary *settingsDict = [self decryptAndParseKeyfile:[self.keyfileDirectory stringByAppendingPathComponent:file]];

            NSString *vers = [settingsDict objectForKey:KEYFILE_LRVERSION_NODENAME];
            if (![self verifyKeyfileFormat:settingsDict filename:file] || [self.lrVersion caseInsensitiveCompare:vers] != NSOrderedSame)
            {
                continue;
            }

            NSString *uuid = [settingsDict objectForKey:KEYFILE_UUID_NODENAME];

            NSString *defaultsKeyfileKey = [NSString stringWithFormat:DEFAULTS_KEYFILE_FORMAT, uuid];

            NSMutableDictionary *defaultsData = [[defaults valueForKey:defaultsKeyfileKey] mutableCopy];
            if (defaultsData == nil)
            {
                defaultsData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithBool:YES], DEFAULTS_KEYFILE_ISACTIVE,
                                nil];

                [defaults setValue:defaultsData forKey:defaultsKeyfileKey];
            }

            [defaultsData setValue:LIST_PDF forKey:LIST_PDF_NAME];
            [defaultsData setValue:LIST_DELETE forKey:LIST_DELETE_NAME];
            [defaultsData setValue:file forKey:KEYFILE_FILENAME_NODENAME];

            [settingsDict addEntriesFromDictionary:defaultsData];

            [self.keyfileList setObject:settingsDict forKey:uuid];
        }
    }

    [self initActiveKeyfile];
}

- (void)initActiveKeyfile
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSString *activeKeyfileDefault = [defaults valueForKey:DEFAULTS_ACTIVE_KEYFILE];

    if ([self.keyfileList valueForKey:activeKeyfileDefault] != nil && [[[self.keyfileList valueForKey:activeKeyfileDefault] valueForKey:DEFAULTS_KEYFILE_ISACTIVE] boolValue])
    {
        self.activeKeyFile = activeKeyfileDefault;
    }
    else if ([self.keyfileList count] > 0)
    {
        self.activeKeyFile = [[self getUUIDsSortedByName] objectAtIndex:0];
        [defaults setValue:self.activeKeyFile forKey:DEFAULTS_ACTIVE_KEYFILE];
    }

    [self setMenuForKeyFileActive];
}

- (NSArray *)getUUIDsSortedByName
{
    NSArray *sortedFiles =[[self.keyfileList allValues] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2)
                           {
                               NSDictionary *keyfile1 = (NSDictionary *)obj1;
                               NSDictionary *keyfile2 = (NSDictionary *)obj2;

                               return [[keyfile1 objectForKey:KEYFILE_NAME_NODENAME] compare:[keyfile2 objectForKey:KEYFILE_NAME_NODENAME]];
                           }];

    NSMutableArray *sortedUUIDs = [NSMutableArray array];

    for (NSDictionary *keyfile in sortedFiles)
    {
        [sortedUUIDs addObject:[keyfile objectForKey:KEYFILE_UUID_NODENAME]];
    }

    return sortedUUIDs;
}

- (CGEventFlags)convertModifiers:(int)mod
{
    CGEventFlags flags = 0;

    if (mod & kModifierShift)
    {
        flags |= kCGEventFlagMaskShift;
    }

    if (mod & kModifierControl)
    {
        flags |= kCGEventFlagMaskControl;
    }

    if (mod & kModifierOption)
    {
        flags |= kCGEventFlagMaskAlternate;
    }

    if (mod & kModifierCommand)
    {
        flags |= kCGEventFlagMaskCommand;
    }

    return flags;
}

- (void)loadDictionaryFromActiveKeysFile
{
    self.isKeyControlActive = false;

    NSDictionary *settingsDict = [self.keyfileList objectForKey:self.activeKeyFile];
    NSArray *keysDictionary = [settingsDict objectForKey:KEYFILE_KEYS_NODENAME];

    if (keysDictionary == nil)
    {
        self.keysDict = [NSDictionary dictionary];
        DualLog(@"Bad keyfile format: missing %@", KEYFILE_KEYS_NODENAME);
    }
    else
    {
        // convert the modifiers into mac modifiers
        NSMutableArray *newArr = [NSMutableArray arrayWithCapacity:[keysDictionary count]];

        for (int i = 0; i < [keysDictionary count]; ++i)
        {
            NSMutableDictionary *newDict = [[keysDictionary objectAtIndex:i] mutableCopy];

            [newDict setValue:[NSNumber numberWithUnsignedLongLong:[self convertModifiers:[[newDict objectForKey:KEYFILE_MODIFIERS_NODENAME] intValue]]] forKey:KEYFILE_MODIFIERS_NODENAME];

            NSMutableDictionary *adjustments = [[newDict objectForKey:KEYFILE_ADJUSTMENTS_NODENAME] mutableCopy];

            id remap = [adjustments objectForKey:KEYFILE_ADJUSTMENT_REMAP_NODENAME];

            if (remap)
            {
                NSNumber *key = NULL;
                NSNumber *mod = NULL;

                if ([remap isKindOfClass:[NSNumber class]] || [remap isKindOfClass:[NSString class]])
                {
                    key = [NSNumber numberWithInt:[remap intValue]];
                    mod = [NSNumber numberWithUnsignedLongLong:[self convertModifiers:0]];
                }
                else
                {
                    key = [remap objectForKey:KEYFILE_KEY_NODENAME];
                    mod = [NSNumber numberWithUnsignedLongLong:[self convertModifiers:[[remap objectForKey:KEYFILE_MODIFIERS_NODENAME] intValue]]];
                }

                [adjustments setObject:[NSDictionary dictionaryWithObjectsAndKeys:key,KEYFILE_KEY_NODENAME, mod,KEYFILE_MODIFIERS_NODENAME, nil] forKey:KEYFILE_ADJUSTMENT_REMAP_NODENAME];
                [newDict setObject:adjustments forKey:KEYFILE_ADJUSTMENTS_NODENAME];
            }

            [newArr addObject:newDict];
        }

        self.keysDict = newArr;
    }

    if ([settingsDict objectForKey:KEYFILE_MODEKEY_NODENAME] == nil)
    {
        self.controlToggleKey = 53;
        DualLog(@"Bad keyfile format: missing %@", KEYFILE_MODEKEY_NODENAME);
    }
    else
    {
        self.controlToggleKey = [[settingsDict objectForKey:KEYFILE_MODEKEY_NODENAME] intValue];
    }
}

- (void)initMappings
{
    self.keyMapping = [[NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"KeyMapping" ofType:@"json"] encoding:NSUTF8StringEncoding error:nil] JSONValue];

    self.adjustmentMapping = [[NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AdjustmentMapping" ofType:@"json"] encoding:NSUTF8StringEncoding error:nil] JSONValue];

    self.adjustmentLimits = [[NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AdjustmentLimits" ofType:@"json"] encoding:NSUTF8StringEncoding error:nil] JSONValue];

    // Load command categories (from MIDI2LR / LR SDK 15)
    NSString *catsPath = [[NSBundle mainBundle] pathForResource:@"CommandCategories" ofType:@"json"];
    if (catsPath) {
        NSData *catsData = [NSData dataWithContentsOfFile:catsPath];
        if (catsData) {
            self.commandCategories = [NSJSONSerialization JSONObjectWithData:catsData options:0 error:nil];
            if (self.commandCategories) {
                self.allCommandCategories = self.commandCategories;
                // Merge all category command IDs and display names into adjustmentMapping
                NSMutableDictionary *mergedAdj = [self.adjustmentMapping mutableCopy] ?: [NSMutableDictionary dictionary];
                for (NSDictionary *cat in self.commandCategories) {
                    NSArray *items = [cat objectForKey:@"items"];
                    for (NSDictionary *item in items) {
                        NSString *cid   = [item objectForKey:@"id"];
                        NSString *cname = [item objectForKey:@"name"];
                        if (cid && cname && ![mergedAdj objectForKey:cid]) {
                            [mergedAdj setObject:cname forKey:cid];
                        }
                    }
                }
                self.adjustmentMapping = mergedAdj;
            }
        }
    }
}

- (void)refreshPluginSettings:(NSTimer *)timer
{
    if (self.pluginSettingsRequestInProgress) return;
    self.pluginSettingsRequestInProgress = YES;
    [HttpRequest sendGetTo:SERVER_SETTINGS_ENDPOINT responded:^(NSURLConnection *connection, NSURLResponse *response, NSData *data, NSString *mimeType) {
        self.pluginSettingsRequestInProgress = NO;
        NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        id settings = [body JSONValue];
        if (![settings isKindOfClass:[NSDictionary class]]) return;
        NSString *brushIncreaseKey = settings[@"brushIncreaseKey"];
        NSString *brushDecreaseKey = settings[@"brushDecreaseKey"];
        NSString *increaseShortcut = [brushIncreaseKey isKindOfClass:[NSString class]] ? brushIncreaseKey : @"]";
        NSString *decreaseShortcut = [brushDecreaseKey isKindOfClass:[NSString class]] ? brushDecreaseKey : @"[";
        NSDictionary *shortcuts = @{@"increase": increaseShortcut, @"decrease": decreaseShortcut};
        [self performSelectorOnMainThread:@selector(updateShortcutKeyCodes:)
                       withObject:@{@"increase": increaseShortcut,
                            @"decrease": decreaseShortcut,
                            @"pastePrevious": @"v"}
                            waitUntilDone:YES];
        NSDictionary *hiddenActions = settings[@"hiddenActions"];
        if (![hiddenActions isKindOfClass:[NSDictionary class]]) return;

        NSMutableSet *hiddenIdentifiers = [NSMutableSet set];
        for (id actionIdentifier in hiddenActions) {
            if ([hiddenActions[actionIdentifier] boolValue]) [hiddenIdentifiers addObject:actionIdentifier];
        }
        if ([hiddenIdentifiers isEqualToSet:self.hiddenCommandIdentifiers ?: [NSSet set]]) return;

        self.hiddenCommandIdentifiers = hiddenIdentifiers;
        NSMutableArray *visibleCategories = [NSMutableArray array];
        for (NSDictionary *category in self.allCommandCategories) {
            NSMutableArray *visibleItems = [NSMutableArray array];
            for (NSDictionary *item in [category objectForKey:@"items"]) {
                if (![hiddenIdentifiers containsObject:[item objectForKey:@"id"]]) [visibleItems addObject:item];
            }
            if (visibleItems.count > 0) {
                [visibleCategories addObject:@{
                    @"category": [category objectForKey:@"category"] ?: @"Other",
                    @"items": visibleItems
                }];
            }
        }
        self.commandCategories = visibleCategories;
        [self.mainController.keyboardEditorController reloadActionCatalog];
        [self.mainController.editorController reloadActionCatalog];
    } failed:^(NSURLConnection *connection, NSError *error) {
        self.pluginSettingsRequestInProgress = NO;
    }];
}

- (NSString *)getKeynameForVirtual:(NSString *)virtKey
{
    return [self.keyMapping objectForKey:virtKey];
}

- (NSString *)getNormalNameForAdjustment:(NSString *)adjustment
{
    return [self.adjustmentMapping valueForKey:adjustment];
}

- (NSString *)getCommandStringForCommand:(NSDictionary *)command
{
    NSString *cmdString = @"";

    NSInteger mod = [[command valueForKey:KEYFILE_MODIFIERS_NODENAME] intValue];

    if (mod & kModifierShift)
        cmdString = [cmdString stringByAppendingString:@"SHIFT + "];

    if (mod & kModifierControl)
        cmdString = [cmdString stringByAppendingString:@"CONTROL + "];

    if (mod & kModifierOption)
        cmdString = [cmdString stringByAppendingString:@"OPTION + "];

    if (mod & kModifierCommand)
        cmdString = [cmdString stringByAppendingString:@"COMMAND + "];

    NSString *keyName = [self getKeynameForVirtual:[command valueForKey:KEYFILE_KEY_NODENAME]];

    if (keyName)
    {
        cmdString = [cmdString stringByAppendingString:keyName];
    }
    else
    {
        cmdString = [cmdString stringByAppendingString:@"?"];
    }

    return cmdString;
}

- (NSAttributedString *)getAmountString:(id)amount isRemap:(BOOL)isRemap
{
    NSString *stringValue = NULL;

    NSDictionary *attribs = self.blackStyle;

    if (isRemap)
    {
        if ([amount isKindOfClass:[NSString class]])
        {
            stringValue = [self getKeynameForVirtual:amount];
        }
        else
        {
            stringValue = [self getCommandStringForCommand:amount];
        }
    }
    else
    {
        NSNumber *numValue = [self.numFormatter numberFromString:amount];

        if (numValue != nil)
        {
            float floatVal = [numValue floatValue];
            stringValue = [NSString stringWithFormat:@"%+g", floatVal];

            attribs = self.goldStyle;

            if (floatVal < 0)
            {
                attribs = self.redStyle;
            }
        }
        else
        {
            stringValue = amount;
        }
    }

    return [[NSAttributedString alloc] initWithString:stringValue attributes:attribs];
}

- (void)updateDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    for (NSDictionary *keyfile in [self.keyfileList allValues])
    {
        NSString *uuid = [keyfile valueForKey:KEYFILE_UUID_NODENAME];
        NSString *defaultsKeyfileKey = [NSString stringWithFormat:DEFAULTS_KEYFILE_FORMAT, uuid];

        NSDictionary *defaultsData = [NSDictionary dictionaryWithObjectsAndKeys:
                        [keyfile valueForKey:DEFAULTS_KEYFILE_ISACTIVE], DEFAULTS_KEYFILE_ISACTIVE,
                        nil];

        [defaults setValue:defaultsData forKey:defaultsKeyfileKey];
    }

    [self resetStatusMenu];
    [self initActiveKeyfile];
}

#pragma mark Key Loop


- (BOOL)checkIsKeySystemEngaged
{
    return self.isKeyControlActive && [self checkIsLRInForeground] && !self.isInTextField;
}

- (void)toggleKeyControlActive
{
    self.isKeyControlActive = !self.isKeyControlActive;
    DualLog(@"KeyControl Active: %d", self.isKeyControlActive);

    [self checkServerAvailability];
}

NSString *GetModString(CGEventFlags modifiers)
{
    NSString *modString = @"";

    if (modifiers & kCGEventFlagMaskShift)
    {
        modString = [modString stringByAppendingString:@"SHIFT + "];
    }

    if (modifiers & kCGEventFlagMaskControl)
    {
        modString = [modString stringByAppendingString:@"CTRL + "];
    }

    if (modifiers & kCGEventFlagMaskAlternate)
    {
        modString = [modString stringByAppendingString:@"OPT + "];
    }

    if (modifiers & kCGEventFlagMaskCommand)
    {
        modString = [modString stringByAppendingString:@"CMD + "];
    }

    return modString;
}

void printKeyDebug(CGEventType type, CGEventFlags modifiers, int keyCode)
{
    NSString *modString = GetModString(modifiers);

    if (type == kCGEventKeyDown)
    {
        DualLog(@"Key Down: %@%d (%llx)", modString, keyCode, modifiers);
    }
    else
    {
        DualLog(@"Key Up: %@%d (%llx)", modString, keyCode, modifiers);
    }
}

CGEventRef myCGCreateEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
    KeyControl *appSelf = (__bridge KeyControl *)refcon;

    // handle kill-event cases
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput)
    {
        CGEventTapEnable(appSelf.eventTap, YES);
        DualLog(@"Event Tap was disabled. Re-enable attempted.");

        return NULL;
    }

    if (CGEventGetIntegerValueField(event, kCGEventSourceUserData) == kVSCOInjectedKeyEventMarker) return event;

    int keyCode = (int)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    CGEventFlags modifiers = CGEventGetFlags(event);
    BOOL isLightroomForeground = [appSelf checkIsLRInForeground];
    if (type == kCGEventFlagsChanged && keyCode == kVK_CapsLock && isLightroomForeground) {
        NSNumber *capsLockEnabled = @((modifiers & kCGEventFlagMaskAlphaShift) != 0);
        [appSelf performSelectorOnMainThread:@selector(setKeyboardHUDVisibleForCapsLock:)
                                  withObject:capsLockEnabled
                               waitUntilDone:NO];
        return NULL;
    }
    if (isLightroomForeground && (modifiers & kCGEventFlagMaskAlphaShift)) {
        modifiers &= ~kCGEventFlagMaskAlphaShift;
        CGEventSetFlags(event, modifiers);
    }
    NSDictionary *matchedCommand = [appSelf commandForKeyCode:keyCode modifierFlags:modifiers];
    if (type == kCGEventFlagsChanged && appSelf.keyboardHUDEnabled) {
        NSDictionary *eventInfo = @{@"modifierMask": @([appSelf modifierMaskForEventFlags:modifiers])};
        [appSelf performSelectorOnMainThread:@selector(updateKeyboardHUDForEvent:) withObject:eventInfo waitUntilDone:NO];
    } else if ((type == kCGEventKeyDown || type == kCGEventKeyUp) && appSelf.keyboardHUDEnabled) {
        NSMutableDictionary *eventInfo = [@{@"modifierMask": @([appSelf modifierMaskForEventFlags:modifiers])} mutableCopy];
        if (type == kCGEventKeyDown) {
            [eventInfo setObject:[NSString stringWithFormat:@"%d", keyCode] forKey:@"keyCode"];
            NSString *actionTitle = matchedCommand ? [appSelf actionTitleForCommand:matchedCommand] : @"";
            [eventInfo setObject:actionTitle ?: @"" forKey:@"actionTitle"];
        }
        [appSelf performSelectorOnMainThread:@selector(updateKeyboardHUDForEvent:) withObject:eventInfo waitUntilDone:NO];
    }

    // Mode switch for app
    if ( !(modifiers & (kCGEventFlagMaskShift | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate | kCGEventFlagMaskCommand)) && keyCode == appSelf.controlToggleKey && [appSelf checkIsLRInForeground])
    {
        if (type == kCGEventKeyDown)
        {
            [appSelf toggleKeyControlActive];
        }

        return NULL;
    }

    // show/hide quick keylist ( CMD + / )
    if (appSelf.isKeyControlActive && modifiers & kCGEventFlagMaskCommand && keyCode == 44)
    {
        if (type == kCGEventKeyUp)
        {
            if ([appSelf checkIsKeySystemEngaged])
            {
                [appSelf performSelectorOnMainThread:@selector(showQuickList) withObject:nil waitUntilDone:NO];
            }
            else
            {
                [appSelf performSelectorOnMainThread:@selector(dismissQuickList) withObject:nil waitUntilDone:NO];
            }
        }

        return NULL;
    }

    if ((type == kCGEventKeyDown || type == kCGEventKeyUp) && [appSelf checkIsKeySystemEngaged] && matchedCommand)
    {
        NSMutableDictionary *adjustments = [[matchedCommand objectForKey:KEYFILE_ADJUSTMENTS_NODENAME] mutableCopy];
        NSDictionary *remap = [adjustments objectForKey:KEYFILE_ADJUSTMENT_REMAP_NODENAME];
        CGEventRef newEvent = NULL;

        id brushSizeChange = [adjustments objectForKey:@"ChangeBrushSize"];
        if (type == kCGEventKeyDown && brushSizeChange) {
            [appSelf sendBrushSizeChange:[[brushSizeChange description] doubleValue]];
            [adjustments removeObjectForKey:@"ChangeBrushSize"];
        }
        if (type == kCGEventKeyDown && [adjustments objectForKey:@"PasteSettingsFromPrevious"]) {
            [appSelf sendPasteSettingsFromPrevious];
            [adjustments removeObjectForKey:@"PasteSettingsFromPrevious"];
        }

        if (remap)
        {
            int newKey = [[remap objectForKey:KEYFILE_KEY_NODENAME] intValue];
            CGEventFlags newMod = [[remap objectForKey:KEYFILE_MODIFIERS_NODENAME] unsignedLongLongValue];

            newEvent = CGEventCreateKeyboardEvent(NULL, newKey, type == kCGEventKeyDown);
            CGEventSetFlags(newEvent, newMod);
            [adjustments removeObjectForKey:KEYFILE_ADJUSTMENT_REMAP_NODENAME];

            NSString *modString = GetModString(newMod);
            DualLog(@"Remapping key to %@%d", modString, newKey);
        }

        if (type == kCGEventKeyDown && adjustments.count > 0)
        {
            [appSelf sendUpdate:adjustments];
            DualLog(@"Key Command Executed");
        }
        return newEvent;
    }

    return event;
}

// suppress false positive on event-tap create
#ifndef __clang_analyzer__

- (void)startUpEventLoop
{
    self.keyThread = [NSThread currentThread];

    // initialize keys dictionary
    [self loadDictionaryFromActiveKeysFile];

    CFRunLoopSourceRef runLoopSource;

    self.eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault,
                                     CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged),
                                     myCGCreateEventCallback, (__bridge void *)self);

    if (!self.eventTap) {
        DualLog(@"Couldn't create event tap!");

        exit(0);
    }

    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.eventTap, 0);

    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);

    CGEventTapEnable(self.eventTap, true);

    CFRunLoopRun();

    CFRelease(runLoopSource);
}

#endif


@end

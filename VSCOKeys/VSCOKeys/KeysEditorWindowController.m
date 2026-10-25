//
//  KeysEditorWindowController.m
//  VSCOKeys
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

#import "KeysEditorWindowController.h"
#import "MainWindowController.h"
#import "KeyControl.h"
#import "Constants.h"
#import "NSColor+FromHex.h"
#import "NSObject+SBJson.h"

// ──────────────────────────────────────────────────────────────────────────────
// Column identifiers
// ──────────────────────────────────────────────────────────────────────────────
static NSString * const kColKey    = @"edKey";
static NSString * const kColMod    = @"edMod";
static NSString * const kColAction = @"edAction";
static NSString * const kColValue  = @"edValue";
static NSString * const kColDup    = @"edDup";
static NSString * const kColDel    = @"edDel";

// ──────────────────────────────────────────────────────────────────────────────
// Internal binding dict keys
// ──────────────────────────────────────────────────────────────────────────────
static NSString * const kBindKey    = @"bKey";    // keycode string, e.g. "13"
static NSString * const kBindMod    = @"bMod";    // modifier bitmask string, e.g. "2"
static NSString * const kBindAdj    = @"bAdj";    // adjustment key, e.g. "Saturation"
static NSString * const kBindValue  = @"bValue";  // value string, e.g. "-1"

@interface KeysEditorWindowController ()

// ── Metadata fields ──────────────────────────────────────────────────────────
@property (retain) NSTextField   *nameField;
@property (retain) NSTextField   *authorField;
@property (retain) NSTextField   *descField;
@property (retain) NSPopUpButton *modeKeyPopup;

// ── Bindings table ───────────────────────────────────────────────────────────
@property (retain) NSTableView   *tableView;
@property (retain) NSScrollView  *scrollView;

// ── Action buttons (bulk) ────────────────────────────────────────────────────
@property (retain) NSButton *bulkDupBtn;
@property (retain) NSButton *bulkDelBtn;

// ── Data ─────────────────────────────────────────────────────────────────────
/// Current UUID being edited (new layouts get a fresh one on startNewLayout)
@property (retain) NSString      *currentUUID;
/// Original filename (so we can overwrite in place for existing layouts)
@property (retain) NSString      *currentFilename;
/// Flat list of {bKey, bMod, bAdj, bValue}
@property (retain) NSMutableArray *bindings;

// ── Last-used adjustment (remembered across Add Binding calls) ───────────────
@property (retain) NSString      *lastUsedAdjKey;

// ── Sorted lookup arrays (index → code/key) ──────────────────────────────────
@property (retain) NSArray *sortedKeyCodes;    // sorted by display name: ["0","11",…]
@property (retain) NSArray *sortedKeyNames;    // parallel display names: ["A","B",…]
@property (retain) NSArray *sortedAdjKeys;     // sorted by display name
@property (retain) NSArray *sortedAdjNames;    // parallel display names
@property (retain) NSArray *modBitmasks;       // parallel to modTitles
@property (retain) NSArray *modTitles;

// ── Status label ─────────────────────────────────────────────────────────────
@property (retain) NSTextField *statusLabel;

// ── Categorized action menu template (built once, cloned per row) ─────────────
@property (retain) NSMenu *actionMenuTemplate;

@end

@implementation KeysEditorWindowController

@synthesize keyControl;
@synthesize mainController;
@synthesize rootView;

@synthesize nameField, authorField, descField, modeKeyPopup;
@synthesize tableView, scrollView;
@synthesize bulkDupBtn, bulkDelBtn;
@synthesize currentUUID, currentFilename, bindings;
@synthesize lastUsedAdjKey;
@synthesize sortedKeyCodes, sortedKeyNames, sortedAdjKeys, sortedAdjNames;
@synthesize modBitmasks, modTitles;
@synthesize statusLabel;
@synthesize actionMenuTemplate;

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Init
// ──────────────────────────────────────────────────────────────────────────────

- (id)initWithKeyControl:(KeyControl *)kc
{
    self = [super init];
    if (self) {
        self.keyControl = kc;
        self.bindings   = [NSMutableArray array];
        // Default new binding adjustment: Exposure2012
        self.lastUsedAdjKey = @"Exposure2012";
        [self buildLookupTables];
        [self buildUI];
    }
    return self;
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Lookup Table Construction
// ──────────────────────────────────────────────────────────────────────────────

- (void)buildLookupTables
{
    // ── Keys ─────────────────────────────────────────────────────────────────
    NSDictionary *km = self.keyControl.keyMapping; // code → displayName
    NSArray *sortedByName = [[km allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [[km objectForKey:a] compare:[km objectForKey:b]];
    }];
    self.sortedKeyCodes = sortedByName;
    NSMutableArray *names = [NSMutableArray array];
    for (NSString *code in sortedByName) {
        [names addObject:[km objectForKey:code]];
    }
    self.sortedKeyNames = names;

    // ── Adjustments ──────────────────────────────────────────────────────────
    // Deduplicate by displayName so each popup item has an exact 1:1 match with sortedAdjKeys
    NSDictionary *am = self.keyControl.adjustmentMapping; // adjKey → displayName
    NSArray *allAdjKeys = [[am allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSString *nameA = [am objectForKey:a];
        NSString *nameB = [am objectForKey:b];
        NSComparisonResult res = [nameA compare:nameB];
        if (res == NSOrderedSame) {
            // Prefer modern "2012" keys (e.g. Exposure2012, Contrast2012, etc.)
            BOOL aIs2012 = [a hasSuffix:@"2012"];
            BOOL bIs2012 = [b hasSuffix:@"2012"];
            if (aIs2012 && !bIs2012) return NSOrderedAscending;
            if (!aIs2012 && bIs2012) return NSOrderedDescending;
            return [a compare:b];
        }
        return res;
    }];

    NSMutableArray *dedupKeys = [NSMutableArray array];
    NSMutableArray *dedupNames = [NSMutableArray array];
    NSMutableSet *seenNames = [NSMutableSet set];

    for (NSString *key in allAdjKeys) {
        NSString *dispName = [am objectForKey:key];
        if (![seenNames containsObject:dispName]) {
            [seenNames addObject:dispName];
            [dedupKeys addObject:key];
            [dedupNames addObject:dispName];
        }
    }

    self.sortedAdjKeys = dedupKeys;
    self.sortedAdjNames = dedupNames;

    // ── Modifiers ─────────────────────────────────────────────────────────────
    // Expose meaningful single-key and two-key combinations
    self.modBitmasks = @[@"0", @"1", @"2", @"4", @"8", @"3", @"5", @"9", @"6", @"10", @"12"];
    self.modTitles   = @[@"—", @"SHIFT", @"CTRL", @"OPT", @"CMD",
                         @"SHIFT+CTRL", @"SHIFT+OPT", @"SHIFT+CMD",
                         @"CTRL+OPT",  @"CTRL+CMD",  @"OPT+CMD"];

    // ── Categorized action menu template ─────────────────────────────────────
    // Built once from CommandCategories.json; cloned per-row in dataCellForTableColumn.
    NSArray *cats = self.keyControl.commandCategories;
    if (cats) {
        NSMenu *tmpl = [[NSMenu alloc] initWithTitle:@""];
        [tmpl setAutoenablesItems:NO];
        for (NSDictionary *cat in cats) {
            NSString *catName = [cat objectForKey:@"category"];
            NSArray *catItems = [cat objectForKey:@"items"];
            NSMenuItem *catItem = [[NSMenuItem alloc] initWithTitle:catName action:nil keyEquivalent:@""];
            NSMenu *sub = [[NSMenu alloc] initWithTitle:catName];
            [sub setAutoenablesItems:NO];
            for (NSDictionary *cmdDict in catItems) {
                NSString *cid   = [cmdDict objectForKey:@"id"];
                NSString *cname = [cmdDict objectForKey:@"name"];
                NSMenuItem *mi  = [[NSMenuItem alloc] initWithTitle:cname action:nil keyEquivalent:@""];
                [mi setRepresentedObject:cid];
                [sub addItem:mi];
            }
            [catItem setSubmenu:sub];
            [tmpl addItem:catItem];
        }
        self.actionMenuTemplate = tmpl;
    }
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - UI Construction
// ──────────────────────────────────────────────────────────────────────────────

/// Small helper: dark label
- (NSTextField *)makeLabelWithText:(NSString *)text
{
    NSTextField *lbl = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [lbl setStringValue:text];
    [lbl setBordered:NO];
    [lbl setEditable:NO];
    [lbl setSelectable:NO];
    [lbl setDrawsBackground:NO];
    [lbl setTextColor:[NSColor colorWithCalibratedWhite:0.7 alpha:1]];
    [lbl setFont:[NSFont fontWithName:PROXIMA_FONT_NAME size:10]];
    return lbl;
}

/// Small helper: editable text field styled for the dark theme
- (NSTextField *)makeFieldWithPlaceholder:(NSString *)ph
{
    NSTextField *f = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [f setPlaceholderString:ph];
    [f setBordered:NO];
    [f setEditable:YES];
    [f setSelectable:YES];
    [f setDrawsBackground:YES];
    [f setBackgroundColor:[NSColor colorWithCalibratedWhite:0.28 alpha:1]];
    [f setTextColor:[NSColor colorWithCalibratedWhite:0.95 alpha:1]];
    [f setFont:[NSFont systemFontOfSize:12]];
    [[f cell] setUsesSingleLineMode:YES];
    return f;
}

/// Small helper: flat button
- (NSButton *)makeButtonWithTitle:(NSString *)title darkStyle:(BOOL)dark
{
    NSButton *btn = [[NSButton alloc] initWithFrame:NSZeroRect];
    [btn setTitle:title];
    [btn setButtonType:NSMomentaryLightButton];
    [btn setBordered:NO];
    [btn setFont:[NSFont fontWithName:PROXIMA_FONT_NAME size:11]];
    if (dark) {
        [btn setBezelStyle:NSRoundedBezelStyle];
        [[btn cell] setBackgroundColor:[NSColor colorWithCalibratedWhite:0.25 alpha:1]];
        [btn setAttributedTitle:[[NSAttributedString alloc] initWithString:title
            attributes:@{NSForegroundColorAttributeName:[NSColor whiteColor],
                         NSFontAttributeName:[NSFont fontWithName:PROXIMA_FONT_NAME size:11]}]];
    } else {
        [btn setBezelStyle:NSRoundedBezelStyle];
        [[btn cell] setBackgroundColor:[NSColor whiteColor]];
        [btn setAttributedTitle:[[NSAttributedString alloc] initWithString:title
            attributes:@{NSForegroundColorAttributeName:[NSColor colorWithCalibratedWhite:0.1 alpha:1],
                         NSFontAttributeName:[NSFont fontWithName:PROXIMA_FONT_NAME size:11]}]];
    }
    return btn;
}

- (void)buildUI
{
    // ── Root container ────────────────────────────────────────────────────────
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 825, 463)];
    [root setWantsLayer:YES];
    [root layer].backgroundColor = [NSColor colorWithCalibratedWhite:0.13 alpha:1].CGColor;
    self.rootView = root;

    // ── Left panel ────────────────────────────────────────────────────────────
    CGFloat leftW = 240;
    NSView *leftPanel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, leftW, 463)];
    [leftPanel setWantsLayer:YES];
    [leftPanel layer].backgroundColor = [NSColor colorWithCalibratedWhite:0.13 alpha:1].CGColor;
    [leftPanel setAutoresizingMask:NSViewHeightSizable];
    [root addSubview:leftPanel];

    // Vertical separator line
    NSBox *sep = [[NSBox alloc] initWithFrame:NSMakeRect(leftW, 0, 1, 463)];
    [sep setBoxType:NSBoxCustom];
    [sep setFillColor:[NSColor colorWithCalibratedWhite:0.22 alpha:1]];
    [sep setBorderWidth:0];
    [sep setAutoresizingMask:NSViewHeightSizable];
    [root addSubview:sep];

    // Back to Layouts button
    NSButton *backBtn = [self makeButtonWithTitle:@"BACK TO LAYOUTS" darkStyle:YES];
    [backBtn setFrame:NSMakeRect(0, 410, leftW, 50)];
    [backBtn setAutoresizingMask:NSViewMinYMargin];
    [backBtn setTarget:self];
    [backBtn setAction:@selector(backButtonClicked:)];
    [leftPanel addSubview:backBtn];

    // Title label
    NSTextField *titleLbl = [self makeLabelWithText:@"EDIT LAYOUT"];
    [titleLbl setFont:[NSFont fontWithName:PROXIMA_FONT_NAME size:14]];
    [titleLbl setTextColor:[NSColor whiteColor]];
    [titleLbl setFrame:NSMakeRect(16, 375, 190, 22)];
    [titleLbl setAutoresizingMask:NSViewMinYMargin];
    [leftPanel addSubview:titleLbl];

    // ── Metadata rows ─────────────────────────────────────────────────────────
    CGFloat fieldX = 16, fieldW = leftW - 32;
    CGFloat y = 340;
    CGFloat rowH = 36;

    // Name
    NSTextField *nameLbl = [self makeLabelWithText:@"NAME"];
    [nameLbl setFrame:NSMakeRect(fieldX, y + 20, fieldW, 14)];
    [nameLbl setAutoresizingMask:NSViewMinYMargin];
    [leftPanel addSubview:nameLbl];
    self.nameField = [self makeFieldWithPlaceholder:@"Layout name"];
    [self.nameField setFrame:NSMakeRect(fieldX, y, fieldW, 20)];
    [self.nameField setAutoresizingMask:NSViewMinYMargin];
    [leftPanel addSubview:self.nameField];
    y -= rowH;

    // Author
    NSTextField *authorLbl = [self makeLabelWithText:@"AUTHOR"];
    [authorLbl setFrame:NSMakeRect(fieldX, y + 20, fieldW, 14)];
    [authorLbl setAutoresizingMask:NSViewMinYMargin];
    [leftPanel addSubview:authorLbl];
    self.authorField = [self makeFieldWithPlaceholder:@"Your name"];
    [self.authorField setFrame:NSMakeRect(fieldX, y, fieldW, 20)];
    [self.authorField setAutoresizingMask:NSViewMinYMargin];
    [leftPanel addSubview:self.authorField];
    y -= rowH;

    // Description
    NSTextField *descLbl = [self makeLabelWithText:@"DESCRIPTION"];
    [descLbl setFrame:NSMakeRect(fieldX, y + 20, fieldW, 14)];
    [descLbl setAutoresizingMask:NSViewMinYMargin];
    [leftPanel addSubview:descLbl];
    self.descField = [self makeFieldWithPlaceholder:@"Short description"];
    [self.descField setFrame:NSMakeRect(fieldX, y, fieldW, 20)];
    [self.descField setAutoresizingMask:NSViewMinYMargin];
    [leftPanel addSubview:self.descField];
    y -= rowH;

    // Mode Key popup
    NSTextField *modeKeyLbl = [self makeLabelWithText:@"MODE KEY (TOGGLE)"];
    [modeKeyLbl setFrame:NSMakeRect(fieldX, y + 20, fieldW, 14)];
    [modeKeyLbl setAutoresizingMask:NSViewMinYMargin];
    [leftPanel addSubview:modeKeyLbl];
    self.modeKeyPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(fieldX, y - 2, fieldW, 22) pullsDown:NO];
    [self.modeKeyPopup setFont:[NSFont systemFontOfSize:11]];
    for (NSString *name in self.sortedKeyNames) {
        [self.modeKeyPopup addItemWithTitle:name];
    }
    [self.modeKeyPopup setAutoresizingMask:NSViewMinYMargin];
    [leftPanel addSubview:self.modeKeyPopup];
    y -= rowH;

    y -= 15;

    // ── Buttons ───────────────────────────────────────────────────────────────
    NSButton *saveBtn = [self makeButtonWithTitle:@"SAVE LAYOUT" darkStyle:NO];
    [saveBtn setFrame:NSMakeRect(fieldX, y, fieldW, 26)];
    [saveBtn setAutoresizingMask:NSViewMinYMargin];
    [saveBtn setTarget:self];
    [saveBtn setAction:@selector(saveClicked:)];
    [leftPanel addSubview:saveBtn];
    y -= 34;

    NSButton *newBtn = [self makeButtonWithTitle:@"NEW LAYOUT" darkStyle:YES];
    [newBtn setFrame:NSMakeRect(fieldX, y, fieldW, 26)];
    [newBtn setAutoresizingMask:NSViewMinYMargin];
    [newBtn setTarget:self];
    [newBtn setAction:@selector(newClicked:)];
    [leftPanel addSubview:newBtn];
    y -= 34;

    // Status label (shows "Saved!" etc.)
    self.statusLabel = [self makeLabelWithText:@""];
    [self.statusLabel setFrame:NSMakeRect(fieldX, y, fieldW, 20)];
    [self.statusLabel setAutoresizingMask:NSViewMinYMargin];
    [self.statusLabel setAlignment:NSCenterTextAlignment];
    [leftPanel addSubview:self.statusLabel];

    // ── Right panel ───────────────────────────────────────────────────────────
    CGFloat rightX = leftW + 1;
    NSView *rightPanel = [[NSView alloc] initWithFrame:NSMakeRect(rightX, 0, 825 - rightX, 463)];
    [rightPanel setWantsLayer:YES];
    [rightPanel layer].backgroundColor = [NSColor colorWithCalibratedWhite:0.16 alpha:1].CGColor;
    [rightPanel setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [root addSubview:rightPanel];

    // ── Toolbar row: ADD + DUPLICATE SELECTED + DELETE SELECTED ───────────────
    CGFloat toolY = 425;

    NSButton *addBtn = [self makeButtonWithTitle:@"+ ADD BINDING" darkStyle:NO];
    [addBtn setFrame:NSMakeRect(10, toolY, 130, 26)];
    [addBtn setAutoresizingMask:NSViewMinYMargin];
    [addBtn setTarget:self];
    [addBtn setAction:@selector(addBindingClicked:)];
    [rightPanel addSubview:addBtn];

    self.bulkDupBtn = [self makeButtonWithTitle:@"⧉ DUPLICATE" darkStyle:YES];
    [self.bulkDupBtn setFrame:NSMakeRect(148, toolY, 120, 26)];
    [self.bulkDupBtn setAutoresizingMask:NSViewMinYMargin];
    [self.bulkDupBtn setTarget:self];
    [self.bulkDupBtn setAction:@selector(bulkDuplicateClicked:)];
    [rightPanel addSubview:self.bulkDupBtn];

    self.bulkDelBtn = [self makeButtonWithTitle:@"✕ DELETE" darkStyle:YES];
    [self.bulkDelBtn setFrame:NSMakeRect(276, toolY, 100, 26)];
    [self.bulkDelBtn setAutoresizingMask:NSViewMinYMargin];
    [self.bulkDelBtn setTarget:self];
    [self.bulkDelBtn setAction:@selector(bulkDeleteClicked:)];
    // Style delete button red tint
    [self.bulkDelBtn setAttributedTitle:[[NSAttributedString alloc] initWithString:@"✕ DELETE"
        attributes:@{NSForegroundColorAttributeName:[NSColor colorWithCalibratedRed:1.0 green:0.45 blue:0.45 alpha:1],
                     NSFontAttributeName:[NSFont fontWithName:PROXIMA_FONT_NAME size:11]}]];
    [rightPanel addSubview:self.bulkDelBtn];

    // Column header labels
    CGFloat hY = 406;
    NSArray *headers = @[@"KEY", @"MOD", @"ACTION", @"VALUE", @"", @""];
    NSArray *headerX = @[@10,   @90,    @190,      @430,    @515, @545];
    NSArray *headerW = @[@75,   @95,    @235,       @80,     @28,  @28];
    for (int i = 0; i < (int)headers.count; i++) {
        NSTextField *h = [self makeLabelWithText:headers[i]];
        [h setFrame:NSMakeRect([headerX[i] floatValue], hY, [headerW[i] floatValue], 16)];
        [h setAutoresizingMask:NSViewMinYMargin | (i == 3 ? NSViewWidthSizable : 0)];
        [rightPanel addSubview:h];
    }

    // Divider under headers
    NSBox *hSep = [[NSBox alloc] initWithFrame:NSMakeRect(0, 402, 825 - rightX, 1)];
    [hSep setBoxType:NSBoxCustom];
    [hSep setFillColor:[NSColor colorWithCalibratedWhite:0.28 alpha:1]];
    [hSep setBorderWidth:0];
    [hSep setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
    [rightPanel addSubview:hSep];

    // ── NSTableView ───────────────────────────────────────────────────────────
    self.tableView = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 825 - rightX, 400)];
    [self.tableView setRowHeight:26];
    [self.tableView setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
    [self.tableView setGridColor:[NSColor colorWithCalibratedWhite:0.25 alpha:1]];
    [self.tableView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.18 alpha:1]];
    [self.tableView setHeaderView:nil];   // no built-in header (we drew our own)
    // Allow multi-select so users can select multiple rows with shift/cmd-click
    [self.tableView setAllowsMultipleSelection:YES];
    [self.tableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleRegular];
    [self.tableView setDataSource:self];
    [self.tableView setDelegate:self];

    // ── Table columns ─────────────────────────────────────────────────────────
    struct ColDef { NSString *ident; CGFloat w; BOOL resize; };
    struct ColDef coldefs[] = {
        { kColKey,    80, NO  },
        { kColMod,   100, NO  },
        { kColAction,240, YES },
        { kColValue,  85, NO  },
        { kColDup,    30, NO  },
        { kColDel,    30, NO  },
    };
    for (int i = 0; i < 6; i++) {
        NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:coldefs[i].ident];
        [col setWidth:coldefs[i].w];
        [col setResizingMask:coldefs[i].resize ? NSTableColumnAutoresizingMask : NSTableColumnNoResizing];
        [self.tableView addTableColumn:col];
    }

    self.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 825 - rightX, 400)];
    [self.scrollView setDocumentView:self.tableView];
    [self.scrollView setHasVerticalScroller:YES];
    [self.scrollView setAutohidesScrollers:YES];
    [self.scrollView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.18 alpha:1]];
    [self.scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [rightPanel addSubview:self.scrollView];
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Public API
// ──────────────────────────────────────────────────────────────────────────────

- (void)loadKeyfile:(NSDictionary *)keyfile
{
    [self.nameField   setStringValue:[keyfile objectForKey:KEYFILE_NAME_NODENAME]        ?: @""];
    [self.authorField setStringValue:[keyfile objectForKey:KEYFILE_AUTHOR_NODENAME]      ?: @""];
    [self.descField   setStringValue:[keyfile objectForKey:KEYFILE_DESCRIPTION_NODENAME] ?: @""];
    self.currentUUID     = [keyfile objectForKey:KEYFILE_UUID_NODENAME];
    self.currentFilename = [keyfile objectForKey:KEYFILE_FILENAME_NODENAME];

    // Mode key
    NSString *modeKeyCode = [keyfile objectForKey:KEYFILE_MODEKEY_NODENAME] ?: @"53";
    NSUInteger mki = [self.sortedKeyCodes indexOfObject:modeKeyCode];
    if (mki != NSNotFound) [self.modeKeyPopup selectItemAtIndex:(NSInteger)mki];

    // Bindings
    [self.bindings removeAllObjects];
    for (NSDictionary *keyEntry in [keyfile objectForKey:KEYFILE_KEYS_NODENAME]) {
        NSString *keyCode = [keyEntry objectForKey:KEYFILE_KEY_NODENAME]       ?: @"0";
        NSString *mod     = [keyEntry objectForKey:KEYFILE_MODIFIERS_NODENAME] ?: @"0";
        NSDictionary *adj = [keyEntry objectForKey:KEYFILE_ADJUSTMENTS_NODENAME];
        NSString *adjKey  = [[adj allKeys] firstObject]  ?: [self.sortedAdjKeys firstObject];
        NSString *adjVal  = [adj objectForKey:adjKey]    ?: @"1";

        [self.bindings addObject:[@{kBindKey:keyCode, kBindMod:mod,
                                    kBindAdj:adjKey,  kBindValue:adjVal} mutableCopy]];
    }

    [self.tableView reloadData];
    [self.statusLabel setStringValue:@""];
}

- (void)startNewLayout
{
    [self.nameField   setStringValue:@""];
    [self.authorField setStringValue:@""];
    [self.descField   setStringValue:@""];
    [self.modeKeyPopup selectItemAtIndex:0];

    self.currentUUID     = [[NSUUID UUID] UUIDString];
    self.currentFilename = nil;

    [self.bindings removeAllObjects];
    [self.tableView reloadData];
    [self.statusLabel setStringValue:@"New layout ready"];
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Button Actions
// ──────────────────────────────────────────────────────────────────────────────

- (IBAction)addBindingClicked:(id)sender
{
    // Use last-used adjustment (defaults to Exposure2012 on first use)
    NSString *adjKey = self.lastUsedAdjKey;
    // Verify the key still exists in the lookup (in case mappings were reloaded)
    if (![self.sortedAdjKeys containsObject:adjKey]) {
        adjKey = [self.sortedAdjKeys containsObject:@"Exposure2012"] ? @"Exposure2012"
                                                                      : [self.sortedAdjKeys firstObject];
        if (!adjKey) adjKey = @"Exposure2012";
    }

    NSString *defaultVal = @"";
    NSDictionary *limits = [self.keyControl.adjustmentLimits objectForKey:adjKey];
    if (limits) {
        if (limits[@"min"] && limits[@"min"] != [NSNull null]) {
            defaultVal = [NSString stringWithFormat:@"%g", [limits[@"min"] doubleValue]];
        } else {
            defaultVal = @"1";
        }
    }

    NSMutableDictionary *newBinding = [@{
        kBindKey:   [self.sortedKeyCodes firstObject] ?: @"0",
        kBindMod:   @"0",
        kBindAdj:   adjKey,
        kBindValue: defaultVal
    } mutableCopy];
    [self.bindings addObject:newBinding];
    [self.tableView reloadData];
    // Scroll to the new row
    [self.tableView scrollRowToVisible:(NSInteger)self.bindings.count - 1];
}

// ── Bulk duplicate: duplicate all selected rows (in reverse order to preserve indices) ──
- (IBAction)bulkDuplicateClicked:(id)sender
{
    NSIndexSet *selected = [self.tableView selectedRowIndexes];
    if (selected.count == 0) return;

    // Insert duplicates right after each selected row, traversing from last→first
    // so that earlier indices aren't shifted
    [selected enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.bindings.count) {
            NSMutableDictionary *dup = [self.bindings[idx] mutableCopy];
            [self.bindings insertObject:dup atIndex:idx + 1];
        }
    }];

    [self.tableView reloadData];
}

// ── Bulk delete: remove all selected rows ────────────────────────────────────
- (IBAction)bulkDeleteClicked:(id)sender
{
    NSIndexSet *selected = [self.tableView selectedRowIndexes];
    if (selected.count == 0) return;

    // Remove in reverse so indices stay valid
    [selected enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.bindings.count) {
            [self.bindings removeObjectAtIndex:idx];
        }
    }];

    [self.tableView deselectAll:nil];
    [self.tableView reloadData];
}

- (NSString *)clampValue:(NSString *)valStr forAdjustment:(NSString *)adjKey
{
    if (!valStr || [valStr length] == 0) return @"";
    
    // Non-numeric values (like preset names or remap keys) don't get clamped
    NSScanner *scanner = [NSScanner scannerWithString:valStr];
    double numVal = 0.0;
    if (![scanner scanDouble:&numVal]) {
        return valStr;
    }
    
    NSDictionary *limits = [self.keyControl.adjustmentLimits objectForKey:adjKey];
    if (!limits) {
        return valStr;
    }
    
    id minObj = [limits objectForKey:@"min"];
    id maxObj = [limits objectForKey:@"max"];
    
    if (minObj == nil && maxObj == nil) {
        return valStr;
    }
    
    double minVal = (minObj && minObj != [NSNull null]) ? [minObj doubleValue] : 1.0;
    double maxVal = (maxObj && maxObj != [NSNull null]) ? [maxObj doubleValue] : 100.0;
    
    double sign = (numVal < 0) ? -1.0 : 1.0;
    double absVal = fabs(numVal);
    
    if (absVal < minVal) {
        absVal = minVal;
    }
    if (absVal > maxVal) {
        absVal = maxVal;
    }
    
    double clamped = sign * absVal;
    // Format nicely without trailing zeros if integer
    if (clamped == floor(clamped)) {
        return [NSString stringWithFormat:@"%.0f", clamped];
    } else {
        return [NSString stringWithFormat:@"%g", clamped];
    }
}

- (IBAction)saveClicked:(id)sender
{
    NSString *name = [self.nameField stringValue];
    if ([name length] == 0) {
        [self.statusLabel setStringValue:@"Name required"];
        [self.statusLabel setTextColor:[NSColor colorWithCalibratedRed:1 green:0.3 blue:0.3 alpha:1]];
        return;
    }

    if (!self.currentUUID || [self.currentUUID length] == 0) {
        self.currentUUID = [[NSUUID UUID] UUIDString];
    }

    // Build "keys" array
    NSMutableArray *keysArray = [NSMutableArray array];
    for (NSDictionary *b in self.bindings) {
        NSString *adjKey = b[kBindAdj];
        NSString *value  = [self clampValue:b[kBindValue] forAdjustment:adjKey];
        NSDictionary *adjDict = @{adjKey: value};
        [keysArray addObject:@{
            KEYFILE_KEY_NODENAME:              b[kBindKey],
            KEYFILE_MODIFIERS_NODENAME:        b[kBindMod],
            KEYFILE_ADJUSTMENTS_NODENAME:      adjDict
        }];
    }

    // Selected mode key code
    NSUInteger mki = (NSUInteger)[self.modeKeyPopup indexOfSelectedItem];
    NSString *modeKeyCode = (mki < self.sortedKeyCodes.count)
                            ? self.sortedKeyCodes[mki] : @"53";

    // Modern Lightroom Classic process version
    NSString *lrVer = @"4";

    NSDictionary *layout = @{
        KEYFILE_NAME_NODENAME:        name,
        KEYFILE_AUTHOR_NODENAME:      [self.authorField stringValue],
        KEYFILE_DESCRIPTION_NODENAME: [self.descField   stringValue],
        KEYFILE_UUID_NODENAME:        self.currentUUID,
        KEYFILE_LRVERSION_NODENAME:   lrVer,
        KEYFILE_MODEKEY_NODENAME:     modeKeyCode,
        KEYFILE_KEYS_NODENAME:        keysArray
    };

    // Serialize to JSON
    NSString *json = [layout JSONRepresentation];
    if (!json) {
        [self.statusLabel setStringValue:@"JSON error"];
        [self.statusLabel setTextColor:[NSColor colorWithCalibratedRed:1 green:0.3 blue:0.3 alpha:1]];
        return;
    }

    // Determine file path
    NSString *dir  = self.keyControl.keyfileDirectory;
    NSString *path = [[dir stringByAppendingPathComponent:self.currentUUID]
                          stringByAppendingPathExtension:KEYFILE_JSON_EXTENSION];

    NSError *err = nil;
    BOOL ok = [json writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err];

    if (!ok) {
        [self.statusLabel setStringValue:[NSString stringWithFormat:@"Error: %@", err.localizedDescription]];
        [self.statusLabel setTextColor:[NSColor colorWithCalibratedRed:1 green:0.3 blue:0.3 alpha:1]];
        return;
    }

    // Reload the keyfile list in KeyControl
    [self.keyControl loadAllKeyfiles];
    [self.keyControl resetStatusMenu];

    // Immediately activate and hot-reload the updated layout
    [self.keyControl activateKeyfileWithUUID:self.currentUUID];

    // If main window controller is open, update its selection and view table
    if (self.mainController) {
        self.mainController.keyfileList = [self.keyControl getKeyfileList];
        self.mainController.selectedKeyfile = [self.keyControl.keyfileList objectForKey:self.currentUUID];
        [self.mainController prepareSelectedKeys];
        [self.mainController prepareCommandTableForContent];
    }

    [self.statusLabel setStringValue:@"Saved & Activated!"];
    [self.statusLabel setTextColor:[NSColor colorWithCalibratedRed:0.3 green:0.9 blue:0.4 alpha:1]];

    // Fade status label after 2 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.statusLabel setStringValue:@""];
    });
}

- (IBAction)newClicked:(id)sender
{
    [self startNewLayout];
}

- (void)actionMenuItemSelected:(id)sender
{
    NSMenuItem *item = (NSMenuItem *)sender;
    NSInteger row = [item tag];
    NSString *newAdj = [item representedObject];
    if (!newAdj || row < 0 || row >= (NSInteger)self.bindings.count) return;
    NSMutableDictionary *b = self.bindings[(NSUInteger)row];
    b[kBindAdj] = newAdj;
    self.lastUsedAdjKey = newAdj;
    
    // If the new command is a variable slider (has limits), clamp or assign a default.
    // If it is a button/action command (no limits), clear the value.
    NSDictionary *limits = [self.keyControl.adjustmentLimits objectForKey:newAdj];
    if (limits) {
        NSString *clamped = [self clampValue:b[kBindValue] forAdjustment:newAdj];
        if ([clamped length] == 0) {
            clamped = (limits[@"min"] && limits[@"min"] != [NSNull null]) ? [NSString stringWithFormat:@"%g", [limits[@"min"] doubleValue]] : @"1";
        }
        b[kBindValue] = clamped;
    } else {
        b[kBindValue] = @"";
    }
    [self.tableView reloadData];
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - NSTableView DataSource & Delegate
// ──────────────────────────────────────────────────────────────────────────────

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
    return (NSInteger)self.bindings.count;
}

/// Return a fully-configured NSCell for each column/row.
- (NSCell *)tableView:(NSTableView *)tv dataCellForTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
    if (row < 0 || row >= (NSInteger)self.bindings.count) return nil;
    NSDictionary *b = self.bindings[(NSUInteger)row];
    NSString *colId = col.identifier;

    if ([colId isEqualToString:kColKey]) {
        NSPopUpButtonCell *cell = [[NSPopUpButtonCell alloc] initTextCell:@"" pullsDown:NO];
        [cell setFont:[NSFont systemFontOfSize:11]];
        [cell setBordered:NO];
        for (NSString *kname in self.sortedKeyNames) {
            [cell addItemWithTitle:kname];
        }
        NSUInteger sel = [self.sortedKeyCodes indexOfObject:b[kBindKey]];
        if (sel != NSNotFound) [cell selectItemAtIndex:(NSInteger)sel];
        return cell;
    }

    if ([colId isEqualToString:kColMod]) {
        NSPopUpButtonCell *cell = [[NSPopUpButtonCell alloc] initTextCell:@"" pullsDown:NO];
        [cell setFont:[NSFont systemFontOfSize:11]];
        [cell setBordered:NO];
        for (NSString *t in self.modTitles) {
            [cell addItemWithTitle:t];
        }
        NSUInteger sel = [self.modBitmasks indexOfObject:b[kBindMod]];
        if (sel != NSNotFound) [cell selectItemAtIndex:(NSInteger)sel];
        return cell;
    }

    if ([colId isEqualToString:kColAction]) {
        NSPopUpButtonCell *cell = [[NSPopUpButtonCell alloc] initTextCell:@"" pullsDown:NO];
        [cell setFont:[NSFont systemFontOfSize:11]];
        [cell setBordered:NO];

        NSString *currKey = b[kBindAdj];
        NSString *currName = [self.keyControl.adjustmentMapping objectForKey:currKey] ?: currKey;

        NSMenu *rowMenu = [[NSMenu alloc] initWithTitle:@""];
        [rowMenu setAutoenablesItems:NO];

        // Hidden dummy item so the cell displays the current command name
        NSMenuItem *dummy = [[NSMenuItem alloc] initWithTitle:currName ?: @"" action:nil keyEquivalent:@""];
        [dummy setHidden:YES];
        [rowMenu addItem:dummy];

        // Build categorized submenus from template
        for (NSMenuItem *tmplCat in [self.actionMenuTemplate itemArray]) {
            NSMenuItem *catItem = [[NSMenuItem alloc] initWithTitle:[tmplCat title] action:nil keyEquivalent:@""];
            if ([tmplCat hasSubmenu]) {
                NSMenu *catSub = [[NSMenu alloc] initWithTitle:[tmplCat title]];
                [catSub setAutoenablesItems:NO];
                for (NSMenuItem *tmplCmd in [[tmplCat submenu] itemArray]) {
                    NSMenuItem *cmdItem = [[NSMenuItem alloc] initWithTitle:[tmplCmd title]
                                           action:@selector(actionMenuItemSelected:) keyEquivalent:@""];
                    [cmdItem setTarget:self];
                    [cmdItem setTag:row];
                    [cmdItem setRepresentedObject:[tmplCmd representedObject]];
                    [catSub addItem:cmdItem];
                }
                [catItem setSubmenu:catSub];
            }
            [rowMenu addItem:catItem];
        }

        [cell setMenu:rowMenu];
        [cell selectItem:dummy];
        [cell setTitle:currName ?: @""];
        return cell;
    }

    if ([colId isEqualToString:kColValue]) {
        NSDictionary *limits = [self.keyControl.adjustmentLimits objectForKey:b[kBindAdj]];
        BOOL isVariable = (limits != nil);

        NSTextFieldCell *cell = [[NSTextFieldCell alloc] initTextCell:b[kBindValue] ?: @""];
        [cell setEditable:isVariable];
        [cell setFont:[NSFont systemFontOfSize:11]];
        [cell setTextColor:isVariable ? [NSColor colorWithCalibratedWhite:0.9 alpha:1] : [NSColor colorWithCalibratedWhite:0.45 alpha:1]];
        [cell setBackgroundColor:[NSColor colorWithCalibratedWhite:0.22 alpha:1]];
        [cell setDrawsBackground:YES];

        if (limits) {
            id minObj = [limits objectForKey:@"min"];
            id maxObj = [limits objectForKey:@"max"];
            if (minObj != nil && minObj != [NSNull null] && maxObj != nil && maxObj != [NSNull null]) {
                [cell setPlaceholderString:[NSString stringWithFormat:@"%@..%@", minObj, maxObj]];
            } else if (maxObj != nil && maxObj != [NSNull null]) {
                [cell setPlaceholderString:[NSString stringWithFormat:@"max %@", maxObj]];
            }
        } else {
            [cell setPlaceholderString:@"—"];
        }
        return cell;
    }

    if ([colId isEqualToString:kColDup]) {
        NSButtonCell *cell = [[NSButtonCell alloc] init];
        [cell setButtonType:NSMomentaryLightButton];
        [cell setBordered:NO];
        [cell setBezelStyle:NSRoundRectBezelStyle];
        NSColor *blueColor = [NSColor colorWithCalibratedRed:0.4 green:0.7 blue:1.0 alpha:1];
        NSAttributedString *attTitle = [[NSAttributedString alloc] initWithString:@"⧉"
            attributes:@{NSForegroundColorAttributeName: blueColor,
                         NSFontAttributeName: [NSFont systemFontOfSize:13]}];
        [cell setAttributedTitle:attTitle];
        return cell;
    }

    if ([colId isEqualToString:kColDel]) {
        NSButtonCell *cell = [[NSButtonCell alloc] init];
        [cell setButtonType:NSMomentaryLightButton];
        [cell setBordered:NO];
        [cell setBezelStyle:NSRoundRectBezelStyle];
        NSColor *redColor = [NSColor colorWithCalibratedRed:0.85 green:0.3 blue:0.3 alpha:1];
        NSAttributedString *attTitle = [[NSAttributedString alloc] initWithString:@"✕"
            attributes:@{NSForegroundColorAttributeName: redColor,
                         NSFontAttributeName: [NSFont systemFontOfSize:13]}];
        [cell setAttributedTitle:attTitle];
        return cell;
    }

    return nil;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
    if (row < 0 || row >= (NSInteger)self.bindings.count) return nil;
    NSDictionary *b = self.bindings[(NSUInteger)row];
    NSString *colId = col.identifier;

    if ([colId isEqualToString:kColKey]) {
        NSUInteger idx = [self.sortedKeyCodes indexOfObject:b[kBindKey]];
        return idx != NSNotFound ? @(idx) : @0;
    }
    if ([colId isEqualToString:kColMod]) {
        NSUInteger idx = [self.modBitmasks indexOfObject:b[kBindMod]];
        return idx != NSNotFound ? @(idx) : @0;
    }
    if ([colId isEqualToString:kColAction]) {
        return @"";  // Display title managed by NSPopUpButtonCell; selection handled by actionMenuItemSelected:
    }
    if ([colId isEqualToString:kColValue]) {
        return b[kBindValue] ?: @"";
    }
    if ([colId isEqualToString:kColDup]) {
        return @NO;  // button state
    }
    if ([colId isEqualToString:kColDel]) {
        return @NO;  // button state
    }
    return nil;
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)obj forTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
    if (row < 0 || row >= (NSInteger)self.bindings.count) return;
    NSMutableDictionary *b = self.bindings[(NSUInteger)row];
    NSString *colId = col.identifier;

    if ([colId isEqualToString:kColKey]) {
        NSInteger idx = [obj integerValue];
        if (idx >= 0 && idx < (NSInteger)self.sortedKeyCodes.count) {
            b[kBindKey] = self.sortedKeyCodes[(NSUInteger)idx];
        }
    }
    else if ([colId isEqualToString:kColMod]) {
        NSInteger idx = [obj integerValue];
        if (idx >= 0 && idx < (NSInteger)self.modBitmasks.count) {
            b[kBindMod] = self.modBitmasks[(NSUInteger)idx];
        }
    }
    else if ([colId isEqualToString:kColAction]) {
        // Selection handled by actionMenuItemSelected: action callback
    }
    else if ([colId isEqualToString:kColValue]) {
        NSString *rawVal = [obj description] ?: @"";
        b[kBindValue] = [self clampValue:rawVal forAdjustment:b[kBindAdj]];
    }
    else if ([colId isEqualToString:kColDup]) {
        // Single-row duplicate button (inline ⧉)
        NSMutableDictionary *dup = [self.bindings[(NSUInteger)row] mutableCopy];
        NSUInteger insertIdx = (NSUInteger)row + 1;
        [self.bindings insertObject:dup atIndex:insertIdx];
        [self.tableView reloadData];
        [self.tableView scrollRowToVisible:(NSInteger)insertIdx];
    }
    else if ([colId isEqualToString:kColDel]) {
        // Single-row delete button (inline ✕)
        [self.bindings removeObjectAtIndex:(NSUInteger)row];
        [self.tableView reloadData];
    }
}

/// Alternating row background colors; highlight selected rows
- (void)tableView:(NSTableView *)tv willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
    BOOL isSelected = [tv isRowSelected:row];
    NSColor *evenBg   = [NSColor colorWithCalibratedWhite:0.18 alpha:1];
    NSColor *oddBg    = [NSColor colorWithCalibratedWhite:0.21 alpha:1];
    NSColor *selBg    = [NSColor colorWithCalibratedRed:0.2 green:0.4 blue:0.7 alpha:0.5];
    NSColor *bg       = isSelected ? selBg : (row % 2 == 0 ? evenBg : oddBg);

    if ([cell respondsToSelector:@selector(setBackgroundColor:)]) {
        [cell setBackgroundColor:bg];
    }
    if ([cell respondsToSelector:@selector(setDrawsBackground:)]) {
        [cell setDrawsBackground:YES];
    }
}

- (IBAction)backButtonClicked:(id)sender
{
    if (self.mainController) {
        [self.mainController listButtonPressed:nil];
    }
}

@end

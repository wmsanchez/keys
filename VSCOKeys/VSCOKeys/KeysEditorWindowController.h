//
//  KeysEditorWindowController.h
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

#import <Cocoa/Cocoa.h>

@class KeyControl;

@class MainWindowController;

@interface KeysEditorWindowController : NSObject <NSTableViewDataSource, NSTableViewDelegate>

@property (assign) MainWindowController *mainController;

/// The KeyControl instance — must be set before building the UI.
@property (retain) KeyControl *keyControl;

/// The root view to embed in the "edit" tab of the main window.
@property (retain) NSView *rootView;

/// Initialize with a KeyControl reference; builds UI immediately.
- (id)initWithKeyControl:(KeyControl *)keyControl;

/// Populate fields from an existing .keysjson dictionary.
- (void)loadKeyfile:(NSDictionary *)keyfile;

/// Clear all fields and start a brand-new layout.
- (void)startNewLayout;
- (void)reloadActionCatalog;

@end

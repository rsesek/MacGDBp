/*
 * MacGDBp
 * Copyright (c) 2007 - 2011, Blue Static <http://www.bluestatic.org>
 * 
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU 
 * General Public License as published by the Free Software Foundation; either version 2 of the 
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without 
 * even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU 
 * General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along with this program; if not, 
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
 */

#import <Cocoa/Cocoa.h>


@interface PreferencesController : NSWindowController

@property (strong) IBOutlet NSToolbar* toolbar;

@property (strong) IBOutlet NSView* generalPreferencesView;
@property (strong) IBOutlet NSToolbarItem* generalPreferencesItem;

@property (strong) IBOutlet NSDictionaryController* fileAccessController;
@property (strong) IBOutlet NSView* fileAccessPreferencesView;
@property (strong) IBOutlet NSToolbarItem* fileAccessPreferencesItem;

@property (strong) IBOutlet NSView* pathsPreferencesView;
@property (strong) IBOutlet NSToolbarItem* pathsPreferencesItem;

- (void)showPreferencesWindow;

- (IBAction)addFileAccess:(id)sender;

// panel switching
- (IBAction)showGeneral:(id)sender;
- (IBAction)showFileAccess:(id)sender;
- (IBAction)showPaths:(id)sender;

@end

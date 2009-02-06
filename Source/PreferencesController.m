/*
 * MacGDBp
 * Copyright (c) 2007 - 2009, Blue Static <http://www.bluestatic.org>
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

#import "PreferencesController.h"

NSSize generalSize;
NSSize pathsSize;

@interface PreferencesController (Private)
- (void)resizeWindowToSize:(NSSize)size;
@end


@implementation PreferencesController

/**
 * Loads the NIB and shows the preferences
 */
- (id)init
{
	if (self = [super initWithWindowNibName:@"Preferences"])
	{
		blankView = [[NSView alloc] init];
	}
	return self;
}

/**
 * Destructor
 */
- (void)dealloc
{
	[blankView release];
	[super dealloc];
}

/**
 * Awake from nib
 */
- (void)awakeFromNib
{
	generalSize = [generalPreferencesView frame].size;
	pathsSize = [pathsPreferencesView frame].size;
}

/**
 * Shows the preferences controller window
 */
- (void)showPreferencesWindow
{
	[self showGeneral:self];
	[[self window] center];
	[[self window] makeKeyAndOrderFront:self];
}

#pragma mark Panel Switching

/**
 * Shows the general panel
 */
- (IBAction)showGeneral:(id)sender
{
	if ([[self window] contentView] == generalPreferencesView)
		return;
	
	[self resizeWindowToSize:generalSize];
	
	[[self window] setContentView:generalPreferencesView];
	[toolbar setSelectedItemIdentifier:[generalPreferencesItem itemIdentifier]];
}

/**
 * Shows the path replacement panel
 */
- (IBAction)showPaths:(id)sender
{
	if ([[self window] contentView] == pathsPreferencesView)
		return;
	
	[self resizeWindowToSize:pathsSize];
	
	[[self window] setContentView:pathsPreferencesView];
	[toolbar setSelectedItemIdentifier:[pathsPreferencesItem itemIdentifier]];
}

#pragma mark NSToolbar Delegate

/**
 * Returns the selection names
 */
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:
		[generalPreferencesItem itemIdentifier],
		[pathsPreferencesItem itemIdentifier],
		nil
	];
}

#pragma mark Private

/**
 * Resizes the preferences window to be the size of the given preferences panel
 */
- (void)resizeWindowToSize:(NSSize)size
{
	[[self window] setContentView:blankView]; // don't want weird redraw artifacts
	
	NSRect newFrame;
	
	newFrame = [NSWindow contentRectForFrameRect:[[self window] frame] styleMask:[[self window] styleMask]];
	
	float height = size.height + 55;
	
	newFrame.origin.y += newFrame.size.height;
	newFrame.origin.y -= height;
	newFrame.size.height = height;
	newFrame.size.width = size.width;
	
	newFrame = [NSWindow frameRectForContentRect:newFrame styleMask:[[self window] styleMask]];
	
	[[self window] setFrame:newFrame display:YES animate:YES];
}

@end

/*
 * MacGDBp
 * Copyright (c) 2007 - 2008, Blue Static <http://www.bluestatic.org>
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

#import "ConnectWindowController.h"
#import "DebuggerWindowController.h"
#import "AppDelegate.h"

static id instance = nil;

@implementation ConnectWindowController

/**
 * Creates a shared controller that can be accessed statically
 */
+ (id)sharedController
{
	if (!instance)
	{
		instance = [[ConnectWindowController alloc] initWithWindowNibName:@"Connect"];
		[instance window];
	}
	return instance;
}

/**
 * Creates a new DebuggerConnection object (and then completely forgets about it) and then close the window
 */
- (IBAction)connect:(id)sender
{
	[[[DebuggerWindowController alloc] initWithPort:[port intValue] session:[session stringValue]] autorelease];
	[[self window] orderOut:self];
}

@end

/*
 * MacGDBp
 * Copyright (c) 2002 - 2007, Blue Static <http://www.bluestatic.org>
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
#import "DebuggerConnection.h"
#import "AppDelegate.h"

@implementation ConnectWindowController

/**
 * Creates a shared controller that can be accessed statically
 */
+ (id)sharedController
{
	static id instance = nil;
	if (!instance)
	{
		instance = [[ConnectWindowController alloc] initWithWindowNibName:@"Connect"];
		[instance window];
		
		[[NSNotificationCenter defaultCenter] addObserver:instance
												 selector:@selector(applicationWillTerminate:)
													 name:NSApplicationWillTerminateNotification
												   object:NSApp];
		 
	}
	return instance;
}

/**
 * Called when the applicaion is about to terminate so we can release itself
 */
- (void)applicationWillTerminate:(NSNotification *)notif
{
	[self release];
}

/**
 * Creates a new DebuggerConnection object (and then completely forgets about it) and then close the window
 */
- (IBAction)connect:(id)sender
{
	DebuggerConnection *cnx = [[DebuggerConnection alloc] initWithPort:[_port intValue] session:[_session stringValue]];
	[[NSApp delegate] registerConnection:cnx];
	[cnx release];
	[[self window] orderOut:self];
}

@end

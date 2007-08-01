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

#import "DebuggerConnection.h"


@implementation DebuggerConnection

/**
 * Creates a new DebuggerConnection and initializes the socket from the given connection
 * paramters.
 */
- (id)initWithHost: (NSString *)host port: (int)port session: (NSString *)session
{
	NSLog(@"initWithHost");
	if (self = [super init])
	{
		_host = [host retain];
		_port = port;
		_session = [session retain];
		_windowController = [[DebuggerWindowController alloc] initWithConnection: self];
		[[_windowController window] makeKeyAndOrderFront: self];
	}
	return self;
}

/**
 * Deallocates all of the object's data members
 */
- (void)dealloc
{
	[_host release];
	[_session release];
	
	[super dealloc];
}

@end

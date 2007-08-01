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

#import "DebuggerWindowController.h"
#import "DebuggerConnection.h"

@implementation DebuggerWindowController

/**
 * Initializes the window controller and sets the connection
 */
- (id)initWithConnection: (DebuggerConnection *)cnx
{
	if (self = [super initWithWindowNibName: @"Debugger"])
	{
		_connection = [cnx retain];
		[[self window] setTitle: [NSString stringWithFormat: @"GDBp @ %@:%d/%@", [_connection host], [_connection port], [_connection session]]];
	}
	return self;
}

/**
 * Release object members
 */
- (void)dealloc
{
	[_connection release];
	
	[super dealloc];
}

@end

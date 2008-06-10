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

#import "BreakpointWindowController.h"


@implementation BreakpointWindowController

/**
 * Constructor
 */
- (id)init
{
	if (self = [super initWithWindowNibName:@"Breakpoints"])
	{
		manager = [BreakpointManager sharedManager];
	}
	return self;
}


/**
 * Adds a breakpoint by calling up a file chooser and selecting a file for
 * breaking in
 */
- (IBAction)addBreakpoint:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	if ([panel runModal] != NSOKButton)
	{
		return;
	}
	
	[sourceView setFile:[panel filename]];
}

/**
 * Removes a breakpoint
 */
- (IBAction)removeBreakpoint:(id)sender
{
	
}

#pragma mark BSSourceView Delegate

/**
 * The gutter was clicked, which indicates that a breakpoint needs to be changed
 */
- (void)gutterClickedAtLine:(int)line forFile:(NSString *)file
{
	if ([manager hasBreakpointAt:line inFile:file])
	{
		[manager removeBreakpointAt:line inFile:file];
	}
	else
	{
		Breakpoint *bp = [[Breakpoint alloc] initWithLine:line inFile:file];
		[manager addBreakpoint:bp];
	}
	
	[[sourceView numberView] setMarkers:[manager breakpointsForFile:file]];
	[[sourceView numberView] setNeedsDisplay:YES];
}

@end

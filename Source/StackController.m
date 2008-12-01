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

#import "StackController.h"


@implementation StackController

@synthesize stack;

/**
 * Constructor
 */
- (id)init
{
	if (self = [super init])
	{
		stack = [[NSMutableArray alloc] init];
	}
	return self;
}

/**
 * Destructor
 */
- (void)dealloc
{
	[stack release];
	[super dealloc];
}

/**
 * Returns a reference to the top of the stack
 */
- (StackFrame *)peek
{
	return [stack lastObject];
}

/**
 * Pops the current frame off the stack and returns the frame
 */
- (StackFrame *)pop
{
	StackFrame *frame = [stack lastObject];
	if (frame != nil)
		[stack removeLastObject];
	return frame;
}

/**
 * Pushes a frame onto the end of the stack
 */
- (void)push:(StackFrame *)frame
{
	[stack insertObject:frame atIndex:[stack count]];
}

@end

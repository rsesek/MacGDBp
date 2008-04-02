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

#import "BreakpointManager.h"


@implementation BreakpointManager

/**
 * Initializer
 */
- (id)init
{
	if (self = [super init])
	{
		breakpoints = [NSMutableDictionary dictionary];
	}
	return self;
}

/**
 * Returns the shared manager (singleton)
 */
+ (BreakpointManager *)sharedManager
{
	static BreakpointManager *manager;
	if (!manager)
	{
		manager = [[BreakpointManager alloc] init];
	}
	return manager;
}

/**
 * Registers a breakpoint at a given line
 */
- (void)addBreakpoint:(Breakpoint *)bp;
{
	NSMutableSet *lines = [breakpoints valueForKey:[bp file]];
	if (lines == nil)
	{
		lines = [NSMutableSet setWithObject:bp];
		[breakpoints setValue:lines forKey:[bp file]];
	}
	else
	{
		[lines addObject:bp];
	}
	NSLog(@"breakpoints = %@", breakpoints);
}

/**
 * Removes a breakpoint at a given line/file combination, or nil if nothing was removed
 */
- (Breakpoint *)removeBreakpointAt:(int)line inFile:(NSString *)file
{
	NSMutableSet *lines = [breakpoints valueForKey:file];
	for (Breakpoint *b in lines)
	{
		if ([b line] == line)
		{
			[lines removeObject:b];
			return b;
		}
	}
	return nil;
}

/**
 * Returns all the breakpoints for a given file
 */
- (NSSet *)breakpointsForFile:(NSString *)file
{
	return [breakpoints valueForKey:file];
}

/**
 * Checks to see if a given file has a breakpoint on a given line
 */
- (BOOL)hasBreakpointAt:(int)line inFile:(NSString *)file
{
	NSSet *lines = [breakpoints valueForKey:file];
	if (!lines)
	{
		return NO;
	}
	for (Breakpoint *b in lines)
	{
		if ([b line] == line)
		{
			return YES;
		}
	}
	return NO;
}

@end

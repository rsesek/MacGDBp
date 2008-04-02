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

#import "Breakpoint.h"


@implementation Breakpoint

@synthesize file, line, debuggerId;

/**
 * Initializes a breakpoint with a file and line
 */
- (id)initWithLine:(int)l inFile:(NSString *)f
{
	if (self = [super init])
	{
		file = f;
		line = l;
	}
	return self;
}

/**
 * Determines if two breakpoints are equal
 */
- (BOOL)isEqual:(id)obj
{
	return ([[obj file] isEqualToString:file] && [obj line] == line);
}

/**
 * Returns the hash value of a breakpoint
 */
- (NSUInteger)hash
{
	return ([file hash] << 8) + line;
}

/**
 * Pretty-print
 */
- (NSString *)description
{
	return [NSString stringWithFormat:@"%@:%i", file, line];
}

@end

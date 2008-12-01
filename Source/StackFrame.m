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

#import "StackFrame.h"

/**
 * Private class continuation
 */
@interface StackFrame()
@property(readwrite, copy) NSString *filename;
@property(readwrite, copy) NSString *source;
@property(readwrite, copy) NSDictionary *contexts;
@end
/***/

@implementation StackFrame

@synthesize index, filename, source, lineNumber, function, contexts;

/**
 * Constructor
 */
- (id)initWithIndex:(int)anIndex
	   withFilename:(NSString *)aFilename
		 withSource:(NSString *)aSource
			 atLine:(int)aLineNumber
		 inFunction:(NSString *)aFunction
	   withContexts:(NSDictionary *)aContexts
{
	if (self = [super init])
	{
		self.index		= anIndex;
		self.filename	= aFilename;
		self.source		= aSource;
		self.lineNumber	= aLineNumber;
		self.function	= aFunction;
		self.contexts	= aContexts;
	}
	return self;
}

/**
 * Determines whether or not the given frame was shifted, rather than jumped. Essentially,
 * this checks if it's in the same file/function.
 */
- (BOOL)isShiftedFrame:(StackFrame *)frame
{
	return ([filename isEqualToString:frame.filename]);
}

/**
 * Returns a human-readable representation
 */
- (NSString *)description
{
	return [NSString stringWithFormat:@"#%d %@ [%@:%d]", index, function, filename, lineNumber];
}

@end

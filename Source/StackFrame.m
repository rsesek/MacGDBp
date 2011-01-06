/*
 * MacGDBp
 * Copyright (c) 2007 - 2011, Blue Static <http://www.bluestatic.org>
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

@implementation StackFrame

@synthesize loaded = loaded_;
@synthesize routingID = routingID_;
@synthesize index = index_;
@synthesize filename = filename_;
@synthesize source = source_;
@synthesize lineNumber = lineNumber_;
@synthesize function = function_;
@synthesize variables = variables_;

- (void)dealloc
{
  self.filename = nil;
  self.source = nil;
  self.function = nil;
  self.variables = nil;
  [super dealloc];
}

/**
 * Determines whether or not the given frame was shifted, rather than jumped. Essentially,
 * this checks if it's in the same file/function.
 */
- (BOOL)isShiftedFrame:(StackFrame*)frame
{
  return ([self.filename isEqualToString:frame.filename] && [self.function isEqualToString:frame.function]);
}

/**
 * Returns a human-readable representation
 */
- (NSString*)description
{
  return [NSString stringWithFormat:@"#%d %@ [%@:%d]", self.index, self.function, self.filename, self.lineNumber];
}

@end

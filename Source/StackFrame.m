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

@synthesize loaded;
@synthesize index;
@synthesize filename;
@synthesize source;
@synthesize lineNumber;
@synthesize function;
@synthesize variables;

- (void)dealloc {
  self.filename = nil;
  self.source = nil;
  self.function = nil;
  self.variables = nil;
  [super dealloc];
}

- (BOOL)isShiftedFrame:(StackFrame*)frame {
  return ([self.filename isEqualToString:frame.filename] && [self.function isEqualToString:frame.function]);
}

- (NSString*)description {
  return [NSString stringWithFormat:@"#%d %@ [%@:%d]", self.index, self.function, self.filename, self.lineNumber];
}

@end

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

#import "Breakpoint.h"

#import "PreferenceNames.h"

@implementation Breakpoint

@synthesize file = file_;
@synthesize line = line_;
@synthesize debuggerId = debuggerId_;

/**
 * Initializes a breakpoint with a file and line
 */
- (id)initWithLine:(NSUInteger)l inFile:(NSString*)f
{
  if (self = [super init])
  {
    file_ = [f retain];
    line_ = l;
  }
  return self;
}

/**
 * Dealloc
 */
- (void)dealloc
{
  [file_ release];
  [super dealloc];
}

/**
 * Creates a Breakpoint from the values of an NSDictionary
 */
- (id)initWithDictionary:(NSDictionary*)dict
{
  if (self = [super init])
  {
    file_ = [[dict valueForKey:@"file"] retain];
    line_ = [[dict valueForKey:@"line"] intValue];
  }
  return self;
}

/**
 * Returns the transformed path for the breakpoint, as Xdebug needs it
 */
- (NSString*)transformedPath
{
  NSString* path = self.file;
  
  NSMutableArray* transforms = [[NSUserDefaults standardUserDefaults] mutableArrayValueForKey:kPrefPathReplacements];
  if (!transforms || [transforms count] < 1)
    return path;
  
  for (NSDictionary* replacement in transforms)
  {
    path = [path
      stringByReplacingOccurrencesOfString:[replacement valueForKey:@"local"]
      withString:[replacement valueForKey:@"remote"]
    ];
  }
  
  return path;
}

/**
 * Determines if two breakpoints are equal
 */
- (BOOL)isEqual:(id)obj
{
  return ([[obj file] isEqualToString:self.file] && [obj line] == self.line);
}

/**
 * Returns the hash value of a breakpoint
 */
- (NSUInteger)hash
{
  return ([self.file hash] << 8) + self.line;
}

/**
 * Returns an NSDictionary of the data so it can be stored in NSUserDefaults
 */
- (NSDictionary*)dictionary
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
      self.file, @"file",
      [NSNumber numberWithInt:self.line], @"line",
      nil
  ];
}

/**
 * Pretty-print
 */
- (NSString*)description
{
  return [NSString stringWithFormat:@"%@:%lu", self.file, self.line];
}

@end

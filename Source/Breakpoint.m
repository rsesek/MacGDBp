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

NSString* const kBreakpointTypeFile = @"line";
NSString* const kBreakpointTypeFunctionEntry = @"call";

@implementation Breakpoint {
  NSString* _type;  // weak
  unsigned long _debuggerId;

  NSString* _file;

  NSString* _functionName;
}

- (instancetype)initWithLine:(NSUInteger)l inFile:(NSString*)f
{
  if ((self = [super init])) {
    _type = kBreakpointTypeFile;
    _file = [f copy];
    _line = l;
  }
  return self;
}

- (instancetype)initWithFunctionNamed:(NSString *)function {
  if ((self = [super init])) {
    _type = kBreakpointTypeFunctionEntry;
    _functionName = [function copy];
  }
  return self;
}

- (id)initWithDictionary:(NSDictionary*)dict
{
  if ((self = [super init])) {
    NSString* type = [dict valueForKey:@"type"];
    if (!type || [type isEqualToString:kBreakpointTypeFile]) {
      _type = kBreakpointTypeFile;
      _file = [[dict valueForKey:@"file"] copy];
      _line = [[dict valueForKey:@"line"] intValue];
    } else if ([type isEqualToString:kBreakpointTypeFunctionEntry]) {
      _type = kBreakpointTypeFunctionEntry;
      _functionName = [[dict valueForKey:@"function"] copy];
    } else {
      [NSException raise:NSInvalidArgumentException
                  format:@"Unknown Breakpoint type: %@", type];
    }
  }
  return self;
}

- (void)dealloc
{
  [_file release];
  [_functionName release];
  [super dealloc];
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
  if (_type == kBreakpointTypeFile) {
    return @{
      @"type" : _type,
      @"file" : self.file,
      @"line" : @(self.line)
    };
  } else if (_type == kBreakpointTypeFunctionEntry) {
    return @{
      @"type"     : _type,
      @"function" : self.functionName
    };
  }
  return nil;
}

/**
 * Pretty-print
 */
- (NSString*)description
{
  return [NSString stringWithFormat:@"Breakpoint %@", [[self dictionary] description]];
}

@end

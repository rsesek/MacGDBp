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
NSString* const kBreakpointTypeFunctionReturn = @"return";

@implementation Breakpoint {
  NSString* _type;  // weak
  unsigned long _debuggerId;

  NSString* _file;

  NSString* _functionName;
}

+ (instancetype)breakpointAtLine:(unsigned long)line inFile:(NSString*)file
{
  Breakpoint* breakpoint = [[[Breakpoint alloc] init] autorelease];
  breakpoint->_type = kBreakpointTypeFile;
  breakpoint->_file = [file copy];
  breakpoint->_line = line;
  return breakpoint;
}

+ (instancetype)breakpointOnFunctionNamed:(NSString*)name type:(NSString*)type
{
  Breakpoint* breakpoint = [[[Breakpoint alloc] init] autorelease];
  NSAssert1(type == kBreakpointTypeFunctionEntry || type == kBreakpointTypeFunctionReturn, @"Unexpected breakpoint type: %@", type);
  breakpoint->_type = type;
  breakpoint->_functionName = [name copy];
  return breakpoint;
}

- (instancetype)initWithDictionary:(NSDictionary*)dict
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
    } else if ([type isEqualToString:kBreakpointTypeFunctionReturn]) {
      _type = kBreakpointTypeFunctionReturn;
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
 * Returns the string to display in the breakpoints list.
 */
- (NSString*)displayValue
{
  if (self.type == kBreakpointTypeFile) {
    return [NSString stringWithFormat:@"%@:%ld", self.file, self.line];
  } else if (self.type == kBreakpointTypeFunctionEntry ||
             self.type == kBreakpointTypeFunctionReturn) {
    return [NSString stringWithFormat:@"%@()", self.functionName];
  }
  return nil;
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

- (BOOL)isEqual:(id)obj
{
  if (![obj isKindOfClass:[self class]]) {
    return NO;
  }

  Breakpoint* other = obj;
  if (self.type != other.type) {
    return NO;
  }

  if (self.type == kBreakpointTypeFile) {
    return [self.file isEqualToString:other.file] && self.line == other.line;
  } else if (self.type == kBreakpointTypeFunctionEntry ||
             self.type == kBreakpointTypeFunctionReturn) {
    return [self.functionName isEqualToString:other.functionName];
  }

  return NO;
}

- (NSDictionary*)dictionary
{
  if (self.type == kBreakpointTypeFile) {
    return @{
      @"type" : self.type,
      @"file" : self.file,
      @"line" : @(self.line)
    };
  } else if (self.type == kBreakpointTypeFunctionEntry ||
             self.type == kBreakpointTypeFunctionReturn) {
    return @{
      @"type"     : self.type,
      @"function" : self.functionName
    };
  }
  return nil;
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"Breakpoint %@", [[self dictionary] description]];
}

@end

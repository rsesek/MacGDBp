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
  NSString* __weak _type;
  unsigned long _debuggerId;

  NSString* _file;
  NSData* _secureBookmark;
  NSURL* _secureFileAccess;

  NSString* _functionName;
}

+ (instancetype)breakpointAtLine:(unsigned long)line inFile:(NSString*)file
{
  Breakpoint* breakpoint = [[Breakpoint alloc] init];
  breakpoint->_type = kBreakpointTypeFile;
  breakpoint->_file = [file copy];
  breakpoint->_line = line;
  return breakpoint;
}

+ (instancetype)breakpointOnFunctionNamed:(NSString*)name
{
  Breakpoint* breakpoint = [[Breakpoint alloc] init];
  breakpoint->_type = kBreakpointTypeFunctionEntry;
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
      _secureBookmark = [[dict valueForKey:@"secureBookmark"] copy];
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

- (void)dealloc {
  if (_secureFileAccess)
    [self stopSecureFileAccess];
}

/**
 * Returns the string to display in the breakpoints list.
 */
- (NSString*)displayValue
{
  if (self.type == kBreakpointTypeFile) {
    return [NSString stringWithFormat:@"%@:%ld", self.file, self.line];
  } else if (self.type == kBreakpointTypeFunctionEntry) {
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
  } else if (self.type == kBreakpointTypeFunctionEntry) {
    return [self.functionName isEqualToString:other.functionName];
  }

  return NO;
}

- (NSDictionary*)dictionary
{
  if (self.type == kBreakpointTypeFile) {
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:@{
      @"type" : self.type,
      @"file" : self.file,
      @"line" : @(self.line),
    }];
    if (self.secureBookmark)
      [dict setObject:self.secureBookmark forKey:@"secureBookmark"];
    return dict;
  } else if (self.type == kBreakpointTypeFunctionEntry) {
    return @{
      @"type"     : self.type,
      @"function" : self.functionName
    };
  }
  return nil;
}

- (BOOL)createSecureBookmark
{
  NSURL* fileURL = [NSURL fileURLWithPath:self.file];
  return [self _createSecureBookmarkWithURL:fileURL];
}

- (BOOL)_createSecureBookmarkWithURL:(NSURL*)url
{
  NSError* error;
  NSData* secureBookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
                         includingResourceValuesForKeys:nil
                                          relativeToURL:nil
                                                  error:&error];
  if (secureBookmark) {
    self.secureBookmark = secureBookmark;
    return YES;
  } else {
    NSLog(@"Failed to create secure bookmark: %@", error);
    return NO;
  }
}

- (BOOL)startSecureFileAccess
{
  assert(self.type == kBreakpointTypeFile);
  if (_secureFileAccess)
    return YES;
  if (!_secureBookmark)
    return NO;

  BOOL isStale;
  NSError* error;
  _secureFileAccess = [NSURL URLByResolvingBookmarkData:_secureBookmark
                                                options:NSURLBookmarkResolutionWithSecurityScope
                                          relativeToURL:nil
                                    bookmarkDataIsStale:&isStale
                                                  error:&error];
  if (error) {
    NSLog(@"Failed to access file via secure bookmark: %@", error);
    return NO;
  }
  if (isStale)
    [self _createSecureBookmarkWithURL:_secureFileAccess];

  return [_secureFileAccess startAccessingSecurityScopedResource];
}

- (BOOL)stopSecureFileAccess
{
  assert(self.type == kBreakpointTypeFile);
  if (!_secureFileAccess)
    return YES;
  if (!_secureBookmark)
    return NO;

  [_secureFileAccess stopAccessingSecurityScopedResource];
  _secureFileAccess = nil;
  return YES;
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"Breakpoint %@", [[self dictionary] description]];
}

@end

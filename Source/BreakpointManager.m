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

#import "BreakpointManager.h"

#import "PreferenceNames.h"

@implementation BreakpointManager {
  NSMutableArray* _breakpoints;
  NSMutableArray* _savedBreakpoints;

  DebuggerBackEnd* __weak _connection;
}

- (id)init
{
  if (self = [super init])
  {
    _breakpoints = [[NSMutableArray alloc] init];
    _savedBreakpoints = [[NSMutableArray alloc] init];

    NSArray* savedBreakpoints = [[NSUserDefaults standardUserDefaults] arrayForKey:kPrefBreakpoints];
    if (savedBreakpoints) {
      for (NSDictionary* d in savedBreakpoints) {
        Breakpoint* bp = [[Breakpoint alloc] initWithDictionary:d];
        [_breakpoints addObject:bp];
        [_savedBreakpoints addObject:[bp dictionary]];
      }
    }
  }
  return self;
}

/**
 * Registers a breakpoint at a given line
 */
- (void)addBreakpoint:(Breakpoint*)bp;
{
  if ([_breakpoints containsObject:bp])
    return;

  [self willChangeValueForKey:@"breakpoints"];
  [_breakpoints addObject:bp];
  [self didChangeValueForKey:@"breakpoints"];

  [_connection addBreakpoint:bp];

  [_savedBreakpoints addObject:[bp dictionary]];
  [[NSUserDefaults standardUserDefaults] setObject:_savedBreakpoints forKey:kPrefBreakpoints];
}

- (Breakpoint*)removeBreakpoint:(Breakpoint*)bp
{
  // Use the -isEqual: test to find the object in |_breakpoints| that also has
  // the debugger id and secure bookmark data.
  NSUInteger idx = [_breakpoints indexOfObject:bp];
  if (idx == NSNotFound)
    return nil;

  bp = [_breakpoints objectAtIndex:idx];

  [self willChangeValueForKey:@"breakpoints"];
  [_breakpoints removeObject:bp];
  [self didChangeValueForKey:@"breakpoints"];

  [_connection removeBreakpoint:bp];

  [_savedBreakpoints removeObject:[bp dictionary]];
  [[NSUserDefaults standardUserDefaults] setObject:_savedBreakpoints forKey:kPrefBreakpoints];

  return bp;
}

/**
 * Returns all the breakpoints for a given file
 */
- (NSSet<NSNumber*>*)breakpointsForFile:(NSString*)file
{
  NSMutableSet<NSNumber*>* matches = [NSMutableSet set];
  for (Breakpoint* b in _breakpoints) {
    if ([b.file isEqualToString:file]) {
      [matches addObject:@(b.line)];
    }
  }

  return matches;
}


- (BOOL)hasBreakpoint:(Breakpoint*)breakpoint
{
  return [_breakpoints containsObject:breakpoint];
}

@end

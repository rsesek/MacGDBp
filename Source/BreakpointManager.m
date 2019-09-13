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

#import "AppDelegate.h"
#import "PreferenceNames.h"

@interface BreakpointManager (Private)
- (void)updateDisplaysForFile:(NSString*)file;
@end

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
      [_savedBreakpoints addObjectsFromArray:savedBreakpoints];
      for (NSDictionary* d in savedBreakpoints) {
        [_breakpoints addObject:[[Breakpoint alloc] initWithDictionary:d]];
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
  if (![_breakpoints containsObject:bp])
  {
    [self willChangeValueForKey:@"breakpoints"];
    [_breakpoints addObject:bp];
    [self didChangeValueForKey:@"breakpoints"];

    [_connection addBreakpoint:bp];

    [_savedBreakpoints addObject:[bp dictionary]];
    [[NSUserDefaults standardUserDefaults] setObject:_savedBreakpoints forKey:kPrefBreakpoints];

    [self updateDisplaysForFile:[bp file]];
  }
}

- (Breakpoint*)removeBreakpoint:(Breakpoint*)bp
{
  if ([_breakpoints containsObject:bp]) {
    [self willChangeValueForKey:@"breakpoints"];
    [_breakpoints removeObject:bp];
    [self didChangeValueForKey:@"breakpoints"];

    [_connection removeBreakpoint:bp];

    [_savedBreakpoints removeObject:[bp dictionary]];
    [[NSUserDefaults standardUserDefaults] setObject:_savedBreakpoints forKey:kPrefBreakpoints];

    if (bp.file)
      [self updateDisplaysForFile:bp.file];

    return bp;
  }
  return nil;
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

/**
 * Checks to see if a given file has a breakpoint on a given line
 */
- (BOOL)hasBreakpointAt:(NSUInteger)line inFile:(NSString*)file
{
  return [self hasBreakpoint:[Breakpoint breakpointAtLine:line inFile:file]];
}

#pragma mark Private

/**
 * This marks BSSourceView needsDisplay, rearranges the objects in the breakpoints controller,
 * and sets the markers for the BSLineNumberView
 */
- (void)updateDisplaysForFile:(NSString*)file
{
  AppDelegate* appDel = [NSApp delegate];
  [[[appDel breakpoint] arrayController] rearrangeObjects];
  [[[appDel debugger] sourceViewer] setNeedsDisplay:YES];
  [[[appDel debugger] sourceViewer] setMarkers:[self breakpointsForFile:file]];
}

@end

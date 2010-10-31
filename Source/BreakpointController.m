/*
 * MacGDBp
 * Copyright (c) 2007 - 2010, Blue Static <http://www.bluestatic.org>
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

#import "BreakpointController.h"
#import "AppDelegate.h"


@implementation BreakpointController

@synthesize sourceView, arrayController;

/**
 * Constructor
 */
- (id)init
{
  if (self = [super initWithWindowNibName:@"Breakpoints"])
  {
    manager = [BreakpointManager sharedManager];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BreakpointsWindowVisible"])
      [[self window] orderBack:nil];
  }
  return self;
}

/**
 * Adds a breakpoint by calling up a file chooser and selecting a file for
 * breaking in
 */
- (IBAction)addBreakpoint:(id)sender
{
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  
  if ([panel runModal] != NSOKButton)
  {
    return;
  }
  
  [sourceView setFile:[panel filename]];
}

/**
 * Removes a breakpoint
 */
- (IBAction)removeBreakpoint:(id)sender
{
  NSArray* selection = [arrayController selectedObjects];
  if ([selection count] < 1)
  {
    return;
  }
  
  for (Breakpoint* bp in selection)
  {
    [manager removeBreakpointAt:[bp line] inFile:[bp file]];
  }
}

#pragma mark NSTableView Delegate

/**
 * NSTableView delegate method that informs the controller that the stack selection did change and that
 * we should update the source viewer
 */
- (void)tableViewSelectionDidChange:(NSNotification*)notif
{
  NSArray* selection = [arrayController selectedObjects];
  if ([selection count] < 1)
  {
    return;
  }
  
  Breakpoint* bp = [selection objectAtIndex:0];
  [sourceView setFile:[bp file]];
  [sourceView scrollToLine:[bp line]];
  [[sourceView numberView] setMarkers:[NSSet setWithArray:[manager breakpointsForFile:[bp file]]]];
}

#pragma mark BSSourceView Delegate

/**
 * The gutter was clicked, which indicates that a breakpoint needs to be changed
 */
- (void)gutterClickedAtLine:(int)line forFile:(NSString*)file
{
  if ([manager hasBreakpointAt:line inFile:file])
  {
    [manager removeBreakpointAt:line inFile:file];
  }
  else
  {
    Breakpoint* bp = [[Breakpoint alloc] initWithLine:line inFile:file];
    [manager addBreakpoint:bp];
    [bp release];
  }
  
  [[sourceView numberView] setMarkers:[NSSet setWithArray:[manager breakpointsForFile:file]]];
  [[sourceView numberView] setNeedsDisplay:YES];
}

@end

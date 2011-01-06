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

#import "BreakpointController.h"
#import "AppDelegate.h"


@implementation BreakpointController

@synthesize tableView = tableView_;
@synthesize arrayController = arrayController_;
@synthesize sourceView = sourceView_;

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
 * Awake from NIB.
 */
- (void)awakeFromNib
{
  NSArray* dragTypes = [NSArray arrayWithObject:NSFilenamesPboardType];
  [tableView_ registerForDraggedTypes:dragTypes];
}

/**
 * Adds a breakpoint by calling up a file chooser and selecting a file for
 * breaking in
 */
- (IBAction)addBreakpoint:(id)sender
{
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  
  if ([panel runModal] != NSOKButton)
    return;
  
  [sourceView_ setFile:[panel filename]];
}

/**
 * Removes a breakpoint
 */
- (IBAction)removeBreakpoint:(id)sender
{
  NSArray* selection = [arrayController_ selectedObjects];
  if ([selection count] < 1)
    return;

  for (Breakpoint* bp in selection)
    [manager removeBreakpointAt:[bp line] inFile:[bp file]];
}

#pragma mark NSTableView Delegate

/**
 * NSTableView delegate method that informs the controller that the stack selection did change and that
 * we should update the source viewer
 */
- (void)tableViewSelectionDidChange:(NSNotification*)notif
{
  NSArray* selection = [arrayController_ selectedObjects];
  if ([selection count] < 1)
    return;
  
  Breakpoint* bp = [selection objectAtIndex:0];
  [sourceView_ setFile:[bp file]];
  if ([bp line] > 0)
    [sourceView_ scrollToLine:[bp line]];
  [[sourceView_ numberView] setMarkers:[NSSet setWithArray:[manager breakpointsForFile:[bp file]]]];
}

#pragma mark NSTableView Data Source

/**
 * Handles the beginning of a drag operation.
 */
- (BOOL)tableView:(NSTableView*)aTableView
    writeRowsWithIndexes:(NSIndexSet*)rowIndexes
    toPasteboard:(NSPasteboard*)pboard
{
  NSLog(@"begin");
  return [[pboard types] containsObject:NSFilenamesPboardType];
}

/**
 * Validates the drag operation.
 */
- (NSDragOperation)tableView:(NSTableView*)aTableView
                validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation
{
  NSLog(@"validate");
  NSPasteboard* pboard = [info draggingPasteboard];
  if ([[pboard types] containsObject:NSFilenamesPboardType]) {
    NSArray* files = [pboard propertyListForType:NSFilenamesPboardType];
    if ([files count])
      return NSDragOperationGeneric;
  }
  return NSDragOperationNone;
}

/**
 * Incorporates the dropped data.
 */
- (BOOL)tableView:(NSTableView*)aTableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)operation
{
  NSLog(@"accept");
  BOOL valid = [self tableView:aTableView
                  validateDrop:info
                   proposedRow:row
         proposedDropOperation:operation] == NSDragOperationGeneric;
  if (valid) {
    NSPasteboard* pboard = [info draggingPasteboard];
    NSArray* files = [pboard propertyListForType:NSFilenamesPboardType];
    for (NSString* file in files) {
      Breakpoint* bp = [[[Breakpoint alloc] initWithLine:0 inFile:file] autorelease];
      [manager addBreakpoint:bp];
    }
    return YES;
  }
  return NO;
}

#pragma mark BSSourceView Delegate

/**
 * The gutter was clicked, which indicates that a breakpoint needs to be changed
 */
- (void)gutterClickedAtLine:(int)line forFile:(NSString*)file
{
  if ([manager hasBreakpointAt:line inFile:file]) {
    [manager removeBreakpointAt:line inFile:file];
  } else {
    Breakpoint* bp = [[Breakpoint alloc] initWithLine:line inFile:file];
    [manager addBreakpoint:bp];
    [bp release];
  }
  
  [[sourceView_ numberView] setMarkers:[NSSet setWithArray:[manager breakpointsForFile:file]]];
  [[sourceView_ numberView] setNeedsDisplay:YES];
}

@end

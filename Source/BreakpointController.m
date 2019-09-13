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
#import "PreferenceNames.h"

@implementation BreakpointController {
  BreakpointManager* _manager;

  BSSourceView* _sourceView;

  NSArrayController* __weak _arrayController;
}

/**
 * Constructor
 */
- (instancetype)initWithBreakpointManager:(BreakpointManager*)breakpointManager
                               sourceView:(BSSourceView*)sourceView
{
  if ((self = [super initWithNibName:@"Breakpoints" bundle:nil])) {
    _manager = breakpointManager;
    _sourceView = sourceView;
  }
  return self;
}

- (void)awakeFromNib
{
  [[self.addBreakpointButton cell] setUsesItemFromMenu:NO];
  [self.addBreakpointButton.cell setMenuItem:[self.addBreakpointButton.menu itemAtIndex:0]];
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
  
  [_sourceView setFile:[[panel URL] path]];
}

- (IBAction)addFunctionBreakpoint:(id)sender
{
  [self.view.window beginSheet:self.addFunctionBreakpointWindow completionHandler:nil];
}

- (IBAction)cancelFunctionBreakpoint:(id)sender
{
  [self.view.window endSheet:self.addFunctionBreakpointWindow];
}

- (IBAction)saveFunctionBreakpoint:(id)sender
{
  [_manager addBreakpoint:[Breakpoint breakpointOnFunctionNamed:self.functionNameField.stringValue]];
  [self.view.window endSheet:self.addFunctionBreakpointWindow];
}

/**
 * Removes a breakpoint
 */
- (IBAction)removeBreakpoint:(id)sender
{
  NSArray* selection = [_arrayController selectedObjects];
  if ([selection count] < 1)
  {
    return;
  }
  
  for (Breakpoint* bp in selection) {
    [_manager removeBreakpoint:bp];
  }
}

#pragma mark NSTableView Delegate

/**
 * NSTableView delegate method that informs the controller that the stack selection did change and that
 * we should update the source viewer
 */
- (void)tableViewSelectionDidChange:(NSNotification*)notif
{
  NSArray* selection = [_arrayController selectedObjects];
  if ([selection count] < 1) {
    return;
  }
  
  Breakpoint* bp = [selection objectAtIndex:0];
  if (bp.type != kBreakpointTypeFile) {
    return;
  }

  [_sourceView setFile:[bp file]];
  [_sourceView scrollToLine:[bp line]];
  [_sourceView setMarkers:[_manager breakpointsForFile:bp.file]];
}

@end

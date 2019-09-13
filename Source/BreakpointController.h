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

#import <Cocoa/Cocoa.h>

#import "BreakpointManager.h"
#import "BSSourceView.h"

@interface BreakpointController : NSViewController

@property(nonatomic, weak) IBOutlet NSPopUpButton* addBreakpointButton;
@property(nonatomic, weak) IBOutlet NSArrayController* arrayController;

@property(nonatomic, weak) IBOutlet NSWindow* addFunctionBreakpointWindow;
@property(nonatomic, weak) IBOutlet NSTextField* functionNameField;

- (instancetype)initWithBreakpointManager:(BreakpointManager*)breakpointManager
                               sourceView:(BSSourceView*)sourceView;

- (IBAction)addBreakpoint:(id)sender;

- (IBAction)removeBreakpoint:(id)sender;

- (IBAction)addFunctionBreakpoint:(id)sender;
- (IBAction)cancelFunctionBreakpoint:(id)sender;
- (IBAction)saveFunctionBreakpoint:(id)sender;

@end

/*
 * MacGDBp
 * Copyright (c) 2007 - 2009, Blue Static <http://www.bluestatic.org>
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
#import "DebuggerController.h"
#import "BreakpointController.h"
#import "PreferencesController.h"

@interface AppDelegate : NSObject
{
	IBOutlet DebuggerController *debugger;
	IBOutlet BreakpointController *breakpoint;
	PreferencesController *prefs;
}

@property(readonly) DebuggerController *debugger;
@property(readonly) BreakpointController *breakpoint;

- (IBAction)showDebuggerWindow:(id)sender;
- (IBAction)showInspectorWindow:(id)sender;
- (IBAction)showBreakpointWindow:(id)sender;
- (IBAction)showPreferences:(id)sender;

- (IBAction)openHelpPage:(id)sender;

@end

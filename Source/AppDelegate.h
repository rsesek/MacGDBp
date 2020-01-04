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

#import <Sparkle/SUUpdaterDelegate.h>

#import "BreakpointController.h"
#import "DebuggerController.h"
#import "LoggingController.h"
#import "PreferencesController.h"

@interface AppDelegate : NSObject <SUUpdaterDelegate>
{
  IBOutlet DebuggerController* debugger;
  IBOutlet LoggingController* loggingController_;
}

@property (readonly) DebuggerController* debugger;
@property (readonly) BreakpointController* breakpoint;
@property (readonly) LoggingController* loggingController;
@property (readonly) PreferencesController* prefsController;

// Returns the instance of this class that is acting as the application's
// delegate.
+ (AppDelegate*)instance;

- (IBAction)showDebuggerWindow:(id)sender;
- (IBAction)showBreakpointWindow:(id)sender;
- (IBAction)showPreferences:(id)sender;

- (IBAction)openHelpPage:(id)sender;

@end

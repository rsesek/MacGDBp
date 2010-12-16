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

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize debugger;
@synthesize breakpoint;
@synthesize loggingController = loggingController_;

/**
 * Initialize method that is called before all other messages. This will set the default
 * preference values.
 */
+ (void)load
{
  NSAutoreleasePool* pool = [NSAutoreleasePool new];

  NSDictionary* dict = [[NSDictionary alloc] initWithObjectsAndKeys:
    [NSNumber numberWithInt:9000],  @"Port",
    [NSNumber numberWithBool:YES],  @"BreakpointsWindowVisible",
    [NSNumber numberWithBool:YES],  @"InspectorWindowVisible",
    [NSMutableArray array],         @"PathReplacements",
    [NSNumber numberWithBool:YES],  @"BreakOnFirstLine",
    nil
  ];
  
  [[NSUserDefaults standardUserDefaults] registerDefaults:dict];

  [dict release];

  [pool release];
}

+ (AppDelegate*)instance
{
  return (AppDelegate*)[NSApp delegate];
}

/**
 * Shows the debugger window
 */
- (IBAction)showDebuggerWindow:(id)sender
{
  [[debugger window] makeKeyAndOrderFront:self];
  NSLog(@"logg %@", [loggingController_ window]);
}

/**
 * Shows the breakpoints window
 */
- (IBAction)showBreakpointWindow:(id)sender
{
  if (![[breakpoint window] isVisible] || ![[breakpoint window] isKeyWindow])
    [[breakpoint window] makeKeyAndOrderFront:sender];
  else
    [[breakpoint window] orderOut:sender];
}

/**
 * Shows the preferences window. Lazily loads the PreferencesController.
 */
- (IBAction)showPreferences:(id)sender
{
  if (!prefs)
    prefs = [[PreferencesController alloc] init];
  
  [prefs showPreferencesWindow];
}

/**
 * Opens the URL to the help page
 */
- (IBAction)openHelpPage:(id)sender
{
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.bluestatic.org/software/macgdbp/help.php"]];
}

@end

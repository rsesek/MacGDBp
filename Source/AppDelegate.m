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

#import "AppDelegate.h"

#import <Sparkle/Sparkle.h>

#import "PreferenceNames.h"

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
  @autoreleasepool {
    NSDictionary* defaults = @{
      kPrefPort                     : @9000,
      kPrefInspectorWindowVisible   : @YES,
      kPrefPathReplacements         : [NSMutableArray array],
      kPrefBreakOnFirstLine         : @YES,
      kPrefDebuggerAttached         : @YES
    };
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  }
}

+ (AppDelegate*)instance
{
  return (AppDelegate*)[NSApp delegate];
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
  // Record whether this user ever used the beta VersionCast feed. In the
  // future, we will use this bit to query for unstable releases after the user
  // has upgraded to a stable version.
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

  BOOL usesUnstable = [defaults boolForKey:kPrefUnstableVersionCast];
  NSURL* feedURL = [[SUUpdater sharedUpdater] feedURL];
  usesUnstable = usesUnstable ||
      [[feedURL absoluteString] rangeOfString:@"?unstable"].location != NSNotFound;
  [defaults setBool:usesUnstable forKey:kPrefUnstableVersionCast];
}

- (void)applicationWillTerminate:(NSNotification*)notification
{
  [[NSUserDefaults standardUserDefaults] setBool:self.debugger.connection.autoAttach
                                          forKey:kPrefDebuggerAttached];
}

/**
 * Shows the debugger window
 */
- (IBAction)showDebuggerWindow:(id)sender
{
  [[debugger window] makeKeyAndOrderFront:self];
  [debugger.segmentControl setSelectedSegment:1];
}

/**
 * Shows the breakpoints window
 */
- (IBAction)showBreakpointWindow:(id)sender
{
  [[debugger window] makeKeyAndOrderFront:sender];
  [debugger.segmentControl setSelectedSegment:2];
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
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.bluestatic.org/software/macgdbp/help.php"]];
}

@end

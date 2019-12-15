/*
* MacGDBp
* Copyright (c) 2019, Blue Static <https://www.bluestatic.org>
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

#if USE_APP_SANDBOX

#import "FileAccessController.h"

#import "AppDelegate.h"
#import "PreferenceNames.h"
#import "PreferencesController.h"

@implementation FileAccessController {
  // Self-owned window controller reference. Cleared when |-windowWillClose:|.
  FileAccessController* __strong _selfRef;
}

+ (void)maybeShowFileAccessDialog
{
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary* fileAccesses = [defaults objectForKey:kPrefFileAccessBookmarks];
  // TODO: Re-prompt after some amount of time.
  if ([fileAccesses count] == 0 &&
      ![defaults objectForKey:kPrefFileAccessStartupShowDate]) {
    [defaults setObject:[NSDate date] forKey:kPrefFileAccessStartupShowDate];
    [self showFileAccessDialog];
  }
}

+ (void)showFileAccessDialog
{
  FileAccessController* controller = [[FileAccessController alloc] init];
  [controller.window center];
  [controller showWindow:self];
}

- (instancetype)init
{
  if ((self = [self initWithWindowNibName:@"FileAccess"])) {
    _selfRef = self;
  }
  return self;
}

- (IBAction)openFileAccess:(id)sender
{
  [self close];
  PreferencesController* prefs = [[AppDelegate instance] prefsController];
  [prefs showPreferencesWindow];
  [prefs showFileAccess:sender];
}

- (void)windowWillClose:(NSNotification*)notification
{
  _selfRef = nil;
}

@end

#endif  // USE_APP_SANDBOX

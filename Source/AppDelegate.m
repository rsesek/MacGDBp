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

#import "FileAccessController.h"
#import "PreferenceNames.h"

static NSString* const kAppcastUnstable = @"appcast-unstable.xml";

@implementation AppDelegate {
  PreferencesController* _prefsController;
}

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
      kPrefPhpPath                  : @"/usr/bin/php",
#if USE_APP_SANDBOX
      kPrefFileAccessBookmarks      : [NSMutableDictionary dictionary],
#endif
      kPrefBreakOnFirstLine         : @YES,
      kPrefDebuggerAttached         : @YES,
      kPrefSelectedDebuggerSegment  : @1,
    };
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  }
}

+ (AppDelegate*)instance
{
  return (AppDelegate*)[NSApp delegate];
}

- (PreferencesController*)prefsController
{
  if (!_prefsController)
    _prefsController = [[PreferencesController alloc] init];
  return _prefsController;
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
  [[SUUpdater sharedUpdater] setDelegate:self];

#if USE_APP_SANDBOX
  [FileAccessController maybeShowFileAccessDialog];

  [self _activateSecureFileAccess];
#endif  // USE_APP_SANDBOX
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
  [self.prefsController showPreferencesWindow];
}

/**
 * Opens the URL to the help page
 */
- (IBAction)openHelpPage:(id)sender
{
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.bluestatic.org/software/macgdbp/help/"]];
}

#if USE_APP_SANDBOX
/**
 * Activates any secure file access bookmarks stored in preferences.
 */
- (void)_activateSecureFileAccess
{
  NSDictionary* prefs = [NSUserDefaults.standardUserDefaults objectForKey:kPrefFileAccessBookmarks];
  NSMutableDictionary<NSString*, NSData*>* bookmarks = [NSMutableDictionary dictionaryWithDictionary:prefs];
  for (NSString* path in bookmarks) {
    NSURL* url = [NSURL URLWithString:path];

    BOOL isStale;
    NSError* error;
    url = [NSURL URLByResolvingBookmarkData:bookmarks[path]
                                    options:NSURLBookmarkResolutionWithSecurityScope
                              relativeToURL:nil
                        bookmarkDataIsStale:&isStale
                                      error:&error];
    if (error) {
      NSLog(@"Failed to resolve secure bookmark for path %@: %@", path, error);
      continue;
    }
    if (isStale) {
      NSData* newBookmark = [PreferencesController secureBookmarkDataForURL:url];
      bookmarks[url.absoluteString] = newBookmark;
      [bookmarks removeObjectForKey:path];
    }

    if (![url startAccessingSecurityScopedResource]) {
      NSLog(@"Failed to start accessing resource %@", path);
      continue;
    }
  }

  [NSUserDefaults.standardUserDefaults setObject:bookmarks forKey:kPrefFileAccessBookmarks];
}
#endif  // USE_APP_SANDBOX

////////////////////////////////////////////////////////////////////////////////
#pragma mark SUUpdater Delegate

- (nullable NSString*)feedURLStringForUpdater:(SUUpdater*)updater
{
  // Record whether this user ever used the beta appcast feed.
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSURL* feedURL = [NSURL URLWithString:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"SUFeedURL"]];

  BOOL usesUnstable = [defaults boolForKey:kPrefUnstableVersionCast] ||
                      [[feedURL absoluteString] hasSuffix:kAppcastUnstable];
  [defaults setBool:usesUnstable forKey:kPrefUnstableVersionCast];

  if (!usesUnstable)
    return nil;

  feedURL = [[feedURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:kAppcastUnstable];
  return [feedURL absoluteString];
}

@end

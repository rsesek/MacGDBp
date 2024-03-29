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

#import "PreferencesController.h"

@implementation PreferencesController {
  NSView* _blankView;

  NSSize _generalSize, _fileAccessSize, _pathsSize;
}

/**
 * Loads the NIB and shows the preferences
 */
- (id)init
{
  if (self = [super initWithWindowNibName:@"Preferences"])
  {
    _blankView = [[NSView alloc] init];
  }
  return self;
}

- (void)awakeFromNib
{
  _generalSize = self.generalPreferencesView.frame.size;
#if USE_APP_SANDBOX
  _fileAccessSize = self.fileAccessPreferencesView.frame.size;
#else
  NSUInteger i = [self.toolbar.items indexOfObject:self.fileAccessPreferencesItem];
  if (i != NSNotFound)
    [self.toolbar removeItemAtIndex:i];
#endif
  _pathsSize = self.pathsPreferencesView.frame.size;
}

/**
 * Shows the preferences controller window
 */
- (void)showPreferencesWindow
{
  NSWindow* window = self.window;  // Force the window to load.
  [self showGeneral:self];
  [window center];
  [window makeKeyAndOrderFront:self];
}

/**
 * Brings up a file picker to grant read-only file access to the selected path,
 * which is then persisted across application restarts.
 */
- (IBAction)addFileAccess:(id)sender
{
#if USE_APP_SANDBOX
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseDirectories = YES;
  panel.canChooseFiles = NO;
  if ([panel runModal] != NSOKButton)
    return;

  NSURL* url = panel.URL;

  NSData* secureBookmark = [self.class secureBookmarkDataForURL:url];
  if (!secureBookmark)
    return;

  NSDictionaryControllerKeyValuePair* pair = [self.fileAccessController newObject];
  pair.key = url.absoluteString;
  pair.value = secureBookmark;
  [self.fileAccessController addObject:pair];
#else
  NSAssert(NO, @"not reached");
#endif
}

#if USE_APP_SANDBOX
+ (NSData*)secureBookmarkDataForURL:(NSURL*)url
{
   NSError* error;
   NSData* secureBookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
                          includingResourceValuesForKeys:nil
                                           relativeToURL:nil
                                                   error:&error];
   if (error) {
     NSLog(@"Error creating secure bookmark: %@", error);
   }
  return secureBookmark;
}
#endif  // USE_APP_SANDBOX

#pragma mark Panel Switching

/**
 * Shows the general panel
 */
- (IBAction)showGeneral:(id)sender
{
  [self _switchToView:self.generalPreferencesView resizeTo:_generalSize forToolbarItem:self.generalPreferencesItem];
}

- (IBAction)showFileAccess:(id)sender
{
#if USE_APP_SANDBOX
  [self _switchToView:self.fileAccessPreferencesView resizeTo:_fileAccessSize forToolbarItem:self.fileAccessPreferencesItem];
#else
  NSAssert(NO, @"not reached");
#endif
}

/**
 * Shows the path replacement panel
 */
- (IBAction)showPaths:(id)sender
{
  [self _switchToView:self.pathsPreferencesView resizeTo:_pathsSize forToolbarItem:self.pathsPreferencesItem];
}

#pragma mark NSToolbar Delegate

/**
 * Returns the selection names
 */
- (NSArray*)toolbarSelectableItemIdentifiers:(NSToolbar*)toolbar
{
  return @[
    self.generalPreferencesItem.itemIdentifier,
#if USE_APP_SANDBOX
    self.fileAccessPreferencesItem.itemIdentifier,
#endif
    self.pathsPreferencesItem.itemIdentifier,
  ];
}

#pragma mark Private

- (void)_switchToView:(NSView*)contentView
             resizeTo:(NSSize)size
       forToolbarItem:(NSToolbarItem*)item {
  if (self.window.contentView == contentView)
    return;
  [self _resizeWindowToSize:size];
  self.window.contentView = contentView;
  self.toolbar.selectedItemIdentifier = item.itemIdentifier;
}

/**
 * Resizes the preferences window to be the size of the given preferences panel
 */
- (void)_resizeWindowToSize:(NSSize)size
{
  // Hide the current view when animating, to avoid weird artifacts.
  self.window.contentView = _blankView;

  NSWindowStyleMask styleMask = self.window.styleMask;
  NSRect newFrame = [NSWindow contentRectForFrameRect:self.window.frame styleMask:styleMask];

  CGFloat height = size.height + 55;
  newFrame.origin.y += newFrame.size.height;
  newFrame.origin.y -= height;
  newFrame.size.height = height;
  newFrame.size.width = size.width;

  newFrame = [NSWindow frameRectForContentRect:newFrame styleMask:styleMask];

  [[self window] setFrame:newFrame display:YES animate:YES];
}

@end

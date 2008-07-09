/*
 * MacGDBp
 * Copyright (c) 2007 - 2008, Blue Static <http://www.bluestatic.org>
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

@synthesize debugger, breakpoint;

/**
 * Initializes
 */
- (id)init
{
	if (self = [super init])
	{
	}
	return self;
}

/**
 * Initialize method that is called before all other messages. This will set the default
 * preference values.
 */
+ (void)initialize
{
	NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInt:9000], @"Port", @"macgdbp", @"IDEKey", nil];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:dict];
	
	[dict release];
}

/**
 * Shows the debugger window
 */
- (IBAction)showDebuggerWindow:(id)sender
{
	[[debugger window] makeKeyAndOrderFront:self];
}

/**
 * Shows the breakpoints window
 */
- (IBAction)showBreakpointWindow:(id)sender
{
	[[breakpoint window] makeKeyAndOrderFront:self];
}

/**
 * Shows the preferences window. Lazily loads the PreferencesController.
 */
- (IBAction)showPreferences:(id)sender
{
	if (!prefs)
		prefs = [[PreferencesController alloc] init];
	
	[[prefs window] makeKeyAndOrderFront:self];
}

/**
 * Opens the URL to the help page
 */
- (IBAction)openHelpPage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.bluestatic.org/software/macgdbp/help.php"]];
}

@end

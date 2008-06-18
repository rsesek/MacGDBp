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
 * When the application has finished loading, show the connection dialog
 */
- (void)applicationDidFinishLaunching:(NSNotification *)notif
{
	// TODO: use preference values
	debugger = [[DebuggerWindowController alloc] initWithPort:9000 session:@"macgdbp"];
	breakpoint = [[BreakpointWindowController alloc] init];
	[NSThread detachNewThreadSelector:@selector(versionCheck:) toTarget:self withObject:self];
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
 * Opens the URL to the help page
 */
- (IBAction)openHelpPage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.bluestatic.org/software/macgdbp/help.php"]];
}

#pragma mark Version Checking

/**
 * Checks and sees if the current version is the most up-to-date one
 */
- (void)versionCheck:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSMutableString *version = [NSMutableString stringWithString:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleShortVersionString"]];
	[version replaceOccurrencesOfString:@" " withString:@"-" options:NSLiteralSearch range:NSMakeRange(0, [version length])];
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.bluestatic.org/versioncheck.php?prod=macgdbp&ver=%@", version]];
	NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10];
	NSURLResponse *response;
	NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
	
	if (result == nil)
	{
		[pool release];
		return;
	}
	
	NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:result options:0 error:nil];
	NSXMLNode *comp = [[xml rootElement] childAtIndex:0];
	if ([[comp name] isEqualToString:@"update"])
	{
		[updateString setStringValue:[NSString stringWithFormat:[updateString stringValue], [comp stringValue]]];
		[updateWindow makeKeyAndOrderFront:self];
		[updateWindow center];
	}
	
	[xml release];
	
	[pool release];
}


/**
 * Opens the URL to the download page
 */
- (IBAction)openUpdateInformation:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.bluestatic.org/software/macgdbp/"]];
}

@end

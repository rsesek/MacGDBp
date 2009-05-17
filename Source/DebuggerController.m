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

#import "DebuggerController.h"
#import "GDBpConnection.h"
#import "NSXMLElementAdditions.h"
#import "AppDelegate.h"
#import "BreakpointManager.h"

@interface DebuggerController (Private)
- (void)updateSourceViewer;
- (void)updateStackViewer;
- (void)expandVariables;
- (void)reloadStack;
@end

@implementation DebuggerController

@synthesize connection, sourceViewer, inspector;

/**
 * Initializes the window controller and sets the connection using preference
 * values
 */
- (id)init
{
	if (self = [super initWithWindowNibName:@"Debugger"])
	{
		stackController = [[StackController alloc] init];
		
		NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		connection = [[GDBpConnection alloc] initWithPort:[defaults integerForKey:@"Port"] session:[defaults stringForKey:@"IDEKey"]];
		expandedVariables = [[NSMutableSet alloc] init];
		[[self window] makeKeyAndOrderFront:nil];
		[[self window] setDelegate:self];
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			selector:@selector(handleConnectionError:)
			name:kErrorOccurredNotif
			object:connection
		];
		
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"InspectorWindowVisible"])
			[inspector orderFront:self];
	}
	return self;
}

/**
 * Dealloc
 */
- (void)dealloc
{
	[connection release];
	[expandedVariables release];
	[stackController release];
	[super dealloc];
}

/**
 * Before the display get's comfortable, set up the NSTextView to scroll horizontally
 */
- (void)awakeFromNib
{
	[[self window] setExcludedFromWindowsMenu:YES];
	[[self window] setTitle:[NSString stringWithFormat:@"GDBp @ %@:%d/%@", [connection remoteHost], [connection port], [connection session]]];
	[sourceViewer setDelegate:self];
	[stackArrayController setSortDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES] autorelease]]];
}

/**
 * Called right before the window closes so that we can tell the socket to close down
 */
- (void)windowWillClose:(NSNotification*)notif
{
	[[connection socket] close];
}

/**
 * Validates the menu items for the "Debugger" menu
 */
- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	SEL action = [anItem action];
	
	if (action == @selector(stepOut:))
		return ([connection isConnected] && [stackController.stack count] > 1);
	else if (action == @selector(stepIn:) || action == @selector(stepOver:) || action == @selector(run:))
		return [connection isConnected];
	else if (action == @selector(reconnect:))
		return ![connection isConnected];
	
	return [[self window] validateUserInterfaceItem:anItem];
}

/**
 * Resets all the displays to be empty
 */
- (void)resetDisplays
{
	[variablesTreeController setContent:nil];
	[stackController.stack removeAllObjects];
	[stackArrayController rearrangeObjects];
	[[sourceViewer textView] setString:@""];
	sourceViewer.file = nil;
}

/**
 * Sets the status to be "Error" and then displays the error message
 */
- (void)setError:(NSString*)anError
{
	[errormsg setStringValue:anError];
	[errormsg setHidden:NO];
}

/**
 * Handles a GDBpConnection error
 */
- (void)handleConnectionError:(NSNotification*)notif
{
	[self setError:[[notif userInfo] valueForKey:@"NSString"]];
}

/**
 * Called once the socket accepts and MacGDBp is connected to the debugger
 */
- (void)startDebugger
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BreakOnFirstLine"])
		[self stepIn:self];
}

/**
 * Forwards the message to run script execution to the connection
 */
- (IBAction)run:(id)sender
{
	[connection run];
	if ([connection isConnected])
		[self reloadStack];
}

/**
 * Tells the connection to ask the server to reconnect
 */
- (IBAction)reconnect:(id)sender
{
	[connection reconnect];
	[self resetDisplays];
}

/**
 * Forwards the message to "step in" to the connection
 */
- (IBAction)stepIn:(id)sender
{
	if ([[variablesTreeController selectedObjects] count] > 0)
		selectedVariable = [[variablesTreeController selectedObjects] objectAtIndex:0];
	
	[connection stepIn];
	if ([connection isConnected])
		[self reloadStack];
}

/**
 * Forwards the message to "step out" to the connection
 */
- (IBAction)stepOut:(id)sender
{
	if ([[variablesTreeController selectedObjects] count] > 0)
		selectedVariable = [[variablesTreeController selectedObjects] objectAtIndex:0];
	
	[connection stepOut];
	if ([connection isConnected])
		[self reloadStack];
}

/**
 * Forwards the message to "step over" to the connection
 */
- (IBAction)stepOver:(id)sender
{
	if ([[variablesTreeController selectedObjects] count] > 0)
		selectedVariable = [[variablesTreeController selectedObjects] objectAtIndex:0];
	
	[connection stepOver];
	if ([connection isConnected])
		[self reloadStack];
}

/**
 * NSTableView delegate method that informs the controller that the stack selection did change and that
 * we should update the source viewer
 */
- (void)tableViewSelectionDidChange:(NSNotification*)notif
{
	[self updateSourceViewer];
	[self expandVariables];
}

/**
 * Called whenver an item is expanded. This allows us to determine if we need to fetch deeper
 */
- (void)outlineViewItemDidExpand:(NSNotification*)notif
{
	NSTreeNode* node = [[notif userInfo] objectForKey:@"NSObject"];
	[expandedVariables addObject:[[node representedObject] fullname]];
}

/**
 * Called when an item was collapsed. This allows us to remove it from the list of expanded items
 */
- (void)outlineViewItemDidCollapse:(NSNotification*)notif
{
	[expandedVariables removeObject:[[[[notif userInfo] objectForKey:@"NSObject"] representedObject] fullname]];
}

#pragma mark Private

/**
 * Does the actual updating of the source viewer by reading in the file
 */
- (void)updateSourceViewer
{
	id selection = [stackArrayController selection];
	if ([selection valueForKey:@"filename"] == NSNoSelectionMarker)
		return;
	
	// get the filename
	NSString* filename = [selection valueForKey:@"filename"];
	filename = [[NSURL URLWithString:filename] path];
	if ([filename isEqualToString:@""])
		return;
	
	// replace the source if necessary
	if (![sourceViewer.file isEqualToString:filename])
	{
		NSString* source = [selection valueForKey:@"source"];
		[sourceViewer setString:source asFile:filename];
		
		NSSet* breakpoints = [NSSet setWithArray:[[BreakpointManager sharedManager] breakpointsForFile:filename]];
		[[sourceViewer numberView] setMarkers:breakpoints];
	}
	
	int line = [[selection valueForKey:@"lineNumber"] intValue];
	[sourceViewer setMarkedLine:line];
	[sourceViewer scrollToLine:line];
	
	[[sourceViewer textView] display];
}

/**
 * Does some house keeping to the stack viewer
 */
- (void)updateStackViewer
{
	[stackArrayController rearrangeObjects];
	[stackArrayController setSelectionIndex:0];
	[self expandVariables];
}

/**
 * Expands the variables based on the stored set
 */
- (void)expandVariables
{
	NSString* selection = [selectedVariable fullname];
	
	for (int i = 0; i < [variablesOutlineView numberOfRows]; i++)
	{
		NSTreeNode* node = [variablesOutlineView itemAtRow:i];
		NSString* fullname = [[node representedObject] fullname];
		
		// see if it needs expanding
		if ([expandedVariables containsObject:fullname])
			[variablesOutlineView expandItem:node];
		
		// select it if we had it selected before
		if ([fullname isEqualToString:selection])
			[variablesTreeController setSelectionIndexPath:[node indexPath]];
	}
}

/**
 * This updates the entire stack. Xdebug is queried to get the stack, non-shifted
 * frames are reused and new ones are fetched.
 */
- (void)reloadStack
{
	NSArray* stack = [connection getCurrentStack];
	if (stack == nil)
		return;
	
	[stackController.stack removeAllObjects];
	[stackController.stack addObjectsFromArray:stack];
	[self updateStackViewer];
	[self updateSourceViewer];
}

#pragma mark BSSourceView Delegate

/**
 * The gutter was clicked, which indicates that a breakpoint needs to be changed
 */
- (void)gutterClickedAtLine:(int)line forFile:(NSString*)file
{
	BreakpointManager* mngr = [BreakpointManager sharedManager];
	
	if ([mngr hasBreakpointAt:line inFile:file])
	{
		[mngr removeBreakpointAt:line inFile:file];
	}
	else
	{
		Breakpoint* bp = [[Breakpoint alloc] initWithLine:line inFile:file];
		[mngr addBreakpoint:bp];
		[bp release];
	}
	
	[[sourceViewer numberView] setMarkers:[NSSet setWithArray:[mngr breakpointsForFile:file]]];
	[[sourceViewer numberView] setNeedsDisplay:YES];
}

@end

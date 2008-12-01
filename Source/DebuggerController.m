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

#import "DebuggerController.h"
#import "GDBpConnection.h"
#import "NSXMLElementAdditions.h"
#import "AppDelegate.h"
#import "BreakpointManager.h"

@interface DebuggerController (Private)
- (void)updateSourceViewer;
- (void)updateStackViewer;
@end

@implementation DebuggerController

@synthesize connection, sourceViewer;

/**
 * Initializes the window controller and sets the connection using preference
 * values
 */
- (id)init
{
	if (self = [super initWithWindowNibName:@"Debugger"])
	{
		stackController = [[StackController alloc] init];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		connection = [[GDBpConnection alloc] initWithPort:[defaults integerForKey:@"Port"] session:[defaults stringForKey:@"IDEKey"]];
		expandedRegisters = [[NSMutableSet alloc] init];
		[[self window] makeKeyAndOrderFront:nil];
		[[self window] setDelegate:self];
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			selector:@selector(handleConnectionError:)
			name:kErrorOccurredNotif
			object:connection
		];
	}
	return self;
}

/**
 * Dealloc
 */
- (void)dealloc
{
	[connection release];
	[expandedRegisters release];
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
- (void)windowWillClose:(NSNotification *)notif
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
	[registerController setContent:nil];
	[[sourceViewer textView] setString:@""];
}

/**
 * Sets the status to be "Error" and then displays the error message
 */
- (void)setError:(NSString *)anError
{
	[errormsg setStringValue:anError];
	[errormsg setHidden:NO];
}

/**
 * Handles a GDBpConnection error
 */
- (void)handleConnectionError:(NSNotification *)notif
{
	[self setError:[[notif userInfo] valueForKey:@"NSString"]];
}

/**
 * Sets the stack root element so that the NSOutlineView can display it
 */
- (void)setRegister:(NSXMLDocument *)elm
{
	// XXX: Doing anything short of this will cause bindings to crash spectacularly for no reason whatsoever, and
	//		in seemingly arbitrary places. The class that crashes is _NSKeyValueObservationInfoCreateByRemoving.
	//		http://boredzo.org/blog/archives/2006-01-29/have-you-seen-this-crash says that this means nothing is
	//		being observed, but I doubt that he was using an NSOutlineView which seems to be one f!cking piece of
	//		sh!t when used with NSTreeController. http://www.cocoadev.com/index.pl?NSTreeControllerBugOrDeveloperError
	//		was the inspiration for this fix (below) but the author says that inserting does not work too well, but
	//		that's okay for us as we just need to replace the entire thing.
	[registerController setContent:nil];
	[registerController setContent:[[elm rootElement] children]];
	
	for (int i = 0; i < [registerView numberOfRows]; i++)
	{
		NSTreeNode *node = [registerView itemAtRow:i];
		if ([expandedRegisters containsObject:[[node representedObject] fullname]])
		{
			[registerView expandItem:node];
		}
	}
}

/**
 * Forwards the message to run script execution to the connection
 */
- (IBAction)run:(id)sender
{
	[connection run];
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
	StackFrame *frame = [connection stepIn];
	if ([frame isShiftedFrame:[stackController peek]])
		[stackController pop];
	[stackController push:frame];
	[self updateStackViewer];
}

/**
* Forwards the message to "step out" to the connection
 */
- (IBAction)stepOut:(id)sender
{
	StackFrame *frame = [connection stepOut];
	[stackController pop]; // frame we were out of
	[stackController pop]; // frame we are returning to
	[stackController push:frame];
	[self updateStackViewer];
}

/**
* Forwards the message to "step over" to the connection
 */
- (IBAction)stepOver:(id)sender
{
	StackFrame *frame = [connection stepOver];
	[stackController pop];
	[stackController push:frame];
	[self updateStackViewer];
}

/**
 * NSTableView delegate method that informs the controller that the stack selection did change and that
 * we should update the source viewer
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notif
{
	[self updateSourceViewer];
}

/**
 * Called whenver an item is expanded. This allows us to determine if we need to fetch deeper
 */
- (void)outlineViewItemDidExpand:(NSNotification *)notif
{
	NSTreeNode *node = [[notif userInfo] objectForKey:@"NSObject"];
	[expandedRegisters addObject:[[node representedObject] fullname]];
}

/**
 * Called when an item was collapsed. This allows us to remove it from the list of expanded items
 */
- (void)outlineViewItemDidCollapse:(NSNotification *)notif
{
	[expandedRegisters removeObject:[[[[notif userInfo] objectForKey:@"NSObject"] representedObject] fullname]];
}

#pragma mark Private

/**
 * Does the actual updating of the source viewer by reading in the file
 */
- (void)updateSourceViewer
{
	id selection = [stackArrayController selection];
	if ([selection valueForKey:@"filename"] == NSNoSelectionMarker)
	{
		[[sourceViewer textView] setString:@""];
		return;
	}
	
	// get the filename and then set the text
	NSString *filename = [selection valueForKey:@"filename"];
	filename = [[NSURL URLWithString:filename] path];
	if ([filename isEqualToString:@""])
	{
		return;
	}
	
	[sourceViewer setFile:filename];
	
	int line = [[selection valueForKey:@"lineNumber"] intValue];
	[sourceViewer setMarkedLine:line];
	[sourceViewer scrollToLine:line];
	
	// make sure the font stays Monaco
	//[sourceViewer setFont:[NSFont fontWithName:@"Monaco" size:10.0]];
}

/**
 * Does some house keeping to the stack viewer
 */
- (void)updateStackViewer
{
	[stackArrayController rearrangeObjects];
	[stackArrayController setSelectionIndex:0];
}

#pragma mark BSSourceView Delegate

/**
 * The gutter was clicked, which indicates that a breakpoint needs to be changed
 */
- (void)gutterClickedAtLine:(int)line forFile:(NSString *)file
{
	BreakpointManager *mngr = [BreakpointManager sharedManager];
	
	if ([mngr hasBreakpointAt:line inFile:file])
	{
		[mngr removeBreakpointAt:line inFile:file];
	}
	else
	{
		Breakpoint *bp = [[Breakpoint alloc] initWithLine:line inFile:file];
		[mngr addBreakpoint:bp];
		[bp release];
	}
	
	[[sourceViewer numberView] setMarkers:[NSSet setWithArray:[mngr breakpointsForFile:file]]];
	[[sourceViewer numberView] setNeedsDisplay:YES];
}

@end

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

#import "DebuggerWindowController.h"
#import "DebuggerConnection.h"
#import "NSXMLElementAdditions.h"
#import "AppDelegate.h"
#import "BreakpointManager.h"

@interface DebuggerWindowController (Private)

- (void)updateSourceViewer;

@end

@implementation DebuggerWindowController

@synthesize connection;

/**
 * Initializes the window controller and sets the connection
 */
- (id)initWithPort:(int)aPort session:(NSString *)aSession
{
	if (self = [super initWithWindowNibName:@"Debugger"])
	{
		connection = [[DebuggerConnection alloc] initWithWindowController:self port:aPort session:aSession];
		expandedRegisters = [[NSMutableSet alloc] init];
		[[self window] makeKeyAndOrderFront:nil];
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
	[super dealloc];
}

/**
 * Before the display get's comfortable, set up the NSTextView to scroll horizontally
 */
- (void)awakeFromNib
{
	[self setStatus:@"Connecting"];
	[[self window] setExcludedFromWindowsMenu:YES];
	[sourceViewer setDelegate:self];
}

/**
 * Called right before the window closes so that we can tell the socket to close down
 */
- (void)windowWillClose:(NSNotification *)notif
{
	[[connection socket] close];
}

/**
 * Resets all the displays to be empty
 */
- (void)resetDisplays
{
	[registerController setContent:nil];
	[stackController setContent:nil];
	[[sourceViewer textView] setString:@""];
}

/**
 * Sets the status and clears any error message
 */
- (void)setStatus:(NSString *)aStatus
{
	[errormsg setHidden:YES];
	[statusmsg setStringValue:aStatus];
	[[self window] setTitle:[NSString stringWithFormat:@"GDBp @ %@:%d/%@", [connection remoteHost], [connection port], [connection session]]];
	
	[stepInButton setEnabled:NO];
	[stepOutButton setEnabled:NO];
	[stepOverButton setEnabled:NO];
	[runButton setEnabled:NO];
	[reconnectButton setEnabled:NO];
	
	if ([connection isConnected])
	{
		if ([aStatus isEqualToString:@"Starting"])
		{
			[stepInButton setEnabled:YES];
			[runButton setEnabled:YES];
		}
	}
	else
	{
		[reconnectButton setEnabled:YES];
	}
}

/**
 * Sets the status to be "Error" and then displays the error message
 */
- (void)setError:(NSString *)anError
{
	[errormsg setStringValue:anError];
	[self setStatus:@"Error"];
	[errormsg setHidden:NO];
}

/**
 * Sets the root node element of the stacktrace
 */
- (void)setStack:(NSArray *)node
{
	stack = node;
	
	if ([stack count] > 1)
	{
		[stepOutButton setEnabled:YES];
	}
	[stepInButton setEnabled:YES];
	[stepOverButton setEnabled:YES];
	[runButton setEnabled:YES];
	
	[self updateSourceViewer];
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
}

/**
 * Forwards the message to "step in" to the connection
 */
- (IBAction)stepIn:(id)sender
{
	[connection stepIn];
}

/**
* Forwards the message to "step out" to the connection
 */
- (IBAction)stepOut:(id)sender
{
	[connection stepOut];
}

/**
* Forwards the message to "step over" to the connection
 */
- (IBAction)stepOver:(id)sender
{
	[connection stepOver];
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
 * Does the actual updating of the source viewer by reading in the file
 */
- (void)updateSourceViewer
{
	id selectedLevel = [[stackController selection] valueForKey:@"level"];
	if (selectedLevel == NSNoSelectionMarker)
	{
		[[sourceViewer textView] setString:@""];
		return;
	}
	int selection = [selectedLevel intValue];
	
	if ([stack count] < 1)
	{
		NSLog(@"huh... we don't have a stack");
		return;
	}
	
	// get the filename and then set the text
	NSString *filename = [[stack objectAtIndex:selection] valueForKey:@"filename"];
	filename = [[NSURL URLWithString:filename] path];
	if ([filename isEqualToString:@""])
	{
		return;
	}
	
	[sourceViewer setFile:filename];
	
	int line = [[[stack objectAtIndex:selection] valueForKey:@"lineno"] intValue];
	[sourceViewer setMarkedLine:line];
	[sourceViewer scrollToLine:line];
	
	// make sure the font stays Monaco
	//[sourceViewer setFont:[NSFont fontWithName:@"Monaco" size:10.0]];
}

/**
 * Called whenver an item is expanded. This allows us to determine if we need to fetch deeper
 */
- (void)outlineViewItemDidExpand:(NSNotification *)notif
{
	NSTreeNode *node = [[notif userInfo] objectForKey:@"NSObject"];
	
	// we're not a leaf but have no children. this must be beyond our depth, so go make us deeper
	if (![node isLeaf] && [[node childNodes] count] < 1)
	{
		[connection getProperty:[[node representedObject] fullname] forNode:node];
	}
	
	[expandedRegisters addObject:[[node representedObject] fullname]];
}

/**
 * Called when an item was collapsed. This allows us to remove it from the list of expanded items
 */
- (void)outlineViewItemDidCollapse:(NSNotification *)notif
{
	[expandedRegisters removeObject:[[[[notif userInfo] objectForKey:@"NSObject"] representedObject] fullname]];
}

/**
 * Updates the register view by reinserting a given node back into the outline view
 */
- (void)addChildren:(NSArray *)children toNode:(NSTreeNode *)node
{
	NSXMLElement *parent = [node representedObject];
	for (NSXMLNode *child in children)
	{
		[parent addChild:child];
	}
	
	[registerController rearrangeObjects];
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
		[connection removeBreakpoint:[mngr removeBreakpointAt:line inFile:file]];
	}
	else
	{
		Breakpoint *bp = [[Breakpoint alloc] initWithLine:line inFile:file];
		[mngr addBreakpoint:bp];
		[connection addBreakpoint:bp];
	}
	
	[[sourceViewer numberView] setMarkers:[mngr breakpointsForFile:file]];
	[[sourceViewer numberView] setNeedsDisplay:YES];
}

@end

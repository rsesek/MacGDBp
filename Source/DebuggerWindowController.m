/*
 * MacGDBp
 * Copyright (c) 2002 - 2007, Blue Static <http://www.bluestatic.org>
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

@interface DebuggerWindowController (Private)

- (void)updateSourceViewer;

@end

@implementation DebuggerWindowController

/**
 * Initializes the window controller and sets the connection
 */
- (id)initWithConnection:(DebuggerConnection *)cnx
{
	if (self = [super initWithWindowNibName:@"Debugger"])
	{
		connection = cnx;
		expandedRegisters = [[NSMutableArray alloc] init];
	}
	return self;
}

/**
 * Before the display get's comfortable, set up the NSTextView to scroll horizontally
 */
- (void)awakeFromNib
{
	// set up the scroller for the source viewer
	[sourceViewer setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
	[[sourceViewer textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
	[[sourceViewer textContainer] setWidthTracksTextView:NO];
	[sourceViewer setHorizontallyResizable:YES];
	[sourceViewerScroller setHasHorizontalScroller:YES];
	[sourceViewerScroller display];
}

/**
 * Called when the window is going to be closed so we can clean up all of our stuff
 */
- (void)windowWillClose:(NSNotification *)aNotification
{
	[connection windowDidClose];
}

/**
 * Release object members
 */
- (void)dealloc
{
	[expandedRegisters release];
	
	[super dealloc];
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
	if (stack != nil)
	{
		[stack release];
	}
	
	stack = node;
	[stack retain];
	
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
	/*
	[_registerController willChangeValueForKey:@"rootElement.children"];
	[_registerController unbind:@"contentArray"];
	[_registerController bind:@"contentArray" toObject:elm withKeyPath:@"rootElement.children" options:nil];
	[_registerController didChangeValueForKey:@"rootElement.children"];
	*/
	// XXX: Doing anything short of this will cause bindings to crash spectacularly for no reason whatsoever, and
	//		in seemingly arbitrary places. The class that crashes is _NSKeyValueObservationInfoCreateByRemoving.
	//		http://boredzo.org/blog/archives/2006-01-29/have-you-seen-this-crash says that this means nothing is
	//		being observed, but I doubt that he was using an NSOutlineView which seems to be one f!cking piece of
	//		sh!t when used with NSTreeController. http://www.cocoadev.com/index.pl?NSTreeControllerBugOrDeveloperError
	//		was the inspiration for this fix (below) but the author says that inserting does not work too well, but
	//		that's okay for us as we just need to replace the entire thing.
	[registerController setContent:nil];
	[registerController setContent:[[elm rootElement] children]];
	
	/*for (NSTreeNode *node in expandedRegisters)
	{
		[registerView expandItem:node];
	}*/
	NSLog(@"expanded items = %@", expandedRegisters);
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
	int selection = [stackController selectionIndex];
	if (selection == NSNotFound)
	{
		[sourceViewer setString:@""];
		return;
	}
	
	// get the filename and then set the text
	NSString *filename = [[stack objectAtIndex:selection] valueForKey:@"filename"];
	filename = [[NSURL URLWithString:filename] path];
	NSString *text = [NSString stringWithContentsOfFile:filename];
	[sourceViewer setString:text];
	
	// go through the document until we find the NSRange for the line we want
	int destination = [[[stack objectAtIndex:selection] valueForKey:@"lineno"] intValue];
	int rangeIndex = 0;
	for (int line = 0; line < destination; line++)
	{
		rangeIndex = NSMaxRange([text lineRangeForRange:NSMakeRange(rangeIndex, 0)]);
	}
	
	// now get the true start/end markers for it
	unsigned lineStart, lineEnd;
	[text getLineStart:&lineStart end:NULL contentsEnd:&lineEnd forRange:NSMakeRange(rangeIndex - 1, 0)];
	NSRange lineRange = NSMakeRange(lineStart, lineEnd - lineStart);
	
	// colorize it so the user knows which line we're on in the stack
	[[sourceViewer textStorage] setAttributes:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSColor redColor], [NSColor yellowColor], nil]
																			 forKeys:[NSArray arrayWithObjects:NSForegroundColorAttributeName, NSBackgroundColorAttributeName, nil]]
										 range:lineRange];
	[sourceViewer scrollRangeToVisible:[text lineRangeForRange:NSMakeRange(lineStart, lineEnd - lineStart)]];
	
	// make sure the font stays Monaco
	[sourceViewer setFont:[NSFont fontWithName:@"Monaco" size:10.0]];
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
		[connection getProperty:[[[node representedObject] attributeForName:@"fullname"] stringValue] forNode:node];
	}
	
	[expandedRegisters addObject:[[node representedObject] variable]];
}

/**
 * Called when an item was collapsed. This allows us to remove it from the list of expanded items
 */
- (void)outlineViewItemDidCollapse:(NSNotification *)notif
{
	[expandedRegisters removeObject:[[[[notif userInfo] objectForKey:@"NSObject"] representedObject] variable]];
}

/**
 * Updates the register view by reinserting a given node back into the outline view
 */
- (void)addChildren:(NSArray *)children toNode:(NSTreeNode *)node
{
	NSIndexPath *masterPath = [node indexPath];
	for (int i = 0; i < [children count]; i++)
	{
		[registerController insertObject:[children objectAtIndex:i] atArrangedObjectIndexPath:[masterPath indexPathByAddingIndex:i]];
	}
	
	[registerController rearrangeObjects];
}

@end

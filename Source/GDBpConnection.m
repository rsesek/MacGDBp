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

#import "GDBpConnection.h"
#import "AppDelegate.h"

NSString *kErrorOccurredNotif = @"GDBpConnection_ErrorOccured_Notification";

@interface GDBpConnection()
@property(readwrite, copy) NSString *status;

- (NSString *)createCommand:(NSString *)cmd;
- (NSXMLDocument *)processData:(NSString *)data;
- (StackFrame *)createStackFrame;
- (void)updateStatus;
@end

@implementation GDBpConnection

@synthesize socket, windowController, status;

/**
 * Creates a new DebuggerConnection and initializes the socket from the given connection
 * paramters.
 */
- (id)initWithWindowController:(DebuggerController *)wc port:(int)aPort session:(NSString *)aSession;
{
	if (self = [super init])
	{
		port = aPort;
		session = [aSession retain];
		connected = NO;
		
		windowController = [wc retain];
		
		// now that we have our host information, open the socket
		socket = [[SocketWrapper alloc] initWithConnection:self];
		[socket setDelegate:self];
		[socket connect];
		
		[[BreakpointManager sharedManager] setConnection:self];
	}
	return self;
}

/**
 * Deallocates the object
 */
- (void)dealloc
{
	[socket release];
	[session release];
	[windowController release];
	[super dealloc];
}

/**
 * Gets the port number
 */
- (int)port
{
	return port;
}

/**
 * Gets the session name
 */
- (NSString *)session
{
	return session;
}

/**
 * Returns the name of the remote host
 */
- (NSString *)remoteHost
{
	if (!connected)
	{
		return @"(DISCONNECTED)";
	}
	return [socket remoteHost];
}

/**
 * Returns whether or not we have an active connection
 */
- (BOOL)isConnected
{
	return connected;
}

/**
 * Called by SocketWrapper after the connection is successful. This immediately calls
 * -[SocketWrapper receive] to clear the way for communication, though the information
 * could be useful server information that we don't use right now.
 */
- (void)socketDidAccept:(id)obj
{
	connected = YES;
	[socket receive];
	[self refreshStatus];
	
	// register any breakpoints that exist offline
	for (Breakpoint *bp in [[BreakpointManager sharedManager] breakpoints])
	{
		[self addBreakpoint:bp];
	}
}

/**
 * Receives errors from the SocketWrapper and updates the display
 */
- (void)errorEncountered:(NSString *)error
{
	[[NSNotificationCenter defaultCenter]
		postNotificationName:kErrorOccurredNotif
		object:self
		userInfo:[NSDictionary
			dictionaryWithObject:error
			forKey:@"NSString"
		]
	];
}

/**
 * Reestablishes communication with the remote debugger so that a new connection doesn't have to be
 * created every time you want to debug a page
 */
- (void)reconnect
{
	[socket close];
	self.status = @"Connecting";
	[windowController resetDisplays];
	[socket connect];
}

/**
 * Tells the debugger to continue running the script
 */
- (void)run
{
	[socket send:[self createCommand:@"run"]];
	[socket receive];
	[self updateStatus];
}

/**
 * Tells the debugger to step into the current command.
 */
- (StackFrame *)stepIn
{
	[socket send:[self createCommand:@"step_into"]];
	[socket receive];
	
	StackFrame *frame = [self createStackFrame];
	[self updateStatus];
	
	return frame;
}

/**
 * Tells the debugger to step out of the current context
 */
- (StackFrame *)stepOut
{
	[socket send:[self createCommand:@"step_out"]];
	[socket receive];
	
	StackFrame *frame = [self createStackFrame];
	[self updateStatus];
	
	return frame;
}

/**
 * Tells the debugger to step over the current function
 */
- (StackFrame *)stepOver
{
	[socket send:[self createCommand:@"step_over"]];
	[socket receive];
	
	StackFrame *frame = [self createStackFrame];
	[self updateStatus];
	
	return frame;
}

/**
 * Tells the debugger engine to get a specifc property. This also takes in the NSXMLElement
 * that requested it so that the child can be attached.
 */
- (NSArray *)getProperty:(NSString *)property
{
	[socket send:[self createCommand:[NSString stringWithFormat:@"property_get -n \"%@\"", property]]];
	
	NSXMLDocument *doc = [self processData:[socket receive]];
	
	/*
	 <response>
		<property> <!-- this is the one we requested -->
			<property ... /> <!-- these are what we want -->
		</property>
	 </repsonse>
	 */
	
	// we now have to detach all the children so we can insert them into another document
	NSXMLElement *parent = (NSXMLElement *)[[doc rootElement] childAtIndex:0];
	NSArray *children = [parent children];
	[parent setChildren:nil];
	return children;
}

#pragma mark Breakpoints

/**
 * Send an add breakpoint command
 */
- (void)addBreakpoint:(Breakpoint *)bp
{
	if (!connected)
	{
		return;
	}
	
	NSString *cmd = [self createCommand:[NSString stringWithFormat:@"breakpoint_set -t line -f %@ -n %i", [bp file], [bp line]]];
	[socket send:cmd];
	NSXMLDocument *info = [self processData:[socket receive]];
	[bp setDebuggerId:[[[[info rootElement] attributeForName:@"id"] stringValue] intValue]];
}

/**
 * Removes a breakpoint
 */
- (void)removeBreakpoint:(Breakpoint *)bp
{
	if (!connected)
	{
		return;
	}
	
	[socket send:[self createCommand:[NSString stringWithFormat:@"breakpoint_remove -d %i", [bp debuggerId]]]];
	[socket receive];
}

#pragma mark Private

/**
 * Helper method to create a string command with the -i <session> automatically tacked on
 */
- (NSString *)createCommand:(NSString *)cmd
{
	return [NSString stringWithFormat:@"%@ -i %@", cmd, session];
}

/**
 * Helper function to parse the NSData into an NSXMLDocument
 */
- (NSXMLDocument *)processData:(NSString *)data
{
	NSError *parseError = nil;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:data options:0 error:&parseError];
	if (parseError)
	{
		NSLog(@"Could not parse XML? --- %@", parseError);
		NSLog(@"Error UserInfo: %@", [parseError userInfo]);
		NSLog(@"This is the XML Document: %@", data);
		return nil;
	}
	
	// check and see if there's an error
	NSArray *error = [[doc rootElement] elementsForName:@"error"];
	if ([error count] > 0)
	{
		[self errorEncountered:[[[[error objectAtIndex:0] children] objectAtIndex:0] stringValue]];
		return nil;
	}
	
	return [doc autorelease];
}

/**
 * Creates a StackFrame based on the current position in the debugger
 */
- (StackFrame *)createStackFrame
{
	// get the stack frame
	[socket send:[self createCommand:@"stack_get -d 0"]];
	NSXMLDocument *doc = [self processData:[socket receive]];
	
	// get the names of all the contexts
	[socket send:[self createCommand:@"context_names -d 0"]];
	NSXMLElement *contextNames = [[self processData:[socket receive]] rootElement];
	NSMutableDictionary *contexts = [NSMutableDictionary dictionary];
	for (NSXMLElement *context in [contextNames children])
	{
		NSString *name = [[context attributeForName:@"name"] stringValue];
		int cid = [[[context attributeForName:@"id"] stringValue] intValue];
		
		// fetch the contexts
		[socket send:[self createCommand:[NSString stringWithFormat:@"context_get -d 0 -c %d", cid]]];
		NSArray *variables = [[[self processData:[socket receive]] rootElement] children];
		if (variables != nil && name != nil)
			[contexts setObject:variables forKey:name];
	}
	
	NSXMLElement *xmlframe = [[[doc rootElement] children] objectAtIndex:0];
	StackFrame *frame = [[StackFrame alloc]
		initWithIndex:0
		withFilename:[[xmlframe attributeForName:@"filename"] stringValue]
		withSource:nil
		atLine:[[[xmlframe attributeForName:@"lineno"] stringValue] intValue]
		inFunction:[[xmlframe attributeForName:@"where"] stringValue]
		withContexts:contexts
	];
	
	return [frame autorelease];
}

/**
 * Fetches the value of and sets the status instance variable
 */
- (void)updateStatus
{
	[socket send:[self createCommand:@"status"]];
	NSXMLDocument *doc = [self processData:[socket receive]];
	self.status = [[[[doc rootElement] attributeForName:@"status"] stringValue] capitalizedString];
	
	if ([status isEqualToString:@"Stopped"] || [status isEqualToString:@"Stopping"])
	{
		connected = NO;
		[socket close];
		self.status = @"Stopped";
	}
}

@end

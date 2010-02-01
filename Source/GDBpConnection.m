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

#import "GDBpConnection.h"
#import "AppDelegate.h"

@interface GDBpConnection()
@property(readwrite, copy) NSString* status;

- (NSString*)createCommand:(NSString*)cmd, ...;
- (NSXMLDocument*)processData:(NSString*)data;
- (StackFrame*)createStackFrame:(int)depth;
- (StackFrame*)createCurrentStackFrame;
- (void)updateStatus;
- (NSString*)escapedURIPath:(NSString*)path;
- (void)doSocketAccept:_nil;
@end

@implementation GDBpConnection
@synthesize socket;
@synthesize status;
@synthesize delegate;

/**
 * Creates a new DebuggerConnection and initializes the socket from the given connection
 * paramters.
 */
- (id)initWithPort:(int)aPort
{
	if (self = [super init])
	{
		port = aPort;
		connected = NO;
		
		// now that we have our host information, open the socket
		socket = [[SocketWrapper alloc] initWithPort:port];
		socket.delegate = self;
		[socket connect];
		
		self.status = @"Connecting";
		
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
 * Returns the name of the remote host
 */
- (NSString*)remoteHost
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
- (void)socketDidAccept
{
	[self performSelectorOnMainThread:@selector(doSocketAccept:) withObject:nil waitUntilDone:YES];
}

/**
 * Receives errors from the SocketWrapper and updates the display
 */
- (void)errorEncountered:(NSString*)error
{
	[delegate errorEncountered:error];
}

/**
 * Reestablishes communication with the remote debugger so that a new connection doesn't have to be
 * created every time you want to debug a page
 */
- (void)reconnect
{
	[socket close];
	self.status = @"Connecting";
	[socket connect];
}

/**
 * Creates an entirely new stack and returns it as an array of StackFrame objects.
 */
- (NSArray*)getCurrentStack
{
	// get the total stack depth
	[socket send:[self createCommand:@"stack_depth"]];
	NSXMLDocument* doc = [self processData:[socket receive]];
	int depth = [[[[doc rootElement] attributeForName:@"depth"] stringValue] intValue];
	
	// get all stack frames
	NSMutableArray* stack = [NSMutableArray arrayWithCapacity:depth];
	for (int i = 0; i < depth; i++)
	{
		StackFrame* frame = [self createStackFrame:i];
		[stack insertObject:frame atIndex:i];
	}
	
	return stack;
}

/**
 * Tells the debugger to continue running the script. Returns the current stack frame.
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
- (void)stepIn
{
	[socket send:[self createCommand:@"step_into"]];
	[socket receive];
	
	[self updateStatus];
}

/**
 * Tells the debugger to step out of the current context
 */
- (void)stepOut
{
	[socket send:[self createCommand:@"step_out"]];
	[socket receive];
	
	[self updateStatus];
}

/**
 * Tells the debugger to step over the current function
 */
- (void)stepOver
{
	[socket send:[self createCommand:@"step_over"]];
	[socket receive];
	
	[self updateStatus];
}

/**
 * Tells the debugger engine to get a specifc property. This also takes in the NSXMLElement
 * that requested it so that the child can be attached.
 */
- (NSArray*)getProperty:(NSString*)property
{
	[socket send:[self createCommand:[NSString stringWithFormat:@"property_get -n \"%@\"", property]]];
	
	NSXMLDocument* doc = [self processData:[socket receive]];
	
	/*
	 <response>
		<property> <!-- this is the one we requested -->
			<property ... /> <!-- these are what we want -->
		</property>
	 </repsonse>
	 */
	
	// we now have to detach all the children so we can insert them into another document
	NSXMLElement* parent = (NSXMLElement*)[[doc rootElement] childAtIndex:0];
	NSArray* children = [parent children];
	[parent setChildren:nil];
	return children;
}

#pragma mark Breakpoints

/**
 * Send an add breakpoint command
 */
- (void)addBreakpoint:(Breakpoint*)bp
{
	if (!connected)
		return;
	
	NSString* file = [self escapedURIPath:[bp transformedPath]];
	NSString* cmd = [self createCommand:[NSString stringWithFormat:@"breakpoint_set -t line -f %@ -n %i", file, [bp line]]];
	[socket send:cmd];
	NSXMLDocument* info = [self processData:[socket receive]];
	[bp setDebuggerId:[[[[info rootElement] attributeForName:@"id"] stringValue] intValue]];
}

/**
 * Removes a breakpoint
 */
- (void)removeBreakpoint:(Breakpoint*)bp
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
 * Helper method to create a string command with the -i <transaction id> automatically tacked on. Takes
 * a variable number of arguments and parses the given command with +[NSString stringWithFormat:]
 */
- (NSString*)createCommand:(NSString*)cmd, ...
{
	// collect varargs
	va_list	argList;
	va_start(argList, cmd);
	NSString* format = [[NSString alloc] initWithFormat:cmd arguments:argList]; // format the command
	va_end(argList);
	
	if ([[[[NSProcessInfo processInfo] environment] objectForKey:@"TransportDebug"] boolValue])
		NSLog(@"--> %@", cmd);
	
	return [NSString stringWithFormat:@"%@ -i %d", [format autorelease], transactionID++];
}

/**
 * Helper function to parse the NSData into an NSXMLDocument
 */
- (NSXMLDocument*)processData:(NSString*)data
{
	if (data == nil)
		return nil;
	
	NSError* parseError = nil;
	NSXMLDocument* doc = [[NSXMLDocument alloc] initWithXMLString:data options:0 error:&parseError];
	if (parseError)
	{
		NSLog(@"Could not parse XML? --- %@", parseError);
		NSLog(@"Error UserInfo: %@", [parseError userInfo]);
		NSLog(@"This is the XML Document: %@", data);
		return nil;
	}
	
	// check and see if there's an error
	NSArray* error = [[doc rootElement] elementsForName:@"error"];
	if ([error count] > 0)
	{
		NSLog(@"Xdebug error: %@", error);
		[delegate errorEncountered:[[[[error objectAtIndex:0] children] objectAtIndex:0] stringValue]];
		return nil;
	}
	
	if ([[[[NSProcessInfo processInfo] environment] objectForKey:@"TransportDebug"] boolValue])
		NSLog(@"<-- %@", doc);
	
	return [doc autorelease];
}

/**
 * Generates a stack frame for the given depth
 */
- (StackFrame*)createStackFrame:(int)stackDepth
{
	// get the stack frame
	[socket send:[self createCommand:@"stack_get -d %d", stackDepth]];
	NSXMLDocument* doc = [self processData:[socket receive]];
	if (doc == nil)
		return nil;
	
	NSXMLElement* xmlframe = [[[doc rootElement] children] objectAtIndex:0];
	
	// get the names of all the contexts
	[socket send:[self createCommand:@"context_names -d 0"]];
	NSXMLElement* contextNames = [[self processData:[socket receive]] rootElement];
	NSMutableArray* variables = [NSMutableArray array];
	for (NSXMLElement* context in [contextNames children])
	{
		NSString* name = [[context attributeForName:@"name"] stringValue];
		int cid = [[[context attributeForName:@"id"] stringValue] intValue];
		
		// fetch the contexts
		[socket send:[self createCommand:[NSString stringWithFormat:@"context_get -d %d -c %d", stackDepth, cid]]];
		NSArray* addVars = [[[self processData:[socket receive]] rootElement] children];
		if (addVars != nil && name != nil)
			[variables addObjectsFromArray:addVars];
	}
	
	// get the source
	NSString* filename = [[xmlframe attributeForName:@"filename"] stringValue];
	NSString* escapedFilename = [filename stringByReplacingOccurrencesOfString:@"%" withString:@"%%"]; // escape % in URL chars
	[socket send:[self createCommand:[NSString stringWithFormat:@"source -f %@", escapedFilename]]];
	NSString* source = [[[self processData:[socket receive]] rootElement] value]; // decode base64
	
	// create stack frame
	StackFrame* frame = [[StackFrame alloc]
		initWithIndex:stackDepth
		withFilename:filename
		withSource:source
		atLine:[[[xmlframe attributeForName:@"lineno"] stringValue] intValue]
		inFunction:[[xmlframe attributeForName:@"where"] stringValue]
		withVariables:variables
	];
	
	return [frame autorelease];
}

/**
 * Creates a StackFrame based on the current position in the debugger
 */
- (StackFrame*)createCurrentStackFrame
{
	return [self createStackFrame:0];
}

/**
 * Fetches the value of and sets the status instance variable
 */
- (void)updateStatus
{
	[socket send:[self createCommand:@"status"]];
	NSXMLDocument* doc = [self processData:[socket receive]];
	self.status = [[[[doc rootElement] attributeForName:@"status"] stringValue] capitalizedString];
	
	if (status == nil || [status isEqualToString:@"Stopped"] || [status isEqualToString:@"Stopping"])
	{
		connected = NO;
		[socket close];
		
		[delegate debuggerDisconnected];
		
		self.status = @"Stopped";
	}
}

/**
 * Given a file path, this returns a file:// URI and escapes any spaces for the
 * debugger engine.
 */
- (NSString*)escapedURIPath:(NSString*)path
{
	// Custon GDBp paths are fine.
	if ([[path substringToIndex:4] isEqualToString:@"gdbp"])
		return path;
	
	// Create a temporary URL that will escape all the nasty characters.
	NSURL* url = [NSURL fileURLWithPath:path];
	NSString* urlString = [url absoluteString];
	
	// Remove the host because this is a file:// URL;
	urlString = [urlString stringByReplacingOccurrencesOfString:[url host] withString:@""];
	
	// Escape % for use in printf-style NSString formatters.
	urlString = [urlString stringByReplacingOccurrencesOfString:@"%" withString:@"%%"];
	return urlString;
}

/**
 * Helper method for |-socketDidAccept| to be called on the main thread.
 */
- (void)doSocketAccept:_nil
{
	connected = YES;
	transactionID = 0;
	[socket receive];
	[self updateStatus];
	
	// register any breakpoints that exist offline
	for (Breakpoint* bp in [[BreakpointManager sharedManager] breakpoints])
	{
		[self addBreakpoint:bp];
	}
	
	// Load the debugger to make it look active.
	[delegate debuggerConnected];
}

@end

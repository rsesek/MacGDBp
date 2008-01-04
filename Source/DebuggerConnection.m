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

#import "DebuggerConnection.h"
#import "AppDelegate.h"

@interface DebuggerConnection (Private)

- (NSString *)createCommand:(NSString *)cmd;

@end

@implementation DebuggerConnection

/**
 * Creates a new DebuggerConnection and initializes the socket from the given connection
 * paramters.
 */
- (id)initWithPort:(int)aPort session:(NSString *)aSession
{
	if (self = [super init])
	{
		port = aPort;
		session = [aSession retain];
		connected = NO;
		
		windowController = [[DebuggerWindowController alloc] initWithConnection:self];
		[[windowController window] makeKeyAndOrderFront:self];
		
		// now that we have our host information, open the socket
		socket = [[SocketWrapper alloc] initWithPort:port];
		[socket setDelegate:self];
		[windowController setStatus:@"Connecting"];
		[socket connect];
	}
	return self;
}

/**
 * This is a forwarded message from DebuggerWindowController that tells the connection to prepare to
 * close
 */
- (void)windowDidClose
{
	[[NSApp delegate] unregisterConnection:self];
}

/**
 * Releases all of the object's data members and closes the streams
 */
- (void)dealloc
{
	[session release];
	[socket release];
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
 * SocketWrapper delegate method that is called whenever new data is received
 */
- (void)dataReceived:(NSData *)response deliverTo:(SEL)selector
{
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:response options:NSXMLDocumentTidyXML error:nil];
	
	// check and see if there's an error
	NSArray *error = [[doc rootElement] elementsForName:@"error"];
	if ([error count] > 0)
	{
		[windowController setError:[[[[error objectAtIndex:0] children] objectAtIndex:0] stringValue]];
		return;
	}
	
	// if the caller of [_socket receive:] specified a deliverTo, just forward the message to them
	if (selector != nil)
	{
		[self performSelector:selector withObject:doc];
	}
	
	[doc release];
}

/**
 * SocketWrapper delegate method that is called after data is sent. This really
 * isn't useful for much.
 */
- (void)dataSent:(NSString *)data
{}

/**
 * Called by SocketWrapper after the connection is successful. This immediately calls
 * -[SocketWrapper receive] to clear the way for communication
 */
- (void)socketDidAccept
{
	connected = YES;
	[socket receive:@selector(handshake:)];
}

/**
 * Receives errors from the SocketWrapper and updates the display
 */
- (void)errorEncountered:(NSError *)error
{
	[windowController setError:[error domain]];
}

/**
 * The initial packet handshake. This allows us to set things like the title of the window
 * and glean information about hte server we are debugging
 */
- (void)handshake:(NSXMLDocument *)doc
{
	[self refreshStatus];
}

/**
 * Handler used by dataReceived:deliverTo: for anytime the status command is issued. It sets
 * the window controller's status text
 */
- (void)updateStatus:(NSXMLDocument *)doc
{
	NSString *status = [[[doc rootElement] attributeForName:@"status"] stringValue];
	[windowController setStatus:[status capitalizedString]];
	
	if ([status isEqualToString:@"break"])
	{
		[self updateStackTraceAndRegisters];
	}
}

/**
 * Tells the debugger to continue running the script
 */
- (void)run
{
	[socket send:[self createCommand:@"run"]];
	[self refreshStatus];
}

/**
 * Method that runs tells the debugger to give us its status. This will call _updateStatus
 * and will update the status text on the window
 */
- (void)refreshStatus
{
	[socket send:[self createCommand:@"status"]];
	[socket receive:@selector(updateStatus:)];
}

/**
 * Tells the debugger to step into the current command.
 */
- (void)stepIn
{
	[socket send:[self createCommand:@"step_into"]];
	[socket receive:nil];
	[self refreshStatus];
}

/**
 * Tells the debugger to step out of the current context
 */
- (void)stepOut
{
	[socket send:[self createCommand:@"step_out"]];
	[socket receive:nil];
	[self refreshStatus];
}

/**
 * Tells the debugger to step over the current function
 */
- (void)stepOver
{
	[socket send:[self createCommand:@"step_over"]];
	[socket receive:nil];
	[self refreshStatus];
}

/**
 * This function queries the debug server for the current stacktrace and all the registers on
 * level one. If a user then tries to expand past level one... TOOD: HOLY CRAP WHAT DO WE DO PAST LEVEL 1?
 */
- (void)updateStackTraceAndRegisters
{
	[socket send:[self createCommand:@"stack_get"]];
	[socket receive:@selector(stackReceived:)];
	
	[socket send:[self createCommand:@"context_get"]];
	[socket receive:@selector(registerReceived:)];
}

/**
 * Called by the dataReceived delivery delegate. This updates the window controller's data
 * for the stack trace
 */
- (void)stackReceived:(NSXMLDocument *)doc
{
	NSArray *children = [[doc rootElement] children];
	NSMutableArray *stack = [NSMutableArray array];
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	for (int i = 0; i < [children count]; i++)
	{
		NSArray *attrs = [[children objectAtIndex:i] attributes];
		for (int j = 0; j < [attrs count]; j++)
		{
			[dict setValue:[[attrs objectAtIndex:j] stringValue] forKey:[[attrs objectAtIndex:j] name]];
		}
		[stack addObject:dict];
		dict = [NSMutableDictionary dictionary];
	}
	[windowController setStack:stack];
}

/**
 * Called when we have a new register to display
 */
- (void)registerReceived:(NSXMLDocument *)doc
{
	[windowController setRegister:doc];
}

/**
 * Tells the debugger engine to get a specifc property. This also takes in the NSXMLElement
 * that requested it so that the child can be attached in the delivery.
 */
- (void)getProperty:(NSString *)property forElement:(NSXMLElement *)elm
{
	[socket send:[self createCommand:[NSString stringWithFormat:@"property_get -n \"%@\"", property]]];
	depthFetchElement = elm;
	[socket receive:@selector(propertyReceived:)];
}

/**
 * Called when a property is received. This then adds the result as children to the passed object
 */
- (void)propertyReceived:(NSXMLDocument *)doc
{
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
	[windowController addChildren:children toNode:depthFetchElement];
	depthFetchElement = nil;
}

/**
 * Helper method to create a string command with the -i <session> automatically tacked on
 */
- (NSString *)createCommand:(NSString *)cmd
{
	return [NSString stringWithFormat:@"%@ -i %@", cmd, session];
}

@end

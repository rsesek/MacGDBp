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

#import "DebuggerConnection.h"
#import "AppDelegate.h"

@interface DebuggerConnection (Private)

- (NSString *)createCommand:(NSString *)cmd;
- (NSXMLDocument *)processData:(NSData *)data;

@end

@implementation DebuggerConnection

@synthesize socket, windowController;

/**
 * Creates a new DebuggerConnection and initializes the socket from the given connection
 * paramters.
 */
- (id)initWithWindowController:(DebuggerWindowController *)wc port:(int)aPort session:(NSString *)aSession;
{
	if (self = [super init])
	{
		port = aPort;
		session = aSession;
		connected = NO;
		
		windowController = wc;
		
		// now that we have our host information, open the socket
		socket = [[SocketWrapper alloc] initWithConnection:self];
		[socket setDelegate:self];
		[socket connect];
	}
	return self;
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
}

/**
 * Receives errors from the SocketWrapper and updates the display
 */
- (void)errorEncountered:(NSString *)error
{
	[windowController setError:error];
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
 * Method that runs tells the debugger to give us its status and will update the status text on the window
 */
- (void)refreshStatus
{
	[socket send:[self createCommand:@"status"]];
	
	NSXMLDocument *doc = [self processData:[socket receive]];
	NSString *status = [[[doc rootElement] attributeForName:@"status"] stringValue];
	[windowController setStatus:[status capitalizedString]];
	
	if ([status isEqualToString:@"break"])
	{
		[self updateStackTraceAndRegisters];
	}
}

/**
 * Tells the debugger to step into the current command.
 */
- (void)stepIn
{
	[socket send:[self createCommand:@"step_into"]];
	[socket receive];
	[self refreshStatus];
}

/**
 * Tells the debugger to step out of the current context
 */
- (void)stepOut
{
	[socket send:[self createCommand:@"step_out"]];
	[socket receive];
	[self refreshStatus];
}

/**
 * Tells the debugger to step over the current function
 */
- (void)stepOver
{
	[socket send:[self createCommand:@"step_over"]];
	[socket receive];
	[self refreshStatus];
}

/**
 * This function queries the debug server for the current stacktrace and all the registers on
 * level one. If a user then tries to expand past level one... TOOD: HOLY CRAP WHAT DO WE DO PAST LEVEL 1?
 */
- (void)updateStackTraceAndRegisters
{
	// do the stack
	[socket send:[self createCommand:@"stack_get"]];
	NSXMLDocument *doc = [self processData:[socket receive]];
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
	
	// do the registers
	[socket send:[self createCommand:@"context_get"]];
	[windowController setRegister:[self processData:[socket receive]]];
}

/**
 * Tells the debugger engine to get a specifc property. This also takes in the NSXMLElement
 * that requested it so that the child can be attached.
 */
- (void)getProperty:(NSString *)property forNode:(NSTreeNode *)node
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
	[windowController addChildren:children toNode:node];
}

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
- (NSXMLDocument *)processData:(NSData *)data
{
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:data options:NSXMLDocumentTidyXML error:nil];
	
	// check and see if there's an error
	NSArray *error = [[doc rootElement] elementsForName:@"error"];
	if ([error count] > 0)
	{
		[windowController setError:[[[[error objectAtIndex:0] children] objectAtIndex:0] stringValue]];
		return nil;
	}
	
	return doc;
}

@end

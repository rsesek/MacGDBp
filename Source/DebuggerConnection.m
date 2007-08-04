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

@implementation DebuggerConnection

/**
 * Creates a new DebuggerConnection and initializes the socket from the given connection
 * paramters.
 */
- (id)initWithPort: (int)port session: (NSString *)session
{
	if (self = [super init])
	{
		_port = port;
		_session = [session retain];
		_connected = NO;
		
		_windowController = [[DebuggerWindowController alloc] initWithConnection: self];
		[[_windowController window] makeKeyAndOrderFront: self];
		
		// now that we have our host information, open the socket
		_socket = [[SocketWrapper alloc] initWithPort: port];
		[_socket setDelegate: self];
		[_windowController setStatus: @"Connecting"];
		[_socket connect];
		
		// clean up after ourselves
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(applicationWillTerminate:)
													 name: NSApplicationWillTerminateNotification
												   object: NSApp];
	}
	return self;
}

/**
 * Release ourselves when we're about to die
 */
- (void)applicationWillTerminate: (NSNotification *)notif
{
	[self release];
}

/**
 * Releases all of the object's data members and closes the streams
 */
- (void)dealloc
{
	[_session release];
	[_socket release];
	
	[super dealloc];
}

/**
 * Gets the port number
 */
- (int)port
{
	return _port;
}

/**
 * Gets the session name
 */
- (NSString *)session
{
	return _session;
}

/**
 * Returns the name of the remote host
 */
- (NSString *)remoteHost
{
	if (!_connected)
	{
		return @"(DISCONNECTED)";
	}
	return [_socket remoteHost];
}

/**
 * SocketWrapper delegate method that is called whenever new data is received
 */
- (void)dataReceived: (NSString *)response deliverTo: (SEL)selector
{
	// if the caller of [_socket receive:] specified a deliverTo, just forward the message to them
	if (selector != nil)
	{
		[self performSelector: selector withObject: response];
	}
	NSLog(@"receive = %@", response);
}

/**
 * SocketWrapper delegate method that is called after data is sent. This really
 * isn't useful for much.
 */
- (void)dataSent: (NSString *)data
{
	NSLog(@"send = %@", data);
}

/**
 * Called by SocketWrapper after the connection is successful. This immediately calls
 * -[SocketWrapper receive] to clear the way for communication
 */
- (void)socketDidAccept
{
	_connected = YES;
	[_socket receive: @selector(_handshake:)];
}

/**
 * Receives errors from the SocketWrapper and updates the display
 */
- (void)errorEncountered: (NSError *)error
{
	[_windowController setError: [error domain]];
}

/**
 * The initial packet handshake. This allows us to set things like the title of the window
 * and glean information about hte server we are debugging
 */
- (void)_handshake: (NSString *)packet
{
	[self refreshStatus];
}

/**
 * Handler used by dataReceived:deliverTo: for anytime the status command is issued. It sets
 * the window controller's status text
 */
- (void)_updateStatus: (NSString *)packet
{
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString: packet options: NSXMLDocumentTidyXML error: nil];
	[_windowController setStatus: [[[[doc rootElement] attributeForName: @"status"] stringValue] capitalizedString]];
	[doc release];
}

/**
 * Tells the debugger to continue running the script
 */
- (void)run
{
	[_socket send: [self _createCommand: @"run"]];
	[self refreshStatus];
}

/**
 * Method that runs tells the debugger to give us its status. This will call _updateStatus
 * and will update the status text on the window
 */
- (void)refreshStatus
{
	[_socket send: [self _createCommand: @"status"]];
	[_socket receive: @selector(_updateStatus:)];
}

/**
 * Tells the debugger to step into the current command.
 */
// TODO: populate the stack trace and registers list
- (void)stepIn
{
	[_socket send: [self _createCommand: @"step_into"]];
	[_socket receive: nil];
	[self refreshStatus];
	[self updateStackTraceAndRegisters];
}

/**
 * This function queries the debug server for the current stacktrace and all the registers on
 * level one. If a user then tries to expand past level one... TOOD: HOLY CRAP WHAT DO WE DO PAST LEVEL 1?
 */
- (void)updateStackTraceAndRegisters
{
	[_socket send: [self _createCommand: @"stack_get"]];
	[_socket receive: @selector(_stackReceived:)];
}

/**
 * Called by the dataReceived delivery delegate. This updates the window controller's data
 * for the stack trace
 */
- (void)_stackReceived: (NSString *)packet
{
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString: packet options: NSXMLDocumentTidyXML error: nil];
	NSArray *children = [[doc rootElement] children];
	NSMutableArray *stack = [NSMutableArray array];
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	for (int i = 0; i < [children count]; i++)
	{
		NSArray *attrs = [[children objectAtIndex: i] attributes];
		for (int j = 0; j < [attrs count]; j++)
		{
			[dict setValue: [[attrs objectAtIndex: j] stringValue] forKey: [[attrs objectAtIndex: j] name]];
		}
		[stack addObject: dict];
		dict = [NSMutableDictionary dictionary];
	}
	[_windowController setStack: stack];
}

/**
 * Helper method to create a string command with the -i <session> automatically tacked on
 */
- (NSString *)_createCommand: (NSString *)cmd
{
	return [NSString stringWithFormat: @"%@ -i %@", cmd, _session];
}

@end

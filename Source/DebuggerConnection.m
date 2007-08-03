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
		
		_windowController = [[DebuggerWindowController alloc] initWithConnection: self];
		[[_windowController window] makeKeyAndOrderFront: self];
		
		// now that we have our host information, open the socket
		_socket = [[SocketWrapper alloc] initWithPort: port];
		[_socket setDelegate: self];
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
 * SocketWrapper delegate method that is called whenever new data is received
 */
- (void)dataReceived: (NSString *)response
{
	NSLog(@"response = %@", response);
}

/**
 * SocketWrapper delegate method that is called after data is sent. This really
 * isn't useful for much.
 */
- (void)dataSent
{
	NSLog(@"data sent");
}

/**
 * Called by SocketWrapper after the connection is successful. This immediately calls
 * -[SocketWrapper receive] to clear the way for communication
 */
- (void)socketDidAccept
{
	NSLog(@"accepted connection");
	[_socket receive];
}

/**
 * Receives errors from the SocketWrapper and updates the display
 */
- (void)errorEncountered: (NSError *)error
{
	NSLog(@"error = %@", error);
}

@end

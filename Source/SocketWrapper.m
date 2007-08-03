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

#import "SocketWrapper.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

NSString *sockNotificationDebuggerConnection = @"DebuggerConnection";
NSString *sockNotificationReceiver = @"SEL-del-SocketWrapper_dataReceived";
NSString *NsockError = @"SocketWrapper_Error";
NSString *NsockDidAccept = @"SocketWrapper_DidAccept";
NSString *NsockDataReceived = @"SocketWrapper_DataReceived";
NSString *NsockDataSent = @"SocketWrapper_DataSent";

@implementation SocketWrapper

/**
 * Initializes the socket wrapper with a host and port
 */
- (id)initWithPort: (int)port
{
	if (self = [super init])
	{
		_port = port;
		
		// the delegate notifications work funky because of threads. we register ourselves as the
		// observer and then pass up the messages that are actually from this object (as we can't only observe self due to threads)
		// to our delegate, and not to all delegates
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(_sendMessageToDelegate:) name: nil object: nil];
	}
	return self;
}

/**
 * Close our socket and clean up anything else
 */
- (void)dealloc
{
	close(_socket);
	
	[super dealloc];
}

/**
 * Returns the delegate
 */
- (id)delegate
{
	return _delegate;
}

/**
 * Sets the delegate but does *not* retain it
 */
- (void)setDelegate: (id)delegate
{
	_delegate = delegate;
}

/**
 * Returns the name of the host to whom we are currently connected.
 */
- (NSString *)remoteHost
{
	struct sockaddr_in addr;
	socklen_t addrLength;
	
	if (getpeername(_socket, (struct sockaddr *)&addr, &addrLength) < 0)
	{
		[self _postNotification: NsockError withObject: [NSError errorWithDomain: @"Could not get remote hostname." code: -1 userInfo: nil]];
	}
	
	char *name = inet_ntoa(addr.sin_addr);
	
	return [NSString stringWithUTF8String: name];
}

/**
 * This is the notification listener for all types of notifications. If the notifications are from a SocketWrapper
 * class, it checks that the value of _delegate in the NSNotification's userInfo matches that of this object. If it does,
 * then the notification was sent from the same object in another thread and it passes the message along to the object's
 * delegate. Complicated enough?
 */
- (void)_sendMessageToDelegate: (NSNotification *)notif
{
	// this isn't us, so there's no point in continuing
	if ([[notif userInfo] objectForKey: sockNotificationDebuggerConnection] != _delegate)
	{
		return;
	}
	
	NSString *name = [notif name];
	
	if (name == NsockDidAccept)
	{
		[_delegate socketDidAccept];
	}
	else if (name == NsockDataReceived)
	{
		[_delegate dataReceived: [notif object] deliverTo: NSSelectorFromString([[notif userInfo] objectForKey: sockNotificationReceiver])];
	}
	else if (name == NsockDataSent)
	{
		[_delegate dataSent];
	}
	else if (name == NsockError)
	{
		[_delegate errorEncountered: [NSError errorWithDomain: [notif object] code: -1 userInfo: nil]];
	}
}

/**
 * Connects to a socket on the port specified during init. This will dispatch another thread to do the
 * actual waiting. Delegate notifications are posted along the way to let the client know what is going on.
 */
- (void)connect
{
	[NSThread detachNewThreadSelector: @selector(_connect:) toTarget: self withObject: nil];
}

/**
 * This does the actual dirty work (in a separate thread) of connecting to a socket
 */
- (void)_connect: (id)obj
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// create an INET socket that we'll be listen()ing on
	int socketOpen = socket(PF_INET, SOCK_STREAM, 0);
	
	// create our address given the port
	struct sockaddr_in address;
	address.sin_family = AF_INET;
	address.sin_port = htons(_port);
	address.sin_addr.s_addr = htonl(INADDR_ANY);
	memset(address.sin_zero, '\0', sizeof(address.sin_zero));
	
	// bind the socket... and don't give up until we've tried for a while
	int tries = 0;
	while (bind(socketOpen, (struct sockaddr *)&address, sizeof(address)) < 0)
	{
		if (tries >= 5)
		{
			close(socketOpen);
			[self _postNotification: NsockError withObject: @"Could not bind to socket"];
			return;
		}
		NSLog(@"couldn't bind to the socket... trying again in 5");
		sleep(5);
		tries++;
	}
	
	// now we just have to keep our ears open
	if (listen(socketOpen, 0) == -1)
	{
		[self _postNotification: NsockError withObject: @"Could not use bound socket for listening"];
	}
	
	// accept a connection
	struct sockaddr_in remoteAddress;
	socklen_t remoteAddressLen = sizeof(remoteAddress);
	_socket = accept(socketOpen, (struct sockaddr *)&remoteAddress, &remoteAddressLen);
	if (_socket < 0)
	{
		close(socketOpen);
		[self _postNotification: NsockError withObject: @"Client failed to accept remote socket"];
		return;
	}
	
	// we're done listening now that we have a connection
	close(socketOpen);
	
	[self _postNotification: NsockDidAccept withObject: nil];
	
	[pool release];
}

/**
 * Reads from the socket and returns the result as a NSString (because it's always going to be XML). Be aware
 * that the underlying socket recv() call will *wait* for the server to send a message, so be sure that this
 * is used either in a threaded environment so the interface does not hang, or when you *know* the server 
 * will return something (which we almost always do).
 *
 * The paramater is an optional selector which the delegate method dataReceived:deliverTo: should forward to
 */
- (void)receive: (SEL)selector
{
	// create a buffer
	char buffer[1024];
	
	// do our initial recv() call to get (hopefully) all the data and the lengh of the packet
	int recvd = recv(_socket, &buffer, sizeof(buffer), 0);
	
	// take the received data and put it into an NSData
	NSMutableData *data = [NSMutableData data];
	
	// strip the length from the packet, and clear the null byte then add it to the NSData
	char packetLength[8];
	int i = 0;
	while (buffer[i] != '\0')
	{
		packetLength[i] = buffer[i];
		i++;
	}
	
	// we also want the null byte, so move us up 1
	i++;
	
	// the total length of the full transmission
	int length = atoi(packetLength);
	
	// move the packet part of the received data into it's own char[]
	char packet[sizeof(buffer)];
	memmove(packet, &buffer[i], recvd - i);
	
	// convert bytes to NSData
	[data appendBytes: packet length: recvd];
	
	// check if we have a partial packet
	if (length + i > sizeof(buffer))
	{
		while (recvd < length)
		{
			int latest = recv(_socket, &buffer, sizeof(buffer), 0);
			if (latest < 1)
			{
				[self _postNotification: NsockError withObject: @"Socket closed or could not be read"];
				return;
			}
			[data appendBytes: buffer length: latest];
			recvd += latest;
		}
	}
	
	// convert the NSData into a NSString
	NSString *string = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
	
	if (selector != nil)
	{
		[self _postNotification: NsockDataReceived
					 withObject: string
					   withDict: [NSMutableDictionary dictionaryWithObject: NSStringFromSelector(selector) forKey: sockNotificationReceiver]];
	}
	else
	{
		[self _postNotification: NsockDataReceived withObject: string];
	}
}

/**
 * Sends a given NSString over the socket
 */
- (void)send: (NSString *)data
{
	data = [NSString stringWithFormat: @"%@\0", data];
	int sent = send(_socket, [data UTF8String], [data length], 0);
	if (sent < 0)
	{
		[self _postNotification: NsockError withObject: @"Failed to write data to socket"];
		return;
	}
	if (sent < [data length])
	{
		// TODO - do we really need to worry about partial sends with the lenght of our commands?
		NSLog(@"FAIL: only partial packet was sent; sent %d bytes", sent);
	}
	
	[self _postNotification: NsockDataSent withObject: nil];
}

/**
 * Helper method to simply post a notification to the default notification center with a given name and object
 */
- (void)_postNotification: (NSString *)name withObject: (id)obj
{
	[self _postNotification: name withObject: obj withDict: [NSMutableDictionary dictionary]];
}

/**
 * Another helper method to aid in the posting of notifications. This one should be used if you have additional
 * things for the userInfo. This automatically adds the sockNotificationDebuggerConnection key.
 */
- (void)_postNotification: (NSString *)name withObject: (id)obj withDict: (NSMutableDictionary *)dict
{
	[dict setValue: _delegate forKey: sockNotificationDebuggerConnection];
	[[NSNotificationCenter defaultCenter] postNotificationName: name object: obj userInfo: dict];
}

@end

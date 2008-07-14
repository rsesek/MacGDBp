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

#import "SocketWrapper.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

@interface SocketWrapper ()
@property (copy, readwrite, getter=remoteHost) NSString *hostname;

- (void)error:(NSString *)msg;
@end

@implementation SocketWrapper
@synthesize hostname;

/**
 * Initializes the socket wrapper with a host and port
 */
- (id)initWithConnection:(GDBpConnection *)cnx
{
	if (self = [super init])
	{
		connection = [cnx retain];
		port = [connection port];
	}
	return self;
}

/**
 * Dealloc
 */
- (void)dealloc
{
	[connection release];
	[hostname release];
	[super dealloc];
}

/**
 * Close our socket and clean up anything else
 */
- (void)close
{
	close(sock);
}

/**
 * Returns the delegate
 */
- (id)delegate
{
	return delegate;
}

/**
 * Sets the delegate but does *not* retain it
 */
- (void)setDelegate:(id)aDelegate
{
	delegate = aDelegate;
}

/**
 * Connects to a socket on the port specified during init. This will dispatch another thread to do the
 * actual waiting. Delegate notifications are posted along the way to let the client know what is going on.
 */
- (void)connect
{
	[NSThread detachNewThreadSelector:@selector(connect:) toTarget:self withObject:nil];
}

/**
 * This does the actual dirty work (in a separate thread) of connecting to a socket
 */
- (void)connect:(id)obj
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// create an INET socket that we'll be listen()ing on
	int socketOpen = socket(PF_INET, SOCK_STREAM, 0);
	
	// create our address given the port
	struct sockaddr_in address;
	address.sin_family = AF_INET;
	address.sin_port = htons(port);
	address.sin_addr.s_addr = htonl(INADDR_ANY);
	memset(address.sin_zero, '\0', sizeof(address.sin_zero));
	
	// allow an already-opened socket to be reused
	int yes = 1;
	setsockopt(socketOpen, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int));
	
	// bind the socket... and don't give up until we've tried for a while
	int tries = 0;
	while (bind(socketOpen, (struct sockaddr *)&address, sizeof(address)) < 0)
	{
		if (tries >= 5)
		{
			close(socketOpen);
			[self error:@"Could not bind to socket"];
			[pool release];
			return;
		}
		NSLog(@"couldn't bind to the socket... trying again in 5");
		sleep(5);
		tries++;
	}
	
	// now we just have to keep our ears open
	if (listen(socketOpen, 0) == -1)
	{
		[self error:@"Could not use bound socket for listening"];
	}
	
	// accept a connection
	struct sockaddr_in remoteAddress;
	socklen_t remoteAddressLen = sizeof(remoteAddress);
	sock = accept(socketOpen, (struct sockaddr *)&remoteAddress, &remoteAddressLen);
	if (sock < 0)
	{
		close(socketOpen);
		[self error:@"Client failed to accept remote socket"];
		[pool release];
		return;
	}
	
	// we're done listening now that we have a connection
	close(socketOpen);
	
	struct sockaddr_in addr;
	socklen_t addrLength;
	if (getpeername(sock, (struct sockaddr *)&addr, &addrLength) < 0)
	{
		[self error:@"Could not get remote hostname."];
	}
	char *name = inet_ntoa(addr.sin_addr);
	[self setHostname:[NSString stringWithUTF8String:name]];
	
	[connection performSelectorOnMainThread:@selector(socketDidAccept:) withObject:nil waitUntilDone:NO];
	
	[pool release];
}

/**
 * Reads from the socket and returns the result as a NSString (because it's always going to be XML). Be aware
 * that the underlying socket recv() call will *wait* for the server to send a message, so be sure that this
 * is used either in a threaded environment so the interface does not hang, or when you *know* the server 
 * will return something (which we almost always do). Returns the data that was received from the socket.
 */
- (NSString *)receive
{
	// create a buffer
	char buffer[1024];
	
	// do our initial recv() call to get (hopefully) all the data and the lengh of the packet
	int recvd = recv(sock, &buffer, sizeof(buffer), 0);
	
	// take the received data and put it into an NSData
	NSMutableString *str = [NSMutableString string];
	
	// strip the length from the packet, and clear the null byte then add it to the NSData
	char packetLength[8];
	memset(packetLength, '\0', sizeof(packetLength));
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
	memset(packet, '\0', sizeof(packet));
	memmove(packet, &buffer[i], recvd - i);
	
	// convert bytes to NSString
	[str appendString:[NSString stringWithCString:packet length:recvd - i]];
	
	// check if we have a partial packet
	if (length + i > sizeof(buffer))
	{
		while (recvd < length + i)
		{
			int latest = recv(sock, &buffer, sizeof(buffer), 0);
			if (latest < 1)
			{
				[self error:@"Socket closed or could not be read"];
				return nil;
			}
			[str appendString:[NSString stringWithCString:buffer length:latest]];
			recvd += latest;
		}
	}
	
	NSString *tmp = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; // strip whitespace
	tmp = [tmp substringToIndex:[tmp length] - 1]; // don't want the null byte
	
	NSAssert([tmp UTF8String][[tmp length] - 1] == '>', @"-[SocketWrapper receive] buffer is incomplete");
	
	return tmp;
}

/**
 * Sends a given NSString over the socket. Returns YES on complete submission.
 */
- (BOOL)send:(NSString *)data
{
	data = [NSString stringWithFormat:@"%@\0", data];
	int sent = send(sock, [data UTF8String], [data length], 0);
	if (sent < 0)
	{
		[self error:@"Failed to write data to socket"];
		return NO;
	}
	if (sent < [data length])
	{
		// TODO - do we really need to worry about partial sends with the lenght of our commands?
		NSLog(@"FAIL: only partial packet was sent; sent %d bytes", sent);
		return NO;
	}
	
	return YES;
}

/**
 * Helper method that just calls -[DebuggerWindowController setError:] on the main thread
 */
- (void)error:(NSString *)msg
{
	[delegate performSelectorOnMainThread:@selector(setError:) withObject:msg waitUntilDone:NO];
}

@end

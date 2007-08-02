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

@implementation SocketWrapper

/**
 * Initializes the socket wrapper with a host and port
 */
- (id)initWithPort: (int)port
{
	if (self = [super init])
	{
		// create an INET socket that we'll be listen()ing on
		int socketOpen = socket(PF_INET, SOCK_STREAM, 0);
		
		// create our address given the port
		struct sockaddr_in address;
		address.sin_family = AF_INET;
		address.sin_port = htons(port);
		address.sin_addr.s_addr = htonl(INADDR_ANY);
		memset(address.sin_zero, '\0', sizeof(address.sin_zero));
		
		// bind the socket... and don't give up until we've tried for a while
		int tries = 0;
		while (bind(socketOpen, (struct sockaddr *)&address, sizeof(address)) < 0)
		{
			if (tries >= 5)
			{
				close(socketOpen);
				NSLog(@"giving up now");
				return nil;
			}
			NSLog(@"couldn't bind to the socket... trying again in 5");
			sleep(5);
			tries++;
		}
		
		// now we just have to keep our ears open
		if (listen(socketOpen, 0) == -1)
		{
			NSLog(@"listen failed");
			return nil;
		}
		
		// accept a connection
		struct sockaddr_in remoteAddress;
		socklen_t remoteAddressLen = sizeof(remoteAddress);
		_socket = accept(socketOpen, (struct sockaddr *)&remoteAddress, &remoteAddressLen);
		if (_socket < 0)
		{
			close(socketOpen);
			NSLog(@"could not accept() the socket");
			return nil;
		}
		
		// we're done listening now that we have a connection
		close(socketOpen);
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

@end

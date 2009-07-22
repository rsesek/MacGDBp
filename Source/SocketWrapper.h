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

#import <Cocoa/Cocoa.h>

@protocol SocketWrapperDelegate;

@interface SocketWrapper : NSObject
{
	int port;
	int sock;
	NSString* hostname;
	
	id <SocketWrapperDelegate> delegate;
}
@property (assign) id <SocketWrapperDelegate> delegate;

- (id)initWithPort:(int)aPort;

- (void)connect;
- (void)close;
- (NSString*)receive;
- (BOOL)send:(NSString*)data;

- (NSString*)remoteHost;

@end

@protocol SocketWrapperDelegate <NSObject>

// Returns a human-readable error message when an error occurred.
- (void)errorEncountered:(NSString*)error;

// Called after the socket is ready for reading and writing. This is not called
// from the main thread.
- (void)socketDidAccept;

@end

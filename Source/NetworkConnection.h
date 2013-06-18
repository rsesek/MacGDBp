/*
 * MacGDBp
 * Copyright (c) 2007 - 2011, Blue Static <http://www.bluestatic.org>
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

#import "ProtocolClient.h"

@protocol NetworkConnectionDelegate;
@class LoggingController;

// This class is the lowest level component to the network. It deals with all
// the intricacies of network and stream programming. Almost all the work this
// class does is on a background thread, which is created when the connection is
// asked to connect and shutdown when asked to close.
@interface NetworkConnection : ProtocolClient<ProtocolClientDelegate>
{
  // The port to connect on.
  NSUInteger port_;

  ProtocolClient* _ideClient;

  // If the connection to the debugger engine is currently active.
  BOOL connected_;

  // The delegate. All methods are executed on the main thread.
  NSObject<NetworkConnectionDelegate>* delegate_;
}

@property (readonly) NSUInteger port;
@property (readonly) BOOL connected;
@property (assign) id <NetworkConnectionDelegate> delegate;

- (id)initWithPort:(NSUInteger)aPort;

- (void)connect;
- (void)close;

- (NSString*)escapedURIPath:(NSString*)path;

@end

// Delegate ////////////////////////////////////////////////////////////////////

@protocol NetworkConnectionDelegate <NSObject>

@optional

- (void)connectionDidAccept:(NetworkConnection*)cx;
- (void)connectionDidClose:(NetworkConnection*)cx;

- (void)handleInitialResponse:(NSXMLDocument*)response;

- (void)handleResponse:(NSXMLDocument*)response;

- (void)errorEncountered:(NSString*)error;

@end

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

#ifdef __cplusplus
class NetworkCallbackController;
#else
@class NetworkCallbackController;
#endif

@protocol NetworkConnectionDelegate;
@class LoggingController;

// This class is the lowest level component to the network. It deals with all
// the intricacies of network and stream programming. Almost all the work this
// class does is on a background thread, which is created when the connection is
// asked to connect and shutdown when asked to close.
@interface NetworkConnection : NSObject
{
  // The port to connect on.
  NSUInteger port_;
  
  // If the connection to the debugger engine is currently active.
  BOOL connected_;

  // The thread on which network operations are performed. Weak.
  NSThread* thread_;

  // Reference to the message loop that the socket runs on. Weak.
  NSRunLoop* runLoop_;

  // Internal class that manages CFNetwork callbacks. Strong.
  NetworkCallbackController* callbackController_;

  // The read stream that is scheduled on the main run loop. Weak.
  CFReadStreamRef readStream_;
  
  // The write stream. Weak.
  CFWriteStreamRef writeStream_;

  // Run loop source used to quit the thread. Strong.
  CFRunLoopSourceRef quitSource_;

  // An ever-increasing integer that gives each transaction a unique ID for the
  // debugging engine.
  NSUInteger transactionID;
  
  // The most recently received transaction ID.
  NSUInteger lastReadTransaction_;
  
  // The last transactionID written to the stream.
  NSUInteger lastWrittenTransaction_;
  
  // To prevent blocked writing, we enqueue all writes and then wait for the
  // write stream to tell us it's ready. We store the pending commands in this
  // array. We use this as a queue (FIFO), with index 0 being first.
  NSMutableArray* queuedWrites_;
  
  // We send queued writes in multiple places, sometimes off a run loop event.
  // Because of this, we need to ensure that only one client is dequeing and
  // sending at a time.
  NSRecursiveLock* writeQueueLock_;
  
  // Information about the current read loop. We append to |currentPacket_|
  // until |currentPacketSize_| has reached |packetSize_|.
  NSMutableString* currentPacket_;
  int packetSize_;
  int currentPacketIndex_;

  // The delegate. All methods are executed on the main thread.
  NSObject<NetworkConnectionDelegate>* delegate_;
}

@property (readonly) NSUInteger port;
@property (readonly) BOOL connected;
@property (assign) id <NetworkConnectionDelegate> delegate;

- (id)initWithPort:(NSUInteger)aPort;

- (void)connect;
- (void)close;

// This sends the given command format to the debugger. This method is thread
// safe and schedules the request on the |runLoop_|.
- (NSNumber*)sendCommandWithFormat:(NSString*)format, ...;

- (NSString*)escapedURIPath:(NSString*)path;
- (NSInteger)transactionIDFromResponse:(NSXMLDocument*)response;
- (NSInteger)transactionIDFromCommand:(NSString*)command;

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

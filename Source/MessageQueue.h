/*
 * MacGDBp
 * Copyright (c) 2013, Blue Static <http://www.bluestatic.org>
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

#import <Foundation/Foundation.h>

#import "ThreadSafeDeleage.h"

@protocol MessageQueueDelegate;

// MessageQueue operates a listening socket, that is connected to another
// program with which it exchanges UTF8 string messages. A message contains two
// parts, both terminated by '\0'. The first is an ASCII integer number that is
// the length of the second part. The second part is the actual string message.
@interface MessageQueue : NSObject {
 @private
  // The port number on which to open a listening socket.
  NSUInteger _port;

  // The thread and its run loop on which this class primarily operates.
  NSThread* _thread;
  NSRunLoop* _runLoop;

  // Whether or not the message queue is connected to a client.
  BOOL _connected;

  // A queue of messages that are waiting to be sent.
  NSMutableArray* _queue;

  // The delegate for this class.
  ThreadSafeDeleage<MessageQueueDelegate>* _delegate;

  // The socket that listens for new incoming connections.
  CFSocketRef _socket;

  // The child socket that has been accepted from |_socket|.
  CFSocketNativeHandle _child;

  // The read and write streams that are created on the |_child| socket.
  CFReadStreamRef _readStream;
  CFWriteStreamRef _writeStream;

  // When a message is being read, this temporary buffer is used to build up
  // the complete message from successive reads.
  NSMutableString* _message;
  NSUInteger _totalMessageSize;
  NSUInteger _messageSize;
}

// Creates a new MessasgeQueue that will listen on |port| and report information
// to its |delegate|.
- (id)initWithPort:(NSUInteger)port delegate:(id<MessageQueueDelegate>)delegate;

// Whether or not the message queue has attached itself to a child.
- (BOOL)isConnected;

// Opens a socket that will listen for connections.
- (void)connect;

// Closes either the listening or child socket and completely disconnects.
- (void)disconnect;

// Enqueues a |message| to be sent to the client. This may be called from any
// thread.
- (void)sendMessage:(NSString*)message;

@end

// Delegate ////////////////////////////////////////////////////////////////////

// The delegate for the message queue. These methods may be called on any thread.
@protocol MessageQueueDelegate <NSObject>
// Callback for any errors that the MessageQueue encounters.
- (void)messageQueueError:(NSError*)error;

// Called when the listening socket has accepted a child socket.
- (void)clientDidConnect:(MessageQueue*)queue;

// Called when the child socket has been disconnected.
- (void)clientDidDisconnect:(MessageQueue*)queue;

// If the write stream is ready, the delegate controls whether or not the next
// pending message should be sent via the result of this method.
- (BOOL)shouldSendMessage;

// Callback for when a message has been sent.
- (void)didSendMessage:(NSString*)message;

// Callback with the message content when one has been receieved.
- (void)didReceiveMessage:(NSString*)message;
@end

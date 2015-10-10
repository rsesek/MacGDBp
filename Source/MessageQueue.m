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

#import "MessageQueue.h"

#include <dispatch/dispatch.h>
#include <netinet/in.h>
#include <sys/socket.h>

@implementation MessageQueue {
  // The port number on which to open a listening socket.
  NSUInteger _port;

  // The dispatch queue for this instance.
  dispatch_queue_t _dispatchQueue;

  // Whether or not the message queue is connected to a client.
  BOOL _connected;

  // A queue of messages that are waiting to be sent.
  NSMutableArray* _messageQueue;

  // The delegate for this class.
  BSProtocolThreadInvoker<MessageQueueDelegate>* _delegate;

  BOOL _listening;

  int _socket;

  // The two dispatch sources for the |_child|.
  dispatch_source_t _readSource;
  dispatch_source_t _writeSource;

  // When a message is being read, this temporary buffer is used to build up
  // the complete message from successive reads.
  NSMutableString* _message;
  NSUInteger _totalMessageSize;
  NSUInteger _messageSize;
}

- (id)initWithPort:(NSUInteger)port delegate:(id<MessageQueueDelegate>)delegate {
  if ((self = [super init])) {
    _port = port;
    _dispatchQueue = dispatch_queue_create(
        [[NSString stringWithFormat:@"org.bluestatic.MacGDBp.MessageQueue.%p", self] UTF8String],
        DISPATCH_QUEUE_SERIAL);
    _messageQueue = [[NSMutableArray alloc] init];
    _delegate = (BSProtocolThreadInvoker<MessageQueueDelegate>*)
        [[BSProtocolThreadInvoker alloc] initWithObject:delegate
                                         protocol:@protocol(MessageQueueDelegate)
                                           thread:[NSThread currentThread]];
  }
  return self;
}

- (void)dealloc {
  dispatch_release(_dispatchQueue);
  [_messageQueue release];
  [_delegate release];
  [super dealloc];
}

- (BOOL)isConnected {
  return _connected;
}

- (void)connect {
  if (_connected)
    return;

  _connected = YES;
  dispatch_async(_dispatchQueue, ^{ [self openListeningSocket]; });
}

- (void)disconnect {
  dispatch_async(_dispatchQueue, ^{ [self disconnectClient]; });
  _connected = NO;
}

- (void)sendMessage:(NSString*)message {
  dispatch_async(_dispatchQueue, ^{
    [_messageQueue addObject:message];
    [self dequeueAndSend];
  });
}

// Private /////////////////////////////////////////////////////////////////////

- (void)openListeningSocket {
  // Create a socket.
  do {
    _socket = socket(PF_INET, SOCK_STREAM, 0);
    if (_socket < 0) {
      NSLog(@"Could not connect to socket: %d %s", errno, strerror(errno));
    }
  } while (!_socket);

  // Allow old, yet-to-be recycled sockets to be reused.
  int yes = 1;
  setsockopt(_socket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int));
  setsockopt(_socket, SOL_SOCKET, SO_REUSEPORT, &yes, sizeof(int));

  // Bind to the address.
  struct sockaddr_in address = {0};
  address.sin_len = sizeof(address);
  address.sin_family = AF_INET;
  address.sin_port = htons(_port);
  address.sin_addr.s_addr = htonl(INADDR_ANY);

  int rv;
  do {
    rv = bind(_socket, &address, sizeof(address));
    if (rv !=  0) {
      NSLog(@"Could not bind to socket: %d, %s", errno, strerror(errno));
    }
  } while (rv != 0);

  // Listen for a connection.
  rv = listen(_socket, 1);
  if (rv < 0) {
    NSLog(@"Could not listen on socket: %d, %s", errno, strerror(errno));
    close(_socket);
    _connected = NO;
    return;
  }
  _readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _socket, 0, _dispatchQueue);
  dispatch_source_set_event_handler(_readSource, ^{
    [self acceptConnection];
  });
  dispatch_resume(_readSource);
}

// Closes down the listening socket, the child socket, and the streams.
- (void)disconnectClient {
  if (_readSource) {
    dispatch_source_cancel(_readSource);
    dispatch_release(_readSource);
    _readSource = NULL;
  }

  if (_writeSource) {
    dispatch_source_cancel(_writeSource);
    dispatch_release(_writeSource);
    _writeSource = NULL;
  }

  if (_socket) {
    close(_socket);
    _socket = -1;
  }

  _listening = NO;
  [_messageQueue removeAllObjects];

  [_delegate messageQueueDidDisconnect:self];
}

// If the write stream is ready and there is data to send, sends the next message.
- (void)dequeueAndSend {
  if (![_messageQueue count])
    return;

  NSString* message = [_messageQueue objectAtIndex:0];
  [self performSend:message];
  [_messageQueue removeObjectAtIndex:0];
}

// Writes the string into the write stream.
- (void)performSend:(NSString*)message {
  // TODO: May need to negotiate with the server as to the string encoding.
  const NSStringEncoding kEncoding = NSUTF8StringEncoding;
  // Add space for the NUL byte.
  NSUInteger maxBufferSize = [message maximumLengthOfBytesUsingEncoding:kEncoding] + 1;

  UInt8* buffer = malloc(maxBufferSize);
  bzero(buffer, maxBufferSize);

  NSUInteger bufferSize = 0;
  if (![message getBytes:buffer
               maxLength:maxBufferSize
              usedLength:&bufferSize
                encoding:kEncoding
                 options:0
                   range:NSMakeRange(0, [message length])
          remainingRange:NULL]) {
    free(buffer);
    return;
  }

  // Include a NUL byte.
  ++bufferSize;

  // Write the packet out, and spin in a busy wait loop if the stream is not ready. This
  // method is only ever called in response to a stream ready event.
  NSUInteger totalWritten = 0;
  while (totalWritten < bufferSize) {
    ssize_t bytesWritten = write(_socket, buffer + totalWritten, bufferSize - totalWritten);
    if (bytesWritten < 0) {
      NSLog(@"Failed to write to stream: %d, %s", errno, strerror(errno));
      break;
    }
    totalWritten += bytesWritten;
  }

  [_delegate messageQueue:self didSendMessage:message];

  free(buffer);
}

// Reads bytes out of the read stream. This may be called multiple times if the
// message cannot be read in one pass.
- (void)readMessageFromStream {
  const NSUInteger kBufferSize = 1024;
  UInt8 buffer[kBufferSize];
  CFIndex bufferOffset = 0;  // Starting point in |buffer| to work with.
  ssize_t bytesRead = read(_socket, buffer, kBufferSize);
  if (bytesRead == 0) {
    [self disconnectClient];
    return;
  }
  const char* charBuffer = (const char*)buffer;

  // The read loop works by going through the buffer until all the bytes have
  // been processed.
  while (bufferOffset < bytesRead) {
    // Find the NUL separator, or the end of the string.
    NSUInteger partLength = 0;
    for (CFIndex i = bufferOffset; i < bytesRead && charBuffer[i] != '\0'; ++i, ++partLength) ;

    // If there is not a current packet, set some state.
    if (!_message) {
      // Read the message header: the size.  This will be |partLength| bytes.
      _totalMessageSize = atoi(charBuffer + bufferOffset);
      _messageSize = 0;
      _message = [[NSMutableString alloc] initWithCapacity:_totalMessageSize];
      bufferOffset += partLength + 1;  // Pass over the NUL byte.
      continue;  // Spin the loop to begin reading actual data.
    }

    // Substring the byte stream and append it to the packet string.
    CFStringRef bufferString = CFStringCreateWithBytes(kCFAllocatorDefault,
                                                       buffer + bufferOffset,  // Byte pointer, offset by start index.
                                                       partLength,  // Length.
                                                       kCFStringEncodingUTF8,
                                                       true);
    [_message appendString:(NSString*)bufferString];
    CFRelease(bufferString);

    // Advance counters.
    _messageSize += partLength;
    bufferOffset += partLength + 1;

    // If this read finished the packet, handle it and reset.
    if (_messageSize >= _totalMessageSize) {
      [_delegate messageQueue:self didReceiveMessage:[_message autorelease]];
      _message = nil;

      // Process any outgoing messages.
      [self dequeueAndSend];
    }
  }
}

- (void)acceptConnection {
  _listening = NO;

  struct sockaddr_in address = {0};
  socklen_t addressLength = sizeof(address);
  int connection = accept(_socket, &address, &addressLength);
  if (connection < 0) {
    NSLog(@"Failed to accept connection: %d, %s", errno, strerror(errno));
    [self disconnectClient];
    return;
  }

  dispatch_source_cancel(_readSource);
  close(_socket);

  _readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, connection, 0, _dispatchQueue);
  dispatch_source_set_event_handler(_readSource, ^{
    [self readMessageFromStream];
  });

  _writeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, connection, 0, _dispatchQueue);
  dispatch_source_set_event_handler(_writeSource, ^{
    [self dequeueAndSend];
  });

  _socket = connection;

  dispatch_resume(_readSource);
  dispatch_resume(_writeSource);

  [_delegate messageQueueDidConnect:self];
}

@end

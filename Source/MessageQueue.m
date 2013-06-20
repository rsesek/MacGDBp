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

#include <netinet/in.h>
#include <sys/socket.h>

@interface MessageQueue (Private)
// Thread main function that is started from -connect.
- (void)runMessageQueue;

// All the following methods must be called from the -runMessageQueue thread.

// Creates a listening socket and schedules it in the run loop.
- (void)listenForClient;

// Closes down the listening socket, the child socket, and the streams.
- (void)disconnectClient;

// This first calls -disconnectClient and then stops the run loop and terminates
// the -runMessageQueue thread.
- (void)stopRunLoop;

// Adds a |message| to |_queue|.
- (void)enqueueMessage:(NSString*)message;

// If the write stream is ready and there is data to send, sends the next message.
- (void)dequeueAndSend;

// Writes the string into the write stream.
- (void)performSend:(NSString*)message;

// Reads bytes out of the read stream. This may be called multiple times if the
// message cannot be read in one pass.
- (void)readMessageFromStream;

// Forwarding methods from the CoreFoundation callbacks.
- (void)listenSocket:(CFSocketRef)socket acceptedSocket:(CFSocketNativeHandle)child;
- (void)readStream:(CFReadStreamRef)stream handleEvent:(CFStreamEventType)event;
- (void)writeStream:(CFWriteStreamRef)stream handleEvent:(CFStreamEventType)event;
@end

// CoreFoundation Callbacks ////////////////////////////////////////////////////

static void MessageQueueSocketAccept(CFSocketRef socket,
                                     CFSocketCallBackType callbackType,
                                     CFDataRef address,
                                     const void* data,
                                     void* self)
{
  CFSocketNativeHandle child = *(CFSocketNativeHandle*)data;
  [(MessageQueue*)self listenSocket:socket acceptedSocket:child];
}

static void MessageQueueReadEvent(CFReadStreamRef stream,
                                  CFStreamEventType eventType,
                                  void* self)
{
  [(MessageQueue*)self readStream:stream handleEvent:eventType];
}

static void MessageQueueWriteEvent(CFWriteStreamRef stream,
                                   CFStreamEventType eventType,
                                   void* self)
{
  [(MessageQueue*)self writeStream:stream handleEvent:eventType];
}

////////////////////////////////////////////////////////////////////////////////

@implementation MessageQueue

- (id)initWithPort:(NSUInteger)port delegate:(id<MessageQueueDelegate>)delegate {
  if ((self = [super init])) {
    _port = port;
    _queue = [[NSMutableArray alloc] init];
    _delegate = (ThreadSafeDeleage<MessageQueueDelegate>*)
        [[ThreadSafeDeleage alloc] initWithObject:delegate
                                         protocol:@protocol(MessageQueueDelegate)
                                           thread:[NSThread currentThread]
                                            modes:@[ NSDefaultRunLoopMode ]];
  }
  return self;
}

- (void)dealloc {
  [_queue release];
  [_delegate release];
  [super dealloc];
}

- (BOOL)isConnected {
  return _connected;
}

- (void)connect {
  if (_thread)
    return;

  [NSThread detachNewThreadSelector:@selector(runMessageQueue)
                           toTarget:self
                         withObject:nil];
}

- (void)disconnect {
  [self performSelector:@selector(stopRunLoop)
               onThread:_thread
             withObject:nil
          waitUntilDone:NO];
}

- (void)sendMessage:(NSString*)message {
  [self performSelector:@selector(enqueueMessage:)
               onThread:_thread
             withObject:message
          waitUntilDone:NO];
}

// Private /////////////////////////////////////////////////////////////////////

- (void)runMessageQueue {
  @autoreleasepool {
    _thread = [NSThread currentThread];
    _runLoop = [NSRunLoop currentRunLoop];

    _connected = NO;
    [self scheduleListenSocket];

    // Use CFRunLoop instead of NSRunLoop because the latter has no programmatic
    // stop routine.
    CFRunLoopRun();

    _thread = nil;
    _runLoop = nil;
  }
}

- (void)scheduleListenSocket {
  // Create the address structure.
  struct sockaddr_in address;
  memset(&address, 0, sizeof(address));
  address.sin_len = sizeof(address);
  address.sin_family = AF_INET;
  address.sin_port = htons(_port);
  address.sin_addr.s_addr = htonl(INADDR_ANY);

  // Create the socket signature.
  CFSocketSignature signature;
  signature.protocolFamily = PF_INET;
  signature.socketType = SOCK_STREAM;
  signature.protocol = IPPROTO_TCP;
  signature.address = (CFDataRef)[NSData dataWithBytes:&address length:sizeof(address)];

  CFSocketContext context = { 0 };
  context.info = self;

  do {
    _socket =
        CFSocketCreateWithSocketSignature(kCFAllocatorDefault,
                                          &signature,  // Socket signature.
                                          kCFSocketAcceptCallBack,  // Callback types.
                                          &MessageQueueSocketAccept,  // Callback function.
                                          &context);  // Context to pass to callout.
    if (!_socket) {
      //[connection_ errorEncountered:@"Could not open socket."];
      sleep(1);
    }
  } while (!_socket);

  // Allow old, yet-to-be recycled sockets to be reused.
  int yes = 1;
  setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int));
  setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEPORT, &yes, sizeof(int));

  // Schedule the socket on the run loop.
  CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
  CFRunLoopAddSource([_runLoop getCFRunLoop], source, kCFRunLoopCommonModes);
  CFRelease(source);
}

- (void)disconnectClient {
  if (_readStream) {
    CFReadStreamUnscheduleFromRunLoop(_readStream, [_runLoop getCFRunLoop], kCFRunLoopCommonModes);
    CFReadStreamClose(_readStream);
    CFRelease(_readStream);
    _readStream = NULL;
  }

  if (_writeStream) {
    CFWriteStreamUnscheduleFromRunLoop(_writeStream, [_runLoop getCFRunLoop], kCFRunLoopCommonModes);
    CFWriteStreamClose(_writeStream);
    CFRelease(_writeStream);
    _writeStream = NULL;
  }

  if (_child) {
    close(_child);
    _child = NULL;
  }

  _connected = NO;
  [_delegate messageQueueDidDisconnect:self];
}

- (void)stopRunLoop {
  [self disconnectClient];
  CFRunLoopStop([_runLoop getCFRunLoop]);
}

- (void)enqueueMessage:(NSString*)message {
  [_queue addObject:message];
  [self dequeueAndSend];
}

- (void)dequeueAndSend {
  if (![_queue count])
    return;

  if (!CFWriteStreamCanAcceptBytes(_writeStream))
    return;

  NSString* message = [_queue objectAtIndex:0];
  [self performSend:message];
  [_queue removeObjectAtIndex:0];
}

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
    CFIndex bytesWritten = CFWriteStreamWrite(_writeStream, buffer + totalWritten, bufferSize - totalWritten);
    if (bytesWritten < 0) {
      CFErrorRef error = CFWriteStreamCopyError(_writeStream);
      //ReportError(error);
      break;
    }
    totalWritten += bytesWritten;
  }

  [_delegate messageQueue:self didSendMessage:message];

  free(buffer);
}

- (void)readMessageFromStream {
  const NSUInteger kBufferSize = 1024;
  UInt8 buffer[kBufferSize];
  CFIndex bufferOffset = 0;  // Starting point in |buffer| to work with.
  CFIndex bytesRead = CFReadStreamRead(_readStream, buffer, kBufferSize);
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

- (void)listenSocket:(CFSocketRef)socket acceptedSocket:(CFSocketNativeHandle)child {
  if (socket != _socket) {
    // TODO: error
    return;
  }

  _child = child;

  // Create the streams on the socket.
  CFStreamCreatePairWithSocket(kCFAllocatorDefault,
                               _child,  // Socket handle.
                               &_readStream,  // Read stream in-pointer.
                               &_writeStream);  // Write stream in-pointer.

  // Create struct to register callbacks for the stream.
  CFStreamClientContext context = { 0 };
  context.info = self;

  // Set the client of the read stream.
  CFOptionFlags readFlags = kCFStreamEventOpenCompleted |
                            kCFStreamEventHasBytesAvailable |
                            kCFStreamEventErrorOccurred |
                            kCFStreamEventEndEncountered;
  if (CFReadStreamSetClient(_readStream, readFlags, &MessageQueueReadEvent, &context))
    // Schedule in run loop to do asynchronous communication with the engine.
    CFReadStreamScheduleWithRunLoop(_readStream, [_runLoop getCFRunLoop], kCFRunLoopCommonModes);
  else
    return;

  // Open the stream now that it's scheduled on the run loop.
  if (!CFReadStreamOpen(_readStream)) {
    //ReportError(CFReadStreamCopyError(readStream_));
    return;
  }

  // Set the client of the write stream.
  CFOptionFlags writeFlags = kCFStreamEventOpenCompleted |
  kCFStreamEventCanAcceptBytes |
  kCFStreamEventErrorOccurred |
  kCFStreamEventEndEncountered;
  if (CFWriteStreamSetClient(_writeStream, writeFlags, &MessageQueueWriteEvent, &context))
    // Schedule it in the run loop to receive error information.
    CFWriteStreamScheduleWithRunLoop(_writeStream, [_runLoop getCFRunLoop], kCFRunLoopCommonModes);
  else
    return;

  // Open the write stream.
  if (!CFWriteStreamOpen(_writeStream)) {
//    ReportError(CFWriteStreamCopyError(_writeStream));
    return;
  }

  _connected = YES;
  [_delegate messageQueueDidConnect:self];

  CFSocketInvalidate(_socket);
  CFRelease(_socket);
  _socket = NULL;
}

- (void)readStream:(CFReadStreamRef)stream handleEvent:(CFStreamEventType)event
{
  assert(stream == _readStream);
  switch (event)
  {
    case kCFStreamEventHasBytesAvailable:
      [self readMessageFromStream];
      break;

    case kCFStreamEventErrorOccurred:
      //ReportError(CFReadStreamCopyError(stream));
      [self stopRunLoop];
      break;

    case kCFStreamEventEndEncountered:
      [self stopRunLoop];
      break;

    default:
      // TODO: error
      break;
  };
}

- (void)writeStream:(CFWriteStreamRef)stream handleEvent:(CFStreamEventType)event
{
  assert(stream == _writeStream);
  switch (event) {
    case kCFStreamEventCanAcceptBytes:
      [self dequeueAndSend];
      break;

    case kCFStreamEventErrorOccurred:
      //ReportError(CFWriteStreamCopyError(stream));
      [self stopRunLoop];
      break;

    case kCFStreamEventEndEncountered:
      [self stopRunLoop];
      break;

    default:
      // TODO: error
      break;
  }
}

@end

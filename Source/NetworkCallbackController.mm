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

#import "NetworkCallbackController.h"

#import <sys/socket.h>
#import <netinet/in.h>

#import "NetworkConnection.h"
#import "NetworkConnectionPrivate.h"

NetworkCallbackController::NetworkCallbackController(NetworkConnection* connection)
    : listeningSocket_(NULL),
      socketHandle_(NULL),
      readStream_(NULL),
      writeStream_(NULL),
      connection_(connection),
      runLoop_(CFRunLoopGetCurrent())
{
}

void NetworkCallbackController::OpenConnection(NSUInteger port)
{
  // Pass ourselves to the callback so we don't have to use ugly globals.
  CFSocketContext context = { 0 };
  context.info = this;
  
  // Create the address structure.
  struct sockaddr_in address;
  memset(&address, 0, sizeof(address));
  address.sin_len = sizeof(address);
  address.sin_family = AF_INET;
  address.sin_port = htons(port);
  address.sin_addr.s_addr = htonl(INADDR_ANY);    
  
  // Create the socket signature.
  CFSocketSignature signature;
  signature.protocolFamily = PF_INET;
  signature.socketType = SOCK_STREAM;
  signature.protocol = IPPROTO_TCP;
  signature.address = (CFDataRef)[NSData dataWithBytes:&address length:sizeof(address)];
  
  do {
    listeningSocket_ =
        CFSocketCreateWithSocketSignature(kCFAllocatorDefault,
                                          &signature,  // Socket signature.
                                          kCFSocketAcceptCallBack,  // Callback types.
                                          &NetworkCallbackController::SocketAcceptCallback,  // Callout function pointer.
                                          &context);  // Context to pass to callout.
    if (!listeningSocket_) {
      [connection_ errorEncountered:@"Could not open socket."];
      sleep(1);
    }
  } while (!listeningSocket_);
  
  // Allow old, yet-to-be recycled sockets to be reused.
  BOOL yes = YES;
  setsockopt(CFSocketGetNative(listeningSocket_), SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(BOOL));
  setsockopt(CFSocketGetNative(listeningSocket_), SOL_SOCKET, SO_REUSEPORT, &yes, sizeof(BOOL));
  
  // Schedule the socket on the run loop.
  CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, listeningSocket_, 0);
  CFRunLoopAddSource(runLoop_, source, kCFRunLoopCommonModes);
  CFRelease(source);  
}

void NetworkCallbackController::CloseConnection()
{
  UnscheduleReadStream();
  UnscheduleWriteStream();

  if (socketHandle_) {
    close(socketHandle_);
    socketHandle_ = NULL;
    [connection_ socketDisconnected];
  }
}

BOOL NetworkCallbackController::WriteStreamCanAcceptBytes()
{
  return writeStream_ && CFWriteStreamCanAcceptBytes(writeStream_);
}

BOOL NetworkCallbackController::WriteString(NSString* string)
{
  BOOL done = NO;

  char* cString = const_cast<char*>([string UTF8String]);
  size_t stringLength = strlen(cString);

  // Busy wait while writing. BAADD. Should background this operation.
  while (!done) {
    if (WriteStreamCanAcceptBytes()) {
      // Include the NULL byte in the string when we write.
      CFIndex bytesWritten = CFWriteStreamWrite(writeStream_, (UInt8*)cString, stringLength + 1);
      if (bytesWritten < 0) {
        CFErrorRef error = CFWriteStreamCopyError(writeStream_);
        ReportError(error);
        break;
      }
      // Incomplete write.
      else if (bytesWritten < static_cast<CFIndex>(strlen(cString))) {
        // Adjust the buffer and wait for another chance to write.
        stringLength -= bytesWritten;
        memmove(string, string + bytesWritten, stringLength);
      }
      else {
        done = YES;
      }
    }
  }

  return done;
}

// Static Methods //////////////////////////////////////////////////////////////

void NetworkCallbackController::SocketAcceptCallback(CFSocketRef socket,
                                                     CFSocketCallBackType callbackType,
                                                     CFDataRef address,
                                                     const void* data,
                                                     void* self)
{
  assert(callbackType == kCFSocketAcceptCallBack);
  static_cast<NetworkCallbackController*>(self)->OnSocketAccept(socket, address, data);
}

void NetworkCallbackController::ReadStreamCallback(CFReadStreamRef stream,
                                                   CFStreamEventType eventType,
                                                   void* self)
{
  static_cast<NetworkCallbackController*>(self)->OnReadStreamEvent(stream, eventType);
}

void NetworkCallbackController::WriteStreamCallback(CFWriteStreamRef stream,
                                                    CFStreamEventType eventType,
                                                    void* self)
{
  static_cast<NetworkCallbackController*>(self)->OnWriteStreamEvent(stream, eventType);
}


// Private Instance Methods ////////////////////////////////////////////////////

void NetworkCallbackController::OnSocketAccept(CFSocketRef socket,
                                               CFDataRef address,
                                               const void* data)
{
  // Keep a reference to the socket handle of the child socket. Do not create
  // a CFSocket with this because doing so prohibits the use of streams. The
  // kCFSocketDataCallBack would have to be used instead.
  socketHandle_ = *(CFSocketNativeHandle*)data;

  // Create the streams on the socket.
  CFStreamCreatePairWithSocket(kCFAllocatorDefault,
                               socketHandle_,  // Socket handle.
                               &readStream_,  // Read stream in-pointer.
                               &writeStream_);  // Write stream in-pointer.
  
  // Create struct to register callbacks for the stream.
  CFStreamClientContext context = { 0 };
  context.info = this;
  
  // Set the client of the read stream.
  CFOptionFlags readFlags = kCFStreamEventOpenCompleted |
                            kCFStreamEventHasBytesAvailable |
                            kCFStreamEventErrorOccurred |
                            kCFStreamEventEndEncountered;
  if (CFReadStreamSetClient(readStream_, readFlags, &NetworkCallbackController::ReadStreamCallback, &context))
    // Schedule in run loop to do asynchronous communication with the engine.
    CFReadStreamScheduleWithRunLoop(readStream_, runLoop_, kCFRunLoopCommonModes);
  else
    return;
  
  // Open the stream now that it's scheduled on the run loop.
  if (!CFReadStreamOpen(readStream_)) {
    ReportError(CFReadStreamCopyError(readStream_));
    return;
  }
  
  // Set the client of the write stream.
  CFOptionFlags writeFlags = kCFStreamEventOpenCompleted |
                             kCFStreamEventCanAcceptBytes |
                             kCFStreamEventErrorOccurred |
                             kCFStreamEventEndEncountered;
  if (CFWriteStreamSetClient(writeStream_, writeFlags, &NetworkCallbackController::WriteStreamCallback, &context))
    // Schedule it in the run loop to receive error information.
    CFWriteStreamScheduleWithRunLoop(writeStream_, runLoop_, kCFRunLoopCommonModes);
  else
    return;
  
  // Open the write stream.
  if (!CFWriteStreamOpen(writeStream_)) {
    ReportError(CFWriteStreamCopyError(writeStream_));
    return;
  }

  [connection_ socketDidAccept];

  CloseSocket();
}

void NetworkCallbackController::OnReadStreamEvent(CFReadStreamRef stream,
                                                  CFStreamEventType eventType)
{
  switch (eventType)
  {
    case kCFStreamEventHasBytesAvailable:
      if (readStream_)
        [connection_ readStreamHasData:stream];
      break;
      
    case kCFStreamEventErrorOccurred:
      ReportError(CFReadStreamCopyError(stream));
      CloseConnection();
      break;
      
    case kCFStreamEventEndEncountered:
      CloseConnection();
      break;
  };
}

void NetworkCallbackController::OnWriteStreamEvent(CFWriteStreamRef stream,
                                                   CFStreamEventType eventType)
{
  switch (eventType)
  {
    case kCFStreamEventCanAcceptBytes:
      [connection_ sendQueuedWrites];
      break;
      
    case kCFStreamEventErrorOccurred:
      ReportError(CFWriteStreamCopyError(stream));
      CloseConnection();
      break;
      
    case kCFStreamEventEndEncountered:
      CloseConnection();
      break;
  }
}

void NetworkCallbackController::CloseSocket()
{
  if (listeningSocket_) {
    CFSocketInvalidate(listeningSocket_);
    CFRelease(listeningSocket_);
    listeningSocket_ = NULL;
  }  
}

void NetworkCallbackController::UnscheduleReadStream()
{
  if (!readStream_)
    return;
  CFReadStreamUnscheduleFromRunLoop(readStream_, runLoop_, kCFRunLoopCommonModes);
  CFReadStreamClose(readStream_);
  CFRelease(readStream_);
  readStream_ = NULL;
}

void NetworkCallbackController::UnscheduleWriteStream()
{
  if (!writeStream_)
    return;
  CFWriteStreamUnscheduleFromRunLoop(writeStream_, runLoop_, kCFRunLoopCommonModes);
  CFWriteStreamClose(writeStream_);
  CFRelease(writeStream_);
  writeStream_ = NULL;
}

void NetworkCallbackController::ReportError(CFErrorRef error)
{
  [connection_ errorEncountered:[(NSError*)error description]];
  CFRelease(error);
}

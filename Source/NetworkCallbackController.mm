/*
 * MacGDBp
 * Copyright (c) 2007 - 2010, Blue Static <http://www.bluestatic.org>
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

#import "NetworkConnection.h"
#import "NetworkConnectionPrivate.h"

NetworkCallbackController::NetworkCallbackController(NetworkConnection* connection)
    : connection_(connection),
      runLoop_(CFRunLoopGetCurrent())
{
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
  CFReadStreamRef readStream;
  CFWriteStreamRef writeStream;
  
  // Create the streams on the socket.
  CFStreamCreatePairWithSocket(kCFAllocatorDefault,
                               *(CFSocketNativeHandle*)data,  // Socket handle.
                               &readStream,  // Read stream in-pointer.
                               &writeStream);  // Write stream in-pointer.
  
  // Create struct to register callbacks for the stream.
  CFStreamClientContext context = { 0 };
  context.info = this;
  
  // Set the client of the read stream.
  CFOptionFlags readFlags = kCFStreamEventOpenCompleted |
  kCFStreamEventHasBytesAvailable |
  kCFStreamEventErrorOccurred |
  kCFStreamEventEndEncountered;
  if (CFReadStreamSetClient(readStream, readFlags, &NetworkCallbackController::ReadStreamCallback, &context))
    // Schedule in run loop to do asynchronous communication with the engine.
    CFReadStreamScheduleWithRunLoop(readStream, runLoop_, kCFRunLoopCommonModes);
  else
    return;
  
  // Open the stream now that it's scheduled on the run loop.
  if (!CFReadStreamOpen(readStream)) {
    ReportError(CFReadStreamCopyError(readStream));
    return;
  }
  
  // Set the client of the write stream.
  CFOptionFlags writeFlags = kCFStreamEventOpenCompleted |
  kCFStreamEventCanAcceptBytes |
  kCFStreamEventErrorOccurred |
  kCFStreamEventEndEncountered;
  if (CFWriteStreamSetClient(writeStream, writeFlags, &NetworkCallbackController::WriteStreamCallback, &context))
    // Schedule it in the run loop to receive error information.
    CFWriteStreamScheduleWithRunLoop(writeStream, runLoop_, kCFRunLoopCommonModes);
  else
    return;
  
  // Open the write stream.
  if (!CFWriteStreamOpen(writeStream)) {
    ReportError(CFWriteStreamCopyError(writeStream));
    return;
  }
  
  connection_.readStream = readStream;
  connection_.writeStream = writeStream;
  [connection_ socketDidAccept];
}

void NetworkCallbackController::OnReadStreamEvent(CFReadStreamRef stream,
                                                  CFStreamEventType eventType)
{
  switch (eventType)
  {
    case kCFStreamEventHasBytesAvailable:
      [connection_ readStreamHasData];
      break;
      
    case kCFStreamEventErrorOccurred:
    {
      ReportError(CFReadStreamCopyError(stream));
      UnscheduleReadStream();
      break;
    }
      
    case kCFStreamEventEndEncountered:
      UnscheduleReadStream();
      [connection_ socketDisconnected];
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
    {
      ReportError(CFWriteStreamCopyError(stream));
      UnscheduleWriteStream();
      break;
    }
      
    case kCFStreamEventEndEncountered:
      UnscheduleReadStream();
      [connection_ socketDisconnected];
      break;
  }
}

void NetworkCallbackController::UnscheduleReadStream()
{
  CFReadStreamUnscheduleFromRunLoop(connection_.readStream, runLoop_, kCFRunLoopCommonModes);
  CFReadStreamClose(connection_.readStream);
  CFRelease(connection_.readStream);    
  connection_.readStream = NULL;
}

void NetworkCallbackController::UnscheduleWriteStream()
{
  CFWriteStreamUnscheduleFromRunLoop(connection_.writeStream, runLoop_, kCFRunLoopCommonModes);
  CFWriteStreamClose(connection_.writeStream);
  CFRelease(connection_.writeStream);
  connection_.writeStream = NULL;
}

void NetworkCallbackController::ReportError(CFErrorRef error)
{
  [connection_ errorEncountered:[(NSError*)error description]];
  CFRelease(error);
}

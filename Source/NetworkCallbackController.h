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

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

@class NetworkConnection;

// This class is used for the CFNetwork callbacks. It is a private class and
// the instance is owned by the NewtorkConnection instance. This class can be
// considered an extension of NetworkConnection.
class NetworkCallbackController
{
 public:
  // This object should be constructed on the thread which the streams are
  // to be scheduled on. It will hold a weak reference to the run loop on that
  // thread.
  explicit NetworkCallbackController(NetworkConnection* connection);

  // Creates a socket and schedules it on the current run loop.
  void OpenConnection(NSUInteger port);

  // Closes down the read/write streams.
  void CloseConnection();

  // Checks whether the write stream is ready for writing.
  BOOL WriteStreamCanAcceptBytes();

  // Writes the string to the write stream. This will block, so be sure to check
  // if it can write before calling this. Returns YES if the string was
  // successfully written.
  BOOL WriteString(NSString* string);

 private:
  // These static methods forward an invocation to the instance methods. The
  // last void pointer, named |self|, is the instance of this class.
  static void SocketAcceptCallback(CFSocketRef socket,
                                   CFSocketCallBackType callbackType,
                                   CFDataRef address,
                                   const void* data,
                                   void* self);
  static void ReadStreamCallback(CFReadStreamRef stream,
                                 CFStreamEventType eventType,
                                 void* self);  
  static void WriteStreamCallback(CFWriteStreamRef stream,
                                  CFStreamEventType eventType,
                                  void* self);

  void OnSocketAccept(CFSocketRef socket,
                      CFDataRef address,
                      const void* data);
  void OnReadStreamEvent(CFReadStreamRef stream, CFStreamEventType eventType);
  void OnWriteStreamEvent(CFWriteStreamRef stream, CFStreamEventType eventType);

  // Removes the read or write stream from the run loop, closes the stream,
  // releases the reference.
  void UnscheduleReadStream();
  void UnscheduleWriteStream();

  // Messages the NetworkConnection's delegate and takes ownership of |error|.
  void ReportError(CFErrorRef error);

  // The actual socket.
  CFSocketRef socket_;  // Strong.

  // The read and write streams that are scheduled on the |runLoop_|. Both are
  // weak and are owned by the run loop source.
  CFReadStreamRef readStream_;
  CFWriteStreamRef writeStream_;

  NetworkConnection* connection_;  // Weak, owns this.
  CFRunLoopRef runLoop_;  // Weak.
};


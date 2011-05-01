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

#import "NetworkConnection.h"
#import "NetworkConnectionPrivate.h"

#import "AppDelegate.h"
#import "LoggingController.h"
#include "NetworkCallbackController.h"

// Other Run Loop Callbacks ////////////////////////////////////////////////////

void PerformQuitSignal(void* info)
{
  NetworkConnection* obj = (NetworkConnection*)info;
  [obj performQuitSignal];
}

////////////////////////////////////////////////////////////////////////////////

@implementation NetworkConnection

@synthesize port = port_;
@synthesize connected = connected_;
@synthesize delegate = delegate_;

@synthesize readStream = readStream_;
@synthesize lastReadTransaction = lastReadTransaction_;
@synthesize currentPacket = currentPacket_;
@synthesize writeStream = writeStream_;
@synthesize lastWrittenTransaction = lastWrittenTransaction_;
@synthesize queuedWrites = queuedWrites_;

- (id)initWithPort:(NSUInteger)aPort
{
  if (self = [super init]) {
    port_ = aPort;
  }
  return self;
}

- (void)dealloc
{
  self.currentPacket = nil;
  [super dealloc];
}

/**
 * Kicks off the socket on another thread.
 */
- (void)connect
{
  if (thread_ && !connected_) {
    // A thread has been detached but the socket has yet to connect. Do not
    // spawn a new thread otherwise multiple threads will be blocked on the same
    // socket.
    return;
  }
  [NSThread detachNewThreadSelector:@selector(runNetworkThread) toTarget:self withObject:nil];
}

/**
 * Creates, connects to, and schedules a CFSocket.
 */
- (void)runNetworkThread
{
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

  thread_ = [NSThread currentThread];
  runLoop_ = [NSRunLoop currentRunLoop];
  callbackController_ = new NetworkCallbackController(self);

  // Create a source that is used to quit.
  CFRunLoopSourceContext quitContext = { 0 };
  quitContext.info = self;
  quitContext.perform = PerformQuitSignal;
  quitSource_ = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &quitContext);
  CFRunLoopAddSource([runLoop_ getCFRunLoop], quitSource_, kCFRunLoopCommonModes);

  callbackController_->OpenConnection(port_);

  CFRunLoopRun();

  thread_ = nil;
  runLoop_ = nil;
  delete callbackController_;
  callbackController_ = NULL;

  CFRunLoopSourceInvalidate(quitSource_);
  CFRelease(quitSource_);
  quitSource_ = NULL;

  [pool release];
}

/**
 * Called by SocketWrapper after the connection is successful. This immediately calls
 * -[SocketWrapper receive] to clear the way for communication, though the information
 * could be useful server information that we don't use right now.
 */
- (void)socketDidAccept
{
  connected_ = YES;
  transactionID = 1;
  lastReadTransaction_ = 0;
  lastWrittenTransaction_ = 0;
  self.queuedWrites = [NSMutableArray array];
  writeQueueLock_ = [NSRecursiveLock new];
  if ([delegate_ respondsToSelector:@selector(connectionDidAccept:)])
    [delegate_ performSelectorOnMainThread:@selector(connectionDidAccept:)
                                withObject:self
                             waitUntilDone:NO];
}

/**
 * Closes a socket and releases the ref.
 */
- (void)close
{
  if (thread_) {
    [thread_ cancel];
  }
  if (runLoop_ && quitSource_) {
    CFRunLoopSourceSignal(quitSource_);
    CFRunLoopWakeUp([runLoop_ getCFRunLoop]);
  }
}

/**
 * Quits the run loop and stops the thread.
 */
- (void)performQuitSignal
{
  self.queuedWrites = nil;
  connected_ = NO;
  [writeQueueLock_ release];

  if (runLoop_) {
    CFRunLoopStop([runLoop_ getCFRunLoop]);
  }

  callbackController_->CloseConnection();
}

/**
 * Notification that the socket disconnected.
 */
- (void)socketDisconnected
{
  if ([delegate_ respondsToSelector:@selector(connectionDidClose:)])
    [delegate_ connectionDidClose:self];
}

/**
 * Writes a command into the write stream. If the stream is ready for writing,
 * we do so immediately. If not, the command is queued and will be written
 * when the stream is ready.
 */
- (void)send:(NSString*)command
{
  if (lastReadTransaction_ >= lastWrittenTransaction_ && CFWriteStreamCanAcceptBytes(writeStream_)) {
    [self performSend:command];
  } else {
    [writeQueueLock_ lock];
    [queuedWrites_ addObject:command];
    [writeQueueLock_ unlock];
  }
  [self sendQueuedWrites];
}

/**
 * This will send a command to the debugger engine. It will append the
 * transaction ID automatically. It accepts a NSString command along with a
 * a variable number of arguments to substitute into the command, a la
 * +[NSString stringWithFormat:]. Returns the transaction ID as a NSNumber.
 */
- (NSNumber*)sendCommandWithFormat:(NSString*)format, ...
{
  // Collect varargs and format command.
  va_list args;
  va_start(args, format);
  NSString* command = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  
  NSNumber* callbackKey = [NSNumber numberWithInt:transactionID++];
  NSString* taggedCommand = [NSString stringWithFormat:@"%@ -i %@", [command autorelease], callbackKey];
  [self performSelector:@selector(send:)
               onThread:thread_
             withObject:taggedCommand
          waitUntilDone:connected_];
  
  return callbackKey;
}

/**
 * Certain commands expect encoded data to be the the last, unnamed parameter
 * of the command. In these cases, inserting the transaction ID at the end is
 * incorrect, so clients use this method to have |{txn}| replaced with the
 * transaction ID.
 */
- (NSNumber*)sendCustomCommandWithFormat:(NSString*)format, ...
{
  // Collect varargs and format command.
  va_list args;
  va_start(args, format);
  NSString* command = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
  va_end(args);  

  NSNumber* callbackKey = [NSNumber numberWithInt:transactionID++];
  NSString* taggedCommand = [command stringByReplacingOccurrencesOfString:@"{txn}"
                                                               withString:[callbackKey stringValue]];
  [self performSelector:@selector(send:)
               onThread:thread_
             withObject:taggedCommand
          waitUntilDone:connected_];
  
  return callbackKey;
}

/**
 * Given a file path, this returns a file:// URI and escapes any spaces for the
 * debugger engine.
 */
- (NSString*)escapedURIPath:(NSString*)path
{
  // Custon GDBp paths are fine.
  if ([[path substringToIndex:4] isEqualToString:@"gdbp"])
    return path;
  
  // Create a temporary URL that will escape all the nasty characters.
  NSURL* url = [NSURL fileURLWithPath:path];
  NSString* urlString = [url absoluteString];
  
  // Remove the host because this is a file:// URL;
  urlString = [urlString stringByReplacingOccurrencesOfString:[url host] withString:@""];
  
  // Escape % for use in printf-style NSString formatters.
  urlString = [urlString stringByReplacingOccurrencesOfString:@"%" withString:@"%%"];
  return urlString;
}

/**
 * Returns the transaction_id from an NSXMLDocument.
 */
- (NSInteger)transactionIDFromResponse:(NSXMLDocument*)response
{
  return [[[[response rootElement] attributeForName:@"transaction_id"] stringValue] intValue];
}

/**
 * Scans a command string for the transaction ID component. If it is not found,
 * returns NSNotFound.
 */
- (NSInteger)transactionIDFromCommand:(NSString*)command
{
  NSRange occurrence = [command rangeOfString:@"-i "];
  if (occurrence.location == NSNotFound)
    return NSNotFound;
  NSString* transaction = [command substringFromIndex:occurrence.location + occurrence.length];
  return [transaction intValue];
}

// Private /////////////////////////////////////////////////////////////////////
#pragma mark Private

// Delegate Thread-Safe Wrappers ///////////////////////////////////////////////

/**
 * Receives errors from the SocketWrapper and updates the display
 */
- (void)errorEncountered:(NSString*)error
{
  if (![delegate_ respondsToSelector:@selector(errorEncountered:)])
    return;
  [delegate_ performSelectorOnMainThread:@selector(errorEncountered:)
                              withObject:error
                           waitUntilDone:NO];
}

- (LogEntry*)recordSend:(NSString*)command
{
  LoggingController* logger = [[AppDelegate instance] loggingController];
  LogEntry* entry = [LogEntry newSendEntry:command];
  entry.lastReadTransactionID = lastReadTransaction_;
  entry.lastWrittenTransactionID = lastWrittenTransaction_;
  [logger performSelectorOnMainThread:@selector(recordEntry:)
                           withObject:entry
                        waitUntilDone:NO];
  return [entry autorelease];
}

- (LogEntry*)recordReceive:(NSString*)command
{
  LoggingController* logger = [[AppDelegate instance] loggingController];
  LogEntry* entry = [LogEntry newReceiveEntry:command];
  entry.lastReadTransactionID = lastReadTransaction_;
  entry.lastWrittenTransactionID = lastWrittenTransaction_;
  [logger performSelectorOnMainThread:@selector(recordEntry:)
                           withObject:entry
                        waitUntilDone:NO];
  return [entry autorelease];
}

// Stream Managers /////////////////////////////////////////////////////////////

/**
 * Callback from the CFReadStream that there is data waiting to be read.
 */
- (void)readStreamHasData
{
  const NSUInteger kBufferSize = 1024;
  UInt8 buffer[kBufferSize];
  CFIndex bufferOffset = 0;  // Starting point in |buffer| to work with.
  CFIndex bytesRead = CFReadStreamRead(readStream_, buffer, kBufferSize);
  const char* charBuffer = (const char*)buffer;
  
  // The read loop works by going through the buffer until all the bytes have
  // been processed.
  while (bufferOffset < bytesRead) {
    // Find the NULL separator, or the end of the string.
    NSUInteger partLength = 0;
    for (CFIndex i = bufferOffset; i < bytesRead && charBuffer[i] != '\0'; ++i, ++partLength) ;
    
    // If there is not a current packet, set some state.
    if (!self.currentPacket) {
      // Read the message header: the size.  This will be |partLength| bytes.
      packetSize_ = atoi(charBuffer + bufferOffset);
      currentPacketIndex_ = 0;
      self.currentPacket = [NSMutableString stringWithCapacity:packetSize_];
      bufferOffset += partLength + 1;  // Pass over the NULL byte.
      continue;  // Spin the loop to begin reading actual data.
    }
    
    // Substring the byte stream and append it to the packet string.
    CFStringRef bufferString = CFStringCreateWithBytes(kCFAllocatorDefault,
                                                       buffer + bufferOffset,  // Byte pointer, offset by start index.
                                                       partLength,  // Length.
                                                       kCFStringEncodingUTF8,
                                                       true);
    [self.currentPacket appendString:(NSString*)bufferString];
    CFRelease(bufferString);
    
    // Advance counters.
    currentPacketIndex_ += partLength;
    bufferOffset += partLength + 1;
    
    // If this read finished the packet, handle it and reset.
    if (currentPacketIndex_ >= packetSize_) {
      [self handlePacket:[[currentPacket_ retain] autorelease]];
      self.currentPacket = nil;
      packetSize_ = 0;
      currentPacketIndex_ = 0;
    }
  }
}

/**
 * Performs the packet handling of a raw string XML packet. From this point on,
 * the packets are associated with a transaction and are then dispatched.
 */
- (void)handlePacket:(NSString*)packet
{
  // Test if we can convert it into an NSXMLDocument.
  NSError* error = nil;
  NSXMLDocument* xml = [[NSXMLDocument alloc] initWithXMLString:currentPacket_
                                                        options:NSXMLDocumentTidyXML
                                                          error:&error];
  // TODO: Remove this assert before stable release. Flush out any possible
  // issues during testing.
  assert(xml);

  // Validate the transaction.
  NSInteger transaction = [self transactionIDFromResponse:xml];
  if (transaction < lastReadTransaction_) {
    NSLog(@"Transaction #%d is out of date (lastRead = %d). Dropping packet: %@",
        transaction, lastReadTransaction_, packet);
    return;
  }
  if (transaction != lastWrittenTransaction_) {
    NSLog(@"Transaction #%d received out of order. lastRead = %d, lastWritten = %d. Continuing.",
        transaction, lastReadTransaction_, lastWrittenTransaction_);
  }

  lastReadTransaction_ = transaction;

  // Log this receive event.
  LogEntry* log = [self recordReceive:currentPacket_];
  log.error = error;

  // Finally, dispatch the handler for this response.
  [self handleResponse:[xml autorelease]];  
}

- (void)handleResponse:(NSXMLDocument*)response
{
  // Check and see if there's an error.
  NSArray* error = [[response rootElement] elementsForName:@"error"];
  if ([error count] > 0) {
    NSLog(@"Xdebug error: %@", error);
    NSString* errorMessage = [[[[error objectAtIndex:0] children] objectAtIndex:0] stringValue];
    [self errorEncountered:errorMessage];
  }
  
  if ([[[response rootElement] name] isEqualToString:@"init"]) {
    connected_ = YES;
    [delegate_ performSelectorOnMainThread:@selector(handleInitialResponse:)
                                withObject:response
                             waitUntilDone:NO];
    return;
  }
  
  if ([delegate_ respondsToSelector:@selector(handleResponse:)])
    [delegate_ performSelectorOnMainThread:@selector(handleResponse:)
                                withObject:response
                             waitUntilDone:NO];
  
  [self sendQueuedWrites];
}

/**
 * This performs a blocking send. This should ONLY be called when we know we
 * have write access to the stream. We will busy wait in case we don't do a full
 * send.
 */
- (void)performSend:(NSString*)command
{
  // If this is an out-of-date transaction, do not bother sending it.
  NSInteger transaction = [self transactionIDFromCommand:command];
  if (transaction != NSNotFound && transaction < lastWrittenTransaction_)
    return;
  
  BOOL done = NO;
  
  char* string = (char*)[command UTF8String];
  size_t stringLength = strlen(string);
  
  // Busy wait while writing. BAADD. Should background this operation.
  while (!done) {
    if (CFWriteStreamCanAcceptBytes(writeStream_)){
      // Include the NULL byte in the string when we write.
      CFIndex bytesWritten = CFWriteStreamWrite(writeStream_, (UInt8*)string, stringLength + 1);
      if (bytesWritten < 0) {
        CFErrorRef error = CFWriteStreamCopyError(writeStream_);
        NSLog(@"Write stream error: %@", error);
        CFRelease(error);
      }
      // Incomplete write.
      else if (bytesWritten < static_cast<CFIndex>(strlen(string))) {
        // Adjust the buffer and wait for another chance to write.
        stringLength -= bytesWritten;
        memmove(string, string + bytesWritten, stringLength);
      }
      else {
        done = YES;
        // We need to scan the string to find the transactionID.
        if (transaction == NSNotFound) {
          NSLog(@"sent %@ without a transaction ID", command);
          continue;
        }
        lastWrittenTransaction_ = transaction;
      }
    }
  }

  // Log this trancation.
  [self recordSend:command];
}

/**
 * Checks if there are unsent commands in the |queuedWrites_| queue and sends
 * them if it's OK to do so. This will not block.
 */
- (void)sendQueuedWrites
{
  if (!connected_)
    return;

  [writeQueueLock_ lock];
  if (lastReadTransaction_ >= lastWrittenTransaction_ && [queuedWrites_ count] > 0) {
    NSString* command = [queuedWrites_ objectAtIndex:0];

    // We don't want to block because this is called from the main thread.
    // |-performSend:| busy waits when the stream is not ready. Bail out
    // before we do that becuase busy waiting is BAD.
    if (CFWriteStreamCanAcceptBytes(writeStream_)) {
      [self performSend:command];
      [queuedWrites_ removeObjectAtIndex:0];
    }
  }
  [writeQueueLock_ unlock];
}

@end

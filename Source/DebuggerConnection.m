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

#import "DebuggerConnection.h"

#import <sys/socket.h>
#import <netinet/in.h>

#import "AppDelegate.h"
#import "LoggingController.h"

// DebuggerConnection (Private) ////////////////////////////////////////////////

@interface DebuggerConnection ()

@property (assign) CFSocketRef socket;
@property (assign) CFReadStreamRef readStream;
@property NSUInteger lastReadTransaction;
@property (retain) NSMutableString* currentPacket;
@property (assign) CFWriteStreamRef writeStream;
@property NSUInteger lastWrittenTransaction;
@property (retain) NSMutableArray* queuedWrites;

- (void)connectInternal;

- (void)socketDidAccept;
- (void)socketDisconnected;
- (void)readStreamHasData;

- (void)performSend:(NSString*)command;
- (void)sendQueuedWrites;

- (void)handleResponse:(NSXMLDocument*)response;
- (void)handlePacket:(NSString*)packet;

- (void)errorEncountered:(NSString*)error;

@end

// CFNetwork Callbacks /////////////////////////////////////////////////////////

void ReadStreamCallback(CFReadStreamRef stream, CFStreamEventType eventType, void* connectionRaw)
{
	DebuggerConnection* connection = (DebuggerConnection*)connectionRaw;
	switch (eventType)
	{
		case kCFStreamEventHasBytesAvailable:
			[connection readStreamHasData];
			break;
			
		case kCFStreamEventErrorOccurred:
		{
			CFErrorRef error = CFReadStreamCopyError(stream);
			CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
			CFReadStreamClose(stream);
			CFRelease(stream);
			[connection errorEncountered:[[(NSError*)error autorelease] description]];
			break;
		}
			
		case kCFStreamEventEndEncountered:
			CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
			CFReadStreamClose(stream);
			CFRelease(stream);
			[connection socketDisconnected];
			break;
	};
}

void WriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType eventType, void* connectionRaw)
{
	DebuggerConnection* connection = (DebuggerConnection*)connectionRaw;
	switch (eventType)
	{
		case kCFStreamEventCanAcceptBytes:
			[connection sendQueuedWrites];
			break;
			
		case kCFStreamEventErrorOccurred:
		{
			CFErrorRef error = CFWriteStreamCopyError(stream);
			CFWriteStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
			CFWriteStreamClose(stream);
			CFRelease(stream);
			[connection errorEncountered:[[(NSError*)error autorelease] description]];
			break;
		}
			
		case kCFStreamEventEndEncountered:
			CFWriteStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
			CFWriteStreamClose(stream);
			CFRelease(stream);
			[connection socketDisconnected];
			break;
	}
}

void SocketAcceptCallback(CFSocketRef socket,
													CFSocketCallBackType callbackType,
													CFDataRef address,
													const void* data,
													void* connectionRaw)
{
	assert(callbackType == kCFSocketAcceptCallBack);
	NSLog(@"SocketAcceptCallback()");
	
	DebuggerConnection* connection = (DebuggerConnection*)connectionRaw;
	
	CFReadStreamRef readStream;
	CFWriteStreamRef writeStream;
	
	// Create the streams on the socket.
	CFStreamCreatePairWithSocket(kCFAllocatorDefault,
															 *(CFSocketNativeHandle*)data,  // Socket handle.
															 &readStream,  // Read stream in-pointer.
															 &writeStream);  // Write stream in-pointer.
	
	// Create struct to register callbacks for the stream.
	CFStreamClientContext context;
	context.version = 0;
	context.info = connection;
	context.retain = NULL;
	context.release = NULL;
	context.copyDescription = NULL;
	
	// Set the client of the read stream.
	CFOptionFlags readFlags =
	kCFStreamEventOpenCompleted |
	kCFStreamEventHasBytesAvailable |
	kCFStreamEventErrorOccurred |
	kCFStreamEventEndEncountered;
	if (CFReadStreamSetClient(readStream, readFlags, ReadStreamCallback, &context))
		// Schedule in run loop to do asynchronous communication with the engine.
		CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	else
		return;
	
	// Open the stream now that it's scheduled on the run loop.
	if (!CFReadStreamOpen(readStream))
	{
		CFStreamError error = CFReadStreamGetError(readStream);
		NSLog(@"error! %@", error);
		return;
	}
	
	// Set the client of the write stream.
	CFOptionFlags writeFlags =
	kCFStreamEventOpenCompleted |
	kCFStreamEventCanAcceptBytes |
	kCFStreamEventErrorOccurred |
	kCFStreamEventEndEncountered;
	if (CFWriteStreamSetClient(writeStream, writeFlags, WriteStreamCallback, &context))
		// Schedule it in the run loop to receive error information.
		CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	else
		return;
	
	// Open the write stream.
	if (!CFWriteStreamOpen(writeStream))
	{
		CFStreamError error = CFWriteStreamGetError(writeStream);
		NSLog(@"error! %@", error);
		return;
	}
	
	connection.readStream = readStream;
	connection.writeStream = writeStream;
	[connection socketDidAccept];
}

////////////////////////////////////////////////////////////////////////////////

@implementation DebuggerConnection

@synthesize port = port_;
@synthesize connected = connected_;
@synthesize delegate = delegate_;

@synthesize socket = socket_;
@synthesize readStream = readStream_;
@synthesize lastReadTransaction = lastReadTransaction_;
@synthesize currentPacket = currentPacket_;
@synthesize writeStream = writeStream_;
@synthesize lastWrittenTransaction = lastWrittenTransaction_;
@synthesize queuedWrites = queuedWrites_;

- (id)initWithPort:(NSUInteger)aPort
{
	if (self = [super init])
	{
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
	[NSThread detachNewThreadSelector:@selector(connectInternal) toTarget:self withObject:nil];
}

/**
 * Creates, connects to, and schedules a CFSocket.
 */
- (void)connectInternal
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	runLoop_ = [NSRunLoop currentRunLoop];

	// Pass ourselves to the callback so we don't have to use ugly globals.
	CFSocketContext context;
	context.version = 0;
	context.info = self;
	context.retain = NULL;
	context.release = NULL;
	context.copyDescription = NULL;
	
	// Create the address structure.
	struct sockaddr_in address;
	memset(&address, 0, sizeof(address));
	address.sin_len = sizeof(address);
	address.sin_family = AF_INET;
	address.sin_port = htons(port_);
	address.sin_addr.s_addr = htonl(INADDR_ANY);		
	
	// Create the socket signature.
	CFSocketSignature signature;
	signature.protocolFamily = PF_INET;
	signature.socketType = SOCK_STREAM;
	signature.protocol = IPPROTO_TCP;
	signature.address = (CFDataRef)[NSData dataWithBytes:&address length:sizeof(address)];
	
	socket_ = CFSocketCreateWithSocketSignature(kCFAllocatorDefault,
																							&signature,  // Socket signature.
																							kCFSocketAcceptCallBack,  // Callback types.
																							SocketAcceptCallback,  // Callout function pointer.
																							&context);  // Context to pass to callout.
	if (!socket_)
	{
		[self errorEncountered:@"Could not open socket."];
		return;
	}
	
	// Allow old, yet-to-be recycled sockets to be reused.
	BOOL yes = YES;
	setsockopt(CFSocketGetNative(socket_), SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(BOOL));
	
	// Schedule the socket on the run loop.
	CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket_, 0);
	CFRunLoopAddSource([runLoop_ getCFRunLoop], source, kCFRunLoopCommonModes);
	CFRelease(source);

	[runLoop_ run];

	[pool drain];
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
	self.queuedWrites = [NSMutableArray array];
	writeQueueLock_ = [NSRecursiveLock new];
}

/**
 * Closes a socket and releases the ref.
 */
- (void)close
{
	if (runLoop_) {
		CFRunLoopStop([runLoop_ getCFRunLoop]);
	}

	// The socket goes down, so do the streams, which clean themselves up.
	if (socket_) {
		CFSocketInvalidate(socket_);
		CFRelease(socket_);
	}
	self.queuedWrites = nil;
	[writeQueueLock_ release];
}

/**
 * Notification that the socket disconnected.
 */
- (void)socketDisconnected
{
	[self close];
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
	[self send:[NSString stringWithFormat:@"%@ -i %@", [command autorelease], callbackKey]];
	
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

/**
 * Receives errors from the SocketWrapper and updates the display
 */
- (void)errorEncountered:(NSString*)error
{
	[delegate_ errorEncountered:error];
}

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
	while (bufferOffset < bytesRead)
	{
		// Find the NULL separator, or the end of the string.
		NSUInteger partLength = 0;
		for (NSUInteger i = bufferOffset; i < bytesRead && charBuffer[i] != '\0'; ++i, ++partLength) ;
		
		// If there is not a current packet, set some state.
		if (!self.currentPacket)
		{
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
		NSLog(@"cpi %d ps %d br %d ds %d", currentPacketIndex_, packetSize_, bytesRead, partLength);
		if (currentPacketIndex_ >= packetSize_)
		{
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
	NSXMLDocument* xmlTest = [[NSXMLDocument alloc] initWithXMLString:currentPacket_ options:NSXMLDocumentTidyXML error:&error];
	
	// Try to recover if we encountered an error.
	if (!xmlTest)
	{
		// We do not want to starve the write queue, so manually parse out the
		// transaction ID.
		NSRange location = [currentPacket_ rangeOfString:@"transaction_id"];
		if (location.location != NSNotFound)
		{
			NSUInteger start = location.location + location.length;
			NSUInteger end = start;
			
			NSCharacterSet* numericSet = [NSCharacterSet decimalDigitCharacterSet];
			
			// Loop over the characters after the attribute name to extract the ID.
			while (end < [currentPacket_ length])
			{
				unichar c = [currentPacket_ characterAtIndex:end];
				if ([numericSet characterIsMember:c])
				{
					// If this character is numeric, extend the range to substring.
					++end;
				}
				else
				{
					if (start == end)
					{
						// If this character is nonnumeric and we have nothing in the
						// range, skip this character.
						++start;
						++end;
					}
					else
					{
						// We've moved past the numeric ID so we should stop searching.
						break;
					}
				}
			}
			
			// If we were able to extract the transaction ID, update the last read.
			NSRange substringRange = NSMakeRange(start, end - start);
			NSString* transactionStr = [currentPacket_ substringWithRange:substringRange];
			if ([transactionStr length])
				lastReadTransaction_ = [transactionStr intValue];
		}
		
		// Otherwise, assume +1 and hope it works.
		++lastReadTransaction_;
	}
	else
	{
		// See if the transaction can be parsed out.
		NSInteger transaction = [self transactionIDFromResponse:xmlTest];
		if (transaction < lastReadTransaction_)
		{
			NSLog(@"tx = %d vs %d", transaction, lastReadTransaction_);
			NSLog(@"out of date transaction %@", packet);
			return;
		}
		
		if (transaction != lastWrittenTransaction_)
			NSLog(@"txn %d <> %d last written, %d last read", transaction, lastWrittenTransaction_, lastReadTransaction_);
		
		lastReadTransaction_ = transaction;
	}
	
	// Log this receive event.
	LoggingController* logger = [(AppDelegate*)[NSApp delegate] loggingController];
	LogEntry* log = [logger recordReceive:currentPacket_];
	log.error = error;
	log.lastWrittenTransactionID = lastWrittenTransaction_;
	log.lastReadTransactionID = lastReadTransaction_;
	
	// Finally, dispatch the handler for this response.
	[self handleResponse:[xmlTest autorelease]];	
}

- (void)handleResponse:(NSXMLDocument*)response
{
	// Check and see if there's an error.
	NSArray* error = [[response rootElement] elementsForName:@"error"];
	if ([error count] > 0)
	{
		NSLog(@"Xdebug error: %@", error);
		[delegate_ errorEncountered:[[[[error objectAtIndex:0] children] objectAtIndex:0] stringValue]];
	}
	
	if ([[[response rootElement] name] isEqualToString:@"init"])
	{
		[delegate_ handleInitialResponse:response];
		return;
	}
	
	if ([delegate_ respondsToSelector:@selector(handleResponse:)])
		[(NSObject*)delegate_ performSelectorOnMainThread:@selector(handleResponse:) withObject:response waitUntilDone:NO];
	
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
	int stringLength = strlen(string);
	
	// Busy wait while writing. BAADD. Should background this operation.
	while (!done)
	{
		if (CFWriteStreamCanAcceptBytes(writeStream_))
		{
			// Include the NULL byte in the string when we write.
			int bytesWritten = CFWriteStreamWrite(writeStream_, (UInt8*)string, stringLength + 1);
			if (bytesWritten < 0)
			{
				NSLog(@"write error");
			}
			// Incomplete write.
			else if (bytesWritten < strlen(string))
			{
				// Adjust the buffer and wait for another chance to write.
				stringLength -= bytesWritten;
				memmove(string, string + bytesWritten, stringLength);
			}
			else
			{
				done = YES;
				
				// We need to scan the string to find the transactionID.
				if (transaction == NSNotFound)
				{
					NSLog(@"sent %@ without a transaction ID", command);
					continue;
				}
				lastWrittenTransaction_ = transaction;
			}
		}
	}
	
	// Log this trancation.
	LoggingController* logger = [(AppDelegate*)[NSApp delegate] loggingController];
	LogEntry* log = [logger recordSend:command];
	log.lastWrittenTransactionID = lastWrittenTransaction_;
	log.lastReadTransactionID = lastReadTransaction_;
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
	if (lastReadTransaction_ >= lastWrittenTransaction_ && [queuedWrites_ count] > 0)
	{
		NSString* command = [queuedWrites_ objectAtIndex:0];
		
		// We don't want to block because this is called from the main thread.
		// |-performSend:| busy waits when the stream is not ready. Bail out
		// before we do that becuase busy waiting is BAD.
		if (CFWriteStreamCanAcceptBytes(writeStream_))
		{
			[self performSend:command];
			[queuedWrites_ removeObjectAtIndex:0];
		}
	}
	[writeQueueLock_ unlock];
}

@end

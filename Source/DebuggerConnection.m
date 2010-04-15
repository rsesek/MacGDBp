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

#import <sys/socket.h>
#import <netinet/in.h>

#import "DebuggerConnection.h"

#import "AppDelegate.h"
#import "LoggingController.h"

// GDBpConnection (Private) ////////////////////////////////////////////////////

@interface DebuggerConnection ()
@property (readwrite, copy) NSString* status;
@property (assign) CFSocketRef socket;
@property (assign) CFReadStreamRef readStream;
@property NSUInteger lastReadTransaction;
@property (retain) NSMutableString* currentPacket;
@property (assign) CFWriteStreamRef writeStream;
@property NSUInteger lastWrittenTransaction;
@property (retain) NSMutableArray* queuedWrites;

- (void)connect;
- (void)close;
- (void)socketDidAccept;
- (void)socketDisconnected;
- (void)readStreamHasData;
- (void)send:(NSString*)command;
- (void)performSend:(NSString*)command;
- (void)errorEncountered:(NSString*)error;

- (void)handleResponse:(NSXMLDocument*)response;
- (void)initReceived:(NSXMLDocument*)response;
- (void)updateStatus:(NSXMLDocument*)response;
- (void)debuggerStep:(NSXMLDocument*)response;
- (void)rebuildStack:(NSXMLDocument*)response;
- (void)getStackFrame:(NSXMLDocument*)response;
- (void)setSource:(NSXMLDocument*)response;
- (void)contextsReceived:(NSXMLDocument*)response;
- (void)variablesReceived:(NSXMLDocument*)response;
- (void)propertiesReceived:(NSXMLDocument*)response;

- (NSNumber*)sendCommandWithCallback:(SEL)callback format:(NSString*)format, ...;

- (void)sendQueuedWrites;

- (NSString*)escapedURIPath:(NSString*)path;
- (NSInteger)transactionIDFromResponse:(NSXMLDocument*)response;
- (NSInteger)transactionIDFromCommand:(NSString*)command;
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

// GDBpConnection //////////////////////////////////////////////////////////////

@implementation DebuggerConnection
@synthesize socket = socket_;
@synthesize readStream = readStream_;
@synthesize lastReadTransaction = lastReadTransaction_;
@synthesize currentPacket = currentPacket_;
@synthesize writeStream = writeStream_;
@synthesize lastWrittenTransaction = lastWrittenTransaction_;
@synthesize queuedWrites = queuedWrites_;
@synthesize status;
@synthesize delegate;

/**
 * Creates a new DebuggerConnection and initializes the socket from the given connection
 * paramters.
 */
- (id)initWithPort:(NSUInteger)aPort
{
	if (self = [super init])
	{
		port = aPort;
		connected = NO;
		
		[[BreakpointManager sharedManager] setConnection:self];
		[self connect];
	}
	return self;
}

/**
 * Deallocates the object
 */
- (void)dealloc
{
	[self close];
	self.currentPacket = nil;
	
	[super dealloc];
}


// Getters /////////////////////////////////////////////////////////////////////
#pragma mark Getters

/**
 * Gets the port number
 */
- (NSUInteger)port
{
	return port;
}

/**
 * Returns the name of the remote host
 */
- (NSString*)remoteHost
{
	if (!connected)
	{
		return @"(DISCONNECTED)";
	}
	// TODO: Either impl or remove.
	return @"";
}

/**
 * Returns whether or not we have an active connection
 */
- (BOOL)isConnected
{
	return connected;
}

// Commands ////////////////////////////////////////////////////////////////////
#pragma mark Commands

/**
 * Reestablishes communication with the remote debugger so that a new connection doesn't have to be
 * created every time you want to debug a page
 */
- (void)reconnect
{
	[self close];
	self.status = @"Connecting";
	[self connect];
}

/**
 * Tells the debugger to continue running the script. Returns the current stack frame.
 */
- (void)run
{
	[self sendCommandWithCallback:@selector(debuggerStep:) format:@"run"];
}

/**
 * Tells the debugger to step into the current command.
 */
- (void)stepIn
{
	[self sendCommandWithCallback:@selector(debuggerStep:) format:@"step_into"];
}

/**
 * Tells the debugger to step out of the current context
 */
- (void)stepOut
{
	[self sendCommandWithCallback:@selector(debuggerStep:) format:@"step_out"];
}

/**
 * Tells the debugger to step over the current function
 */
- (void)stepOver
{
	[self sendCommandWithCallback:@selector(debuggerStep:) format:@"step_over"];
}

/**
 * Tells the debugger engine to get a specifc property. This also takes in the NSXMLElement
 * that requested it so that the child can be attached.
 */
- (NSInteger)getProperty:(NSString*)property
{
	[self sendCommandWithCallback:@selector(propertiesReceived:) format:@"property_get -n \"%@\"", property];
}

// Breakpoint Management ///////////////////////////////////////////////////////
#pragma mark Breakpoints

/**
 * Send an add breakpoint command
 */
- (void)addBreakpoint:(Breakpoint*)bp
{
	if (!connected)
		return;
	
	NSString* file = [self escapedURIPath:[bp transformedPath]];
	NSNumber* transaction = [self sendCommandWithCallback:@selector(breakpointReceived:)
												   format:@"breakpoint_set -t line -f %@ -n %i", file, [bp line]];
	[callbackContext_ setObject:bp forKey:transaction];
}

/**
 * Removes a breakpoint
 */
- (void)removeBreakpoint:(Breakpoint*)bp
{
	if (!connected)
	{
		return;
	}
	
	[self sendCommandWithCallback:nil format:@"breakpoint_remove -d %i", [bp debuggerId]];
}


// Socket and Stream Callbacks /////////////////////////////////////////////////
#pragma mark Callbacks

/**
 * Called by SocketWrapper after the connection is successful. This immediately calls
 * -[SocketWrapper receive] to clear the way for communication, though the information
 * could be useful server information that we don't use right now.
 */
- (void)socketDidAccept
{
	connected = YES;
	transactionID = 1;
	stackFrames_ = [[NSMutableDictionary alloc] init];
	self.queuedWrites = [NSMutableArray array];
	writeQueueLock_ = [NSRecursiveLock new];
	callTable_ = [NSMutableDictionary new];
	callbackContext_ = [NSMutableDictionary new];
}

/**
 * Receives errors from the SocketWrapper and updates the display
 */
- (void)errorEncountered:(NSString*)error
{
	[delegate errorEncountered:error];
}

/**
 * Creates, connects to, and schedules a CFSocket.
 */
- (void)connect
{
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
	address.sin_port = htons(port);
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
	CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
	CFRelease(source);
	
	self.status = @"Connecting";
}

/**
 * Closes a socket and releases the ref.
 */
- (void)close
{
	// The socket goes down, so do the streams, which clean themselves up.
	CFSocketInvalidate(socket_);
	CFRelease(socket_);
	[stackFrames_ release];
	self.queuedWrites = nil;
	[writeQueueLock_ release];
	[callTable_ release];
	[callbackContext_ release];
}

/**
 * Notification that the socket disconnected.
 */
- (void)socketDisconnected
{
	[self close];
	[delegate debuggerDisconnected];
}

/**
 * Callback from the CFReadStream that there is data waiting to be read.
 */
- (void)readStreamHasData
{
	UInt8 buffer[1024];
	CFIndex bytesRead = CFReadStreamRead(readStream_, buffer, 1024);
	const char* charBuffer = (const char*)buffer;
	
	// We haven't finished reading a packet, so just read more data in.
	if (currentPacketIndex_ < packetSize_)
	{
		currentPacketIndex_ += bytesRead;
		CFStringRef bufferString = CFStringCreateWithBytes(kCFAllocatorDefault,
														   buffer,
														   bytesRead,
														   kCFStringEncodingUTF8,
														   true);
		[self.currentPacket appendString:(NSString*)bufferString];
		CFRelease(bufferString);
	}
	// Time to read a new packet.
	else
	{
		// Read the message header: the size.
		packetSize_ = atoi(charBuffer);
		currentPacketIndex_ = bytesRead - strlen(charBuffer);
		CFStringRef bufferString = CFStringCreateWithBytes(kCFAllocatorDefault,
														   buffer + strlen(charBuffer) + 1,
														   bytesRead - strlen(charBuffer) - 1,
														   kCFStringEncodingUTF8,
														   true);
		self.currentPacket = [NSMutableString stringWithString:(NSString*)bufferString];
		CFRelease(bufferString);
	}
	
	// We have finished reading the packet.
	if (currentPacketIndex_ >= packetSize_)
	{
		packetSize_ = 0;
		currentPacketIndex_ = 0;
		
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
				NSString* transaction = [currentPacket_ substringWithRange:substringRange];
				if ([transaction length])
					lastReadTransaction_ = [transaction intValue];
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
				NSLog(@"out of date transaction %@", xmlTest);
				return;
			}
			
			if (transaction != lastWrittenTransaction_)
				NSLog(@"txn %d(%d) <> %d doesn't match last written", transaction, lastReadTransaction_, lastWrittenTransaction_);
			
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
}

/**
 * Writes a command into the write stream. If the stream is ready for writing,
 * we do so immediately. If not, the command is queued and will be written
 * when the stream is ready.
 */
- (void)send:(NSString*)command
{
	if (CFWriteStreamCanAcceptBytes(writeStream_))
		[self performSend:command];
	else
		[queuedWrites_ addObject:command];
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

- (void)handleResponse:(NSXMLDocument*)response
{
	// Check and see if there's an error.
	NSArray* error = [[response rootElement] elementsForName:@"error"];
	if ([error count] > 0)
	{
		NSLog(@"Xdebug error: %@", error);
		[delegate errorEncountered:[[[[error objectAtIndex:0] children] objectAtIndex:0] stringValue]];
	}

	if ([[[response rootElement] name] isEqualToString:@"init"])
	{
		[self initReceived:response];
		return;
	}
	
	NSString* callbackStr = [callTable_ objectForKey:[NSNumber numberWithInt:lastReadTransaction_]];
	if (callbackStr)
	{
		SEL callback = NSSelectorFromString(callbackStr);
		[self performSelector:callback withObject:response];
	}
	
	[self sendQueuedWrites];
}

// Specific Response Handlers //////////////////////////////////////////////////
#pragma mark Response Handlers

/**
 * Initial packet received. We've started a brand-new connection to the engine.
 */
- (void)initReceived:(NSXMLDocument*)response
{
	// Register any breakpoints that exist offline.
	for (Breakpoint* bp in [[BreakpointManager sharedManager] breakpoints])
		[self addBreakpoint:bp];
	
	// Load the debugger to make it look active.
	[delegate debuggerConnected];
	
	// TODO: update the status.
}

/**
 * Receiver for status updates. This just freshens up the UI.
 */
- (void)updateStatus:(NSXMLDocument*)response
{
	self.status = [[[[response rootElement] attributeForName:@"status"] stringValue] capitalizedString];
	if (status == nil || [status isEqualToString:@"Stopped"] || [status isEqualToString:@"Stopping"])
	{
		connected = NO;
		[self close];
		[delegate debuggerDisconnected];
		
		self.status = @"Stopped";
	}
}

/**
 * Step in/out/over and run all take this path. We first get the status of the
 * debugger and then request fresh stack information.
 */
- (void)debuggerStep:(NSXMLDocument*)response
{
	[self updateStatus:response];
	if (!connected)
		return;
	
	// If this is the run command, tell the delegate that a bunch of updates
	// are coming. Also remove all existing stack routes and request a new stack.
	// TODO: figure out if we can not clobber the stack every time.
	NSString* command = [[[response rootElement] attributeForName:@"command"] stringValue];
	if (YES || [command isEqualToString:@"run"])
	{
		if ([delegate respondsToSelector:@selector(clobberStack)])
			[delegate clobberStack];
		[stackFrames_ removeAllObjects];
		stackFirstTransactionID_ = [[self sendCommandWithCallback:@selector(rebuildStack:) format:@"stack_depth"] intValue];
	}
}

/**
 * We ask for the stack_depth and now we clobber the stack and start rebuilding
 * it.
 */
- (void)rebuildStack:(NSXMLDocument*)response
{
	NSInteger depth = [[[[response rootElement] attributeForName:@"depth"] stringValue] intValue];
	
	if (stackFirstTransactionID_ == [self transactionIDFromResponse:response])
		stackDepth_ = depth;
	
	// We now need to alloc a bunch of stack frames and get the basic information
	// for them.
	for (NSInteger i = 0; i < depth; i++)
	{
		// Use the transaction ID to create a routing path.
		NSNumber* routingID = [self sendCommandWithCallback:@selector(getStackFrame:) format:@"stack_get -d %d", i];
		[stackFrames_ setObject:[StackFrame alloc] forKey:routingID];
	}
}

/**
 * The initial rebuild of the stack frame. We now have enough to initialize
 * a StackFrame object.
 */
- (void)getStackFrame:(NSXMLDocument*)response
{
	// Get the routing information.
	NSInteger routingID = [self transactionIDFromResponse:response];
	if (routingID < stackFirstTransactionID_)
		return;
	NSNumber* routingNumber = [NSNumber numberWithInt:routingID];
	
	// Make sure we initialized this frame in our last |-rebuildStack:|.
	StackFrame* frame = [stackFrames_ objectForKey:routingNumber];
	if (!frame)
		return;
	
	NSXMLElement* xmlframe = [[[response rootElement] children] objectAtIndex:0];
	
	// Initialize the stack frame.
	[frame initWithIndex:[[[xmlframe attributeForName:@"level"] stringValue] intValue]
			withFilename:[[xmlframe attributeForName:@"filename"] stringValue]
			  withSource:nil
				  atLine:[[[xmlframe attributeForName:@"lineno"] stringValue] intValue]
			  inFunction:[[xmlframe attributeForName:@"where"] stringValue]
		   withVariables:nil];
	
	// Get the source code of the file. Escape % in URL chars.
	NSString* escapedFilename = [frame.filename stringByReplacingOccurrencesOfString:@"%" withString:@"%%"];
	NSNumber* transaction = [self sendCommandWithCallback:@selector(setSource:) format:@"source -f %@", escapedFilename];
	[callbackContext_ setObject:routingNumber forKey:transaction];
	
	// Get the names of all the contexts.
	transaction = [self sendCommandWithCallback:@selector(contextsReceived:) format:@"context_names -d %d", frame.index];
	[callbackContext_ setObject:routingNumber forKey:transaction];
	
	if ([delegate respondsToSelector:@selector(newStackFrame:)])
		[delegate newStackFrame:frame];
}

/**
 * Callback for setting the source of a file while rebuilding a specific stack
 * frame.
 */
- (void)setSource:(NSXMLDocument*)response
{
	NSNumber* transaction = [NSNumber numberWithInt:[self transactionIDFromResponse:response]];
	if ([transaction intValue] < stackFirstTransactionID_)
		return;
	NSNumber* routingNumber = [callbackContext_ objectForKey:transaction];
	if (!routingNumber)
		return;
	
	[callbackContext_ removeObjectForKey:transaction];
	StackFrame* frame = [stackFrames_ objectForKey:routingNumber];
	if (!frame)
		return;
	
	frame.source = [[response rootElement] value];
	
	if ([delegate respondsToSelector:@selector(sourceUpdated:)])
		[delegate sourceUpdated:frame];
}

/**
 * Enumerates all the contexts of a given stack frame. We then in turn get the
 * contents of each one of these contexts.
 */
- (void)contextsReceived:(NSXMLDocument*)response
{
	// Get the stack frame's routing ID and use it again.
	NSNumber* receivedTransaction = [NSNumber numberWithInt:[self transactionIDFromResponse:response]];
	if ([receivedTransaction intValue] < stackFirstTransactionID_)
		return;
	NSNumber* routingID = [callbackContext_ objectForKey:receivedTransaction];
	if (!routingID)
		return;
	
	// Get the stack frame by the |routingID|.
	StackFrame* frame = [stackFrames_ objectForKey:routingID];
	
	NSXMLElement* contextNames = [response rootElement];
	for (NSXMLElement* context in [contextNames children])
	{
		NSInteger cid = [[[context attributeForName:@"id"] stringValue] intValue];
		
		// Fetch each context's variables.
		NSNumber* transaction = [self sendCommandWithCallback:@selector(variablesReceived:)
													   format:@"context_get -d %d -c %d", frame.index, cid];
		[callbackContext_ setObject:routingID forKey:transaction];
	}
}

/**
 * Receives the variables from the context and attaches them to the stack frame.
 */
- (void)variablesReceived:(NSXMLDocument*)response
{
	// Get the stack frame's routing ID and use it again.
	NSInteger transaction = [self transactionIDFromResponse:response];
	if (transaction < stackFirstTransactionID_)
		return;
	NSNumber* receivedTransaction = [NSNumber numberWithInt:transaction];
	NSNumber* routingID = [callbackContext_ objectForKey:receivedTransaction];
	if (!routingID)
		return;
	
	// Get the stack frame by the |routingID|.
	StackFrame* frame = [stackFrames_ objectForKey:routingID];
	
	NSMutableArray* variables = [NSMutableArray array];
	
	// Merge the frame's existing variables.
	if (frame.variables)
		[variables addObjectsFromArray:frame.variables];
	
	// Add these new variables.
	NSArray* addVariables = [[response rootElement] children];
	if (addVariables)
		[variables addObjectsFromArray:addVariables];
	
	frame.variables = variables;
}

/**
 * Callback from a |-getProperty:| request.
 */
- (void)propertiesReceived:(NSXMLDocument*)response
{
	NSInteger transaction = [self transactionIDFromResponse:response];
	
	/*
	 <response>
		 <property> <!-- this is the one we requested -->
			 <property ... /> <!-- these are what we want -->
		 </property>
	 </repsonse>
	 */
	
	// Detach all the children so we can insert them into another document.
	NSXMLElement* parent = (NSXMLElement*)[[response rootElement] childAtIndex:0];
	NSArray* children = [parent children];
	[parent setChildren:nil];
	
	[delegate receivedProperties:children forTransaction:transaction];
}

/**
 * Callback for setting a breakpoint.
 */
- (void)breakpointReceived:(NSXMLDocument*)response
{
	NSNumber* transaction = [NSNumber numberWithInt:[self transactionIDFromResponse:response]];
	Breakpoint* bp = [callbackContext_ objectForKey:transaction];
	if (!bp)
		return;
	
	[callbackContext_ removeObjectForKey:callbackContext_];
	[bp setDebuggerId:[[[[response rootElement] attributeForName:@"id"] stringValue] intValue]];
}

#pragma mark Private

/**
 * This will send a command to the debugger engine. It will append the
 * transaction ID automatically. It accepts a NSString command along with a
 * a variable number of arguments to substitute into the command, a la
 * +[NSString stringWithFormat:]. Returns the transaction ID as a NSNumber.
 */
- (NSNumber*)sendCommandWithCallback:(SEL)callback format:(NSString*)format, ...
{
	// Collect varargs and format command.
	va_list args;
	va_start(args, format);
	NSString* command = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	
	NSNumber* callbackKey = [NSNumber numberWithInt:transactionID++];
	if (callback)
		[callTable_ setObject:NSStringFromSelector(callback) forKey:callbackKey];
	
	[self send:[NSString stringWithFormat:@"%@ -i %@", [command autorelease], callbackKey]];
	
	return callbackKey;
}

/**
 * Checks if there are unsent commands in the |queuedWrites_| queue and sends
 * them if it's OK to do so. This will not block.
 */
- (void)sendQueuedWrites
{
	if (!connected)
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

@end

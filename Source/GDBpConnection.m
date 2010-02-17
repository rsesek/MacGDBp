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

#import "GDBpConnection.h"

#import "AppDelegate.h"


typedef enum _StackFrameComponents
{
	kStackFrameContexts,
	kStackFrameSource,
	kStackFrameVariables
} StackFrameComponent;

// GDBpConnection (Private) ////////////////////////////////////////////////////

@interface GDBpConnection ()
@property (readwrite, copy) NSString* status;
@property (assign) CFSocketRef socket;
@property (assign) CFReadStreamRef readStream;
@property int lastReadTransaction;
@property (retain) NSMutableString* currentPacket;
@property (assign) CFWriteStreamRef writeStream;
@property int lastWrittenTransaction;
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
- (void)handleRouted:(NSArray*)path response:(NSXMLDocument*)response;

- (NSString*)createCommand:(NSString*)cmd, ...;
- (NSString*)createRouted:(NSString*)routingID command:(NSString*)cmd, ...;

- (void)sendQueuedWrites;

- (StackFrame*)createStackFrame:(int)depth;
- (NSString*)escapedURIPath:(NSString*)path;
@end

// CFNetwork Callbacks /////////////////////////////////////////////////////////

void ReadStreamCallback(CFReadStreamRef stream, CFStreamEventType eventType, void* connectionRaw)
{
	GDBpConnection* connection = (GDBpConnection*)connectionRaw;
	switch (eventType)
	{
		case kCFStreamEventHasBytesAvailable:
			NSLog(@"About to read.");
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
	GDBpConnection* connection = (GDBpConnection*)connectionRaw;
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
	
	GDBpConnection* connection = (GDBpConnection*)connectionRaw;
	
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

@implementation GDBpConnection
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
- (id)initWithPort:(int)aPort
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

/**
 * Gets the port number
 */
- (int)port
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
}

/**
 * Receives errors from the SocketWrapper and updates the display
 */
- (void)errorEncountered:(NSString*)error
{
	[delegate errorEncountered:error];
}

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
 * Creates an entirely new stack and returns it as an array of StackFrame objects.
 */
- (NSArray*)getCurrentStack
{
	NSMutableArray* stack = [NSMutableArray array];
	NSLog(@"NOTIMPLEMENTED(): %s", _cmd);
	return stack;
}

/**
 * Tells the debugger to continue running the script. Returns the current stack frame.
 */
- (void)run
{
	[self send:[self createCommand:@"run"]];
}

/**
 * Tells the debugger to step into the current command.
 */
- (void)stepIn
{
	[self send:[self createCommand:@"step_into"]];
}

/**
 * Tells the debugger to step out of the current context
 */
- (void)stepOut
{
	[self send:[self createCommand:@"step_out"]];
}

/**
 * Tells the debugger to step over the current function
 */
- (void)stepOver
{
	[self send:[self createCommand:@"step_over"]];
}

/**
 * Tells the debugger engine to get a specifc property. This also takes in the NSXMLElement
 * that requested it so that the child can be attached.
 */
- (NSArray*)getProperty:(NSString*)property
{
	[socket send:[self createCommand:[NSString stringWithFormat:@"property_get -n \"%@\"", property]]];
	
	NSXMLDocument* doc = [self processData:[socket receive]];
	
	/*
	 <response>
		<property> <!-- this is the one we requested -->
			<property ... /> <!-- these are what we want -->
		</property>
	 </repsonse>
	 */
	
	// we now have to detach all the children so we can insert them into another document
	NSXMLElement* parent = (NSXMLElement*)[[doc rootElement] childAtIndex:0];
	NSArray* children = [parent children];
	[parent setChildren:nil];
	return children;
}

#pragma mark Breakpoints

/**
 * Send an add breakpoint command
 */
- (void)addBreakpoint:(Breakpoint*)bp
{
	if (!connected)
		return;
	
	NSString* file = [self escapedURIPath:[bp transformedPath]];
	NSString* cmd = [self createCommand:[NSString stringWithFormat:@"breakpoint_set -t line -f %@ -n %i", file, [bp line]]];
	[socket send:cmd];
	NSXMLDocument* info = [self processData:[socket receive]];
	[bp setDebuggerId:[[[[info rootElement] attributeForName:@"id"] stringValue] intValue]];
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
	
	[socket send:[self createCommand:[NSString stringWithFormat:@"breakpoint_remove -d %i", [bp debuggerId]]]];
	[socket receive];
}

#pragma mark Socket and Stream Callbacks

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
		[currentPacket_ appendFormat:@"%s", buffer];
		currentPacketIndex_ += bytesRead;
	}
	// Time to read a new packet.
	else
	{
		// Read the message header: the size.
		packetSize_ = atoi(charBuffer);
		currentPacketIndex_ = bytesRead - strlen(charBuffer);
		self.currentPacket = [NSMutableString stringWithFormat:@"%s", buffer + strlen(charBuffer) + 1];
	}
	
	// We have finished reading the packet.
	if (currentPacketIndex_ >= packetSize_)
	{
		packetSize_ = 0;
		currentPacketIndex_ = 0;
		
		// Test if we can convert it into an NSXMLDocument.
		NSError* error = nil;
		NSXMLDocument* xmlTest = [[NSXMLDocument alloc] initWithXMLString:currentPacket_ options:NSXMLDocumentTidyXML error:&error];
		if (error)
		{
			NSLog(@"Could not parse XML? --- %@", error);
			NSLog(@"Error UserInfo: %@", [error userInfo]);
			NSLog(@"This is the XML Document: %@", currentPacket_);
			return;
		}		
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
	if (lastReadTransaction_ >= lastWrittenTransaction_ && CFWriteStreamCanAcceptBytes(writeStream_))
		[self performSend:command];
	else
		[queuedWrites_ addObject:command];
}

/**
 * This performs a blocking send. This should ONLY be called when we know we
 * have write access to the stream. We will busy wait in case we don't do a full
 * send.
 */
- (void)performSend:(NSString*)command
{
	BOOL done = NO;
	
	char* string = (char*)[command UTF8String];
	int stringLength = strlen(string);
	
	// Log the command if TransportDebug is enabled.
	if ([[[[NSProcessInfo processInfo] environment] objectForKey:@"TransportDebug"] boolValue])
		NSLog(@"--> %@", command);
	
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
				NSRange occurrence = [command rangeOfString:@"-i "];
				if (occurrence.location == NSNotFound)
				{
					NSLog(@"sent %@ without a transaction ID", command);
					continue;
				}
				NSString* transaction = [command substringFromIndex:occurrence.location + occurrence.length];
				lastWrittenTransaction_ = [transaction intValue];
				NSLog(@"command = %@", command);
				NSLog(@"read=%d, write=%d", lastReadTransaction_, lastWrittenTransaction_);
			}
		}
	}
}

#pragma mark Response Handlers

- (void)handleResponse:(NSXMLDocument*)response
{
	// Check and see if there's an error.
	NSArray* error = [[response rootElement] elementsForName:@"error"];
	if ([error count] > 0)
	{
		NSLog(@"Xdebug error: %@", error);
		[delegate errorEncountered:[[[[error objectAtIndex:0] children] objectAtIndex:0] stringValue]];
	}
	
	// If TransportDebug is enabled, log the response.
	if ([[[[NSProcessInfo processInfo] environment] objectForKey:@"TransportDebug"] boolValue])
		NSLog(@"<-- %@", response);
	
	// Get the name of the command from the engine's response.
	NSString* command = [[[response rootElement] attributeForName:@"command"] stringValue];
	NSString* transaction = [[[response rootElement] attributeForName:@"transaction_id"] stringValue];
	NSArray* routingPath = [transaction componentsSeparatedByString:@"."];
	
	NSInteger txnID = [[routingPath objectAtIndex:0] intValue];
	if (txnID < lastReadTransaction_)
		NSLog(@"out of date transaction %@", response);
	
	if (txnID != lastWrittenTransaction_)
		NSLog(@"txn doesn't match last written %@", response);
	
	lastReadTransaction_ = [transaction intValue];
	NSLog(@"read=%d, write=%d", lastReadTransaction_, lastWrittenTransaction_);
	
	// Dispatch the command response to an appropriate handler.
	if ([command isEqualToString:@"status"])
		[self updateStatus:response];
	else if ([command isEqualToString:@"run"] || [command isEqualToString:@"step_into"] ||
			 [command isEqualToString:@"step_over"] || [command isEqualToString:@"step_out"])
		[self debuggerStep:response];
	else if ([command isEqualToString:@"stack_depth"])
		[self rebuildStack:response];
	else if ([command isEqualToString:@"stack_get"])
		[self getStackFrame:response];
	else if ([routingPath count] > 1)
		[self handleRouted:routingPath response:response];
	else if ([[[response rootElement] name] isEqualToString:@"init"])
		[self initReceived:response];
	
	[self sendQueuedWrites];
}

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
	[self send:[self createCommand:@"status"]];
	NSString* command = [[[response rootElement] attributeForName:@"command"] stringValue];
	NSUInteger routingID = [[[[response rootElement] attributeForName:@"transaction_id"] stringValue] intValue];
	
	// If this is the run command, tell the delegate that a bunch of updates
	// are coming. Also remove all existing stack routes and request a new stack.
	if ([command isEqualToString:@"run"])
	{
		[delegate clobberStack];
		[stackFrames_ removeAllObjects];
		[self send:[self createCommand:@"stack_depth"]];
	}
	
	[self send:[self createRouted:[NSString stringWithFormat:@"%u", routingID] command:@"stack_get -d 0"]];
}

/**
 * We ask for the stack_depth and now we clobber the stack and start rebuilding
 * it.
 */
- (void)rebuildStack:(NSXMLDocument*)response
{
	NSInteger depth = [[[[response rootElement] attributeForName:@"depth"] stringValue] intValue];
	
	// We now need to alloc a bunch of stack frames and get the basic information
	// for them.
	for (NSInteger i = 0; i < depth; i++)
	{
		NSString* command = [self createCommand:@"stack_get -d %d", i];
		
		// Use the transaction ID to create a routing path.
		NSNumber* routingID = [NSNumber numberWithInt:transactionID - 1];
		[stackFrames_ setObject:[StackFrame alloc] forKey:routingID];
		
		[self send:command];
	}
}

/**
 * The initial rebuild of the stack frame. We now have enough to initialize
 * a StackFrame object.
 */
- (void)getStackFrame:(NSXMLDocument*)response
{
	// Get the routing information.
	NSUInteger routingID = [[[[response rootElement] attributeForName:@"transaction_id"] stringValue] intValue];
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
	
	// Now that we have an initialized frame, request additional information.
	NSString* routingFormat = @"%u.%d";
	NSString* routingPath = nil;
	
	// Get the source code of the file. Escape % in URL chars.
	NSString* escapedFilename = [frame.filename stringByReplacingOccurrencesOfString:@"%" withString:@"%%"];
	routingPath = [NSString stringWithFormat:routingFormat, routingID, kStackFrameSource];
	[self send:[self createRouted:routingPath command:[NSString stringWithFormat:@"source -f %@", escapedFilename]]];
	
	// Get the names of all the contexts.
	routingPath = [NSString stringWithFormat:routingFormat, routingID, kStackFrameContexts];
	[self send:[self createRouted:routingPath command:@"context_names -d %d", frame.index]];
}

/**
 * Routed responses are currently only used in getting all the stack frame data.
 */
- (void)handleRouted:(NSArray*)path response:(NSXMLDocument*)response
{
	NSLog(@"routed %@ = %@", path, response);
	
	// Format of |path|: transactionID.routingID.component
	StackFrameComponent component = [[path objectAtIndex:2] intValue];
	
	// See if we can find the stack frame based on routingID.
	NSNumber* routingNumber = [NSNumber numberWithInt:[[path objectAtIndex:1] intValue]];
	StackFrame* frame = [stackFrames_ objectForKey:routingNumber];
	if (!frame)
		return;
	
	if (component == kStackFrameSource)
		frame.source = [[response rootElement] value];
}

#pragma mark Private

/**
 * Helper method to create a string command with the -i <transaction id> automatically tacked on. Takes
 * a variable number of arguments and parses the given command with +[NSString stringWithFormat:]
 */
- (NSString*)createCommand:(NSString*)cmd, ...
{
	// collect varargs
	va_list	argList;
	va_start(argList, cmd);
	NSString* format = [[NSString alloc] initWithFormat:cmd arguments:argList]; // format the command
	va_end(argList);
	
	return [NSString stringWithFormat:@"%@ -i %d", [format autorelease], transactionID++];
}

/**
 * Helper to create a command string. This works a lot like |-createCommand:| but
 * it also takes a routing ID, which is used to route response data to specific
 * objects.
 */
- (NSString*)createRouted:(NSString*)routingID command:(NSString*)cmd, ...
{
	va_list	argList;
	va_start(argList, cmd);
	NSString* format = [[NSString alloc] initWithFormat:cmd arguments:argList];
	va_end(argList);
	
	return [NSString stringWithFormat:@"%@ -i %d.%@", [format autorelease], transactionID++, routingID];
}

/**
 * Checks if there are unsent commands in the |queuedWrites_| queue and sends
 * them if it's OK to do so. This will not block.
 */
- (void)sendQueuedWrites
{
	[writeQueueLock_ lock];
	if (lastReadTransaction_ >= lastWrittenTransaction_ && [queuedWrites_ count] > 0)
	{
		NSString* command = [queuedWrites_ objectAtIndex:0];
		NSLog(@"Sending queued write: %@", command);
		
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
 * Generates a stack frame for the given depth
 */
- (StackFrame*)createStackFrame:(int)stackDepth
{
	// get the names of all the contexts
	[socket send:[self createCommand:@"context_names -d 0"]];
	NSXMLElement* contextNames = [[self processData:[socket receive]] rootElement];
	NSMutableArray* variables = [NSMutableArray array];
	for (NSXMLElement* context in [contextNames children])
	{
		NSString* name = [[context attributeForName:@"name"] stringValue];
		int cid = [[[context attributeForName:@"id"] stringValue] intValue];
		
		// fetch the contexts
		[socket send:[self createCommand:[NSString stringWithFormat:@"context_get -d %d -c %d", stackDepth, cid]]];
		NSArray* addVars = [[[self processData:[socket receive]] rootElement] children];
		if (addVars != nil && name != nil)
			[variables addObjectsFromArray:addVars];
	}
	
	return nil;
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

@end

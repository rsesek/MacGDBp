//
//  AppDelegate.m
//  CFNetworkTest
//
//  Created by Robert Sesek on 2/15/10.
//  Copyright 2010 Blue Static. All rights reserved.
//

#import <sys/socket.h>
#import <netinet/in.h>

#import "AppDelegate.h"

// AppDelegate (Private) ///////////////////////////////////////////////////////

#define BUFFER_SIZE 1024

@interface AppDelegate (Private)
- (void)newDataToRead;
- (void)streamErrorOccured:(NSError*)error;
- (void)disconnected;
@end

// CFNetwork Callbacks /////////////////////////////////////////////////////////
#pragma mark CFNetwork Callbacks

void ReadStreamCallback(CFReadStreamRef stream, CFStreamEventType eventType, void* appDelegateRaw)
{
	NSLog(@"ReadStreamCallback()");
	AppDelegate* appDelegate = (AppDelegate*)appDelegateRaw;
	switch (eventType)
	{
		case kCFStreamEventHasBytesAvailable:
			[appDelegate newDataToRead];
			break;
			
		case kCFStreamEventErrorOccurred:
		{
			CFErrorRef error = CFReadStreamCopyError(stream);
			CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
			CFReadStreamClose(stream);
			CFRelease(stream);
			[appDelegate streamErrorOccured:[(NSError*)error autorelease]];
			break;
		}
			
		case kCFStreamEventEndEncountered:
			CFReadStreamUnscheduleFromRunLoop(stream, [[NSRunLoop currentRunLoop] getCFRunLoop], kCFRunLoopCommonModes);
			CFReadStreamClose(stream);
			CFRelease(stream);
			[appDelegate disconnected];
			break;
	};
}

void WriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType eventType, void* appDelegateRaw)
{
	NSLog(@"WriteStreamCallback()");
	AppDelegate* appDelegate = (AppDelegate*)appDelegateRaw;
	switch (eventType)
	{
		case kCFStreamEventErrorOccurred:
		{
			CFErrorRef error = CFWriteStreamCopyError(stream);
			CFWriteStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
			CFWriteStreamClose(stream);
			CFRelease(stream);
			[appDelegate streamErrorOccured:[(NSError*)error autorelease]];
			break;
		}
			
		case kCFStreamEventEndEncountered:
			CFWriteStreamUnscheduleFromRunLoop(stream, [[NSRunLoop currentRunLoop] getCFRunLoop], kCFRunLoopCommonModes);
			CFWriteStreamClose(stream);
			CFRelease(stream);
			[appDelegate disconnected];
			break;
	}
}

void SocketAcceptCallback(CFSocketRef socket, CFSocketCallBackType callbackType, CFDataRef address, const void* data, void* appDelegateRaw)
{
	assert(callbackType == kCFSocketAcceptCallBack);
	NSLog(@"SocketAcceptCallback()");
	
	AppDelegate* appDelegate = (AppDelegate*)appDelegateRaw;
	
	// Create the streams on the socket.
	CFStreamCreatePairWithSocket(kCFAllocatorDefault,
								 *(CFSocketNativeHandle*)data,  // Socket handle.
								 &appDelegate->readStream_,  // Read stream in-pointer.
								 &appDelegate->writeStream_);  // Write stream in-pointer.
	
	// Create struct to register callbacks for the stream.
	CFStreamClientContext context;
	context.version = 0;
	context.info = appDelegate;
	context.retain = NULL;
	context.release = NULL;
	context.copyDescription = NULL;
	
	// Set the client of the read stream.
	CFOptionFlags readFlags =
		kCFStreamEventOpenCompleted |
		kCFStreamEventHasBytesAvailable |
		kCFStreamEventErrorOccurred |
		kCFStreamEventEndEncountered;
	if (CFReadStreamSetClient(appDelegate->readStream_, readFlags, ReadStreamCallback, &context))
		// Schedule in run loop to do asynchronous communication with the engine.
		CFReadStreamScheduleWithRunLoop(appDelegate->readStream_, [[NSRunLoop currentRunLoop] getCFRunLoop], kCFRunLoopCommonModes);
	else
		return;
	
	NSLog(@"Read stream scheduled");
	
	// Open the stream now that it's scheduled on the run loop.
	if (!CFReadStreamOpen(appDelegate->readStream_))
	{
		CFStreamError error = CFReadStreamGetError(appDelegate->readStream_);
		NSLog(@"error! %@", error);
		return;
	}
	
	NSLog(@"Read stream opened");
	
	// Set the client of the write stream.
	CFOptionFlags writeFlags =
		kCFStreamEventOpenCompleted |
		kCFStreamEventErrorOccurred |
		kCFStreamEventEndEncountered;
	if (CFWriteStreamSetClient(appDelegate->writeStream_, writeFlags, WriteStreamCallback, &context))
		// Schedule it in the run loop to receive error information.
		CFWriteStreamScheduleWithRunLoop(appDelegate->writeStream_, [[NSRunLoop currentRunLoop] getCFRunLoop], kCFRunLoopCommonModes);
	else
		return;
	
	NSLog(@"Write stream scheduled");
	
	// Open the write stream.
	if (!CFWriteStreamOpen(appDelegate->writeStream_))
	{
		CFStreamError error = CFWriteStreamGetError(appDelegate->writeStream_);
		NSLog(@"error! %@", error);
		return;
	}
	
	NSLog(@"Write stream opened");
}

// SocketRLTestAppDelegate /////////////////////////////////////////////////////

@implementation AppDelegate

@synthesize window = window_;
@synthesize commandField = commandField_;
@synthesize resultView = resultView_;
@synthesize currentPacket = currentPacket_;

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
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
	address.sin_port = htons(9000);
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
		NSLog(@"socket error");
		return;
	}
	
	// Allow old, yet-to-be recycled sockets to be reused.
	BOOL yes = YES;
	setsockopt(CFSocketGetNative(socket_), SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(BOOL));
	
	// Schedule the socket on the run loop.
	CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket_, 0);
	CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], source, kCFRunLoopCommonModes);
	CFRelease(source);
}

- (void)dealloc
{
	// The socket goes down, so do the streams, which clean themselves up.
	CFSocketInvalidate(socket_);
	CFRelease(socket_);
	self.currentPacket = nil;
	[super dealloc];
}

- (IBAction)send:(id)sender
{
	BOOL done = NO;
	
	char* string = (char*)[[self.commandField stringValue] UTF8String];
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
			}			
		}
	}
}

// AppDelegate (Private) ///////////////////////////////////////////////////////
#pragma mark Private

- (void)newDataToRead
{
	UInt8 buffer[BUFFER_SIZE];
	CFIndex bytesRead = CFReadStreamRead(readStream_, buffer, BUFFER_SIZE);
	const char* charBuffer = (const char*)buffer;
	
	// We haven't finished reading a packet, so just read more data in.
	if (packetIndex_ < lastPacketSize_)
	{
		[currentPacket_ appendFormat:@"%s", buffer];
		packetIndex_ += bytesRead;
	}
	// Time to read a new packet.
	else
	{
		// Read the message header: the size.
		lastPacketSize_ = atoi(charBuffer);
		packetIndex_ = bytesRead - strlen(charBuffer);
		self.currentPacket = [NSMutableString stringWithFormat:@"%s", buffer + strlen(charBuffer) + 1];
	}
	
	// We have finished reading the packet.
	if (packetIndex_ >= lastPacketSize_)
	{
		lastPacketSize_ = 0;
		packetIndex_ = 0;
		
		// Update the displays.
		[self.resultView setString:currentPacket_];
		
		// Test if we can convert it into an NSXMLDocument.
		NSError* error = nil;
		NSXMLDocument* xmlTest = [[NSXMLDocument alloc] initWithXMLString:currentPacket_ options:NSXMLDocumentTidyXML error:&error];
		if (error)
			NSLog(@"FAILED XML TEST: %@", error);
		[xmlTest release];
	}
}

- (void)streamErrorOccured:(NSError*)error
{
	NSLog(@"stream error: %@", error);
}

- (void)disconnected
{
}

@end

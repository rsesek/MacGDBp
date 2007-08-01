/*
 * MacGDBp
 * Copyright (c) 2002 - 2007, Blue Static <http://www.bluestatic.org>
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


@implementation DebuggerConnection

/**
 * Creates a new DebuggerConnection and initializes the socket from the given connection
 * paramters.
 */
- (id)initWithHost: (NSString *)host port: (int)port session: (NSString *)session
{
	NSLog(@"initWithHost");
	if (self = [super init])
	{
		_host = [host retain];
		_port = port;
		_session = [session retain];
		
		_windowController = [[DebuggerWindowController alloc] initWithConnection: self];
		[[_windowController window] makeKeyAndOrderFront: self];
		
		// now that we have our host information, open the streams and put them in the run loop
		[NSStream getStreamsToHost: [NSHost hostWithName: _host] port: _port inputStream: &_input outputStream: &_output];
		[_input retain];
		[_output retain];
		
		[_input setDelegate: self];
		[_output setDelegate: self];
		
		[_input scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
		[_output scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
		
		[_input open];
		[_output open];
		
		// clean up after ourselves
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(applicationWillTerminate:)
													 name: NSApplicationWillTerminateNotification
												   object: NSApp];
	}
	return self;
}

/**
 * Release ourselves when we're about to die
 */
- (void)applicationWillTerminate: (NSNotification *)notif
{
	[self release];
}

/**
 * Releases all of the object's data members and closes the streams
 */
- (void)dealloc
{
	[_host release];
	[_session release];
	[_input close];
	[_output close];
	[_input release];
	[_output release];
	
	[super dealloc];
}

/**
 * Gets the hostname
 */
- (NSString *)host
{
	return _host;
}

/**
 * Gets the port number
 */
- (int)port
{
	return _port;
}

/**
 * Gets the session name
 */
- (NSString *)session
{
	return _session;
}

/**
 * Handles stream events. This is the delegate method implemented for NSStream and it
 * merely calls other methods to do it's bidding
 */
- (void)stream: (NSStream *)stream handleEvent: (NSStreamEvent)event
{
	NSLog(@"hi");
	if (event == NSStreamEventHasBytesAvailable)
	{
		if (!_data)
		{
			_data = [[NSMutableData data] retain];
		}
		uint8_t buf[1024];
		unsigned int len = 0;
		len = [(NSInputStream *)stream read: buf maxLength: 1024];
		if (len)
		{
			[_data appendBytes: (const void *)buf length: len];
		}
		else
		{
			[self _readFromStream: _data];
			[_data release];
			_data = nil;
		}
	}
	else if (event == NSStreamEventEndEncountered)
	{
		NSLog(@"we need to close and die right now");
	}
	else if (event == NSStreamEventErrorOccurred)
	{
		NSLog(@"error = %@", [stream streamError]);
	}
	NSLog(@"status = %d", [stream streamStatus]);
}

/**
 * Called when the stream event handler has finished reading all of the data and
 * passes it a data object
 */
- (void)_readFromStream: (NSData *)data
{
	[data retain];
	NSLog(@"data = %@", data);
}

@end

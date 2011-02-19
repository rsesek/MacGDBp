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

@class LogEntry;

// This is the private interface for the NetworkConnection class. This is shared
// by the C++ NetworkCallbackController to communicate.
@interface NetworkConnection ()

@property (assign) CFReadStreamRef readStream;
@property NSUInteger lastReadTransaction;
@property (retain) NSMutableString* currentPacket;
@property (assign) CFWriteStreamRef writeStream;
@property NSUInteger lastWrittenTransaction;
@property (retain) NSMutableArray* queuedWrites;

- (void)runNetworkThread;

- (void)socketDidAccept;
- (void)socketDisconnected;
- (void)readStreamHasData;

// These methods MUST be called on the network thread as they are not threadsafe.
- (void)send:(NSString*)command;
- (void)performSend:(NSString*)command;
- (void)sendQueuedWrites;

- (void)performQuitSignal;

- (void)handleResponse:(NSXMLDocument*)response;
- (void)handlePacket:(NSString*)packet;

// Threadsafe wrappers for the delegate's methods.
- (void)errorEncountered:(NSString*)error;
- (LogEntry*)recordSend:(NSString*)command;
- (LogEntry*)recordReceive:(NSString*)command;

@end

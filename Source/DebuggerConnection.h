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

#import <Cocoa/Cocoa.h>

#import "Breakpoint.h"
#import "StackFrame.h"

@class LoggingController;

@protocol DebuggerConnectionDelegate;

// The DebuggerConnection is the communication layer between the application
// and the Xdebug engine. Clients can issue debugger commands using this class,
// which are sent in an asynchronous manner. Reads are also asynchronous and
// the primary client of this class should set itself as the delegate. The
// primary unit that this class deals with is the StackFrame; clients should
// maintain a stack structure and the Connection will inform the delegate when
// a new frame is created or the stack should be destroyed.
@interface DebuggerConnection : NSObject
{
	// The port to connect on.
	NSUInteger port;
	
	// If the connection to the debugger engine is currently active.
	BOOL connected;
	
	// Human-readable status of the connection.
	NSString* status;
	
	// The connection's delegate.
	id <DebuggerConnectionDelegate> delegate;

	// The raw CFSocket on which the two streams are based. Strong.
	CFSocketRef socket_;
	
	// The read stream that is scheduled on the main run loop. Weak.
	CFReadStreamRef readStream_;
	
	// The write stream. Weak.
	CFWriteStreamRef writeStream_;
	
	// An ever-increasing integer that gives each transaction a unique ID for the
	// debugging engine.
	NSUInteger transactionID;
	
	// The most recently received transaction ID.
	NSUInteger lastReadTransaction_;
	
	// The last transactionID written to the stream.
	NSUInteger lastWrittenTransaction_;
	
	// Callback table. This maps transaction IDs to selectors. When the engine
	// returns a response to the debugger, we will dispatch the response XML to
	// the selector, based on transaction_id.
	NSMutableDictionary* callTable_;
	
	// To prevent blocked writing, we enqueue all writes and then wait for the
	// write stream to tell us it's ready. We store the pending commands in this
	// array. We use this as a stack (FIFO), with index 0 being first.
	NSMutableArray* queuedWrites_;
	
	// We send queued writes in multiple places, sometimes off a run loop event.
	// Because of this, we need to ensure that only one client is dequeing and
	// sending at a time.
	NSRecursiveLock* writeQueueLock_;
	
	// Information about the current read loop. We append to |currentPacket_|
	// until |currentPacketSize_| has reached |packetSize_|.
	NSMutableString* currentPacket_;
	int packetSize_;
	int currentPacketIndex_;
	
	// A dictionary that maps routingIDs to StackFrame objects.
	NSMutableDictionary* stackFrames_;
	// The stack depth for the current build of |stackFrames_|.
	NSInteger stackDepth_;
	// The earliest transaction ID for the current build of |stackFrames_|.
	NSInteger stackFirstTransactionID_;
	
	// This stores additional context information for the callback selector.
	// This dictionary is keyed by the same transaction IDs in |callTable_|, but
	// also stores some other object that can be accessed in the callback.
	NSMutableDictionary* callbackContext_;
}

@property (readonly, copy) NSString* status;
@property (assign) id <DebuggerConnectionDelegate> delegate;

// initializer
- (id)initWithPort:(NSUInteger)aPort;

// getter
- (NSUInteger)port;
- (NSString*)remoteHost;
- (BOOL)isConnected;

// communication
- (void)reconnect;
- (void)run;
- (void)stepIn;
- (void)stepOut;
- (void)stepOver;
- (void)addBreakpoint:(Breakpoint*)bp;
- (void)removeBreakpoint:(Breakpoint*)bp;

// Gets a property by name from the debugger engine. Returns a transaction ID
// which used in the delegate callback.
- (NSInteger)getProperty:(NSString*)property;

@end

// Delegate ////////////////////////////////////////////////////////////////////

@protocol DebuggerConnectionDelegate <NSObject>

// Passes up errors from SocketWrapper and any other errors generated by the
// GDBpConnection.
- (void)errorEncountered:(NSString*)error;

// Called when the socket connects. Passed up from SocketWrapper.
- (void)debuggerConnected;

// Called when we disconnect.
- (void)debuggerDisconnected;

// Tells the debugger to destroy the current stack display.
- (void)clobberStack;

// Tells the debugger that a new stack frame is avaliable.
- (void)newStackFrame:(StackFrame*)frame;

// Tells the debugger that new source is available for the given frame.
- (void)sourceUpdated:(StackFrame*)frame;

// Callback from |-getProperty:|.
- (void)receivedProperties:(NSArray*)properties forTransaction:(NSInteger)transaction;

@end


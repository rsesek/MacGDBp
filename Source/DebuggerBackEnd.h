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

#import <Cocoa/Cocoa.h>

#import "Breakpoint.h"
#import "NetworkConnection.h"
#import "StackFrame.h"

@protocol DebuggerBackEndDelegate;
@class VariableNode;

// The DebuggerBackEnd is the communication layer between the application
// and the back-end debugger. Clients issue debugger commands via this class,
// which are sent in an asynchronous manner. Reads are also asynchronous and
// the primary client of this class should set itself as the delegate. The
// primary unit that this class deals with is the StackFrame; clients should
// maintain a stack structure and the BackEnd will inform the delegate when
// a new frame is created or the stack should be destroyed.
@interface DebuggerBackEnd : NSObject <NetworkConnectionDelegate>
{
  // The connection to the debugger engine.
  NetworkConnection* connection_;
  
  // Human-readable status of the connection.
  NSString* status;
  BOOL active_;

  // Whether the debugger should detach immediately after being contacted by the
  // backend. YES means all debugger connections will be dropped.
  BOOL attached_;
  
  // The connection's delegate.
  id <DebuggerBackEndDelegate> delegate;
  
  // A dictionary that maps routingIDs to StackFrame objects.
  NSMutableDictionary* stackFrames_;
  // The stack depth for the current build of |stackFrames_|.
  NSInteger stackDepth_;
  // The earliest transaction ID for the current build of |stackFrames_|.
  NSInteger stackFirstTransactionID_;

  // Callback table. This maps transaction IDs to selectors. When the engine
  // returns a response to the debugger, we will dispatch the response XML to
  // the selector, based on transaction_id.
  NSMutableDictionary* callTable_;

  // This stores additional context information for the callback selector.
  // This dictionary is keyed by the same transaction IDs in |callTable_|, but
  // also stores some other object that can be accessed in the callback.
  NSMutableDictionary* callbackContext_;
}

@property (readonly, copy) NSString* status;
@property (assign) BOOL attached;
@property (assign) id <DebuggerBackEndDelegate> delegate;

// initializer
- (id)initWithPort:(NSUInteger)aPort;

// getter
- (NSUInteger)port;
- (BOOL)isConnected;

// communication
- (void)run;
- (void)stepIn;
- (void)stepOut;
- (void)stepOver;
- (void)detach;

// Breakpoint management.
- (void)addBreakpoint:(Breakpoint*)bp;
- (void)removeBreakpoint:(Breakpoint*)bp;

// Gets a property by name from the debugger engine. Returns a transaction ID
// which used in the delegate callback. Properties must be retrieved at a
// certain stack depth.
- (NSInteger)getChildrenOfProperty:(VariableNode*)property atDepth:(NSInteger)depth;

// Takes a partially loaded stack frame and fetches the rest of the information.
- (void)loadStackFrame:(StackFrame*)frame;

@end

// Delegate ////////////////////////////////////////////////////////////////////

@protocol DebuggerBackEndDelegate <NSObject>

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
// TODO: rename to |-frameUpdated:|.
- (void)sourceUpdated:(StackFrame*)frame;

// Callback from |-getProperty:|.
- (void)receivedProperties:(NSArray*)properties forTransaction:(NSInteger)transaction;

@end


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
#import "ProtocolClient.h"
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
@interface DebuggerBackEnd : NSObject<ProtocolClientDelegate>

// Human-readable status of the connection.
@property(readonly, copy, nonatomic) NSString* status;

// Whether the debugger should detach immediately after being contacted by the
// backend. YES means all debugger connections will be dropped.
@property(assign, nonatomic) BOOL autoAttach;

@property(assign, nonatomic) id<DebuggerBackEndDelegate> delegate;

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
- (void)stop;
- (void)detach;

// Breakpoint management.
- (void)addBreakpoint:(Breakpoint*)bp;
- (void)removeBreakpoint:(Breakpoint*)bp;

// Evaluates a given string in the current execution context.
- (void)evalScript:(NSString*)str callback:(void (^)(NSString*))callback;

// Gets a property by name from the debugger engine. Properties must be
// retrieved at a certain stack depth.
- (void)getChildrenOfProperty:(VariableNode*)property
                      atDepth:(NSInteger)depth
                     callback:(void (^)(NSArray*))callback;

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

@end


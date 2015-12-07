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

#import "ProtocolClient.h"

@class Breakpoint;
@class DebuggerModel;
@class StackFrame;
@class VariableNode;

// The DebuggerBackEnd is the communication layer between the application
// and the back-end debugger. Clients issue debugger commands via this class,
// which are sent in an asynchronous manner. Reads are also asynchronous and
// the primary client of this class should set a model object, which will be
// updated as data arrive.
@interface DebuggerBackEnd : NSObject<ProtocolClientDelegate>

// Whether the debugger should listen for and attach to connections.
@property(assign, nonatomic) BOOL autoAttach;

// The model object to update in response to changes in the debugger.
@property(assign, nonatomic) DebuggerModel* model;

// Designated initializer. Sets up a connection on |aPort| and will
// initialize it if |autoAttach| is YES.
- (instancetype)initWithPort:(NSUInteger)aPort autoAttach:(BOOL)doAttach;

// getter
- (uint16_t)port;

// communication
- (void)run;
- (void)stepIn;
- (void)stepOut;
- (void)stepOver;
- (void)stop;
- (void)detach;

// Takes a partially loaded stack frame and fetches the rest of the information.
- (void)loadStackFrame:(StackFrame*)frame;

// Ensures that a variable node's immediate children are loaded, and fetches
// any that are not. This is done within the scope of the given stack frame.
- (void)loadVariableNode:(VariableNode*)variable
           forStackFrame:(StackFrame*)frame;

// Breakpoint management.
- (void)addBreakpoint:(Breakpoint*)bp;
- (void)removeBreakpoint:(Breakpoint*)bp;

// Evaluates a given string in the current execution context.
- (void)evalScript:(NSString*)str callback:(void (^)(NSString*))callback;

@end

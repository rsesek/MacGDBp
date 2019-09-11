/*
 * MacGDBp
 * Copyright (c) 2015, Blue Static <https://www.bluestatic.org>
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

#import <Foundation/Foundation.h>

@class BreakpointManager;
@class StackFrame;

// This class represents the state of an active debugging session. It is
// typically updated by the DebuggerBackEnd in response to various commands.
// All of the properties are KVO-compliant.
@interface DebuggerModel : NSObject

// Maintains state about breakpoints.
@property(readonly, nonatomic) BreakpointManager* breakpointManager;

// Whether or not the debugger is currently connected.
@property(readonly, nonatomic) BOOL connected;

// A human-readable representation of the debugger state. E.g., "Break" or
// "Stopped".
@property(copy, nonatomic) NSString* status;

// A string representing the last error message, or nil for no error.
@property(copy, nonatomic) NSString* lastError;

// An array of StackFrame objects for the current call stack.
@property(readonly, nonatomic) NSArray<StackFrame*>* stack;

// Helper accessor for |stack.count|.
@property(readonly, nonatomic) NSUInteger stackDepth;

// Informs the model that the debugger is listening for new connections.
- (void)onListeningOnPort:(uint16_t)port;

// Informs the model that a new connection was initiated. This clears any data
// in the model.
- (void)onNewConnection;

// Informs the model that the connection was terminated.
- (void)onDisconnect;

// Replaces the current stack with |newStack|. This will attempt to preserve
// any already loaded frames.
- (void)updateStack:(NSArray<StackFrame*>*)newStack;

@end

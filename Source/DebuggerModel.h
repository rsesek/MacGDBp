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

@class StackFrame;

@interface DebuggerModel : NSObject

// A human-readable representation of the debugger state. E.g., "Break" or
// "Stopped".
@property(copy, nonatomic) NSString* status;

@property(readonly, nonatomic) NSArray<StackFrame*>* stack;

@property(readonly, nonatomic) NSUInteger stackDepth;

// Informs the model that a new connection was initiated. This clears any data
// in the model.
- (void)onNewConnection;

// Replaces the current stack with |newStack|. This will attempt to preserve
// any already loaded frames.
- (void)updateStack:(NSArray<StackFrame*>*)newStack;

@end

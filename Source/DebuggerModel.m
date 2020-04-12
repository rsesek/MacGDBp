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

#import "DebuggerModel.h"

#import "BreakpointManager.h"
#import "StackFrame.h"

@interface DebuggerModel ()
@property(assign, nonatomic) BOOL connected;
@end

@implementation DebuggerModel {
  NSMutableArray* _stack;
}

- (instancetype)init {
  if (self = [super init]) {
    _breakpointManager = [[BreakpointManager alloc] init];
    _stack = [NSMutableArray new];

    [self onDisconnect];
  }
  return self;
}

- (NSUInteger)stackDepth {
  return self.stack.count;
}

- (void)onListeningOnPort:(uint16_t)port {
  self.status = [NSString stringWithFormat:@"Listening on Port %d", port];
}

- (void)onNewConnection {
  self.status = nil;
  self.connected = YES;
  [_stack removeAllObjects];
}

- (void)onDisconnect {
  self.connected = NO;
  self.status = @"Disconnected";
}

- (void)updateStack:(NSArray<StackFrame*>*)newStack {
  [self willChangeValueForKey:@"stack"];

  [_stack removeAllObjects];
  [_stack addObjectsFromArray:newStack];

  // Renumber the stack.
  for (NSUInteger i = 0; i < self.stack.count; ++i)
    self.stack[i].index = i;

  [self didChangeValueForKey:@"stack"];
}

@end

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

- (void)dealloc {
  [_breakpointManager release];
  [_status release];
  [_lastError release];
  [_stack release];
  [super dealloc];
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
  // Iterate, in reverse order from the bottom to the top, both stacks to find
  // the point of divergence.
  NSEnumerator* itNewStack = [newStack reverseObjectEnumerator];
  NSEnumerator* itOldStack = [self.stack reverseObjectEnumerator];

  StackFrame* frameNew;
  StackFrame* frameOld = [itOldStack nextObject];
  NSUInteger oldStackOffset = self.stack.count;
  while (frameNew = [itNewStack nextObject]) {
    if ([frameNew isEqual:frameOld]) {
      --oldStackOffset;
      frameOld = [itOldStack nextObject];
    } else {
      break;
    }
  }

  [self willChangeValueForKey:@"stack"];

  // Remove any frames from the top of the stack that are not shared with the
  // new stack.
  [_stack removeObjectsInRange:NSMakeRange(0, oldStackOffset)];

  // Continue inserting objects to update the stack with the new frames.
  while (frameNew) {
    [_stack insertObject:frameNew atIndex:0];
    frameNew = [itNewStack nextObject];
  }

  // Renumber the stack.
  for (NSUInteger i = 0; i < self.stack.count; ++i)
    self.stack[i].index = i;

  [self didChangeValueForKey:@"stack"];
}

@end

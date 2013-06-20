/*
 * MacGDBp
 * Copyright (c) 2013, Blue Static <http://www.bluestatic.org>
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

#import "ThreadSafeDeleage.h"

@implementation ThreadSafeDeleage {
  NSObject* _object;
  Protocol* _protocol;
  NSThread* _thread;
  NSArray* _modes;
}

@synthesize object = _object;

- (id)initWithObject:(NSObject*)object
            protocol:(Protocol*)protocol
              thread:(NSThread*)thread {
  return [self initWithObject:object
                     protocol:protocol
                       thread:thread
                        modes:@[ NSRunLoopCommonModes ]];
}

- (id)initWithObject:(NSObject*)object
            protocol:(Protocol*)protocol
              thread:(NSThread*)thread
               modes:(NSArray*)runLoopModes {
  if ((self = [super init])) {
    _object = object;
    _protocol = protocol;
    _thread = thread;
    _modes = [runLoopModes retain];
  }
  return self;
}

- (void)dealloc {
  [_modes release];
  [super dealloc];
}

- (BOOL)conformsToProtocol:(Protocol*)protocol {
  return [_protocol isEqual:protocol];
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector {
  if (!_object)
    return [_protocol methodSignatureForSelector:aSelector];
  return [_object methodSignatureForSelector:aSelector];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
  if (!_object)
    return [_protocol respondsToSelector:aSelector];
  return [_object respondsToSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation*)invocation {
  if ([_object respondsToSelector:[invocation selector]]) {
    [self performSelector:@selector(dispatchInvocation:)
                 onThread:_thread
               withObject:invocation
            waitUntilDone:NO
                    modes:_modes];
  }
}

- (void)dispatchInvocation:(NSInvocation*)invocation {
  [invocation invokeWithTarget:_object];
}

@end

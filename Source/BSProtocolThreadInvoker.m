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

#import "BSProtocolThreadInvoker.h"

@interface BSProtocolThreadInvoker (Private)
// Installs a run loop observer on the target thread that is used to start
// dispatching messages again after falling out of a nested run loop.
// *MUST* be called on the target thread.
- (void)addRunLoopObserver;

// Removes the observer added with |-addRunLoopObserver|. Can be called on any
// thread since CFRunLoop is threadsafe.
- (void)removeRunLoopObserver;

// Enqueues the |invocation| for execution, and dequeues the first if not called
// reentrantly.
// *MUST* be called on the target thread.
- (void)dispatchInvocation:(NSInvocation*)invocation;

// Callback for the run loop whenever it begins a new pass. This will schedule
// work if any was previously deferred due to reentrancy protection.
- (void)observedRunLoopEnter;
@end

@implementation BSProtocolThreadInvoker {
  // The fully qualified target of the invocation.
  NSObject* _object;
  Protocol* _protocol;
  NSThread* _thread;
  CFRunLoopRef _runLoop;
  NSArray* _modes;

  // If executing an invocation from |-dispatchInvocation:|. Protects against
  // reentering the target.
  BOOL _isDispatching;

  // The queue of work to be executed. Enqueues in  |-dispatchInvocation:|.
  NSMutableArray* _invocations;

  CFRunLoopObserverRef _observer;
}

@synthesize object = _object;

- (id)initWithObject:(NSObject*)object
            protocol:(Protocol*)protocol
              thread:(NSThread*)thread
{
  return [self initWithObject:object
                     protocol:protocol
                       thread:thread
                        modes:@[ NSRunLoopCommonModes ]];
}

- (id)initWithObject:(NSObject*)object
            protocol:(Protocol*)protocol
              thread:(NSThread*)thread
               modes:(NSArray*)runLoopModes
{
  if ((self = [super init])) {
    _object = object;
    _protocol = protocol;
    _thread = thread;
    _modes = [runLoopModes copy];
    _invocations = [[NSMutableArray alloc] init];

    [self performSelector:@selector(addRunLoopObserver)
                 onThread:_thread
               withObject:nil
            waitUntilDone:NO
                    modes:_modes];
  }
  return self;
}

- (void)dealloc
{
  [self removeRunLoopObserver];
}

- (BOOL)conformsToProtocol:(Protocol*)protocol
{
  return [_protocol isEqual:protocol];
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector
{
  if (!_object)
    return [_protocol methodSignatureForSelector:aSelector];
  return [_object methodSignatureForSelector:aSelector];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
  if (!_object)
    return [_protocol respondsToSelector:aSelector];
  return [_object respondsToSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation*)invocation
{
  if ([_object respondsToSelector:[invocation selector]]) {
    [invocation retainArguments];
    [self performSelector:@selector(dispatchInvocation:)
                 onThread:_thread
               withObject:invocation
            waitUntilDone:NO
                    modes:_modes];
  }
}

// Private /////////////////////////////////////////////////////////////////////

- (void)addRunLoopObserver
{
  assert([NSThread currentThread] == _thread);
  _runLoop = CFRunLoopGetCurrent();

  BSProtocolThreadInvoker* __block weakSelf = self;
  _observer = CFRunLoopObserverCreateWithHandler(
      kCFAllocatorDefault,
      kCFRunLoopEntry,
      TRUE,  // Repeats.
      0,  // Order.
      ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
          [weakSelf observedRunLoopEnter];
      });
  for (NSString* mode in _modes)
    CFRunLoopAddObserver(_runLoop, _observer, (CFStringRef)mode);
}

- (void)removeRunLoopObserver
{
  for (NSString* mode in _modes)
    CFRunLoopRemoveObserver(_runLoop, _observer, (CFStringRef)mode);
  CFRelease(_observer);
}

- (void)dispatchInvocation:(NSInvocation*)invocation
{
  // |invocation| will be nil if dispatch was requested after entering a new
  // pass of the run loop, to process deferred work.
  if (invocation)
    [_invocations addObject:invocation];

  // Protect the target object from reentering itself. This work will be
  // rescheduled when another run loop starts (including falling out of a
  // nested loop and starting a new pass through a lower loop).
  if (_isDispatching)
    return;

  _isDispatching = YES;

  // Dequeue only one item. If multiple items are present, the next pass through
  // the run loop will schedule another dispatch via |-observedRunLoopEnter|.
  invocation = [_invocations objectAtIndex:0];
  [invocation invokeWithTarget:_object];
  [_invocations removeObjectAtIndex:0];

  _isDispatching = NO;
}

- (void)observedRunLoopEnter
{
  // Don't do anything if there's nothing to do.
  if ([_invocations count] == 0)
    return;

  // If this nested run loop is still executing from within
  // |-dispatchInvocation:|, continue to wait for a the nested loop to exit.
  if (_isDispatching)
    return;

  // A run loop has started running outside of |-dispatchInvocation:|, so
  // schedule work to be done again.
  [self performSelector:@selector(dispatchInvocation:)
               onThread:_thread
             withObject:nil
          waitUntilDone:NO
                  modes:_modes];
}

@end

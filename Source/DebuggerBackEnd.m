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

#import "DebuggerBackEnd.h"

#import "AppDelegate.h"
#import "modp_b64.h"
#import "NSXMLElementAdditions.h"

@interface DebuggerBackEnd ()
@property(readwrite, copy, nonatomic) NSString* status;
@end

@implementation DebuggerBackEnd {
  // The connection to the debugger engine.
  NSUInteger _port;
  ProtocolClient* _client;

  // Whether or not a debugging session is currently active.
  BOOL _active;

  // The earliest transaction ID for the current build of |stackFrames_|.
  NSInteger stackFirstTransactionID_;
}

@synthesize status = _status;
@synthesize autoAttach = _autoAttach;
@synthesize delegate = _delegate;

- (id)initWithPort:(NSUInteger)aPort
{
  if (self = [super init]) {
    [[BreakpointManager sharedManager] setConnection:self];
    _port = aPort;
    _client = [[ProtocolClient alloc] initWithDelegate:self];

    _autoAttach = [[NSUserDefaults standardUserDefaults] boolForKey:@"DebuggerAttached"];

    if (self.autoAttach)
      [_client connectOnPort:_port];
  }
  return self;
}

- (void)dealloc {
  [_client release];
  [super dealloc];
}

// Getters /////////////////////////////////////////////////////////////////////
#pragma mark Getters

/**
 * Gets the port number
 */
- (NSUInteger)port {
  return _port;
}

/**
 * Returns whether or not we have an active connection
 */
- (BOOL)isConnected {
  return _active;
}

/**
 * Sets the attached state of the debugger. This will open and close the
 * connection as appropriate.
 */
- (void)setAutoAttach:(BOOL)flag {
  if (flag == _autoAttach)
    return;

  if (_autoAttach)
    [_client disconnect];
  else
    [_client connectOnPort:_port];

  _autoAttach = flag;
}

// Commands ////////////////////////////////////////////////////////////////////
#pragma mark Commands

/**
 * Tells the debugger to continue running the script. Returns the current stack frame.
 */
- (void)run {
  [_client sendCommandWithFormat:@"run" handler:^(NSXMLDocument* message) {
    [self debuggerStep:message];
  }];
}

/**
 * Tells the debugger to step into the current command.
 */
- (void)stepIn {
  [_client sendCommandWithFormat:@"step_into" handler:^(NSXMLDocument* message) {
    [self debuggerStep:message];
  }];
}

/**
 * Tells the debugger to step out of the current context
 */
- (void)stepOut {
  [_client sendCommandWithFormat:@"step_out" handler:^(NSXMLDocument* message) {
    [self debuggerStep:message];
  }];
}

/**
 * Tells the debugger to step over the current function
 */
- (void)stepOver {
  [_client sendCommandWithFormat:@"step_over" handler:^(NSXMLDocument* message) {
    [self debuggerStep:message];
  }];
}

/**
 * Halts execution of the script.
 */
- (void)stop {
  [_client disconnect];
  _active = NO;
  self.status = @"Stopped";
}

/**
 * Ends the current debugging session.
 */
- (void)detach {
  [_client sendCommandWithFormat:@"detach"];
  _active = NO;
  self.status = @"Stopped";
}

/**
 * Tells the debugger engine to get a specifc property. This also takes in the NSXMLElement
 * that requested it so that the child can be attached.
 */
- (void)getChildrenOfProperty:(VariableNode*)property
                      atDepth:(NSInteger)depth
                     callback:(void (^)(NSArray*))callback {
  ProtocolClientMessageHandler handler = ^(NSXMLDocument* message) {
    /*
     <response>
       <property> <!-- this is the one we requested -->
         <property ... /> <!-- these are what we want -->
       </property>
     </repsonse>
     */

    // Detach all the children so we can insert them into another document.
    NSXMLElement* parent = (NSXMLElement*)[[message rootElement] childAtIndex:0];
    NSArray* children = [parent children];
    [parent setChildren:nil];

    callback(children);
  };
  [_client sendCommandWithFormat:@"property_get -d %d -n %@" handler:handler, depth, [property fullName]];
}

- (void)loadStackFrame:(StackFrame*)frame {
  if (frame.loaded)
    return;

  // Get the source code of the file. Escape % in URL chars.
  if ([frame.filename length]) {
    ProtocolClientMessageHandler handler = ^(NSXMLDocument* message) {
      int receivedTransaction = [_client transactionIDFromResponse:message];
      if (receivedTransaction < stackFirstTransactionID_)
        return;

      frame.source = [[message rootElement] base64DecodedValue];
      if ([self.delegate respondsToSelector:@selector(sourceUpdated:)])
        [self.delegate sourceUpdated:frame];
    };
    [_client sendCommandWithFormat:@"source -f %@" handler:handler, frame.filename];
  }

  // Get the names of all the contexts.
  ProtocolClientMessageHandler handler = ^(NSXMLDocument* message) {
    [self loadContexts:message forFrame:frame];
  };
  [_client sendCommandWithFormat:@"context_names -d %d" handler:handler, frame.index];

  // This frame will be fully loaded.
  frame.loaded = YES;
}

// Breakpoint Management ///////////////////////////////////////////////////////
#pragma mark Breakpoints

/**
 * Send an add breakpoint command
 */
- (void)addBreakpoint:(Breakpoint*)bp {
  if (!_active)
    return;
  
  NSString* file = [ProtocolClient escapedFilePathURI:[bp transformedPath]];
  ProtocolClientMessageHandler handler = ^(NSXMLDocument* message) {
    [bp setDebuggerId:[[[[message rootElement] attributeForName:@"id"] stringValue] intValue]];
  };
  [_client sendCommandWithFormat:@"breakpoint_set -t line -f %@ -n %i" handler:handler, file, [bp line]];
}

/**
 * Removes a breakpoint
 */
- (void)removeBreakpoint:(Breakpoint*)bp {
  if (!_active)
    return;
  
  [_client sendCommandWithFormat:@"breakpoint_remove -d %i", [bp debuggerId]];
}

/**
 * Sends a string to be evaluated by the engine.
 */
- (void)evalScript:(NSString*)str callback:(void (^)(NSString*))callback {
  if (!_active)
    return;

  char* encodedString = malloc(modp_b64_encode_len([str length]));
  modp_b64_encode(encodedString, [str UTF8String], [str length]);
  ProtocolClientMessageHandler handler = ^(NSXMLDocument* message) {
    NSXMLElement* parent = (NSXMLElement*)[[message rootElement] childAtIndex:0];
    NSString* value = [parent base64DecodedValue];
    callback(value);
  };
  [_client sendCustomCommandWithFormat:@"eval -i {txn} -- %s" handler:handler, encodedString];
  free(encodedString);
}

// Protocol Client Delegate ////////////////////////////////////////////////////
#pragma mark Protocol Client Delegate

- (void)debuggerEngineConnected:(ProtocolClient*)client {
  _active = YES;
}

/**
 * Called when the connection is finally closed. This will reopen the listening
 * socket if the debugger remains attached.
 */
- (void)debuggerEngineDisconnected:(ProtocolClient*)client {
  _active = NO;

  if ([self.delegate respondsToSelector:@selector(debuggerDisconnected)])
    [self.delegate debuggerDisconnected];

  if (self.autoAttach)
    [_client connectOnPort:_port];
}

- (void)protocolClient:(ProtocolClient*)client receivedInitialMessage:(NSXMLDocument*)message {
  [self handleInitialResponse:message];
}

- (void)protocolClient:(ProtocolClient*)client receivedErrorMessage:(NSXMLDocument*)message {
  NSArray* error = [[message rootElement] elementsForName:@"error"];
  if ([error count] > 0) {
    NSLog(@"Xdebug error: %@", error);
    NSString* errorMessage = [[[[error objectAtIndex:0] children] objectAtIndex:0] stringValue];
    [self errorEncountered:errorMessage];
  }
}

// Specific Response Handlers //////////////////////////////////////////////////
#pragma mark Response Handlers

- (void)errorEncountered:(NSString*)error {
  [self.delegate errorEncountered:error];
}

/**
 * Initial packet received. We've started a brand-new connection to the engine.
 */
- (void)handleInitialResponse:(NSXMLDocument*)response {
  if (!self.autoAttach) {
    [_client sendCommandWithFormat:@"detach"];
    return;
  }

  _active = YES;

  // Register any breakpoints that exist offline.
  for (Breakpoint* bp in [[BreakpointManager sharedManager] breakpoints])
    [self addBreakpoint:bp];
  
  // Load the debugger to make it look active.
  [self.delegate debuggerConnected];
  
  // TODO: update the status.
}

/**
 * Receiver for status updates. This just freshens up the UI.
 */
- (void)updateStatus:(NSXMLDocument*)response {
  self.status = [[[[response rootElement] attributeForName:@"status"] stringValue] capitalizedString];
  _active = YES;
  if (!_status || [_status isEqualToString:@"Stopped"]) {
    [_delegate debuggerDisconnected];
    _active = NO;
  } else if ([_status isEqualToString:@"Stopping"]) {
    [_client sendCommandWithFormat:@"stop"];
    _active = NO;
  }
}

/**
 * Step in/out/over and run all take this path. We first get the status of the
 * debugger and then request fresh stack information.
 */
- (void)debuggerStep:(NSXMLDocument*)response {
  [self updateStatus:response];
  if (![self isConnected])
    return;

  // If this is the run command, tell the delegate that a bunch of updates
  // are coming. Also remove all existing stack routes and request a new stack.
  if ([self.delegate respondsToSelector:@selector(clobberStack)])
    [self.delegate clobberStack];

  [_client sendCommandWithFormat:@"stack_depth" handler:^(NSXMLDocument* message) {
    stackFirstTransactionID_ = [_client transactionIDFromResponse:message];
    [self rebuildStack:message];
  }];
}

/**
 * We ask for the stack_depth and now we clobber the stack and start rebuilding
 * it.
 */
- (void)rebuildStack:(NSXMLDocument*)response {
  NSInteger depth = [[[[response rootElement] attributeForName:@"depth"] stringValue] intValue];

  // We now need to alloc a bunch of stack frames and get the basic information
  // for them.
  for (NSInteger i = 0; i < depth; i++) {
    // Use the transaction ID to create a routing path.
    ProtocolClientMessageHandler handler = ^(NSXMLDocument* message) {
      NSInteger receivedTransaction = [_client transactionIDFromResponse:message];
      if (receivedTransaction < stackFirstTransactionID_)
        return;

      StackFrame* frame = [[[StackFrame alloc] init] autorelease];
      NSXMLElement* xmlframe = (NSXMLElement*)[[[message rootElement] children] objectAtIndex:0];

      // Initialize the stack frame.
      frame.index = [[[xmlframe attributeForName:@"level"] stringValue] intValue];
      frame.filename = [[xmlframe attributeForName:@"filename"] stringValue];
      frame.lineNumber = [[[xmlframe attributeForName:@"lineno"] stringValue] intValue];
      frame.function = [[xmlframe attributeForName:@"where"] stringValue];

      // Only get the complete frame for the first level. The other frames will get
      // information loaded lazily when the user clicks on one.
      if (frame.index == 0) {
        [self loadStackFrame:frame];
      }

      if ([self.delegate respondsToSelector:@selector(newStackFrame:)])
        [self.delegate newStackFrame:frame];
    };
    [_client sendCommandWithFormat:@"stack_get -d %d" handler:handler, i];
  }
}

/**
 * Enumerates all the contexts of a given stack frame. We then in turn get the
 * contents of each one of these contexts.
 */
- (void)loadContexts:(NSXMLDocument*)response forFrame:(StackFrame*)frame {
  int receivedTransaction = [_client transactionIDFromResponse:response];
  if (receivedTransaction < stackFirstTransactionID_)
    return;

  NSXMLElement* contextNames = [response rootElement];
  for (NSXMLElement* context in [contextNames children]) {
    NSInteger cid = [[[context attributeForName:@"id"] stringValue] intValue];
    
    // Fetch each context's variables.
    ProtocolClientMessageHandler handler = ^(NSXMLDocument* message) {
      NSMutableArray* variables = [NSMutableArray array];

      // Merge the frame's existing variables.
      if (frame.variables)
        [variables addObjectsFromArray:frame.variables];

      // Add these new variables.
      NSArray* addVariables = [[message rootElement] children];
      if (addVariables) {
        for (NSXMLElement* elm in addVariables) {
          VariableNode* node = [[VariableNode alloc] initWithXMLNode:elm];
          [variables addObject:[node autorelease]];
        }
      }

      frame.variables = variables;
    };
    [_client sendCommandWithFormat:@"context_get -d %d -c %d" handler:handler, frame.index, cid];
  }
}

@end

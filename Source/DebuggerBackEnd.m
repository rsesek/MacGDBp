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
#import "Breakpoint.h"
#import "DebuggerModel.h"
#import "NSXMLElementAdditions.h"
#import "StackFrame.h"

@implementation DebuggerBackEnd {
  // The connection to the debugger engine.
  uint16_t _port;
  ProtocolClient* _client;
}

- (instancetype)initWithPort:(NSUInteger)aPort autoAttach:(BOOL)doAttach
{
  if (self = [super init]) {
    _port = aPort;
    _client = [[ProtocolClient alloc] initWithDelegate:self];

    _autoAttach = doAttach;
    if (doAttach)
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
- (uint16_t)port {
  return _port;
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
  self.model.status = @"Stopped";
}

/**
 * Ends the current debugging session.
 */
- (void)detach {
  [_client sendCommandWithFormat:@"detach"];
  self.model.status = @"Stopped";
}

- (void)loadStackFrame:(StackFrame*)frame {
  if (frame.loaded)
    return;

  // Get the source code of the file. Escape % in URL chars.
  if ([frame.filename length]) {
    ProtocolClientMessageHandler handler = ^(NSXMLDocument* message) {
      frame.source = [[message rootElement] base64DecodedValue];
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

- (void)loadVariableNode:(VariableNode*)variable
           forStackFrame:(StackFrame*)frame {
  if (variable.children.count == variable.childCount)
    return;

  [self loadVariableNode:variable forStackFrame:frame dataPage:0 loadedData:@[]];
}

- (void)loadVariableNode:(VariableNode*)variable
           forStackFrame:(StackFrame*)frame
                dataPage:(unsigned int)dataPage
              loadedData:(NSArray*)loadedData {
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

    // Check to see if there are more children to load.
    NSArray* newLoadedData = [loadedData arrayByAddingObjectsFromArray:children];

    NSInteger totalChildren = [[[parent attributeForName:@"numchildren"] stringValue] integerValue];
    if ([newLoadedData count] < (NSUInteger)totalChildren) {
      [self loadVariableNode:variable
               forStackFrame:frame
                    dataPage:dataPage + 1
                  loadedData:newLoadedData];
    } else {
      [variable setChildrenFromXMLChildren:newLoadedData];
    }
  };
  [_client sendCommandWithFormat:@"property_get -d %d -n %@ -p %u" handler:handler, frame.index, variable.fullName, dataPage];
}

// Breakpoint Management ///////////////////////////////////////////////////////
#pragma mark Breakpoints

/**
 * Send an add breakpoint command
 */
- (void)addBreakpoint:(Breakpoint*)bp {
  if (!self.model.connected)
    return;

  ProtocolClientMessageHandler handler = ^(NSXMLDocument* message) {
    [bp setDebuggerId:[[[[message rootElement] attributeForName:@"id"] stringValue] intValue]];
  };
  if (bp.type == kBreakpointTypeFile) {
    NSString* file = [ProtocolClient escapedFilePathURI:[bp transformedPath]];
    [_client sendCommandWithFormat:@"breakpoint_set -t line -f %@ -n %i" handler:handler, file, [bp line]];
  } else if (bp.type == kBreakpointTypeFunctionEntry) {
    [_client sendCommandWithFormat:@"breakpoint_set -t call -m %@" handler:handler, bp.functionName];
  }
}

/**
 * Removes a breakpoint
 */
- (void)removeBreakpoint:(Breakpoint*)bp {
  if (!self.model.connected)
    return;
  
  [_client sendCommandWithFormat:@"breakpoint_remove -d %i", [bp debuggerId]];
}

/**
 * Sends a string to be evaluated by the engine.
 */
- (void)evalScript:(NSString*)str callback:(void (^)(NSString*))callback {
  if (!self.model.connected)
    return;

  NSData* stringData = [str dataUsingEncoding:NSUTF8StringEncoding];
  ProtocolClientMessageHandler handler = ^(NSXMLDocument* message) {
    NSXMLElement* parent = (NSXMLElement*)[[message rootElement] childAtIndex:0];
    NSString* value = [parent base64DecodedValue];
    callback(value);
  };
  [_client sendCustomCommandWithFormat:@"eval -i {txn} -- %@"
                               handler:handler, [stringData base64EncodedStringWithOptions:0]];
}

// Protocol Client Delegate ////////////////////////////////////////////////////
#pragma mark Protocol Client Delegate

- (void)debuggerEngineConnected:(ProtocolClient*)client {
  [_model onNewConnection];
}

/**
 * Called when the connection is finally closed. This will reopen the listening
 * socket if the debugger remains attached.
 */
- (void)debuggerEngineDisconnected:(ProtocolClient*)client {
  [_model onDisconnect];

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
    _model.lastError = errorMessage;
  }
}

// Specific Response Handlers //////////////////////////////////////////////////
#pragma mark Response Handlers

/**
 * Initial packet received. We've started a brand-new connection to the engine.
 */
- (void)handleInitialResponse:(NSXMLDocument*)response {
  if (!self.autoAttach) {
    [_client sendCommandWithFormat:@"detach"];
    return;
  }

  // Register any breakpoints that exist offline.
  for (Breakpoint* bp in self.model.breakpointManager.breakpoints)
    [self addBreakpoint:bp];
  
  // TODO: update the status.
}

/**
 * Receiver for status updates. This just freshens up the UI.
 */
- (void)updateStatus:(NSXMLDocument*)response {
  NSString* status = [[[[response rootElement] attributeForName:@"status"] stringValue] capitalizedString];
  self.model.status = status;
  if (!status || [status isEqualToString:@"Stopped"]) {
    [_model onDisconnect];
  } else if ([status isEqualToString:@"Stopping"]) {
    [_client sendCommandWithFormat:@"stop"];
  }
}

/**
 * Step in/out/over and run all take this path. We first get the status of the
 * debugger and then request fresh stack information.
 */
- (void)debuggerStep:(NSXMLDocument*)response {
  [self updateStatus:response];
  if (!self.model.connected)
    return;

  [_client sendCommandWithFormat:@"stack_depth" handler:^(NSXMLDocument* message) {
    [self rebuildStack:message];
  }];
}

/**
 * We ask for the stack_depth and now we clobber the stack and start rebuilding
 * it.
 */
- (void)rebuildStack:(NSXMLDocument*)response {
  NSUInteger depth = [[[[response rootElement] attributeForName:@"depth"] stringValue] intValue];

  // Send a request to get each frame of the stack, which will be added to this
  // array. When the final frame arrives, the |tempStack| is released.
  __block NSMutableArray* tempStack = [[NSMutableArray alloc] init];

  for (NSUInteger i = 0; i < depth; ++i) {
    ProtocolClientMessageHandler handler = ^(NSXMLDocument* message) {
      [tempStack addObject:[self transformXMLToStackFrame:message]];
      if (i == depth - 1) {
        [self.model updateStack:[tempStack autorelease]];
      }
    };
    [_client sendCommandWithFormat:@"stack_get -d %d" handler:handler, i];
  }
}

/**
 * Creates a StackFrame object from an NSXMLDocument response from the "stack_get"
 * command.
 */
- (StackFrame*)transformXMLToStackFrame:(NSXMLDocument*)response {
  NSXMLElement* xmlframe = (NSXMLElement*)[[[response rootElement] children] objectAtIndex:0];
  StackFrame* frame = [[[StackFrame alloc] init] autorelease];
  frame.index = [[[xmlframe attributeForName:@"level"] stringValue] intValue];
  frame.filename = [[xmlframe attributeForName:@"filename"] stringValue];
  frame.lineNumber = [[[xmlframe attributeForName:@"lineno"] stringValue] intValue];
  frame.function = [[xmlframe attributeForName:@"where"] stringValue];
  return frame;
}

/**
 * Enumerates all the contexts of a given stack frame. We then in turn get the
 * contents of each one of these contexts.
 */
- (void)loadContexts:(NSXMLDocument*)response forFrame:(StackFrame*)frame {
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

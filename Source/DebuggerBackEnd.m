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
#import "NSXMLElementAdditions.h"

// GDBpConnection (Private) ////////////////////////////////////////////////////

@interface DebuggerBackEnd ()
@property (readwrite, copy) NSString* status;

- (void)recordCallback:(SEL)callback forTransaction:(NSNumber*)txn;

- (void)updateStatus:(NSXMLDocument*)response;
- (void)debuggerStep:(NSXMLDocument*)response;
- (void)rebuildStack:(NSXMLDocument*)response;
- (void)getStackFrame:(NSXMLDocument*)response;
- (void)setSource:(NSXMLDocument*)response;
- (void)contextsReceived:(NSXMLDocument*)response;
- (void)variablesReceived:(NSXMLDocument*)response;
- (void)propertiesReceived:(NSXMLDocument*)response;

@end

// GDBpConnection //////////////////////////////////////////////////////////////

@implementation DebuggerBackEnd

@synthesize status;
@synthesize attached = attached_;
@synthesize delegate;

/**
 * Creates a new DebuggerBackEnd and initializes the socket from the given connection
 * paramters.
 */
- (id)initWithPort:(NSUInteger)aPort
{
  if (self = [super init])
  {
    stackFrames_ = [[NSMutableDictionary alloc] init];
    callbackContext_ = [NSMutableDictionary new];
    callTable_ = [NSMutableDictionary new];

    [[BreakpointManager sharedManager] setConnection:self];
    connection_ = [[NetworkConnection alloc] initWithPort:aPort];
    connection_.delegate = self;
    [connection_ connect];

    attached_ = [[NSUserDefaults standardUserDefaults] boolForKey:@"DebuggerAttached"];
  }
  return self;
}

/**
 * Deallocates the object
 */
- (void)dealloc
{
  [connection_ close];
  [stackFrames_ release];
  [callTable_ release];
  [callbackContext_ release];
  [super dealloc];
}


// Getters /////////////////////////////////////////////////////////////////////
#pragma mark Getters

/**
 * Gets the port number
 */
- (NSUInteger)port
{
  return [connection_ port];
}

/**
 * Returns whether or not we have an active connection
 */
- (BOOL)isConnected
{
  return [connection_ connected] && active_;
}

// Commands ////////////////////////////////////////////////////////////////////
#pragma mark Commands

/**
 * Tells the debugger to continue running the script. Returns the current stack frame.
 */
- (void)run
{
  NSNumber* tx = [connection_ sendCommandWithFormat:@"run"];
  [self recordCallback:@selector(debuggerStep:) forTransaction:tx];
}

/**
 * Tells the debugger to step into the current command.
 */
- (void)stepIn
{
  NSNumber* tx = [connection_ sendCommandWithFormat:@"step_into"];
  [self recordCallback:@selector(debuggerStep:) forTransaction:tx];
}

/**
 * Tells the debugger to step out of the current context
 */
- (void)stepOut
{
  NSNumber* tx = [connection_ sendCommandWithFormat:@"step_out"];
  [self recordCallback:@selector(debuggerStep:) forTransaction:tx];
}

/**
 * Tells the debugger to step over the current function
 */
- (void)stepOver
{
  NSNumber* tx = [connection_ sendCommandWithFormat:@"step_over"];
  [self recordCallback:@selector(debuggerStep:) forTransaction:tx];
}

/**
 * Halts execution of the script.
 */
- (void)stop
{
  [connection_ close];
  active_ = NO;
  self.status = @"Stopped";
  if ([delegate respondsToSelector:@selector(debuggerDisconnected)])
    [delegate debuggerDisconnected];
}

/**
 * Ends the current debugging session.
 */
- (void)detach
{
  [connection_ sendCommandWithFormat:@"detach"];
  active_ = NO;
  self.status = @"Stopped";
  if ([delegate respondsToSelector:@selector(debuggerDisconnected)])
    [delegate debuggerDisconnected];
}

/**
 * Tells the debugger engine to get a specifc property. This also takes in the NSXMLElement
 * that requested it so that the child can be attached.
 */
- (NSInteger)getChildrenOfProperty:(VariableNode*)property atDepth:(NSInteger)depth;
{
  NSNumber* tx = [connection_ sendCommandWithFormat:@"property_get -d %d -n %@", depth, [property fullName]];
  [self recordCallback:@selector(propertiesReceived:) forTransaction:tx];
  return [tx intValue];
}

- (void)loadStackFrame:(StackFrame*)frame
{
  if (frame.loaded)
    return;

  NSNumber* routingNumber = [NSNumber numberWithInt:frame.routingID];
  NSNumber* transaction = nil;

  // Get the source code of the file. Escape % in URL chars.
  if ([frame.filename length]) {
    NSString* escapedFilename = [frame.filename stringByReplacingOccurrencesOfString:@"%" withString:@"%%"];
    transaction = [connection_ sendCommandWithFormat:@"source -f %@", escapedFilename];
    [self recordCallback:@selector(setSource:) forTransaction:transaction];
    [callbackContext_ setObject:routingNumber forKey:transaction];
  }
  
  // Get the names of all the contexts.
  transaction = [connection_ sendCommandWithFormat:@"context_names -d %d", frame.index];
  [self recordCallback:@selector(contextsReceived:) forTransaction:transaction];
  [callbackContext_ setObject:routingNumber forKey:transaction];
  
  // This frame will be fully loaded.
  frame.loaded = YES;
}

// Breakpoint Management ///////////////////////////////////////////////////////
#pragma mark Breakpoints

/**
 * Send an add breakpoint command
 */
- (void)addBreakpoint:(Breakpoint*)bp
{
  if (![connection_ connected])
    return;
  
  NSString* file = [connection_ escapedURIPath:[bp transformedPath]];
  NSNumber* tx = [connection_ sendCommandWithFormat:@"breakpoint_set -t line -f %@ -n %i", file, [bp line]];
  [self recordCallback:@selector(breakpointReceived:) forTransaction:tx];
  [callbackContext_ setObject:bp forKey:tx];
}

/**
 * Removes a breakpoint
 */
- (void)removeBreakpoint:(Breakpoint*)bp
{
  if (![connection_ connected])
    return;
  
  [connection_ sendCommandWithFormat:@"breakpoint_remove -d %i", [bp debuggerId]];
}

// Specific Response Handlers //////////////////////////////////////////////////
#pragma mark Response Handlers

- (void)errorEncountered:(NSString*)error
{
  [delegate errorEncountered:error];
}

/**
 * Initial packet received. We've started a brand-new connection to the engine.
 */
- (void)handleInitialResponse:(NSXMLDocument*)response
{
  if (!self.attached) {
    [connection_ sendCommandWithFormat:@"detach"];
    return;
  }

  active_ = YES;

  // Register any breakpoints that exist offline.
  for (Breakpoint* bp in [[BreakpointManager sharedManager] breakpoints])
    [self addBreakpoint:bp];
  
  // Load the debugger to make it look active.
  [delegate debuggerConnected];
  
  // TODO: update the status.
}

- (void)handleResponse:(NSXMLDocument*)response
{
  NSInteger transactionID = [connection_ transactionIDFromResponse:response];
  NSNumber* key = [NSNumber numberWithInt:transactionID];
  NSString* callbackStr = [callTable_ objectForKey:key];
  if (callbackStr)
  {
    SEL callback = NSSelectorFromString(callbackStr);
    [self performSelector:callback withObject:response];
  }
  [callTable_ removeObjectForKey:key];
}  

/**
 * Receiver for status updates. This just freshens up the UI.
 */
- (void)updateStatus:(NSXMLDocument*)response
{
  self.status = [[[[response rootElement] attributeForName:@"status"] stringValue] capitalizedString];
  active_ = YES;
  if (!status || [status isEqualToString:@"Stopped"]) {
    [delegate debuggerDisconnected];
    active_ = NO;
  } else if ([status isEqualToString:@"Stopping"]) {
    [connection_ sendCommandWithFormat:@"stop"];
    active_ = NO;
  }
}

/**
 * Step in/out/over and run all take this path. We first get the status of the
 * debugger and then request fresh stack information.
 */
- (void)debuggerStep:(NSXMLDocument*)response
{
  [self updateStatus:response];
  if (![self isConnected])
    return;

  // If this is the run command, tell the delegate that a bunch of updates
  // are coming. Also remove all existing stack routes and request a new stack.
  if ([delegate respondsToSelector:@selector(clobberStack)])
    [delegate clobberStack];
  [stackFrames_ removeAllObjects];
  NSNumber* tx = [connection_ sendCommandWithFormat:@"stack_depth"];
  [self recordCallback:@selector(rebuildStack:) forTransaction:tx];
  stackFirstTransactionID_ = [tx intValue];
}

/**
 * We ask for the stack_depth and now we clobber the stack and start rebuilding
 * it.
 */
- (void)rebuildStack:(NSXMLDocument*)response
{
  NSInteger depth = [[[[response rootElement] attributeForName:@"depth"] stringValue] intValue];
  
  if (stackFirstTransactionID_ == [connection_ transactionIDFromResponse:response])
    stackDepth_ = depth;
  
  // We now need to alloc a bunch of stack frames and get the basic information
  // for them.
  for (NSInteger i = 0; i < depth; i++)
  {
    // Use the transaction ID to create a routing path.
    NSNumber* routingID = [connection_ sendCommandWithFormat:@"stack_get -d %d", i];
    [self recordCallback:@selector(getStackFrame:) forTransaction:routingID];
    [stackFrames_ setObject:[[StackFrame new] autorelease] forKey:routingID];
  }
}

/**
 * The initial rebuild of the stack frame. We now have enough to initialize
 * a StackFrame object.
 */
- (void)getStackFrame:(NSXMLDocument*)response
{
  // Get the routing information.
  NSInteger routingID = [connection_ transactionIDFromResponse:response];
  if (routingID < stackFirstTransactionID_)
    return;
  NSNumber* routingNumber = [NSNumber numberWithInt:routingID];
  
  // Make sure we initialized this frame in our last |-rebuildStack:|.
  StackFrame* frame = [stackFrames_ objectForKey:routingNumber];
  if (!frame)
    return;
  
  NSXMLElement* xmlframe = [[[response rootElement] children] objectAtIndex:0];
  
  // Initialize the stack frame.
  frame.index = [[[xmlframe attributeForName:@"level"] stringValue] intValue];
  frame.filename = [[xmlframe attributeForName:@"filename"] stringValue];
  frame.lineNumber = [[[xmlframe attributeForName:@"lineno"] stringValue] intValue];
  frame.function = [[xmlframe attributeForName:@"where"] stringValue];
  frame.routingID = routingID;

  // Only get the complete frame for the first level. The other frames will get
  // information loaded lazily when the user clicks on one.
  if (frame.index == 0) {
    [self loadStackFrame:frame];
  }
  
  if ([delegate respondsToSelector:@selector(newStackFrame:)])
    [delegate newStackFrame:frame];
}

/**
 * Callback for setting the source of a file while rebuilding a specific stack
 * frame.
 */
- (void)setSource:(NSXMLDocument*)response
{
  NSNumber* transaction = [NSNumber numberWithInt:[connection_ transactionIDFromResponse:response]];
  if ([transaction intValue] < stackFirstTransactionID_)
    return;
  NSNumber* routingNumber = [callbackContext_ objectForKey:transaction];
  if (!routingNumber)
    return;
  
  [callbackContext_ removeObjectForKey:transaction];
  StackFrame* frame = [stackFrames_ objectForKey:routingNumber];
  if (!frame)
    return;
  
  frame.source = [[response rootElement] base64DecodedValue];
  
  if ([delegate respondsToSelector:@selector(sourceUpdated:)])
    [delegate sourceUpdated:frame];
}

/**
 * Enumerates all the contexts of a given stack frame. We then in turn get the
 * contents of each one of these contexts.
 */
- (void)contextsReceived:(NSXMLDocument*)response
{
  // Get the stack frame's routing ID and use it again.
  NSNumber* receivedTransaction = [NSNumber numberWithInt:[connection_ transactionIDFromResponse:response]];
  if ([receivedTransaction intValue] < stackFirstTransactionID_)
    return;
  NSNumber* routingID = [callbackContext_ objectForKey:receivedTransaction];
  if (!routingID)
    return;
  
  // Get the stack frame by the |routingID|.
  StackFrame* frame = [stackFrames_ objectForKey:routingID];
  
  NSXMLElement* contextNames = [response rootElement];
  for (NSXMLElement* context in [contextNames children])
  {
    NSInteger cid = [[[context attributeForName:@"id"] stringValue] intValue];
    
    // Fetch each context's variables.
    NSNumber* tx = [connection_ sendCommandWithFormat:@"context_get -d %d -c %d", frame.index, cid];
    [self recordCallback:@selector(variablesReceived:) forTransaction:tx];
    [callbackContext_ setObject:routingID forKey:tx];
  }
}

/**
 * Receives the variables from the context and attaches them to the stack frame.
 */
- (void)variablesReceived:(NSXMLDocument*)response
{
  // Get the stack frame's routing ID and use it again.
  NSInteger transaction = [connection_ transactionIDFromResponse:response];
  if (transaction < stackFirstTransactionID_)
    return;
  NSNumber* receivedTransaction = [NSNumber numberWithInt:transaction];
  NSNumber* routingID = [callbackContext_ objectForKey:receivedTransaction];
  if (!routingID)
    return;
  
  // Get the stack frame by the |routingID|.
  StackFrame* frame = [stackFrames_ objectForKey:routingID];

  NSMutableArray* variables = [NSMutableArray array];

  // Merge the frame's existing variables.
  if (frame.variables)
    [variables addObjectsFromArray:frame.variables];

  // Add these new variables.
  NSArray* addVariables = [[response rootElement] children];
  if (addVariables) {
    for (NSXMLElement* elm in addVariables) {
      VariableNode* node = [[VariableNode alloc] initWithXMLNode:elm];
      [variables addObject:[node autorelease]];
    }
  }

  frame.variables = variables;
}

/**
 * Callback from a |-getProperty:| request.
 */
- (void)propertiesReceived:(NSXMLDocument*)response
{
  NSInteger transaction = [connection_ transactionIDFromResponse:response];
  
  /*
   <response>
     <property> <!-- this is the one we requested -->
       <property ... /> <!-- these are what we want -->
     </property>
   </repsonse>
   */
  
  // Detach all the children so we can insert them into another document.
  NSXMLElement* parent = (NSXMLElement*)[[response rootElement] childAtIndex:0];
  NSArray* children = [parent children];
  [parent setChildren:nil];
  
  [delegate receivedProperties:children forTransaction:transaction];
}

/**
 * Callback for setting a breakpoint.
 */
- (void)breakpointReceived:(NSXMLDocument*)response
{
  NSNumber* transaction = [NSNumber numberWithInt:[connection_ transactionIDFromResponse:response]];
  Breakpoint* bp = [callbackContext_ objectForKey:transaction];
  if (!bp)
    return;
  
  [callbackContext_ removeObjectForKey:callbackContext_];
  [bp setDebuggerId:[[[[response rootElement] attributeForName:@"id"] stringValue] intValue]];
}

// Private /////////////////////////////////////////////////////////////////////

- (void)recordCallback:(SEL)callback forTransaction:(NSNumber*)txn
{
  [callTable_ setObject:NSStringFromSelector(callback) forKey:txn];
}

@end

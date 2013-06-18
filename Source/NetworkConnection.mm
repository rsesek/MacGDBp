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

#import "NetworkConnection.h"

#import "AppDelegate.h"
#import "LoggingController.h"

// This is the private interface for the NetworkConnection class. This is shared
// by the C++ NetworkCallbackController to communicate.
@interface NetworkConnection (Private)

- (void)handleResponse:(NSXMLDocument*)response;

// Threadsafe wrappers for the delegate's methods.
- (void)errorEncountered:(NSString*)error;
- (LogEntry*)recordSend:(NSString*)command;
- (LogEntry*)recordReceive:(NSString*)command;

@end


////////////////////////////////////////////////////////////////////////////////

@implementation NetworkConnection

@synthesize port = port_;
@synthesize connected = connected_;
@synthesize delegate = delegate_;

- (id)initWithPort:(NSUInteger)aPort
{
  if (self = [super init]) {
    port_ = aPort;
    _ideClient = [[ProtocolClient alloc] initWithDelegate:self];
  }
  return self;
}

/**
 * Kicks off the socket on another thread.
 */
- (void)connect
{
  [_ideClient connectOnPort:port_];
}

- (void)close
{
  [_ideClient disconnect];
}

- (void)debuggerEngineConnected:(ProtocolClient*)client
{
  if ([delegate_ respondsToSelector:@selector(connectionDidAccept:)])
    [delegate_ connectionDidAccept:self];
}

- (void)debuggerEngineDisconnected:(ProtocolClient*)client
{
  if ([delegate_ respondsToSelector:@selector(connectionDidClose:)])
    [delegate_ connectionDidClose:self];
}

- (void)debuggerEngine:(ProtocolClient*)client receivedMessage:(NSXMLDocument*)message
{
  [self handleResponse:message];
}

- (void)dealloc
{
  [_ideClient release];
  [super dealloc];
}

/**
 * Given a file path, this returns a file:// URI and escapes any spaces for the
 * debugger engine.
 */
- (NSString*)escapedURIPath:(NSString*)path
{
  // Custon GDBp paths are fine.
  if ([[path substringToIndex:4] isEqualToString:@"gdbp"])
    return path;
  
  // Create a temporary URL that will escape all the nasty characters.
  NSURL* url = [NSURL fileURLWithPath:path];
  NSString* urlString = [url absoluteString];
  
  // Remove the host because this is a file:// URL;
  urlString = [urlString stringByReplacingOccurrencesOfString:[url host] withString:@""];
  
  // Escape % for use in printf-style NSString formatters.
  urlString = [urlString stringByReplacingOccurrencesOfString:@"%" withString:@"%%"];
  return urlString;
}

// Private /////////////////////////////////////////////////////////////////////
#pragma mark Private

// Delegate Thread-Safe Wrappers ///////////////////////////////////////////////

/**
 * Receives errors from the SocketWrapper and updates the display
 */
- (void)errorEncountered:(NSString*)error
{
  if (![delegate_ respondsToSelector:@selector(errorEncountered:)])
    return;
  [delegate_ performSelectorOnMainThread:@selector(errorEncountered:)
                              withObject:error
                           waitUntilDone:NO];
}

- (LogEntry*)recordSend:(NSString*)command
{
  LoggingController* logger = [[AppDelegate instance] loggingController];
  LogEntry* entry = [LogEntry newSendEntry:command];
  entry.lastReadTransactionID = _lastReadID;
  entry.lastWrittenTransactionID = _lastWrittenID;
  [logger performSelectorOnMainThread:@selector(recordEntry:)
                           withObject:entry
                        waitUntilDone:NO];
  return [entry autorelease];
}

- (LogEntry*)recordReceive:(NSString*)command
{
  LoggingController* logger = [[AppDelegate instance] loggingController];
  LogEntry* entry = [LogEntry newReceiveEntry:command];
  entry.lastReadTransactionID = _lastReadID;
  entry.lastWrittenTransactionID = _lastWrittenID;
  [logger performSelectorOnMainThread:@selector(recordEntry:)
                           withObject:entry
                        waitUntilDone:NO];
  return [entry autorelease];
}

- (void)handleResponse:(NSXMLDocument*)response
{
  // Check and see if there's an error.
  NSArray* error = [[response rootElement] elementsForName:@"error"];
  if ([error count] > 0) {
    NSLog(@"Xdebug error: %@", error);
    NSString* errorMessage = [[[[error objectAtIndex:0] children] objectAtIndex:0] stringValue];
    [self errorEncountered:errorMessage];
  }
  
  if ([[[response rootElement] name] isEqualToString:@"init"]) {
    connected_ = YES;
    [delegate_ handleInitialResponse:response];
    return;
  }
  
  if ([delegate_ respondsToSelector:@selector(handleResponse:)])
    [delegate_ handleResponse:response];
}

@end

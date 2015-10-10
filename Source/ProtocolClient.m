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

#import "ProtocolClient.h"

#import "AppDelegate.h"
#import "LoggingController.h"

@implementation ProtocolClient {
  // The object responsible for the actual communication with the debug server.
  MessageQueue* _messageQueue;

  // The delegate of this class, which receives high-level messages about the
  // state of the debugger.
  id<ProtocolClientDelegate> _delegate;  // weak

  // A map between transaction ID and handler block for that message.
  NSMutableDictionary<NSNumber*, ProtocolClientMessageHandler>* _dispatchTable;

  // The next transaction ID to assign.
  int _nextID;

  // Records the last read and written transaction IDs. These are only used in
  // creating LogEntry objects.
  NSInteger _lastReadID;
  NSInteger _lastWrittenID;
}

- (id)initWithDelegate:(id<ProtocolClientDelegate>)delegate {
  if ((self = [super init])) {
    _delegate = delegate;
    _dispatchTable = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [_dispatchTable release];
  [super dealloc];
}

- (BOOL)isConnected {
  return [_messageQueue isConnected];
}

- (void)connectOnPort:(NSUInteger)port {
  assert(!_messageQueue);
  _messageQueue = [[MessageQueue alloc] initWithPort:port delegate:self];
  [_messageQueue connect];
}

- (void)disconnect {
  [_messageQueue disconnect];
}

- (NSNumber*)sendCommandWithFormat:(NSString*)format, ... {
  // Collect varargs and format command.
  va_list args;
  va_start(args, format);
  NSString* command = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);

  NSNumber* callbackKey = [NSNumber numberWithInt:_nextID++];
  NSString* taggedCommand = [NSString stringWithFormat:@"%@ -i %@", [command autorelease], callbackKey];

  assert(_messageQueue);
  [_messageQueue sendMessage:taggedCommand];
  return callbackKey;
}

- (void)sendCommandWithFormat:(NSString*)format
                      handler:(ProtocolClientMessageHandler)handler, ... {
  // Collect varargs and format command.
  va_list args;
  va_start(args, handler);
  NSString* command = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);

  int transaction = _nextID++;
  NSString* taggedCommand = [NSString stringWithFormat:@"%@ -i %d", [command autorelease], transaction];

  assert(_messageQueue);
  [_dispatchTable setObject:[[handler copy] autorelease] forKey:@(transaction)];
  [_messageQueue sendMessage:taggedCommand];
}

- (NSNumber*)sendCustomCommandWithFormat:(NSString*)format, ... {
  // Collect varargs and format command.
  va_list args;
  va_start(args, format);
  NSString* command = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
  va_end(args);

  NSNumber* callbackKey = [NSNumber numberWithInt:_nextID++];
  NSString* taggedCommand = [command stringByReplacingOccurrencesOfString:@"{txn}"
                                                               withString:[callbackKey stringValue]];

  [_messageQueue sendMessage:taggedCommand];
  return callbackKey;
}

- (NSInteger)transactionIDFromResponse:(NSXMLDocument*)response {
  return [[[[response rootElement] attributeForName:@"transaction_id"] stringValue] intValue];
}

- (NSInteger)transactionIDFromCommand:(NSString*)command {
  NSRange occurrence = [command rangeOfString:@"-i "];
  if (occurrence.location == NSNotFound)
    return NSNotFound;
  NSString* transaction = [command substringFromIndex:occurrence.location + occurrence.length];
  return [transaction intValue];
}

+ (NSString*)escapedFilePathURI:(NSString*)path {
  // Custon GDBp paths are fine.
  if ([[path substringToIndex:4] isEqualToString:@"gdbp"])
    return path;

  // Create a temporary URL that will escape all the nasty characters.
  NSURL* url = [NSURL fileURLWithPath:path];
  NSString* urlString = [url absoluteString];

  // Remove the host because this is a file:// URL;
  NSString* host = [url host];
  if (host)
    urlString = [urlString stringByReplacingOccurrencesOfString:[url host] withString:@""];

  // Escape % for use in printf-style NSString formatters.
  urlString = [urlString stringByReplacingOccurrencesOfString:@"%" withString:@"%%"];
  return urlString;
}

// MessageQueueDelegate ////////////////////////////////////////////////////////

- (void)messageQueue:(MessageQueue*)queue error:(NSError*)error {
  NSLog(@"error = %@", error);
}

- (void)messageQueueDidConnect:(MessageQueue*)queue {
  _nextID = 0;
  _lastReadID = 0;
  _lastWrittenID = 0;

  [_delegate debuggerEngineConnected:self];
}

- (void)messageQueueDidDisconnect:(MessageQueue*)queue {
  [_messageQueue release];
  _messageQueue = nil;
  [_dispatchTable removeAllObjects];
  [_delegate debuggerEngineDisconnected:self];
}

// Callback for when a message has been sent.
- (void)messageQueue:(MessageQueue*)queue didSendMessage:(NSString*)message {
  NSInteger tag = [self transactionIDFromCommand:message];
  _lastWrittenID = tag;

  LoggingController* logger = [[AppDelegate instance] loggingController];
  LogEntry* entry = [LogEntry newSendEntry:message];
  entry.lastReadTransactionID = _lastReadID;
  entry.lastWrittenTransactionID = _lastWrittenID;
  [logger recordEntry:entry];
}

// Callback with the message content when one has been receieved.
- (void)messageQueue:(MessageQueue*)queue didReceiveMessage:(NSString*)message {
  // Record this message in the transaction log.
  LoggingController* logger = [[AppDelegate instance] loggingController];
  LogEntry* entry = [LogEntry newReceiveEntry:message];
  entry.lastReadTransactionID = _lastReadID;
  entry.lastWrittenTransactionID = _lastWrittenID;
  [logger recordEntry:entry];

  // Parse the XML and test for errors.
  NSError* error = nil;
  NSXMLDocument* xml = [[NSXMLDocument alloc] initWithXMLString:message
                                                        options:NSXMLDocumentTidyXML
                                                          error:&error];
  if (error) {
    [self messageQueue:queue error:error];
    return;
  }
  int transactionID = [self transactionIDFromResponse:xml];

  _lastReadID = transactionID;
  entry.lastReadTransactionID = _lastReadID;

  if ([[[xml rootElement] elementsForName:@"error"] count] > 0) {
    // Handle back-end errors.
    [_delegate protocolClient:self receivedErrorMessage:xml];
  } else if ([[[xml rootElement] name] isEqualToString:@"init"]) {
    // Handle the initial connection message.
    [_delegate protocolClient:self receivedInitialMessage:xml];
  } else {
    // Dispatch the handler for the message.
    ProtocolClientMessageHandler handler = [_dispatchTable objectForKey:@(transactionID)];
    if (handler) {
      handler(xml);
      [_dispatchTable removeObjectForKey:@(transactionID)];
    } else {
      // TODO(rsesek): Remove this path once the backend rewrite is complete.
      [_delegate debuggerEngine:self receivedMessage:xml];
    }
  }
}

@end

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

#import <Foundation/Foundation.h>

#import "MessageQueue.h"

@protocol ProtocolClientDelegate;

typedef void (^ProtocolClientMessageHandler)(NSXMLDocument*);

// ProtocolClient sends string commands to a DBGP <http://www.xdebug.org/docs-dbgp.php>
// debugger engine and receives XML packets in response. This class ensures
// proper sequencing of the messages.
@interface ProtocolClient : NSObject<MessageQueueDelegate>

- (id)initWithDelegate:(id<ProtocolClientDelegate>)delegate;

- (BOOL)isConnected;

- (void)connectOnPort:(NSUInteger)port;
- (void)disconnect;

// This sends the given command format to the debugger. This method is thread
// safe and schedules the request on the |runLoop_|.
- (NSNumber*)sendCommandWithFormat:(NSString*)format, ...;

// Sends a command with the given |format| to the debugger. When a response is
// received, |handler| is invoked. If an error occurs or the connection is
// interrupted, the delegate will be notified.
- (void)sendCommandWithFormat:(NSString*)format
                      handler:(ProtocolClientMessageHandler)handler,
                      ...;

// Sends a command to the debugger. The command must have a substring |{txn}|
// within it, which will be replaced with the transaction ID. Use this if
// |-sendCommandWithFormat:|'s insertion of the transaction ID is incorrect.
- (void)sendCustomCommandWithFormat:(NSString*)format
                            handler:(ProtocolClientMessageHandler)handler,
                            ...;

- (NSInteger)transactionIDFromResponse:(NSXMLDocument*)response;
- (NSInteger)transactionIDFromCommand:(NSString*)command;

// Given a path to a file, creates a URI for it that is suitable for sending to
// the debugger engine.
+ (NSString*)escapedFilePathURI:(NSString*)path;

@end

// Delegate ////////////////////////////////////////////////////////////////////

// All methods of the protocol client are dispatched to the thread on which the
// ProtocolClient was created.
@protocol ProtocolClientDelegate
- (void)debuggerEngineConnected:(ProtocolClient*)client;
- (void)debuggerEngineDisconnected:(ProtocolClient*)client;
- (void)protocolClient:(ProtocolClient*)client receivedInitialMessage:(NSXMLDocument*)message;
- (void)protocolClient:(ProtocolClient*)client receivedErrorMessage:(NSXMLDocument*)message;
- (void)debuggerEngine:(ProtocolClient*)client receivedMessage:(NSXMLDocument*)message;
@end

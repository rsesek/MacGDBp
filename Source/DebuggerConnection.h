/*
 * MacGDBp
 * Copyright (c) 2007 - 2008, Blue Static <http://www.bluestatic.org>
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

#import <Cocoa/Cocoa.h>
#import "DebuggerController.h"
#import "SocketWrapper.h"
#import "Breakpoint.h"

@interface DebuggerConnection : NSObject
{
	int port;
	NSString *session;
	BOOL connected;
	
	DebuggerController *windowController;
	
	SocketWrapper *socket;
}

@property(readonly) SocketWrapper *socket;
@property(readonly) DebuggerController *windowController;

// initializer
- (id)initWithWindowController:(DebuggerController *)wc port:(int)aPort session:(NSString *)aSession;

// getter
- (int)port;
- (NSString *)session;
- (NSString *)remoteHost;
- (BOOL)isConnected;

// communication
- (void)reconnect;
- (void)run;
- (void)stepIn;
- (void)stepOut;
- (void)stepOver;
- (void)addBreakpoint:(Breakpoint *)bp;
- (void)removeBreakpoint:(Breakpoint *)bp;
- (void)refreshStatus;
- (void)updateStackTraceAndRegisters;

// helpers
- (NSArray *)getProperty:(NSString *)property;

@end

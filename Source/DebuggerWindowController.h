/*
 * MacGDBp
 * Copyright (c) 2002 - 2007, Blue Static <http://www.bluestatic.org>
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

@class DebuggerConnection;

@interface DebuggerWindowController : NSWindowController
{
	DebuggerConnection *connection;
	
	IBOutlet NSArrayController *stackController;
	NSArray *stack;
	
	IBOutlet NSTreeController *registerController;
	IBOutlet NSOutlineView *registerView;
	NSMutableArray *expandedRegisters;
	
	IBOutlet NSTextField *status;
	IBOutlet NSTextField *errormsg;
	
	IBOutlet NSTextView *sourceViewer;
	IBOutlet NSScrollView *sourceViewerScroller;
	
	IBOutlet NSButton *stepInButton;
	IBOutlet NSButton *stepOutButton;
	IBOutlet NSButton *stepOverButton;
	IBOutlet NSButton *runButton;
	IBOutlet NSButton *_reconnectButton;
}

- (id)initWithConnection:(DebuggerConnection *)cnx;

- (void)setStatus:(NSString *)aStatus;
- (void)setError:(NSString *)anError;
- (void)setStack:(NSArray *)node;
- (void)setRegister:(NSXMLDocument *)reg;

- (void)addChildren:(NSArray *)children toNode:(id)node;

- (IBAction)run:(id)sender;
- (IBAction)stepIn:(id)sender;
- (IBAction)stepOut:(id)sender;
- (IBAction)stepOver:(id)sender;
- (IBAction)reconnect:(id)sender;

@end

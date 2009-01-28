/*
 * MacGDBp
 * Copyright (c) 2007 - 2009, Blue Static <http://www.bluestatic.org>
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
#import "BSSourceView.h"
#import "StackController.h"

@class GDBpConnection;

@interface DebuggerController : NSWindowController
{
	GDBpConnection *connection;
	
	StackController *stackController;
	IBOutlet NSArrayController *stackArrayController;
	
	IBOutlet NSTreeController *variablesTreeController;
	IBOutlet NSOutlineView *variablesOutlineView;
	NSMutableSet *expandedVariables;
	
	IBOutlet NSTextField *statusmsg;
	IBOutlet NSTextField *errormsg;
	
	IBOutlet BSSourceView *sourceViewer;
}

@property(readonly) GDBpConnection *connection;
@property(readonly) BSSourceView *sourceViewer;

- (void)resetDisplays;

- (void)setError:(NSString *)anError;

- (void)startDebugger;

- (IBAction)run:(id)sender;
- (IBAction)stepIn:(id)sender;
- (IBAction)stepOut:(id)sender;
- (IBAction)stepOver:(id)sender;
- (IBAction)reconnect:(id)sender;

@end

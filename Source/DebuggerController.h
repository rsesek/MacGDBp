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

#import <Cocoa/Cocoa.h>

#include "VariableNode.h"

@class BSSourceView;
@class DebuggerBackEnd;
@class DebuggerModel;

@interface DebuggerController : NSWindowController <NSWindowDelegate>

@property(readonly) DebuggerBackEnd* connection;
@property(readonly) DebuggerModel* model;

@property(retain) IBOutlet BSSourceView* sourceViewer;
@property(retain) IBOutlet NSWindow* inspector;

@property(retain) IBOutlet NSButton* attachedCheckbox;
@property(retain) IBOutlet NSArrayController* stackArrayController;
@property(retain) IBOutlet NSTreeController* variablesTreeController;
@property(retain) IBOutlet NSOutlineView* variablesOutlineView;

@property(retain) IBOutlet NSTextField* statusField;
@property(retain) IBOutlet NSSegmentedControl* segmentControl;
@property(retain) IBOutlet NSTabView* tabView;

- (IBAction)showInspectorWindow:(id)sender;
- (IBAction)showEvalWindow:(id)sender;

- (IBAction)attachedToggled:(id)sender;

- (IBAction)run:(id)sender;
- (IBAction)stepIn:(id)sender;
- (IBAction)stepOut:(id)sender;
- (IBAction)stepOver:(id)sender;
- (IBAction)stop:(id)sender;

@end

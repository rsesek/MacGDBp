/*
 * MacGDBp
 * Copyright (c) 2011, Blue Static <http://www.bluestatic.org>
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

@class DebuggerBackEnd;

@interface EvalController : NSWindowController {
 @private
  DebuggerBackEnd* backEnd_;

  // Outlets.
  NSTextField* dataField_;
  NSTextField* resultField_;
}

@property(nonatomic, retain) IBOutlet NSTextField* dataField;
@property(nonatomic, retain) IBOutlet NSTextField* resultField;

- (id)initWithBackEnd:(DebuggerBackEnd*)backEnd;

- (void)runModalForWindow:(NSWindow*)parent;

- (IBAction)evaluateScript:(id)sender;
- (IBAction)closeWindow:(id)sender;

// Callback from the DebuggerBackEnd that is routed through the
// DebuggerController. This will message the current EvalController if it is
// running modally. If the controller is not running, the message will be
// dropped.
+ (void)scriptWasEvaluatedWithResult:(NSString*)result;

@end

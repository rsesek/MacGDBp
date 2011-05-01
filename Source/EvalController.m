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

#import "EvalController.h"

#import "DebuggerBackEnd.h"

static EvalController* g_activeEvalController = nil;

@implementation EvalController

@synthesize dataField = dataField_;
@synthesize resultField = resultField_;

- (id)initWithBackEnd:(DebuggerBackEnd*)backEnd
{
  if (self = [super initWithWindowNibName:@"Eval"]) {
    backEnd_ = backEnd;
  }
  return self;
}

- (void)dealloc
{
  self.dataField = nil;
  self.resultField = nil;
  [super dealloc];
}

- (void)runModalForWindow:(NSWindow*)parent
{
  assert(!g_activeEvalController);
  g_activeEvalController = self;
  [NSApp beginSheet:[self window]
     modalForWindow:parent
      modalDelegate:self
     didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
        contextInfo:nil];
}

- (void)sheetDidEnd:(NSWindow*)sheet
         returnCode:(NSInteger)returnCode
        contextInfo:(void*)contextInfo
{
  g_activeEvalController = nil;
  [self autorelease];
}

- (IBAction)evaluateScript:(id)sender
{
  NSString* code = [self.dataField stringValue];
  [backEnd_ evalScript:code];
}

- (IBAction)closeWindow:(id)sender
{
  [self close];
  [NSApp endSheet:[self window]];
}

+ (void)scriptWasEvaluatedWithResult:(NSString*)result
{
  [g_activeEvalController.resultField setStringValue:result];
}

@end

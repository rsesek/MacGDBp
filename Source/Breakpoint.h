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

extern NSString* const kBreakpointTypeFile;
extern NSString* const kBreakpointTypeFunctionEntry;

// This represents a breakpoint at a certain file and line number. It also
// maintains the identifier that the backend assigns to the breakpoint.
@interface Breakpoint : NSObject

// The type of breakpoint, one of the kBreakpointType constants above.
@property (readonly) NSString* type;

// The unique identifier assigned by the debugger engine, only valid while
// connected.
@property (readwrite, assign) unsigned long debuggerId;

// kBreakpointTypeFile:
@property (readonly) NSString* file;
@property (readonly) unsigned long line;

// kBreakpointTypeFunctionEntry:
@property (readonly) NSString* functionName;

- (instancetype)initWithLine:(unsigned long)l inFile:(NSString*)f;
- (instancetype)initWithFunctionNamed:(NSString*)function;

// Initializer from NSUserDefaults.
- (instancetype)initWithDictionary:(NSDictionary*)dict;

- (NSString*)transformedPath;

// Creates a dictionary representation for use in NSUserDefaults.
- (NSDictionary*)dictionary;

@end

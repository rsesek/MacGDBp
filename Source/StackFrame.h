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

@class VariableNode;

@interface StackFrame : NSObject

/**
 * Whether or not the stack frame has been fully loaded.
 */
@property(nonatomic) BOOL loaded;

/**
 * The position in the stack
 */
@property(readwrite, nonatomic) NSUInteger index;

/**
 * File the current frame is in
 */
@property(copy, nonatomic) NSString* filename;

/**
 * Cached, highlighted version of the source
 */
@property(copy, nonatomic) NSString* source;

/**
 * Line number of the source the frame points to
 */
@property(readwrite, nonatomic) NSUInteger lineNumber;

/**
 * Current-executing function
 */
@property(copy, nonatomic) NSString* function;

/**
 * Variable list
 */
@property(retain, nonatomic) NSArray<VariableNode*>* variables;

/**
 * Whether or not this is the same stack scope as |frame|.
 */
- (BOOL)isShiftedFrame:(StackFrame*)frame;

@end

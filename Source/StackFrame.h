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

@interface StackFrame : NSObject
{
  /**
   * Whether or not the stack frame has been fully loaded.
   */
  BOOL loaded_;

  /**
   * The position in the stack
   */
  NSUInteger index_;
  
  /**
   * File the current frame is in
   */
  NSString* filename_;
  
  /**
   * Cached, highlighted version of the source
   */
  NSString* source_;
  
  /**
   * Line number of the source the frame points to
   */
  NSUInteger lineNumber_;
  
  /**
   * Current-executing function
   */
  NSString* function_;
  
  /**
   * Variable list
   */
  NSArray* variables_;
}

@property BOOL loaded;
@property (readwrite) NSUInteger index;
@property (copy) NSString* filename;
@property (copy) NSString* source;
@property (readwrite) NSUInteger lineNumber;
@property (copy) NSString* function;
@property (retain) NSArray* variables;

- (BOOL)isShiftedFrame:(StackFrame*)frame;

@end

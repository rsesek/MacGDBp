/*
 * MacGDBp
 * Copyright (c) 2007 - 2010, Blue Static <http://www.bluestatic.org>
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
	 * The position in the stack
	 */
	int index;
	
	/**
	 * File the current frame is in
	 */
	NSString* filename;
	
	/**
	 * Cached, highlighted version of the source
	 */
	NSString* source;
	
	/**
	 * Line number of the source the frame points to
	 */
	int lineNumber;
	
	/**
	 * Current-executing function
	 */
	NSString* function;
	
	/**
	 * Variable list
	 */
	NSArray* variables;
}

@property(readwrite) int index;
@property(readonly, copy) NSString* filename;
@property(readonly, copy) NSString* source;
@property(readwrite) int lineNumber;
@property(readwrite, copy) NSString* function;
@property(readonly, copy) NSArray* variables;

- (id)initWithIndex:(int)anIndex
	   withFilename:(NSString*)aFilename
		 withSource:(NSString*)aSource
			 atLine:(int)aLineNumber
		 inFunction:(NSString*)function
	  withVariables:(NSArray*)variables;

- (BOOL)isShiftedFrame:(StackFrame*)frame;

@end

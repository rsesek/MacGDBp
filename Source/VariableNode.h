/*
 * MacGDBp
 * Copyright (c) 2010, Blue Static <http://www.bluestatic.org>
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

// A VariableNode represents a property in the variable list display. It
// converts XML response nodes to this format and extracts all the necessary
// information. The fields of this class are defined by the spec:
//  http://www.xdebug.org/docs-dbgp.php#properties-variables-and-values
@interface VariableNode : NSObject
{
  NSString* name_;
  NSString* fullName_;
  NSString* className_;
  NSString* type_;
  NSString* value_;
  NSMutableArray* children_;
  NSInteger childCount_;
  NSString* address_;
}

@property (readonly, copy) NSString* name;
@property (readonly, copy) NSString* fullName;
@property (readonly, copy) NSString* className;
@property (readonly, copy) NSString* type;
@property (readonly, copy) NSString* value;
@property (readonly, retain) NSArray* children;
@property (readonly) NSInteger childCount;
@property (readonly, copy) NSString* address;

// Creates and initializes a new VariableNode from the XML response from the
// debugger backend.
- (id)initWithXMLNode:(NSXMLElement*)node;

// When properties are asynchrnously loaded, this method can be used to set
// the children on a node from the list of children from the XML response.
- (void)setChildrenFromXMLChildren:(NSArray*)children;

// Returns the children and requests any unloaded ones.
- (NSArray*)dynamicChildren;

// Whether or not this is a leaf node (i.e. does not have child properties).
- (BOOL)isLeaf;

// Returns a formatted type and classname display.
- (NSString*)displayType;

@end

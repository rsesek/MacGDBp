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

#import "VariableNode.h"

#import "AppDelegate.h"
#include "base64.h"

// Private Properties //////////////////////////////////////////////////////////

@interface VariableNode ()

@property (copy) NSString* name;
@property (copy) NSString* fullName;
@property (copy) NSString* className;
@property (copy) NSString* type;
@property (copy) NSString* value;
@property (retain) NSMutableArray* children;

// Takes an XML node and computes the value.
- (NSString*)decodeValueForNode:(NSXMLElement*)node;

@end

////////////////////////////////////////////////////////////////////////////////

@implementation VariableNode

@synthesize name = name_;
@synthesize fullName = fullName_;
@synthesize className = className_;
@synthesize type = type_;
@synthesize value = value_;
@synthesize children = children_;
@synthesize childCount = childCount_;

- (id)initWithXMLNode:(NSXMLElement*)node
{
  if (self = [super init]) {
    self.name       = [[node attributeForName:@"name"] stringValue];
    self.fullName   = [[node attributeForName:@"fullName"] stringValue];
    self.className  = [[node attributeForName:@"className"] stringValue];
    self.type       = [[node attributeForName:@"type"] stringValue];
    self.value      = [self decodeValueForNode:node];
    self.children   = [NSMutableArray array];
    if ([node children]) {
      [self setChildrenFromXMLChildren:[node children]];
    }
    childCount_     = [[[node attributeForName:@"numchildren"] stringValue] integerValue];
  }
  return self;
}

- (void)dealloc
{
  self.name = nil;
  self.fullName = nil;
  self.className = nil;
  self.type = nil;
  self.value = nil;
  self.children = nil;
  [super dealloc];
}

- (void)setChildrenFromXMLChildren:(NSArray*)children
{
  for (NSXMLElement* child in children) {
    VariableNode* node = [[VariableNode alloc] initWithXMLNode:child];
    [children_ addObject:[node autorelease]];
  }
}

- (NSArray*)dynamicChildren
{
  NSArray* children = self.children;
  if (![self isLeaf] && [children count] < 1) {
    // If this node has children but they haven't been loaded from the backend,
    // request them asynchronously.
    [[AppDelegate instance].debugger fetchProperty:self.fullName forNode:self];
  }
  return children;
}

- (BOOL)isLeaf
{
  return (self.childCount == 0);
}

- (NSString*)displayType
{
  if (self.className != nil) {
    return [NSString stringWithFormat:@"%@ (%@)", self.className, self.type];
  }
  return self.type;
}

// Private /////////////////////////////////////////////////////////////////////

- (NSString*)decodeValueForNode:(NSXMLElement*)node
{
  // Non-leaf nodes do not have a value:
  //   https://www.bluestatic.org/bugs/showreport.php?bugid=168
  if (![self isLeaf]) {
    return @"...";
  }

  // The value of the node is base64 encoded.
  if ([[[node attributeForName:@"encoding"] stringValue] isEqualToString:@"base64"]) {
    const char* str = [[node stringValue] UTF8String];
    int strlen = [[node stringValue] length];

    char* data;
    size_t datalen;

    if (!base64_decode_alloc(str, strlen, &data, &datalen))
      NSLog(@"error in converting %@ from base64", self);

    NSString* ret = nil;
    if (data) {
      ret = [NSString stringWithUTF8String:data];
      free(data);
    }

    return ret;
  }

  // The value is just a normal string.
  return [node stringValue];  
}

@end

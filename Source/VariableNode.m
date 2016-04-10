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

#import "VariableNode.h"

#include "NSXMLElementAdditions.h"

@implementation VariableNode {
  NSMutableArray* _children;
}

- (id)initWithXMLNode:(NSXMLElement*)node {
  if (self = [super init]) {
    _name       = [[[node attributeForName:@"name"] stringValue] copy];
    _fullName   = [[[node attributeForName:@"fullname"] stringValue] copy];
    _className  = [[[node attributeForName:@"classname"] stringValue] copy];
    _type       = [[[node attributeForName:@"type"] stringValue] copy];
    _value      = [[node base64DecodedValue] copy];
    _children   = [[NSMutableArray alloc] init];
    if ([node children]) {
      [self setChildrenFromXMLChildren:[node children]];
    }
    _childCount = [[[node attributeForName:@"numchildren"] stringValue] integerValue];
    _address    = [[[node attributeForName:@"address"] stringValue] copy];
  }
  return self;
}

- (void)dealloc {
  [_name release];
  [_fullName release];
  [_className release];
  [_type release];
  [_value release];
  [_children release];
  [_address release];
  [super dealloc];
}

- (void)setChildrenFromXMLChildren:(NSArray*)children {
  [self willChangeValueForKey:@"children"];

  [_children removeAllObjects];

  for (NSXMLNode* child in children) {
    // Other child nodes may be the string value.
    if ([child isKindOfClass:[NSXMLElement class]]) {
      VariableNode* node = [[VariableNode alloc] initWithXMLNode:(NSXMLElement*)child];
      // Don't include the CLASSNAME property as that information is retrieved
      // elsewhere.
      if (![node.name isEqualToString:@"CLASSNAME"])
        [_children addObject:node];
      [node release];
    }
  }

  [self didChangeValueForKey:@"children"];
}

- (BOOL)isLeaf {
  return self.childCount == 0;
}

- (NSString*)displayType {
  if (self.className != nil) {
    return [NSString stringWithFormat:@"%@ (%@)", self.className, self.type];
  }
  return self.type;
}

- (NSString*)description {
  return [NSString stringWithFormat:@"<VariableNode %p : %@>", self, self.fullName];
}

@end

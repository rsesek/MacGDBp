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

#import "AppDelegate.h"
#include "modp_b64.h"

@implementation NSXMLElement (GDBpAdditions)

/**
 * Returns whether or not this node has any children
 */
- (BOOL)isLeaf
{
  return ([[[self attributeForName:@"children"] stringValue] intValue] == 0);
}

/**
 * Returns the value of the property
 */
- (NSString*)base64DecodedValue
{
  // Non-leaf nodes do not have a value:
  //   https://www.bluestatic.org/bugs/showreport.php?bugid=168
  if (![self isLeaf]) {
    return @"...";
  }
  
  // The value of the node is base64 encoded.
  if ([[[self attributeForName:@"encoding"] stringValue] isEqualToString:@"base64"]) {
    const char* src = [[self stringValue] UTF8String];
    int srclen = [[self stringValue] length];

    int destlen = modp_b64_decode_len(srclen);
    char* dest = malloc(destlen);
    memset(dest, 0, destlen);

    modp_b64_decode(dest, src, srclen);

    NSString* ret = nil;
    if (dest) {
      ret = [NSString stringWithUTF8String:dest];
      free(dest);
    }
    
    return ret;
  }
  
  // The value is just a normal string.
  return [self stringValue];  
}

@end

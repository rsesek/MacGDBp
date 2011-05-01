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

@interface NSXMLElement (GDBpAdditions_Private)
- (NSString*)internalName;
- (NSString*)internalBase64DecodedValue;
- (void)recursiveBase64DecodedValue:(NSMutableString*)stringBuilder
                              depth:(NSUInteger)depth;
@end

@implementation NSXMLElement (GDBpAdditions)

/**
 * Returns whether or not this node has any children
 */
- (BOOL)isLeaf
{
  return ([[[self attributeForName:@"children"] stringValue] intValue] == 0);
}

/**
 * Returns the "name" attribute.
 */
- (NSString*)internalName
{
  return [[self attributeForName:@"name"] stringValue];
}

/**
 * Does the actual work of decoding base64.
 */
- (NSString*)internalBase64DecodedValue
{
  // The value of the node is base64 encoded.
  if ([[[self attributeForName:@"encoding"] stringValue] isEqualToString:@"base64"]) {
    const char* src = [[self stringValue] UTF8String];
    NSUInteger srclen = [[self stringValue] length];

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

/**
 * Returns the value of the property
 */
- (NSString*)base64DecodedValue
{
  if (![self isLeaf]) {
    // For non-leaf nodes, display the object structure by recursively printing
    // the base64-decoded values.
    NSMutableString* mutableString = [[NSMutableString alloc] initWithString:@"(\n"];
    [self recursiveBase64DecodedValue:mutableString depth:1];
    [mutableString appendString:@")"];
    return [mutableString autorelease];
  }

  return [self internalBase64DecodedValue];  
}

/**
 * Recursively builds a print_r()-style output by attaching the data to
 * |stringBuilder| with indent level specified by |depth|.
 */
- (void)recursiveBase64DecodedValue:(NSMutableString*)stringBuilder
                              depth:(NSUInteger)depth
{
  // Create the indention string for this level.
  NSString* indent = [@"" stringByPaddingToLength:depth withString:@"\t" startingAtIndex:0];

  if ([self isLeaf]) {
    // If this is a leaf node, simply append the key=>value pair.
    [stringBuilder appendFormat:@"%@%@\t=>\t%@\n", indent, [self internalName], [self internalBase64DecodedValue]];
  } else {
    // If this node has children, increase the depth and recurse.
    [stringBuilder appendFormat:@"%@%@\t=>\t(\n", indent, [self internalName]];
    for (NSXMLElement* elm in [self children]) {
      [elm recursiveBase64DecodedValue:stringBuilder depth:depth + 1];
    }
    [stringBuilder appendFormat:@"%@)\n", indent];
  }
}

@end

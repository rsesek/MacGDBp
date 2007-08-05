/*
 * MacGDBp
 * Copyright (c) 2002 - 2007, Blue Static <http://www.bluestatic.org>
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

@implementation NSXMLElement (NSXMLElementAdditions)

/**
 * Return's the property's name from the attributes list
 */
- (NSString *)variable
{
	NSLog(@"name = %@", [self attributes]);
	return [[self attributeForName: @"name"] stringValue];
}

/**
 * Returns whether or not this node has any children
 */
- (BOOL)isLeaf
{
	NSLog(@"isleaf");
	return ([[[self attributeForName: @"children"] stringValue] intValue] == 0);
}

/**
 * Returns the value of the property
 */
- (NSString *)value
{
	return [self stringValue];
}

/**
 * Returns the type of variable this is
 */
- (NSString *)type
{
	return [[self attributeForName: @"type"] stringValue];
}

@end

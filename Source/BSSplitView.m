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

#import "BSSplitView.h"


@implementation BSSplitView

/**
 * Override the drawing method for the divider so we can make it prettier
 *
 * @todo draw the dimple
 */
- (void)drawDividerInRect:(NSRect)rect
{
  // Draw the gradient.
  NSColor* startColor = [NSColor colorWithDeviceRed:0.875 green:0.875 blue:0.875 alpha:1.0];
  NSColor* endColor = [NSColor colorWithDeviceRed:0.812 green:0.812 blue:0.812 alpha:1.0];
  NSGradient* gradient = [[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor];
  [gradient drawInRect:rect angle:([self isVertical] ? 0.0 : 90.0)];
  [gradient release];
  
  // Stroke the divider.
  [[NSColor colorWithDeviceRed:0.667 green:0.667 blue:0.667 alpha:1.0] setStroke];
  [NSBezierPath setDefaultLineWidth:0.5];
  [NSBezierPath strokeRect:rect];
  
  // Draw the dimple image.
  NSImage* dimple = [NSImage imageNamed:@"dimple.png"];
  NSSize dmpSize = [dimple size];
  NSPoint origin = NSMakePoint(NSMidX(rect) - (dmpSize.width / 2),
                               NSMidY(rect) - (dmpSize.height / 2));
  [dimple drawAtPoint:origin
             fromRect:NSZeroRect
            operation:NSCompositeSourceOver
             fraction:1.0];
}

/**
 * Returns the size of the divider to draw
 */
- (CGFloat)dividerThickness;
{
  return 6.0;
}

@end

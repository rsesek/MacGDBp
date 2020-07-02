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

#import "BSSourceViewTextView.h"

#import "BSSourceView.h"

@implementation BSSourceViewTextView

- (void)drawRect:(NSRect)rect
{
  [super drawRect:rect];

  NSLayoutManager* layoutManager = [self layoutManager];
  NSUInteger i = 0, line = 1;
  while (i < [layoutManager numberOfGlyphs]) {
    NSRange fragRange;
    NSRect fragRect = [layoutManager lineFragmentRectForGlyphAtIndex:i
                                                      effectiveRange:&fragRange];
    if ([_sourceView markedLine] == line) {
      fragRect = [self convertRect:fragRect fromView:self];
      fragRect.origin.x = rect.origin.x;  // Flush all the way to the edge.
      [[[NSColor redColor] colorWithAlphaComponent:0.25] set];
      [NSBezierPath fillRect:fragRect];
      break;
    }

    i += fragRange.length;
    ++line;
  }
}

@end

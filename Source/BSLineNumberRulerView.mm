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

#import "BSLineNumberRulerView.h"

@interface BSLineNumberRulerView (Private)
- (void)computeLineIndex;
@end


@implementation BSLineNumberRulerView

- (id)initWithScrollView:(NSScrollView*)scrollView
{
  if (self = [super initWithScrollView:scrollView orientation:NSVerticalRuler]) {
    [self setClientView:[scrollView documentView]];
  }
  return self;
}

- (void)awakeFromNib
{
  [self setClientView:[[self scrollView] documentView]];
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)rect
{
  // Draw the background color.
  [[NSColor colorWithDeviceRed:0.871 green:0.871 blue:0.871 alpha:1] set];
  [NSBezierPath fillRect:rect];

  // Draw the right stroke.
  [[NSColor grayColor] setStroke];
  [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect))
                            toPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect))];
}

- (void)performLayout
{
  [self computeLineIndex];
}

// Private /////////////////////////////////////////////////////////////////////

/**
 * Iterates over the text storage system and computes a map of line numbers to
 * first character index for a line's frame rectangle.
 */
- (void)computeLineIndex
{
  lineIndex_.clear();

  NSView* view = [self clientView];
  if (![view isKindOfClass:[NSTextView class]])
    return;

  NSString* text = [(NSTextView*)view string];
  NSUInteger stringLength = [text length];
  NSUInteger index = 0;

  while (index < stringLength) {
    lineIndex_.push_back(index);
    index = NSMaxRange([text lineRangeForRange:NSMakeRange(index, 0)]);
  }

  NSUInteger lineEnd, contentEnd;
  [text getLineStart:NULL
                 end:&lineEnd
         contentsEnd:&contentEnd
            forRange:NSMakeRange(lineIndex_.back(), 0)];
  if (contentEnd < lineEnd)
    lineIndex_.push_back(index);

  NSLog(@"line count = %d", lineIndex_.size());
}

@end

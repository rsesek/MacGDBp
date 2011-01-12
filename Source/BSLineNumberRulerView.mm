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

#include <algorithm>

@interface BSLineNumberRulerView (Private)
- (void)computeLineIndex;
- (NSAttributedString*)attributedStringForLineNumber:(NSUInteger)line;
- (NSDictionary*)fontAttributes;
@end

// Constants {{

// The default width of the ruler.
const CGFloat kDefaultWidth = 30.0;

// }}


@implementation BSLineNumberRulerView

- (id)initWithScrollView:(NSScrollView*)scrollView
{
  if (self = [super initWithScrollView:scrollView orientation:NSVerticalRuler]) {
    [self setClientView:[scrollView documentView]];
    [self setRuleThickness:kDefaultWidth];
  }
  return self;
}

- (void)awakeFromNib
{
  [self setClientView:[[self scrollView] documentView]];
  [self setRuleThickness:kDefaultWidth];
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

  // Get some common elements of the source view.
  NSView* view = [self clientView];
  if (![view isKindOfClass:[NSTextView class]])
    return;
  NSTextView* textView = (NSTextView*)view;
  NSLayoutManager* layoutManager = [textView layoutManager];
  NSTextContainer* textContainer = [textView textContainer];
  NSRect visibleRect = [[[self scrollView] contentView] bounds];

  // Get the visible glyph range, as NSRulerView only draws in the visible rect.
  NSRange visibleGlyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect
                                                       inTextContainer:textContainer];
  NSRange characterRange = [layoutManager characterRangeForGlyphRange:visibleGlyphRange
                                                     actualGlyphRange:NULL];

  // Go through the lines.
  const NSRange kNullRange = NSMakeRange(NSNotFound, 0);
  const CGFloat yOffset = [textView textContainerInset].height;

  size_t lineCount = lineIndex_.size();
  std::vector<NSUInteger>::iterator element =
      std::lower_bound(lineIndex_.begin(),
                       lineIndex_.end(),
                       characterRange.location);
  for (NSUInteger line = std::distance(lineIndex_.begin(), element);
       line < lineCount; ++line) {
    NSUInteger firstCharacterIndex = lineIndex_[line];
    NSLog(@"line = %d @ %d / %d", line, firstCharacterIndex, lineCount);
    // Stop after iterating past the end of the visible range.
    if (firstCharacterIndex > NSMaxRange(characterRange))
      break;

    NSUInteger rectCount;
    NSRectArray frameRects = [layoutManager rectArrayForCharacterRange:NSMakeRange(firstCharacterIndex, 0)
                                          withinSelectedCharacterRange:kNullRange
                                                       inTextContainer:textContainer
                                                             rectCount:&rectCount];
    if (frameRects) {
      NSUInteger lineNumber = line + 1;
      NSAttributedString* lineNumberString =
          [self attributedStringForLineNumber:lineNumber];
      NSSize stringSize = [lineNumberString size];

      CGFloat yCoord = yOffset + NSMinY(frameRects[0]) - NSMinY(visibleRect);
      [lineNumberString drawInRect:NSMakeRect(NSWidth(rect) - stringSize.width,
                                              yCoord,
                                              NSWidth(rect),
                                              NSHeight(frameRects[0]))];
    }
  }
}

- (void)performLayout
{
  [self computeLineIndex];

  // Determine the width of the ruler based on the line count.
  NSUInteger lastElement = lineIndex_.back() + 1;
  NSAttributedString* lastElementString = [self attributedStringForLineNumber:lastElement];
  NSSize boundingSize = [lastElementString size];
  [self setRuleThickness:std::max(kDefaultWidth, boundingSize.width)];
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

/**
 * Takes in a line number and returns a formatted attributed string, usable
 * for drawing.
 */
- (NSAttributedString*)attributedStringForLineNumber:(NSUInteger)line
{
  NSString* format = [NSString stringWithFormat:@"%d", line];
  return [[[NSAttributedString alloc] initWithString:format
                                          attributes:[self fontAttributes]] autorelease];
}

/**
 * Returns the dictionary for an NSAttributedString with which the line numbers
 * will be drawn.
 */
- (NSDictionary*)fontAttributes
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
      [NSFont fontWithName:@"Monaco" size:9.0], NSFontAttributeName,
      [NSColor grayColor], NSForegroundColorAttributeName,
      nil
  ];
}

@end

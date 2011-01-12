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

#import "BSLineNumberView.h"

@class BSLineNumberRulerView;
@protocol BSSourceViewDelegate;

@interface BSSourceView : NSView
{
 @private
  NSTextView* textView_;
  BSLineNumberRulerView* ruler_;
  NSScrollView* scrollView_;

  NSSet* markers_;

  NSString* file;
  int markedLine;

  id<BSSourceViewDelegate> delegate;
}

@property (assign) NSTextView* textView;
@property (assign) NSScrollView* scrollView;
@property (retain) NSSet* markers;
@property (nonatomic, assign) NSString* file;
@property (assign) int markedLine;
@property (assign) id delegate;

- (void)setFile:(NSString*)f;
- (void)setString:(NSString*)source asFile:(NSString*)path;
- (void)scrollToLine:(int)line;

@end

// Delegate ////////////////////////////////////////////////////////////////////

@protocol BSSourceViewDelegate <NSObject>
@optional

// Notifies the delegate that the gutter was clicked at a certain line.
- (void)gutterClickedAtLine:(int)line forFile:(NSString*)file;

// Whether to accept a file drop.
- (BOOL)sourceView:(BSSourceView*)sv acceptsDropOfFile:(NSString*)fileName;
@end

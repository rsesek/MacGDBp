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

@class BSLineNumberRulerView;
@protocol BSSourceViewDelegate;
@class BSSourceViewTextView;

// A BSSourceView is a view that contains an NSTextView that also has a line
// number ruler. This class wraps synchronization management between the text
// field and the line numbmering and marker drawing.
//
// Rather than setting the string of the text view directly, use the provided
// methods to load from a file path or to load a string as a virtual file.
@interface BSSourceView : NSView {
 @private
  BSSourceViewTextView* textView_;
  BSLineNumberRulerView* ruler_;
  NSScrollView* scrollView_;

  // Line numbers to mark.
  NSSet<NSNumber*>* markers_;

  NSString* file_;
  NSUInteger markedLine_;

  id<BSSourceViewDelegate> delegate_;
}

@property (nonatomic, readonly) NSTextView* textView;
@property (nonatomic, readonly) NSScrollView* scrollView;
@property (nonatomic, retain) NSSet<NSNumber*>* markers;
@property (nonatomic, retain) NSString* file;
@property (nonatomic, assign) NSUInteger markedLine;
@property (nonatomic, assign) id delegate;

- (void)setFile:(NSString*)f;
- (void)setString:(NSString*)source asFile:(NSString*)path;
- (void)scrollToLine:(NSUInteger)line;

@end

// Delegate ////////////////////////////////////////////////////////////////////

@protocol BSSourceViewDelegate <NSObject>
@optional

// Notifies the delegate that the gutter was clicked at a certain line.
- (void)gutterClickedAtLine:(NSUInteger)line forFile:(NSString*)file;

// Whether to accept a file drop.
- (BOOL)sourceView:(BSSourceView*)sv acceptsDropOfFile:(NSString*)fileName;
@end

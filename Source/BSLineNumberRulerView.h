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

@class BSSourceView;

// The NSRulerView that draws line numbers on the BSSourceView. The design of
// this class draws heavily on the work of Noodlesoft:
//   http://www.noodlesoft.com/blog/2008/10/05/displaying-line-numbers-with-nstextview/
// However, all code is original.
@interface BSLineNumberRulerView : NSRulerView

// Designated initializer.
- (instancetype)initWithSourceView:(BSSourceView*)sourceView;

// Performs layout and redraws the line number view.
- (void)performLayout;

// Returns the line number (1-based) at the given point. |point| should be in
// the receiver's coordinate system.
- (unsigned long)lineNumberAtPoint:(NSPoint)point;

@end

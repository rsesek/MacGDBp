/*
 * MacGDBp
 * Copyright (c) 2016, Blue Static <https://www.bluestatic.org>
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

@class NSString;

// NSNumber integer for the port to listen on.
extern NSString* const kPrefPort;

// NSNumber bool for whether the inspector window is visible.
extern NSString* const kPrefInspectorWindowVisible;

// NSMutableArray of path replacements.
extern NSString* const kPrefPathReplacements;

// NSNumber bool for whether to stop the debugger on the first line of the
// program.
extern NSString* const kPrefBreakOnFirstLine;

// NSNumber bool for whether the debugger is currently listening/attached.
extern NSString* const kPrefDebuggerAttached;

// NSNumber bool for whether the app ever reported as an unstable version in
// update checks. This will let the user download future unstable versions.
extern NSString* const kPrefUnstableVersionCast;

// NSMutableArray of breakpoints.
extern NSString* const kPrefBreakpoints;

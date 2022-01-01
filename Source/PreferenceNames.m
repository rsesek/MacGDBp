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

#import <Foundation/Foundation.h>

NSString* const kPrefPort = @"Port";

NSString* const kPrefInspectorWindowVisible = @"InspectorWindowVisible";

NSString* const kPrefPathReplacements = @"PathReplacements";

NSString* const kPrefPhpPath = @"PhpPath";

#if USE_APP_SANDBOX
NSString* const kPrefFileAccessBookmarks = @"FileAccessBookmarks";

NSString* const kPrefFileAccessStartupShowDate = @"FileAccessStartupShowDate";
#endif  // USE_APP_SANDBOX

NSString* const kPrefBreakOnFirstLine = @"BreakOnFirstLine";

NSString* const kPrefDebuggerAttached = @"DebuggerAttached";

NSString* const kPrefUnstableVersionCast = @"UnstableVersionCast";

NSString* const kPrefBreakpoints = @"Breakpoints";

NSString* const kPrefSelectedDebuggerSegment = @"DebuggerSegment";

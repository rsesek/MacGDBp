/*
 * MacGDBp
 * Copyright (c) 2010, Blue Static <http://www.bluestatic.org>
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

@class LogEntry;

// The LoggingController manages the communication log with the debugger engine.
// Whenever a command or a response received, the DebuggerConnection notifies
// this class to record the relevant information.
@interface LoggingController : NSWindowController
{
  // An array of log entries, with object at index 0 being the oldest entry.
  NSMutableArray* logEntries_;

  // The array controller.
  IBOutlet NSArrayController* logEntriesController_;
}
@property (readonly) NSArray* logEntries;

// Designated initializer.
- (id)init;

// Creates a new log entry with the specified command, adds it to the entries
// list, and returns the new entry as a weak pointer. Callers can then set
// additional properties.
- (LogEntry*)recordSend:(NSString*)command;

// Creates a new log entry with the specified response data, adds it to the list
// of entries, and returns the new entry as a weak pointer. Callers can then set
// additional properties.
- (LogEntry*)recordReceive:(NSString*)response;

@end

// Log Entry ///////////////////////////////////////////////////////////////////

typedef enum _LogEntryDirection {
  kLogEntrySending = 0,
  kLogEntryReceiving
} LogEntryDirection;

// A simple class that stores information for a single log entry.
@interface LogEntry : NSObject
{
  // The direction this communication went.
  LogEntryDirection direction_;
  
  // The command that was sent or the response.
  NSString* contents_;

  // Any error information.
  NSError* error_;

  // The values of the last read and written transaction IDs.
  NSUInteger lastWrittenTransactionID_;
  NSUInteger lastReadTransactionID_;
}
@property (assign) LogEntryDirection direction;
@property (copy) NSString* contents;
@property (retain) NSError* error;
@property (assign) NSUInteger lastWrittenTransactionID;
@property (assign) NSUInteger lastReadTransactionID;
- (NSString*)directionName;
@end

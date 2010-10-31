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

#import "LoggingController.h"


@implementation LoggingController

@synthesize logEntries = logEntries_;

- (id)init
{
  if (self = [self initWithWindowNibName:@"Log"])
  {
    logEntries_ = [NSMutableArray new];
  }
  return self;
}

- (void)dealloc
{
  [logEntries_ release];
  [super dealloc];
}

- (LogEntry*)recordSend:(NSString*)command
{
  LogEntry* entry = [LogEntry new];
  entry.direction = kLogEntrySending;
  entry.contents = command;
  [logEntries_ addObject:entry];
  [logEntriesController_ rearrangeObjects];
  return [entry autorelease];
}

- (LogEntry*)recordReceive:(NSString*)response
{
  LogEntry* entry = [LogEntry new];
  entry.direction = kLogEntryReceiving;
  entry.contents = response;
  [logEntries_ addObject:entry];
  [logEntriesController_ rearrangeObjects];
  return [entry autorelease];
}

@end

////////////////////////////////////////////////////////////////////////////////

@implementation LogEntry

@synthesize direction = direction_;
@synthesize contents = contents_;
@synthesize error = error_;
@synthesize lastWrittenTransactionID = lastWrittenTransactionID_;
@synthesize lastReadTransactionID = lastReadTransactionID_;

- (void)dealloc
{
  self.contents = nil;
  self.error = nil;
  self.lastWrittenTransactionID = 0;
  self.lastReadTransactionID = 0;
}

- (NSString*)directionName
{
  return (direction_ == kLogEntryReceiving ? @"Recv" : @"Send");
}

@end


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

#import "BSSourceView.h"

@interface BSSourceView (Private)
- (void)setupViews;
- (void)errorHighlightingFile:(NSNotification*)notif;
- (void)setPlainTextStringFromFile:(NSString*)filePath;
@end

@implementation BSSourceView

@synthesize numberView, textView, scrollView, markedLine, delegate, file;

/**
 * Initializes the source view with the path of a file
 */
- (id)initWithFrame:(NSRect)frame
{
  if (self = [super initWithFrame:frame])
  {
    [self setupViews];
    [[NSNotificationCenter defaultCenter]
      addObserver:self
      selector:@selector(errorHighlightingFile:)
      name:NSFileHandleReadToEndOfFileCompletionNotification
      object:nil
    ];
  }
  return self;
}

/**
 * Dealloc
 */
- (void)dealloc
{
  [file release];
  
  [numberView removeFromSuperview];
  [scrollView removeFromSuperview];
  [textView removeFromSuperview];
  
  [super dealloc];
}

/**
 * Sets the file name as well as the text of the source view
 */
- (void)setFile:(NSString*)f
{
  if (file != f)
  {
    [file release];
    file = [f retain];
  }
  
  if (![[NSFileManager defaultManager] fileExistsAtPath:f])
  {
    [textView setString:@""];
    return;
  }

  @try
  {
    // Attempt to use the PHP CLI to highlight the source file as HTML
    NSPipe* outPipe = [NSPipe pipe];
    NSPipe* errPipe = [NSPipe pipe];
    NSTask* task = [[NSTask new] autorelease];
    
    [task setLaunchPath:@"/usr/bin/php"]; // This is the path to the default Leopard PHP executable
    [task setArguments:[NSArray arrayWithObjects:@"-s", f, nil]];
    [task setStandardOutput:outPipe];
    [task setStandardError:errPipe];
    [task launch];
    
    [[errPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    
    NSData* data               = [[outPipe fileHandleForReading] readDataToEndOfFile];
    NSAttributedString* source = [[NSAttributedString alloc] initWithHTML:data documentAttributes:NULL];
    [[textView textStorage] setAttributedString:source];
    [source release];
  }
  @catch (NSException* exception)
  {
    // If the PHP executable is not available then the NSTask will throw an exception
    [self setPlainTextStringFromFile:f];
  }
}

/**
 * Sets the contents of the SourceView via a string rather than loading from a path
 */
- (void)setString:(NSString*)source asFile:(NSString*)path
{
  // create the temp file
  NSError* error = nil;
  NSString* tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"MacGDBpHighlighter"];
  [source writeToFile:tmpPath atomically:NO encoding:NSUTF8StringEncoding error:&error];
  if (error)
  {
    [textView setString:source];
    return;
  }
  
  // highlight the temporary file
  [self setFile:tmpPath];
  
  // delete the temp file
  [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:NULL];
  
  // plop in our fake path so nobody knows the difference
  if (path != file)
  {
    [file release];
    file = [path copy];
  }
}

/**
 * If an error occurs in reading the highlighted PHP source, this will merely set the string
 */
- (void)errorHighlightingFile:(NSNotification*)notif
{
  NSData* data = [[notif userInfo] objectForKey:NSFileHandleNotificationDataItem];
  if ([data length] > 0) // there's something on stderr, so the PHP CLI failed
    [self setPlainTextStringFromFile:file];
}

/**
 * Flip the coordinates
 */
- (BOOL)isFlipped
{
  return YES;
}

/**
 * Tells the text view to scroll to a certain line
 */
- (void)scrollToLine:(int)line
{
  if ([[textView textStorage] length] == 0)
    return;
  
  // go through the document until we find the NSRange for the line we want
  int rangeIndex = 0;
  for (int i = 0; i < line; i++)
  {
    rangeIndex = NSMaxRange([[textView string] lineRangeForRange:NSMakeRange(rangeIndex, 0)]);
  }
  
  // now get the true start/end markers for it
  unsigned lineStart, lineEnd;
  [[textView string] getLineStart:&lineStart end:NULL contentsEnd:&lineEnd forRange:NSMakeRange(rangeIndex - 1, 0)];
  [textView scrollRangeToVisible:[[textView string] lineRangeForRange:NSMakeRange(lineStart, lineEnd - lineStart)]];
}

/**
 * Setup all the subviews for the source metaview
 */
- (void)setupViews
{
  int gutterWidth = 30;
  
  // setup the line number view
  NSRect numberFrame = [self bounds];
  numberFrame.origin = NSMakePoint(0.0, 0.0);
  numberFrame.size.width = gutterWidth;
  numberView = [[BSLineNumberView alloc] initWithFrame:numberFrame];
  [numberView setAutoresizingMask:NSViewHeightSizable];
  [numberView setSourceView:self];
  [self addSubview:numberView];
  
  // create the scroll view
  NSRect scrollFrame = [self bounds];
  scrollFrame.origin.x = gutterWidth;
  scrollFrame.size.width = scrollFrame.size.width - gutterWidth;
  scrollView = [[NSScrollView alloc] initWithFrame:scrollFrame];
  [scrollView setHasHorizontalScroller:YES];
  [scrollView setHasVerticalScroller:YES];
  [scrollView setAutohidesScrollers:YES];
  [scrollView setBorderType:NSBezelBorder];
  [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [[scrollView contentView] setAutoresizesSubviews:YES];
  [self addSubview:scrollView];
  
  // add the text view to the scroll view
  NSRect textFrame;
  textFrame.origin = NSMakePoint(0.0, 0.0);
  textFrame.size = [scrollView contentSize];
  textView = [[BSSourceViewTextView alloc] initWithFrame:textFrame];
  [textView setSourceView:self];
  [textView setEditable:NO];
  [textView setFont:[NSFont fontWithName:@"Monaco" size:10.0]];
  [textView setHorizontallyResizable:YES];
  [textView setVerticallyResizable:YES];
  [textView setMinSize:textFrame.size];
  [textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
  [[textView textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
  [[textView textContainer] setWidthTracksTextView:NO];
  [[textView textContainer] setHeightTracksTextView:NO];
  [textView setAutoresizingMask:NSViewNotSizable];
  [scrollView setDocumentView:textView];

  NSArray* types = [NSArray arrayWithObject:NSFilenamesPboardType];
  [self registerForDraggedTypes:types];
}

/**
 * Gets the plain-text representation of the file at |filePath| and sets the
 * contents in the source view.
 */
- (void)setPlainTextStringFromFile:(NSString*)filePath
{
  NSError* error = nil;
  NSString* contents = [NSString stringWithContentsOfFile:filePath
                                                 encoding:NSUTF8StringEncoding
                                                    error:&error];
  if (error) {
    NSLog(@"Error reading file at %@: %@", filePath, error);
    return;
  }
  [textView setString:contents];
}

/**
 * Validates an initiated drag operation.
 */
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
  if ([delegate respondsToSelector:@selector(sourceView:acceptsDropOfFile:)])
    return NSDragOperationCopy;
  return NSDragOperationNone;
}

/**
 * Performs a dragging operation of files to set the contents of the file.
 */
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
  NSPasteboard* pboard = [sender draggingPasteboard];
  if ([[pboard types] containsObject:NSFilenamesPboardType]) {
    NSArray* files = [pboard propertyListForType:NSFilenamesPboardType];
    if ([files count]) {
      NSString* filename = [files objectAtIndex:0];
      if ([delegate respondsToSelector:@selector(sourceView:acceptsDropOfFile:)] &&
          [delegate sourceView:self acceptsDropOfFile:filename]) {
        [self setFile:filename];
        return YES;
      }
    }
  }
  return NO;
}

@end

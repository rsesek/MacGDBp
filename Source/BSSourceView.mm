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

#import "BSLineNumberRulerView.h"
#import "BSSourceViewTextView.h"

@interface BSSourceView (Private)
- (void)setupViews;
- (void)errorHighlightingFile:(NSNotification*)notif;
- (void)setPlainTextStringFromFile:(NSString*)filePath;
@end

@implementation BSSourceView

@synthesize textView = textView_;
@synthesize scrollView = scrollView_;
@synthesize markers = markers_;
@synthesize markedLine = markedLine_;
@synthesize delegate = delegate_;
@synthesize file = file_;

/**
 * Initializes the source view with the path of a file
 */
- (id)initWithFrame:(NSRect)frame
{
  if (self = [super initWithFrame:frame]) {
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
  [file_ release];
  [markers_ release];

  [scrollView_ removeFromSuperview];
  [textView_ removeFromSuperview];
  
  [super dealloc];
}

- (void)setMarkers:(NSSet*)markers {
  [markers_ release];
  markers_ = [markers copy];

  [ruler_ setNeedsDisplay:YES];
}

- (void)setMarkedLine:(NSUInteger)markedLine {
  markedLine_ = markedLine;
  [ruler_ setNeedsDisplay:YES];
}

/**
 * Sets the file name as well as the text of the source view
 */
- (void)setFile:(NSString*)f
{
  if (file_ != f) {
    [file_ release];
    file_ = [f retain];
  }
  
  if (![[NSFileManager defaultManager] fileExistsAtPath:f]) {
    [textView_ setString:@""];
    return;
  }

  @try {
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
    [[textView_ textStorage] setAttributedString:source];
    [source release];
  } @catch (NSException* exception) {
    // If the PHP executable is not available then the NSTask will throw an exception
    [self setPlainTextStringFromFile:f];
  }

  [ruler_ performLayout];
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
  if (error) {
    [textView_ setString:source];
    return;
  }
  
  // highlight the temporary file
  [self setFile:tmpPath];
  
  // delete the temp file
  [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:NULL];
  
  // plop in our fake path so nobody knows the difference
  if (path != file_) {
    [file_ release];
    file_ = [path copy];
  }

  [ruler_ performLayout];
}

/**
 * If an error occurs in reading the highlighted PHP source, this will merely set the string
 */
- (void)errorHighlightingFile:(NSNotification*)notif
{
  NSData* data = [[notif userInfo] objectForKey:NSFileHandleNotificationDataItem];
  if ([data length] > 0 && file_) // there's something on stderr, so the PHP CLI failed
    [self setPlainTextStringFromFile:file_];
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
- (void)scrollToLine:(NSUInteger)line
{
  if ([[textView_ textStorage] length] == 0)
    return;
  
  // go through the document until we find the NSRange for the line we want
  NSUInteger rangeIndex = 0;
  for (NSUInteger i = 0; i < line; i++) {
    rangeIndex = NSMaxRange([[textView_ string] lineRangeForRange:NSMakeRange(rangeIndex, 0)]);
  }
  
  // now get the true start/end markers for it
  NSUInteger lineStart, lineEnd;
  [[textView_ string] getLineStart:&lineStart
                               end:NULL
                       contentsEnd:&lineEnd
                          forRange:NSMakeRange(rangeIndex - 1, 0)];
  [textView_ scrollRangeToVisible:[[textView_ string]
                lineRangeForRange:NSMakeRange(lineStart, lineEnd - lineStart)]];
  [scrollView_ setNeedsDisplay:YES];
}

/**
 * Setup all the subviews for the source metaview
 */
- (void)setupViews
{
  // Create the scroll view.
  scrollView_ = [[[NSScrollView alloc] initWithFrame:[self bounds]] autorelease];
  [scrollView_ setHasHorizontalScroller:YES];
  [scrollView_ setHasVerticalScroller:YES];
  [scrollView_ setAutohidesScrollers:YES];
  [scrollView_ setBorderType:NSBezelBorder];
  [scrollView_ setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [[scrollView_ contentView] setAutoresizesSubviews:YES];
  [self addSubview:scrollView_];

  // add the text view to the scroll view
  NSRect textFrame;
  textFrame.origin = NSMakePoint(0.0, 0.0);
  textFrame.size = [scrollView_ contentSize];
  textView_ = [[[BSSourceViewTextView alloc] initWithFrame:textFrame] autorelease];
  [textView_ setSourceView:self];
  [textView_ setEditable:NO];
  [textView_ setFont:[NSFont fontWithName:@"Monaco" size:10.0]];
  [textView_ setHorizontallyResizable:YES];
  [textView_ setVerticallyResizable:YES];
  [textView_ setMinSize:textFrame.size];
  [textView_ setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
  [[textView_ textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
  [[textView_ textContainer] setWidthTracksTextView:NO];
  [[textView_ textContainer] setHeightTracksTextView:NO];
  [textView_ setAutoresizingMask:NSViewNotSizable];
  [scrollView_ setDocumentView:textView_];

  // Set up the ruler.
  ruler_ = [[[BSLineNumberRulerView alloc] initWithSourceView:self] autorelease];
  [scrollView_ setVerticalRulerView:ruler_];
  [scrollView_ setHasHorizontalRuler:NO];
  [scrollView_ setHasVerticalRuler:YES];
  [scrollView_ setRulersVisible:YES];

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
  [textView_ setString:contents];
}

// Drag Handlers ///////////////////////////////////////////////////////////////

/**
 * Validates an initiated drag operation.
 */
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
  return NSDragOperationCopy;
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
      [self setFile:filename];
      return YES;
    }
  }
  return NO;
}

@end

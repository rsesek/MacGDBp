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

- (void)setMarkers:(NSSet*)markers {
  markers_ = [markers copy];
  [ruler_ setNeedsDisplay:YES];
}

- (void)setMarkedLine:(NSUInteger)markedLine {
  markedLine_ = markedLine;
  [ruler_ setNeedsDisplay:YES];
}

/**
 * Reads the contents of file at |f| and sets the source viewer and filename
 * as such.
 */
- (void)setFile:(NSString*)f
{
  file_ = f;
  
  if (![[NSFileManager defaultManager] fileExistsAtPath:f]) {
    [textView_ setString:@""];
    return;
  }

  [self setSource:f completionHandler:nil];
}

/**
 * Sets the contents of the SourceView to |source| representing the file at |path|.
 */
- (void)setString:(NSString*)source asFile:(NSString*)path
{
  file_ = path;

  // Write the source out as a temporary file so it can be highlighted.
  NSError* error = nil;
  NSString* tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"MacGDBpHighlighter"];
  [source writeToFile:tmpPath atomically:NO encoding:NSUTF8StringEncoding error:&error];
  if (error) {
    [textView_ setString:source];
    return;
  }

  [self setSource:tmpPath completionHandler:^{
    [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:NULL];
  }];
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
 * Returns the preferred font for source views.
 */
+ (NSFont*)sourceFont
{
  static NSFont* font = nil;
  if (!font) {
    font = [NSFont fontWithName:@"Menlo" size:12];
    if (!font)
      font = [NSFont fontWithName:@"Monaco" size:12.0];
  }
  return font;
}

/**
 * Setup all the subviews for the source metaview
 */
- (void)setupViews
{
  // Create the scroll view.
  scrollView_ = [[NSScrollView alloc] initWithFrame:[self bounds]];
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
  textView_ = [[BSSourceViewTextView alloc] initWithFrame:textFrame];
  [textView_ setSourceView:self];
  [textView_ setEditable:NO];
  [textView_ setFont:[[self class] sourceFont]];
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
  ruler_ = [[BSLineNumberRulerView alloc] initWithSourceView:self];
  [scrollView_ setVerticalRulerView:ruler_];
  [scrollView_ setHasHorizontalRuler:NO];
  [scrollView_ setHasVerticalRuler:YES];
  [scrollView_ setRulersVisible:YES];

  NSArray* types = [NSArray arrayWithObject:NSFilenamesPboardType];
  [self registerForDraggedTypes:types];
}

NSString* ColorHEXStringINIDirective(NSString* directive, NSColor* color) {
  CGFloat red, green, blue, alpha;
  color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  [color getRed:&red green:&green blue:&blue alpha:&alpha];
  return [NSString stringWithFormat:@"%@=\"#%02x%02x%02x\"", directive, (UInt8)(red * 255), (UInt8)(green * 255), (UInt8)(blue * 255)];
}

/**
 * Reads the contents of |filePath| and sets it as the displayed text, after
 * attempting to highlight it using the PHP binary.
 */
- (void)setSource:(NSString*)filePath completionHandler:(void(^)(void))handler
{
  @try {
    // Attempt to use the PHP CLI to highlight the source file as HTML
    NSPipe* outPipe = [NSPipe pipe];
    NSPipe* errPipe = [NSPipe pipe];
    NSTask* task = [[NSTask alloc] init];

    [task setLaunchPath:@"/usr/bin/php"]; // This is the path to the default Leopard PHP executable
    [task setArguments:@[
      @"--syntax-highlight",
      @"--define", ColorHEXStringINIDirective(@"highlight.string", [NSColor systemRedColor]),
      @"--define", ColorHEXStringINIDirective(@"highlight.comment", [NSColor systemOrangeColor]),
      @"--define", ColorHEXStringINIDirective(@"highlight.default", [NSColor systemBlueColor]),
      @"--define", ColorHEXStringINIDirective(@"highlight.html", [NSColor systemGrayColor]),
      filePath
    ]];
    [task setStandardOutput:outPipe];
    [task setStandardError:errPipe];
    [task setTerminationHandler:^(NSTask* taskBlock) {
      if (task.terminationStatus != 0) {
        NSLog(@"Failed to highlight PHP file %@. Termination status=%d. stderr: %@",
              filePath, taskBlock.terminationStatus, [[errPipe fileHandleForReading] readDataToEndOfFile]);
      }
    }];
    [task launch];

    // Start reading the stdout pipe on a background queue. This is separate
    // from the terminiationHandler, since a large file could be greater than
    // the pipe buffer.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      NSMutableAttributedString* source;
      NSData* data = [[outPipe fileHandleForReading] readDataToEndOfFile];
      if (data.length) {
        source = [[NSMutableAttributedString alloc] initWithHTML:data
                                                         options:@{ NSCharacterEncodingDocumentAttribute : @(NSUTF8StringEncoding) }
                                              documentAttributes:nil];

        // PHP uses &nbsp; in the highlighted output, which should be converted
        // back to normal spaces.
        NSMutableString* stringData = [source mutableString];
        [stringData replaceOccurrencesOfString:@"\u00A0" withString:@" " options:0 range:NSMakeRange(0, stringData.length)];

        // Override the default font from Courier.
        [source addAttributes:@{ NSFontAttributeName : [[self class] sourceFont] }
                        range:NSMakeRange(0, source.length)];
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        if (source) {
          [[self->textView_ textStorage] setAttributedString:source];
        } else {
          [self setPlainTextStringFromFile:filePath];
        }

        [self->ruler_ performLayout];

        if (handler)
          handler();
      });
    });
  } @catch (NSException* exception) {
    // If the PHP executable is not available then the NSTask will throw an exception
    NSLog(@"Failed to highlight file: %@", exception);
    [self setPlainTextStringFromFile:filePath];
  }
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
    if ([delegate_ respondsToSelector:@selector(error:whileHighlightingFile:)]) {
      [delegate_ error:error whileHighlightingFile:filePath];
    }
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

/*
 * MacGDBp
 * Copyright (c) 2007 - 2008, Blue Static <http://www.bluestatic.org>
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
	}
	return self;
}

/**
 * Dealloc
 */
- (void)dealloc
{
	[file release];
	[super dealloc];
}

/**
 * Sets the file name as well as the text of the source view
 */
- (void)setFile:(NSString *)f
{
	if (file != f)
	{
		[file release];
		file = [f retain];
	}

	@try
	{
		// Attempt to use the PHP CLI to highlight the source file as HTML
		NSPipe* pipe = [NSPipe pipe];
		NSTask* task = [[NSTask new] autorelease];
		[task setLaunchPath:@"/usr/bin/php"]; // This is the path to the default Leopard PHP executable
		[task setArguments:[NSArray arrayWithObjects:@"-s", f, nil]];
		[task setStandardOutput:pipe];
		[task launch];
		NSData* data               = [[pipe fileHandleForReading] readDataToEndOfFile];
		NSAttributedString* source = [[NSAttributedString alloc] initWithHTML:data documentAttributes:NULL];
		[[textView textStorage] setAttributedString:source];
		[source release];
	}
	@catch (NSException* exception)
	{
		// If the PHP executable is not available then the NSTask will throw an exception
		[textView setString:[NSString stringWithContentsOfFile:f]];
	}
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
}

@end

//
//  AppDelegate.h
//  CFNetworkTest
//
//  Created by Robert Sesek on 2/15/10.
//  Copyright 2010 Blue Static. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
@public
    NSWindow* window_;
	NSTextField* commandField_;
	NSTextView* resultView_;
	
	CFSocketRef socket_;  // Strong.
	CFReadStreamRef readStream_;  // Strong.
	CFWriteStreamRef writeStream_;  // Strong.
	
	NSMutableString* currentPacket_;
	int lastPacketSize_;
	int packetIndex_;
}

@property (assign) IBOutlet NSWindow* window;
@property (assign) IBOutlet NSTextField* commandField;
@property (assign) IBOutlet NSTextView* resultView;
@property (retain) NSMutableString* currentPacket;

- (IBAction)send:(id)sender;

@end

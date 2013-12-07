//
//  LibraryManagerWindowController.h
//  MuShare
//
//  Created by Garrett Davidson on 11/27/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LibraryManagerWindowController : NSWindowController <NSOutlineViewDelegate, NSOutlineViewDataSource, NSTableViewDataSource, NSTableViewDelegate>

- (IBAction)reloadLibraries:(id)sender;
- (IBAction)startSync:(id)sender;
- (IBAction)sendFiles:(id)sender;
- (IBAction)receiveFiles:(id)sender;

@end

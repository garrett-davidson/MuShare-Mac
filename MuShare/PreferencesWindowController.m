//
//  PreferencesWindowController.m
//  MuShare
//
//  Created by Garrett Davidson on 11/30/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//

#import "PreferencesWindowController.h"
#import "LibraryManagerWindowController.h"

@interface PreferencesWindowController ()
{
    NSUserDefaults *defaults;
    LibraryManagerWindowController *libraryManager;
}


@end

@implementation PreferencesWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        defaults = [NSUserDefaults standardUserDefaults];
    }
    return self;
}
- (IBAction)selectAFolder:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:true];
    [panel setCanChooseFiles:false];
    [panel setCanCreateDirectories:true];
    [panel setPrompt:@"Choose"];
    [panel setDirectoryURL:[NSURL fileURLWithPath:self.pathTextField.stringValue]];
    if ([panel runModal] == NSOKButton)
    {
        NSURL *path = [panel.URLs objectAtIndex:0];
        [self.pathTextField setStringValue:path.path];
    }
    
}

- (void)windowWillClose:(NSNotification *)notification
{
    NSString *path = self.pathTextField.stringValue;
    if (![path.lastPathComponent isEqualToString:@"MuShare"]) path = [path stringByAppendingString:@"/MuShare"];
    [defaults setObject:path forKey:@"path"];
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL positive = true;
    if (![manager fileExistsAtPath:path isDirectory:&positive]) [manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    [libraryManager reloadLibraries:nil];
}

- (void)showWindow:(id)sender
{
    [super showWindow:sender];
    libraryManager = (LibraryManagerWindowController *)sender;
}

@end

//
//  LibraryManagerWindowController.m
//  MuShare
//
//  Created by Garrett Davidson on 11/27/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//








#import "LibraryManagerWindowController.h"
#import "PreferencesWindowController.h"
#import "Song.h"
#import "iTunes.h"

@interface LibraryManagerWindowController ()
@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSTableView *tableView;

@end

@implementation LibraryManagerWindowController
{
    PreferencesWindowController *prefsWindowController;
    int trackCount;
    NSArray *libraries;
    NSArray *libraryNames;
    NSString *libraryName;
    NSUserDefaults *defaults;
    NSString *currentLibraryID;
    NSString *myLibraryID;
    NSArray *songs;
    NSArray *localSongs;
    NSMutableSet *songsToSync;

    enum URLTypes
    {
        fileURL = 0,
        remoteURL
    };
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        //Clear defaults
        //[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];


        defaults = [NSUserDefaults standardUserDefaults];
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/Music/iTunes/iTunes Music Library.xml", NSHomeDirectory()]] options:NSXMLDocumentTidyXML error:nil];
        [self loadLibraryForXMLDocument:doc];
        localSongs = songs;

        //Get the name for the local library, set it if it doesn't exist
        NSString *libraryID = [[[doc.rootElement childAtIndex:0] childAtIndex:15] stringValue];
        if (![defaults stringForKey:libraryID]) [defaults setObject:@"My Library" forKey:libraryID];
        if (![defaults stringForKey:@"path"]) [defaults setObject:[NSString stringWithFormat:@"%@/Dropbox/MuShare", NSHomeDirectory()] forKey:@"path"];
        myLibraryID = [self idForLibrary:doc];

        [self reloadLibraries:self];
        NSFileManager *manager = [NSFileManager defaultManager];
        NSString *path = [[defaults objectForKey:@"path"] stringByAppendingFormat:@"/%@.xml", NSUserName()];
        [manager removeItemAtPath:path error:nil];
        NSError *err;
        [manager copyItemAtPath:[NSString stringWithFormat:@"%@/Music/iTunes/iTunes Music Library.xml", NSHomeDirectory()] toPath:path error:&err];
        if (err) NSLog(@"Error: %@", err.localizedDescription);

        songsToSync = [NSMutableSet set];

        //Set up timers

        //Receive files
        [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(receiveFiles:) userInfo:nil repeats:true];

        //Send files
        [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(sendFiles:) userInfo:nil repeats:true];

    }

    return self;
}

- (void)loadLibraryForXMLDocument:(NSXMLDocument *)doc
{
    NSXMLNode *root = [doc rootElement];
    NSArray *songNodes = [[[root childAtIndex:0] childAtIndex:17] children];
    songs = [NSArray array];
    for (int i = 0; i < songNodes.count; i+=2)
    {
        NSXMLElement *songElement = [songNodes objectAtIndex:i+1];
        Song *song = [[Song alloc] initWithID:[[[songNodes objectAtIndex:i] stringValue] intValue] AndURLType:[self URLTypeForSong:songElement]];

        //Done this way in case of blank attributes
        NSArray *att = [songElement nodesForXPath:@"key[text()='Name']" error:nil];
        if (att.count) song.name = [[[[att objectAtIndex:0] nextNode] nextNode] stringValue];

        att = [songElement nodesForXPath:@"key[text()='Artist']" error:nil];
        if (att.count) song.artist = [[[[att objectAtIndex:0] nextNode] nextNode] stringValue];

        att = [songElement nodesForXPath:@"key[text()='Album']" error:nil];
        if (att.count) song.album = [[[[att objectAtIndex:0] nextNode] nextNode] stringValue];

        att = [songElement nodesForXPath:@"key[text()='Location']" error:nil];
        if (att.count) song.fileURL = [NSURL URLWithString:[[[[att objectAtIndex:0] nextNode] nextNode] stringValue]];

        songs = [songs arrayByAddingObject:song];
    }
    //tracks = [[root childAtIndex:0] childAtIndex:17];
    //playlists = [[root childAtIndex:0] childAtIndex:19];
    //music = [[playlists childAtIndex:1] childAtIndex:13];
    //trackCount = (int)[[tracks nodesForXPath:@"key" error:nil] count];
    currentLibraryID = [self idForLibrary:doc];
}

- (NSString *)idForLibrary:(NSXMLDocument *)doc
{
    return [[[doc.rootElement childAtIndex:0] childAtIndex:15] stringValue];
}

- (IBAction)showPreferences:(id)sender {
    prefsWindowController = [[PreferencesWindowController alloc] initWithWindowNibName:@"PreferencesWindowController"];
    [prefsWindowController showWindow:self];

    [prefsWindowController.pathTextField setStringValue:[defaults objectForKey:@"path"]];
}

#pragma mark Song Atrributes

- (int)URLTypeForSong:(NSXMLNode *)song
{
    NSString *type = [[[[[song nodesForXPath:@"key[text()='Track Type']" error:nil] objectAtIndex:0] nextNode] nextNode] stringValue];
    return [type isEqualToString:@"URL"] ? remoteURL : fileURL;
}

#pragma mark Outline View
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    return [libraries objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return false;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    return item ? 0 : libraries.count;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(NSXMLDocument *)item
{
    return [libraryNames objectAtIndex:[libraries indexOfObject:item]];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    NSOutlineView *outlineView = notification.object;
    int row = (int)outlineView.selectedRow;
    currentLibraryID = [self idForLibrary:[self outlineView:outlineView child:row ofItem:nil]];
    [self loadLibraryForXMLDocument:[libraries objectAtIndex:row]];
    [self.tableView reloadData];
    [self startSync:nil];
}

#pragma Table View

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return songs.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *columnIdentifier = [tableColumn identifier];
    if ([columnIdentifier isEqualToString:@"sync"])
    {
        Song *song = [songs objectAtIndex:row];
        return [NSNumber numberWithInteger:[localSongs containsObject:song] | [songsToSync containsObject:song]];
    }

    else if ([columnIdentifier isEqualToString:@"name"])
    {

        return [[songs objectAtIndex:(int)row] name];
    }

    else if ([columnIdentifier isEqualToString:@"artist"])
    {
        return [[songs objectAtIndex:(int)row] artist];
    }

    else if ([columnIdentifier isEqualToString:@"album"])
    {
        return [[songs objectAtIndex:(int)row] album];
    }

    else
    {
        return @"error";
    }
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    if ([aTableColumn.identifier isEqualToString:@"sync"]) {
        if ([currentLibraryID isEqualToString:myLibraryID]) [aCell setEnabled:false];
        else if ([[songs objectAtIndex:(int)rowIndex] urlType]) [aCell setEnabled:false];
        else if ([localSongs containsObject:[songs objectAtIndex:(int)rowIndex]]) [aCell setEnabled:false];
        else [aCell setEnabled:true];
    }
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    songs = [songs sortedArrayUsingDescriptors:[tableView sortDescriptors]];
    [tableView reloadData];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    if ([object intValue])
    {
        [songsToSync addObject:[songs objectAtIndex:rowIndex]];
    }
    else
    {
        [songsToSync removeObject:[songs objectAtIndex:rowIndex]];
    }
}




- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)reloadLibraries:(id)sender
{
    libraries = [NSArray arrayWithObject:[[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/Music/iTunes/iTunes Music Library.xml", NSHomeDirectory()]] options:NSXMLDocumentTidyXML error:nil]];
    libraryNames = [NSArray arrayWithObject:@"My Library"];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *files = [manager contentsOfDirectoryAtPath:[defaults objectForKey:@"path"] error:nil];
    for (NSString *file in files)
    {
        if ([file rangeOfString:@".xml"].location != NSNotFound)
        {
            NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", [defaults objectForKey:@"path"], file]] options:NSXMLDocumentTidyXML error:nil];
            NSString *libraryID = [self idForLibrary:doc];
            if (![libraryID isEqualToString:myLibraryID])
            {
                libraries = [libraries arrayByAddingObject:doc];
                libraryNames = [libraryNames arrayByAddingObject:file.stringByDeletingPathExtension];
            }
            NSString *dirPath = [NSString stringWithFormat:@"%@/%@", [defaults objectForKey:@"path"], libraryID];
            if (![manager fileExistsAtPath:dirPath])
            {
                [manager createDirectoryAtPath:dirPath withIntermediateDirectories:false attributes:Nil error:nil];
            }
        }
    }
    [self.outlineView reloadData];
}



#pragma mark Syncing

- (IBAction)startSync:(id)sender {
    NSString *trackIDs = @"";

    for (Song *song in songsToSync)
    {
        trackIDs = [trackIDs stringByAppendingFormat:@"%d\n", song.trackID];
    }

    NSError *err;
    [trackIDs writeToFile:[NSString stringWithFormat:@"%@/%@/%@.txt", [defaults objectForKey:@"path"], currentLibraryID, myLibraryID] atomically:true encoding:NSASCIIStringEncoding error:&err];
    if (err) NSLog(@"Error: %@", err);
}

- (IBAction)sendFiles:(id)sender {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *requestPath = [NSString stringWithFormat:@"%@/%@", [defaults objectForKey:@"path"], myLibraryID];
    NSArray *requests = [manager contentsOfDirectoryAtPath:requestPath error:nil];

    for (NSString *file in requests)
    {
        if ([file rangeOfString:@".txt"].location != NSNotFound)
        {
            NSString *songString = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", requestPath, file] encoding:NSASCIIStringEncoding error:nil];
            NSArray *songsToSend = [songString componentsSeparatedByString:@"\n"];
            if ([songsToSend[0] rangeOfString:@"\r"].location != NSNotFound)
            {
                NSArray *newSongsToSend = [NSArray array];
                for (NSString *name in songsToSend)
                {
                    if (![name isEqualToString:@""])
                        newSongsToSend = [newSongsToSend arrayByAddingObject:[name substringToIndex:name.length - 1]];
                }

                songsToSend = newSongsToSend;
            }
            for (Song *song in localSongs)
            {

                if ([songsToSend containsObject:[NSString stringWithFormat:@"%d", song.trackID]])
                {
                    NSError *err;
                    [manager copyItemAtURL:song.fileURL toURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@/%@.%@", [defaults objectForKey:@"path"], [file substringToIndex:file.length-4], [NSString stringWithFormat:@"%d", song.trackID], song.fileURL.pathExtension]] error:&err];
                    if (err) NSLog(@"%@", err);
                }
            }
            NSString *path = [requestPath stringByAppendingFormat:@"/%@", file];
            NSError *err;
            [manager removeItemAtPath:path error:&err];
            if (err) NSLog(@"%@", err);
        }
    }


}

- (IBAction)receiveFiles:(id)sender {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *requestPath = [NSString stringWithFormat:@"%@/%@", [defaults objectForKey:@"path"], myLibraryID];
    NSArray *newSongs = [manager contentsOfDirectoryAtPath:requestPath error:nil];

    const NSArray *songExtenions = [NSArray arrayWithObjects:@"mp3", @"aiff", @"wav", @"mp4", @"aac", @"m4a", nil];
    for (NSString *songName in newSongs)
    {
        NSString *extension = [songName pathExtension];
        if ([songExtenions containsObject:extension])
        {
            NSString *path =[NSString stringWithFormat:@"%@/%@/%@", [defaults objectForKey:@"path"], myLibraryID, songName];
            [self addToItunes:[NSURL fileURLWithPath:path]];
            [manager removeItemAtPath:path error:nil];
        }
    }

}

- (BOOL)checkForFileRequests
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *requestPath = [NSString stringWithFormat:@"%@/%@", [defaults objectForKey:@"path"], myLibraryID];
    NSArray *requests = [manager contentsOfDirectoryAtPath:requestPath error:nil];
    for (NSString *file in requests)
    {
        if ([file rangeOfString:@".txt"].location != NSNotFound)
        {
            return true;
        }
    }

    return false;
}

- (BOOL)checkForReceivedFiles
{
    //TODO
    //watch for full files vs partials
    return true;
}


- (void)addToItunes:(NSURL *)songURL
{

    iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    SBElementArray *sources = [iTunes sources];
    iTunesSource *librarySource = [sources objectWithName:@"Library"];
    iTunesPlaylist *library = [[librarySource libraryPlaylists] objectWithName:@"Library"];
    [iTunes add:[NSArray arrayWithObject:songURL] to:library];

}


@end




/*
 - (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
 {
    if (!item)
 {
    return root;
 }
 else
 {
    NSXMLNode *node = [[[[tracks nodesForXPath:[NSString stringWithFormat:@"key[%ld]", (long)index+1] error:nil] objectAtIndex:0] nextNode] nextNode];
    return node;
 }
    //return (item == nil) ? root : [[[[tracks nodesForXPath:[NSString stringWithFormat:@"key[%ld]", (long)index] error:nil] objectAtIndex:0] nextNode] nextNode];
 }

 - (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
 {
    if ([self outlineView:outlineView numberOfChildrenOfItem:item]) return true;
    else return false;
 }

 - (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
 {
    if (!item) return 1;
    if (![[self nameForSong:item] isEqualToString:@"plist"]) return 0;
    return trackCount;
 }

 - (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(NSXMLNode *)item
 {
    if (!item) return @"/";
    else return [self nameForSong:item];
    //return (item == nil) ? @"/" : [self nameForSong:item];

 }*/

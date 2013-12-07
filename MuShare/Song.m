//
//  Song.m
//  MuShare
//
//  Created by Garrett Davidson on 12/1/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//

#import "Song.h"

@implementation Song

- (id)initWithID:(int)newTrackID AndURLType:(int)newURLType
{
    self = [super init];
    trackID = newTrackID;
    urlType = newURLType;

    return self;
}

- (int)trackID
{
    return trackID;
}

- (int)urlType
{
    return urlType;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Song %d: %@ by %@ on %@, stored at %@", trackID, self.name, self.artist, self.album, self.fileURL];
}

- (BOOL)isEqual:(Song *)song
{
    BOOL equal = [song.name isEqualToString:self.name];
    if (equal)
    {
        equal = [song.artist isEqualToString:self.artist];
        if (equal) equal = [song.album isEqualToString:self.album];
    }

    return equal;
}

@end

//
//  Song.h
//  MuShare
//
//  Created by Garrett Davidson on 12/1/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Song : NSObject
{
    int trackID;
    int urlType;
}

@property (nonatomic) NSString *name;
@property (nonatomic) NSString *artist;
@property (nonatomic) NSString *album;
@property (nonatomic) NSURL *fileURL;

- (id)initWithID:(int)newTrackID AndURLType:(int)newURLType;
- (int)trackID;
- (int)urlType;
- (BOOL)isEqual:(Song *)song;

@end

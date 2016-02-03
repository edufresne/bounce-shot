//
//  IEAudioPlayer.m
//  Trick Shot
//
//  Created by Eric Dufresne on 2016-01-10.
//  Copyright © 2016 Eric Dufresne. All rights reserved.
//

#import "IEAudioPlayer.h"

@interface IEAudioPlayer ()
@property (strong, nonatomic) NSMutableDictionary *dictionary;
@end

@implementation IEAudioPlayer
+(IEAudioPlayer*)sharedPlayer{
    static IEAudioPlayer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[IEAudioPlayer alloc] init];
    });
    return sharedInstance;
}
-(id)init{
    if (self = [super init]){
        self.dictionary = [NSMutableDictionary dictionary];
    }
    return self;
}
-(void)preloadSoundWithName:(NSString *)name waitForCompletion:(BOOL)completion{
    SKAction *action = [SKAction playSoundFileNamed:name waitForCompletion:completion];
    [self.dictionary setValue:action forKey:name];
}
-(SKAction*)soundActionWithname:(NSString *)name{
    if ([self.dictionary objectForKey:name] == nil)
        [self preloadSoundWithName:name waitForCompletion:NO];
    return [self.dictionary objectForKey:name];
}
-(BOOL)isPreloaded:(NSString *)name{
    return [self.dictionary objectForKey:name] != nil;
}
@end

//
//  IEAudioPlayer.h
//  Trick Shot
//
//  Created by Eric Dufresne on 2016-01-10.
//  Copyright © 2016 Eric Dufresne. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SpriteKit/SKAction.h>

@interface IEAudioPlayer : NSObject
+(IEAudioPlayer*)sharedPlayer;
-(void)preloadSoundWithName:(NSString*)name waitForCompletion:(BOOL)completion;
-(SKAction*)soundActionWithname:(NSString*)name;
-(BOOL)isPreloaded:(NSString*)name;
@end

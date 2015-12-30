//
//  NewLevelSelectScene.h
//  trickshotfix
//
//  Created by Eric Dufresne on 2015-11-04.
//  Copyright © 2015 Eric Dufresne. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface NewLevelSelectScene : SKScene
@property (assign, nonatomic) NSInteger pageIndex;
@property (assign, nonatomic) NSInteger rows;
@property (assign, nonatomic) NSInteger columns;
-(void)prepareToLeave;
@end

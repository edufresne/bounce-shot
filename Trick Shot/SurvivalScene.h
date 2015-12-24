//
//  SurvivalScene.h
//  Trick Shot
//
//  Created by Eric Dufresne on 2015-12-20.
//  Copyright © 2015 Eric Dufresne. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>
#import "IEPointSelectionManager.h"
#import "IEButton.h"
#import "IETimeLabel.h"
typedef enum : NSUInteger{
    GameStatePaused,
    GameStateLost,
    GameStateWaitingForTouch,
    GameStatePlaying,
    GameStateStart
} GameState;
typedef enum : NSUInteger{
    MenuStateHidden,
    MenuStateShowing
}MenuState;
typedef enum : NSUInteger{
    ObstacleShapeSquare,
    ObstacleShapeCircle,
    ObstacleShapeTriangle,
    ObstacleShapePolygon
}ObstacleShape;
@interface SurvivalScene : SKScene <IEPointSelectionDelegate, SKPhysicsContactDelegate, IEButtonDelegate, IETimeLabelDelegate>
@property (assign, nonatomic) GameState gameState;
@property (assign, nonatomic) MenuState menuState;
@end

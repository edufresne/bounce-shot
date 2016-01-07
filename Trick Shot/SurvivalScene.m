//
//  SurvivalScene.m
//  Trick Shot
//
//  Created by Eric Dufresne on 2015-12-20.
//  Copyright © 2015 Eric Dufresne. All rights reserved.
//

#import "SurvivalScene.h"
#import "AppDelegate.h"
#import "IEPowerup.h"
#import "MenuScene.h"
#import <GameKit/GameKit.h>
#import <CoreMotion/CoreMotion.h>
#import "IEDataManager.h"
#define BALL_ARROW_SPACING 15.0
#define noGravity ((self.physicsWorld.gravity.dx == 0) && (self.physicsWorld.gravity.dy == 0))
#define FIRE_SPEED_MULTIPLIER 1.0
#define GRAVITY_FIRE_MULTIPLIER 2.9
#define is_ipad (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define INITIAL_SPEED 10.0*(((int)is_ipad)+1)

#define DIM_FACTOR_POWERUP 12
#define DIM_FACTOR_SMALL_STAR 20.0
#define DIM_FACTOR_BALL 10.0
#define DIM_FACTOR_OBSTACLE 6.4

#define POWERUP_VANISH_TIME 8.0
#define OBSTACLE_VANISH_TIME 12.0

#define kFilteringFactor 0.1
#define kVelocityMultiplier 600.0
#define kMaxDistance sqrtf(powf(self.size.height, 2)+ powf(self.size.width, 2))
#define detailedDebug

@interface SurvivalScene ()
{
    IETimeLabel *timeLabel;
    SKShapeNode *laserPath;
    SKSpriteNode *menuList;
    CGFloat storedTheta;
    NSTimer *timeout;
    CGVector pauseVelocity;
    int currentPowerups;
    IEDecrementTimeLabel *decrement;
    NSInteger currentStars;
    SKLabelNode *starLabel;
    double accelX;
    double accelY;
    BOOL tilt;
}
@property (strong, nonatomic) SKSpriteNode *circle;
@property (strong, nonatomic) SKTexture *dotTexture;
@property (strong, nonatomic) SKSpriteNode *selectionSprite;
@property (strong, nonatomic) SKSpriteNode *spriteNodeWithTexture;
@property (strong, nonatomic) IESimpleSelectionManager *manager;
@property (strong, nonatomic) NSMutableArray *currentObjects;
@property (assign, nonatomic) BOOL powerupExists;
@property (strong, nonatomic) SKShapeNode *dragShape;

@property (strong, nonatomic) CMMotionManager *motionManager;
@end
@implementation SurvivalScene
@synthesize circle;
static const uint32_t ballCategory = 0x1 << 0;
static const uint32_t edgeCategory = 0x1 << 1;
static const uint32_t powerupCategory = 0x1 << 2;
static const uint32_t instaDeathCategory = 0x1 << 3;
static const uint32_t invincibleCategory = 0x1 << 4;
static const uint32_t starCategory = 0x1 << 5;

-(void)didMoveToView:(SKView *)view{
    currentPowerups = 0;
    currentStars = 0;
    self.currentObjects = [[NSMutableArray alloc]init];
    self.gameState = GameStateStart;
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    int index = 5+arc4random()%4;
    if (index == 7)
        index = 5;
    self.backgroundColor = [delegate.arrayOfColors objectAtIndex:index];
    self.physicsWorld.contactDelegate = self;
    self.physicsWorld.gravity = CGVectorZero();
    //Circle initialization
    SKShapeNode *circleShape = [SKShapeNode shapeNodeWithCircleOfRadius:256];
    circleShape.strokeColor = [SKColor darkGrayColor];
    circleShape.fillColor = [SKColor whiteColor];
    if (is_ipad)
        circleShape.lineWidth = 10;
    else
        circleShape.lineWidth = 20;
    circleShape.antialiased = YES;
    circle = [SKSpriteNode spriteNodeWithTexture:[self.view textureFromNode:circleShape]];
    circle.size = CGSizeMake(self.size.width/DIM_FACTOR_BALL, self.size.width/DIM_FACTOR_BALL);
    circle.position = CGPointMake(self.size.width/2, circle.size.height/2);
    circle.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:circle.size.width/2];
    circle.physicsBody.linearDamping = 0;
    circle.physicsBody.angularDamping = 0;
    circle.physicsBody.restitution = 1;
    circle.physicsBody.friction = 0;
    circle.physicsBody.dynamic = YES;
    circle.physicsBody.allowsRotation = YES;
    circle.physicsBody.categoryBitMask = ballCategory;
    circle.physicsBody.collisionBitMask = edgeCategory;
    circle.physicsBody.contactTestBitMask = edgeCategory;
    circle.physicsBody.mass = 0.035744;
    [self addChild:circle];
    //arrow
    NSLog(@"%f", self.size.width/50);
    SKSpriteNode *arrow = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"arrow_light.png"]];
    arrow.size = CGSizeMake(13, 11);
    arrow.alpha = 0.4;
    arrow.position = CGPointMake(self.size.width/2, circle.size.height+BALL_ARROW_SPACING);
    arrow.name = @"arrow";
    [arrow runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction fadeAlphaTo:0.7 duration:2], [SKAction fadeAlphaTo:0.4 duration:2]]]]];
    [arrow runAction:[SKAction rotateByAngle:M_PI_2 duration:0]];
    [self addChild:arrow];
    //DotTexture
    SKShapeNode *dot = [SKShapeNode shapeNodeWithCircleOfRadius:128];
    dot.fillColor = [SKColor whiteColor];
    dot.strokeColor = dot.fillColor;
    dot.antialiased = YES;
    self.dotTexture = [self.view textureFromNode:dot];
    dot.glowWidth = 2;
    //Selection sprite
    self.selectionSprite = [SKSpriteNode spriteNodeWithTexture:self.dotTexture];
    self.selectionSprite.size = CGSizeMake(5, 5);
    [self.selectionSprite runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction scaleTo:2 duration:1], [SKAction scaleTo:1 duration:1]]]]];
    //Title
    SKNode *node = [SKNode node];
    node.position = CGPointMake(self.size.width/2, self.size.height/2);
    SKLabelNode *firstLine = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    firstLine.fontSize = 30;
    firstLine.text = @"Survival Mode";
    firstLine.fontColor = [SKColor whiteColor];
    firstLine.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    firstLine.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    firstLine.position = CGPointZero;
    [node addChild:firstLine];
    SKLabelNode *secondLine = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    secondLine.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    secondLine.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    secondLine.fontColor = [SKColor whiteColor];
    secondLine.fontSize = 20;
    secondLine.text = @"Tap Anywhere to Start";
    secondLine.position = CGPointMake(0, -firstLine.frame.size.height/2-5-secondLine.frame.size.height/2);
    [node addChild:secondLine];
    [self addChild:node];
    [node runAction:[SKAction sequence:@[[SKAction waitForDuration:1], [SKAction fadeAlphaTo:0 duration:0.75], [SKAction removeFromParent]]]];
    node.zPosition = 10;
    //Menu
    SKSpriteNode *menuButton = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"menu_selected.png"]];
    menuButton.size = CGSizeMake(25, 25);
    menuButton.position = CGPointMake(menuButton.size.width/2+5, self.size.height-menuButton.size.height/2-5);
    menuButton.name = @"restart";
    menuButton.zPosition = 10;
    [self addChild:menuButton];
    timeLabel = [IETimeLabel labelNodeWithFontNamed:@"Roboto-Thin"];
    timeLabel.delegate = self;
    timeLabel.fontColor = [SKColor whiteColor];
    timeLabel.fontSize = 16;
    timeLabel.zPosition = 10;
    timeLabel.position = CGPointMake(self.size.width/2, menuButton.position.y);
    [self addChild:timeLabel];
    
    self.manager = [[IESimpleSelectionManager alloc] init];
    self.manager.delegate = self;
    
    starLabel = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    starLabel.fontColor = [SurvivalScene colorWithR:255 G:255 B:77];
    starLabel.fontSize = timeLabel.fontSize;
    starLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    starLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    starLabel.text = @"0";
    SKSpriteNode *miniStar = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"star.png"]];
    miniStar.size = CGSizeMake(starLabel.frame.size.height, starLabel.frame.size.height);
    miniStar.position = CGPointMake(starLabel.frame.size.width*2, 0);
    miniStar.alpha = 0.5;
    starLabel.position = CGPointMake(self.frame.size.width/4, timeLabel.position.y);
    [starLabel addChild:miniStar];
    [self addChild:starLabel];
    
}
-(void)powerupDidEndWithType:(IEPowerupType)type{
    self.powerupExists = NO;
    if (type == IEPowerupGravity || type == IEPowerupTilt){
        if (self.motionManager){
            [self.motionManager stopAccelerometerUpdates];
            self.motionManager = nil;
        }
        NSMutableArray *array = [NSMutableArray array];
        [array addObjectsFromArray:self.manager.connections];
        for (IEPointPair *pair in array){
            [self.manager removePair:pair];
        }
        self.physicsWorld.gravity = CGVectorZero();
        
        self.circle.physicsBody.velocity = CGVectorMake(0, 0);
        circle.physicsBody.linearDamping = 0;
        circle.physicsBody.angularDamping = 0;
        circle.physicsBody.restitution = 1;
        circle.physicsBody.friction = 0;
        
        self.gameState = GameStateWaitingForTouch;
        CGFloat distance = sqrtf(powf(self.size.width, 2)+powf(self.size.height, 2));
        laserPath = [SKShapeNode node];
        laserPath.strokeColor = [SKColor redColor];
        laserPath.fillColor = [SKColor redColor];
        laserPath.alpha = 0.1;
        //TODO: change laser color
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(self.circle.position.x, self.circle.position.y)];
        storedTheta = M_PI;
        
        [path addLineToPoint:CGPointMake(self.circle.position.x+distance*cosf(storedTheta), self.circle.position.y+distance*sinf(storedTheta))];
        laserPath.path = path.CGPath;
        laserPath.lineWidth = 1;
        laserPath.zPosition = self.circle.zPosition-1;
        [self addChild:laserPath];
        
        SKAction *blink = [SKAction sequence:@[[SKAction fadeAlphaTo:0 duration:0.], [SKAction fadeAlphaTo:0.95 duration:0.1]]];
        SKAction *flashAction = [SKAction repeatAction:blink count:5];
        [laserPath runAction:[SKAction sequence:@[[SKAction fadeAlphaTo:0.95 duration:2], flashAction, [SKAction runBlock:^{
            [laserPath removeFromParent];
            laserPath = nil;
            self.gameState = GameStatePlaying;
            CGFloat speed = INITIAL_SPEED*1.25;
            [self.circle.physicsBody applyImpulse:createAngledVector(speed, storedTheta)];
            self.circle.physicsBody.affectedByGravity = YES;
        }]]]];
    }
    else if (type == IEPowerupImmune){
        [self.circle removeAllActions];
        self.circle.physicsBody.categoryBitMask = ballCategory;
        self.circle.colorBlendFactor = 0;
        self.circle.alpha = 1;
    }
    else if (type == IEPowerupKey)
        self.physicsBody = nil;
}
-(void)didBeginContact:(SKPhysicsContact *)contact{
    if (self.gameState == GameStatePlaying){
        if (contact.bodyA.categoryBitMask == instaDeathCategory || contact.bodyB.categoryBitMask == instaDeathCategory){
            if ([contact.bodyA.node isEqualToNode:self.circle]||[contact.bodyB.node isEqualToNode:self.circle]){
                self.gameState = GameStateLost;
                self.circle.physicsBody.contactTestBitMask = 0x0;
                [self.circle runAction:[SKAction sequence:@[[SKAction scaleTo:0 duration:0.25], [SKAction removeFromParent]]]];
                [self handleEndingState];
            }
        }
        else if ( contact.bodyA.categoryBitMask == starCategory || contact.bodyB.categoryBitMask == starCategory){
            SKNode *star;
            if (contact.bodyA.categoryBitMask == starCategory)
                star = contact.bodyA.node;
            else
                star = contact.bodyB.node;
            [star removeAllActions];
            star.physicsBody = nil;
            [star runAction:[SKAction sequence:@[[SKAction group:@[[SKAction fadeAlphaTo:0 duration:0.25], [SKAction scaleBy:1.25 duration:0.25]]], [SKAction removeFromParent]]]];
            currentStars++;
            starLabel.text = [NSString stringWithFormat:@"%i", (int)currentStars];
            [self generateStar];
        }
        else if (contact.bodyA.categoryBitMask == powerupCategory || contact.bodyB.categoryBitMask == powerupCategory){
            IEPowerup *powerup;
            if (contact.bodyA.categoryBitMask == powerupCategory)
                powerup = (IEPowerup*)contact.bodyA.node;
            else
                powerup = (IEPowerup*)contact.bodyB.node;
            powerup.physicsBody = nil;
            IEPowerupType type = powerup.powerupType;
            if (type == IEPowerupAimAndFire){
                CGVector storedVelocity = self.circle.physicsBody.velocity;
                self.circle.physicsBody.velocity = CGVectorMake(0, 0);
                self.circle.physicsBody.affectedByGravity = NO;
                self.gameState = GameStateWaitingForTouch;
                CGFloat distance = sqrtf(powf(self.size.width, 2)+powf(self.size.height, 2));
                laserPath = [SKShapeNode node];
                laserPath.strokeColor = [SKColor redColor];
                laserPath.fillColor = [SKColor redColor];
                laserPath.alpha = 0.1;
                //TODO: change laser color
                UIBezierPath *path = [UIBezierPath bezierPath];
                [path moveToPoint:CGPointMake(self.circle.position.x, self.circle.position.y)];
                storedTheta = atanf(storedVelocity.dy/storedVelocity.dx);
                if (storedTheta<0)
                    storedTheta+=M_PI;
                
                [path addLineToPoint:CGPointMake(self.circle.position.x+distance*cosf(storedTheta), self.circle.position.y+distance*sinf(storedTheta))];
                laserPath.path = path.CGPath;
                laserPath.lineWidth = 1;
                laserPath.zPosition = self.circle.zPosition-1;
                [self addChild:laserPath];
                
                SKAction *blink = [SKAction sequence:@[[SKAction fadeAlphaTo:0 duration:0.], [SKAction fadeAlphaTo:0.95 duration:0.1]]];
                SKAction *flashAction = [SKAction repeatAction:blink count:5];
                [laserPath runAction:[SKAction sequence:@[[SKAction fadeAlphaTo:0.95 duration:2], flashAction, [SKAction runBlock:^{
                    [laserPath removeFromParent];
                    laserPath = nil;
                    self.gameState = GameStatePlaying;
                    CGFloat speed;
                    if (noGravity)
                        speed = INITIAL_SPEED*1.25;
                    else
                        speed = INITIAL_SPEED*1.25;
                    [self.circle.physicsBody applyImpulse:createAngledVector(speed, storedTheta)];
                    self.circle.physicsBody.affectedByGravity = YES;
                }]]]];
            }
            else if (type == IEPowerupKey){
                SKAction *sequence = [SKAction sequence:@[[SKAction waitForDuration:5], [SKAction removeFromParent]]];
                SKSpriteNode *leftBorder = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:CGSizeMake(self.size.width/60, self.size.height)];
                leftBorder.anchorPoint = CGPointZero;
                leftBorder.position = CGPointZero;
                [leftBorder runAction:sequence];
                [self addChild:leftBorder];
                SKSpriteNode *rightBorder = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:leftBorder.size];
                rightBorder.anchorPoint = CGPointMake(1, 0);
                rightBorder.position = CGPointMake(self.size.width, 0);
                [rightBorder runAction:sequence];
                [self addChild:rightBorder];
                SKSpriteNode *bottomBorder = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:CGSizeMake(self.size.width, self.size.width/60)];
                bottomBorder.anchorPoint = CGPointZero;
                bottomBorder.position = CGPointZero;
                [bottomBorder runAction:sequence];
                [self addChild:bottomBorder];
                SKSpriteNode *topBorder = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:bottomBorder.size];
                topBorder.anchorPoint = CGPointMake(0, 1);
                topBorder.position = CGPointMake(0, self.size.height);
                [topBorder runAction:sequence];
                [self addChild:topBorder];
                self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:CGRectMake(self.size.width/60, self.size.width/60, self.size.width-2*self.size.width/60, self.size.height-2*self.size.width/60)];
            }
            else if (type == IEPowerupGravity){
                //Changed restitution of cirlcle from 0 to 0.2.
                self.circle.physicsBody.restitution = 0.2;
                self.circle.physicsBody.friction = 0.2;
                self.circle.physicsBody.linearDamping = 0.1;
                self.physicsWorld.gravity = CGVectorMake(4.5*cosf(powerup.zRotation+M_PI*3/2), 4.5*sinf(powerup.zRotation+M_PI*3/2));
                self.circle.physicsBody.velocity = CGVectorZero();
                for (IEPointPair *pair in self.manager.connections){
                    SKNode *node = pair.dot1;
                    node.physicsBody.restitution = 0.2;
                    node.physicsBody.friction = 0.2;
                }
            }
            else if (type == IEPowerupTilt){
                tilt = YES;
                self.physicsBody.friction = 0.2;
                self.physicsBody.restitution = 0.2;
                self.circle.physicsBody.restitution = 0;
                self.circle.physicsBody.friction = 0.2;
                self.circle.physicsBody.linearDamping = 0.3;
                self.motionManager = [[CMMotionManager alloc] init];
                self.motionManager.accelerometerUpdateInterval = 1/60.0;
                self.physicsWorld.gravity = CGVectorZero();
                self.circle.physicsBody.velocity = CGVectorZero();
                [self.motionManager startAccelerometerUpdatesToQueue:[[NSOperationQueue alloc] init] withHandler:^(CMAccelerometerData * _Nullable accelerometerData, NSError * _Nullable error) {
                    if (error)
                        NSLog(@"No Gyroscope");
                    else{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            CMAcceleration acceleration = accelerometerData.acceleration;
                            accelX = (acceleration.x*kFilteringFactor)+(accelX*(1-kFilteringFactor));
                            accelY = (acceleration.y*kFilteringFactor)+(accelY*(1-kFilteringFactor));
                            circle.physicsBody.velocity = CGVectorMake(accelX*kVelocityMultiplier, (accelY+0.4)*kVelocityMultiplier);
                        });
                    }
                }];
            }
            else if (type == IEPowerupImmune){
                self.circle.physicsBody.categoryBitMask = invincibleCategory;
                self.circle.alpha = 0.7;
                NSArray *colors = [NSArray arrayWithObjects:[SKColor redColor], [SKColor orangeColor], [SKColor yellowColor], [SKColor greenColor], [SKColor blueColor], [SKColor cyanColor], [SKColor magentaColor], [SKColor purpleColor], nil];
                [self.circle runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction waitForDuration:0.1], [SKAction runBlock:^{
                    static int index = 0;
                    [self.circle runAction:[SKAction colorizeWithColor:[colors objectAtIndex:index] colorBlendFactor:1 duration:0]];
                    index++;
                    if (index>=colors.count)
                        index = 0;
                }]]]]];
            }
            [powerup runAction:[SKAction sequence:@[[SKAction group:@[[SKAction fadeAlphaTo:0 duration:1], [SKAction scaleTo:1.4 duration:1]]], [SKAction removeFromParent]]]];
            [self runAction:[SKAction sequence:@[[SKAction waitForDuration:5], [SKAction runBlock:^{
                [self powerupDidEndWithType:type];
            }]]]];
            if (powerup.powerupType != IEPowerupAimAndFire){
                
                IEPowerup *copy = [IEPowerup powerupWithType:powerup.powerupType shiftPoint:CGPointZero];
                copy.size = CGSizeMake(self.size.width/DIM_FACTOR_POWERUP, self.size.width/DIM_FACTOR_POWERUP);
                copy.alpha = 0.5;
                IEDecrementTimeLabel *countDown = [IEDecrementTimeLabel timeLabelWithFontNamed:@"Roboto-Thin" seconds:5];
                countDown.fontColor = [SKColor whiteColor];
                countDown.fontSize = 16;
                countDown.position = CGPointMake(self.size.width-5-copy.size.width/2, self.size.height-5-copy.size.height-countDown.frame.size.height);
                copy.position = CGPointMake(0, copy.size.height/2+countDown.frame.size.height/2+5);
                [self addChild:countDown];
                [countDown start];
                [countDown addChild:copy];
                decrement = countDown;
            }
        }
        else if (contact.bodyA.categoryBitMask == edgeCategory || contact.bodyB.categoryBitMask == edgeCategory){
            SKNode *edge;
            if (contact.bodyA.categoryBitMask == edgeCategory)
                edge = contact.bodyA.node;
            else
                edge = contact.bodyB.node;
            if (noGravity)
                [self.manager removePair:[self.manager connectionClosestToPoint:edge.position]];
        }
    }
}
-(void)update:(NSTimeInterval)currentTime{
    if (self.gameState != GameStatePlaying)
        return;
    if (circle.position.x<-circle.size.width/2 || circle.position.x>self.size.width+circle.size.width/2 || circle.position.y<-circle.size.height || circle.position.y > self.size.height+circle.size.height/2){
        [self.circle removeFromParent];
        self.gameState = GameStateLost;
        [self handleEndingState];
    }
}
-(void)checkTimeout{
    if (circle.position.x<-circle.size.width/2 || circle.position.x>self.size.width+circle.size.width/2 || circle.position.y<-circle.size.height || circle.position.y > self.size.height+circle.size.height/2){
        self.gameState = GameStateLost;
        [circle removeFromParent];
        [self handleEndingState];
        [timeLabel stop];
        timeout = nil;
    }
}
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    CGPoint location = [[touches anyObject] locationInNode:self];
    SKNode *node = [self nodeAtPoint:location];
    if ([node.name isEqualToString:@"restart"] && self.gameState != GameStatePaused && self.gameState != GameStateLost && self.menuState == MenuStateHidden){
        NSLog(@"Inside restart touch");
        [self showContentList];
        [self runAction:[SKAction sequence:@[[SKAction waitForDuration:0.3], [SKAction runBlock:^{
            self.paused = YES;
            pauseVelocity = circle.physicsBody.velocity;
            circle.physicsBody.velocity = CGVectorZero();
            [timeLabel stop];
            if (decrement)
                [decrement stop];
        }]]]];
    }
    else if (self.gameState == GameStateStart || (CGRectContainsPoint(menuList.frame, location) && self.menuState == MenuStateShowing))
        return;
    else if (self.menuState == MenuStateShowing && !CGRectContainsPoint(menuList.frame, location)){
        [self hideContentList];
        self.paused = NO;
        circle.physicsBody.velocity = pauseVelocity;
        pauseVelocity = CGVectorZero();
        [timeLabel start];
        if (decrement)
            [decrement start];
    }
    else if (self.gameState == GameStateWaitingForTouch && self.menuState != MenuStateShowing){
        CGFloat distance = sqrtf(powf(self.size.width/2, 2)+powf(self.size.height/2, 2));
        storedTheta = getAbsoluteAngle(self.circle.position, location);
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(self.circle.position.x, self.circle.position.y)];
        
        [path addLineToPoint:CGPointMake(self.circle.position.x+distance*cosf(storedTheta), self.circle.position.y+distance*sinf(storedTheta))];
        laserPath.path = path.CGPath;
    }
    else if (!self.dragShape && self.gameState == GameStatePlaying){
        SKNode *menu = [self childNodeWithName:@"restart"];
        CGFloat distance = distanceFromPointToPoint(menu.position, location);
        if (distance<self.manager.minimumDrawDistance+menu.frame.size.width/2){
            [self showContentList];
            [self runAction:[SKAction sequence:@[[SKAction waitForDuration:0.3], [SKAction runBlock:^{
                self.paused = YES;
                pauseVelocity = circle.physicsBody.velocity;
                circle.physicsBody.velocity = CGVectorZero();
                [timeLabel stop];
                if (decrement)
                    [decrement stop];
            }]]]];
        }
        else{
            [self.manager startedSelection:location];
        }
    }
}
-(void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    if (self.gameState == GameStatePlaying && self.menuState == MenuStateHidden){
        if (!self.dragShape&&self.manager.hasSelection){
            //If the drag shape has not been created adn the manager has a selection it is initialized.
            self.dragShape = [SKShapeNode node];
            self.dragShape.strokeColor = [SKColor whiteColor];
            self.dragShape.glowWidth = 2;
            [self addChild:self.dragShape];
        }
        // The drag shape has been already created so its path changes to the current touch of the user.
        CGMutablePathRef pathToDraw = CGPathCreateMutable();
        CGPathMoveToPoint(pathToDraw, NULL, self.manager.selectedPoint.x , self.manager.selectedPoint.y);
        CGPathAddLineToPoint(pathToDraw, NULL, location.x, location.y);
        self.dragShape.path = pathToDraw;
    }
    else if (self.gameState == GameStateWaitingForTouch){
        CGFloat distance = sqrtf(powf(self.size.width/2, 2)+powf(self.size.height/2, 2));
        storedTheta = getAbsoluteAngle(self.circle.position, location);
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(self.circle.position.x, self.circle.position.y)];
        
        [path addLineToPoint:CGPointMake(self.circle.position.x+distance*cosf(storedTheta), self.circle.position.y+distance*sinf(storedTheta))];
        laserPath.path = path.CGPath;
    }
}
-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    if (self.gameState == GameStatePlaying&& self.menuState != MenuStateShowing){
        CGPoint location = [[touches anyObject] locationInNode:self];
        if (self.dragShape){
            [self.dragShape removeFromParent];
            self.dragShape = nil;
        }
        [self.manager finishedSelection:location];
    }
    else if (self.gameState == GameStateStart && self.menuState != MenuStateShowing){
        [circle.physicsBody applyImpulse:createAngledVector(INITIAL_SPEED, M_PI_2)];
        SKNode *label = [self childNodeWithName:@"titleLabel"];
        [label removeFromParent];
        SKNode *arrow = [self childNodeWithName:@"arrow"];
        [arrow removeFromParent];
        //Selection Sprite ?
        self.gameState = GameStatePlaying;
        [timeLabel start];
        [self generateStar];
    }
}
-(void)showContentList{
    static BOOL initialized = NO;
    //Only initalizes the menu once using a static boolean
    if (!initialized){
        menuList = [SKSpriteNode spriteNodeWithColor:[SurvivalScene colorWithR:53 G:53 B:53] size:CGSizeMake(self.size.width/5, self.size.height)];
        menuList.anchorPoint = CGPointZero;
        menuList.alpha = 0.5;
        menuList.position = CGPointMake(-menuList.size.width, 0);
        
        IETextureButton *restart = [IETextureButton buttonWithDefaultTexture:[SKTexture textureWithImageNamed:@"restart.png"] selectedTexture:[SKTexture textureWithImageNamed:@"restart_selected.png"]];
        restart.name = @"restartButton";
        restart.size = CGSizeMake(menuList.size.width*3/4, menuList.size.width*3/4);
        restart.delegate = self;
        restart.position = CGPointMake(menuList.size.width/2, menuList.size.height*2/3);
        restart.alpha = 2;
        [menuList addChild:restart];
        
        IETextureButton *menuButton = [IETextureButton buttonWithDefaultTexture:[SKTexture textureWithImageNamed:@"menu.png"] selectedTexture:[SKTexture textureWithImageNamed:@"menu_selected.png"]];
        menuButton.name = @"mainMenuButton";
        menuButton.size = restart.size;
        menuButton.delegate = self;
        menuButton.position = CGPointMake(restart.position.x, menuList.size.height*1/3);
        menuButton.alpha = 2;
        [menuList addChild:menuButton];
        
        for (SKSpriteNode *sprite in menuList.children){
            SKLabelNode *label = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
            label.fontSize = 12;
            label.fontColor = [SKColor whiteColor];
            label.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
            label.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
            if ([sprite.name isEqualToString:@"restartButton"])
                label.text = @"Restart";
            else if ([sprite.name isEqualToString:@"levelSelectButton"])
                label.text = @"Level Select";
            else
                label.text = @"Main Menu";
            
            label.position = CGPointMake(0, -sprite.size.height/2-label.frame.size.height);
            [sprite addChild:label];
        }
    }
    self.menuState = MenuStateShowing;
    [self addChild:menuList];
    [menuList runAction:[SKAction moveByX:menuList.size.width y:0 duration:0.25]];
}
-(void)hideContentList{
    if (menuList){
        self.menuState = MenuStateHidden;
        [menuList runAction:[SKAction moveByX:-menuList.size.width y:0 duration:0.25]];
    }
}
-(void)handleEndingState{
    [timeLabel stop];
    
    [self hideContentList];
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    if (!delegate.adsRemoved)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"showInterstitial" object:nil];
    
    NSTimeInterval time = timeLabel.currentTimeInSeconds;
    IEDataManager *manager = [IEDataManager sharedManager];
    [manager scoredInSurvival:currentStars time:time];
    GKScore *starScore = [[GKScore alloc] initWithLeaderboardIdentifier:@"BounceDraw.SurvivalMostStars"];
    starScore.value = (int64_t)currentStars;
    GKScore *timeScore = [[GKScore alloc] initWithLeaderboardIdentifier:@"BounceDraw.SurvivalLeaderboard"];
    timeScore.value = (int64_t)time;
    [GKScore reportScores:@[starScore, timeScore] withCompletionHandler:^(NSError * _Nullable error) {
        if (error)
            NSLog(@"Could not report scores in survival");
    }];
    
    SKSpriteNode *black = [SKSpriteNode spriteNodeWithColor:[SurvivalScene colorWithR:54 G:54 B:54] size:self.size];
    black.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    black.alpha = 0;
    [self addChild:black];
    [black runAction:[SKAction fadeAlphaTo:0.5 duration:0.25]];
    SKLabelNode *label = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    label.fontSize = 26;
    label.text = [NSString stringWithFormat:@"Time survived: %@", timeLabel];
    label.fontColor = [SKColor whiteColor];
    label.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    label.alpha = 0;
    [self addChild:label];
    [label runAction:[SKAction fadeAlphaTo:1 duration:0.25]];
    SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"star.png"]];
    star.size = CGSizeMake(4*self.size.width/DIM_FACTOR_SMALL_STAR, 4*self.size.width/DIM_FACTOR_SMALL_STAR);
    star.position = CGPointMake(self.size.width/2-star.size.width/2-5, self.size.height+star.size.height/2);
    [self addChild:star];
    [star runAction:[SKAction sequence:@[[SKAction waitForDuration:0.25], [SKAction moveToY:(self.size.height+label.position.y)/2 duration:0.25]]]];
    SKLabelNode *counterNode = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    counterNode.fontColor = starLabel.fontColor;
    counterNode.fontSize = 35;
    counterNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    counterNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    counterNode.text = @"0";
    counterNode.position = CGPointMake(star.position.x+star.size.width/2+counterNode.frame.size.width*3, (self.size.height+label.position.y)/2);
    counterNode.alpha = 0;
    [self addChild:counterNode];
    [counterNode runAction:[SKAction sequence:@[[SKAction waitForDuration:0.5], [SKAction fadeAlphaTo:1 duration:0], [SKAction repeatAction:[SKAction sequence:@[[SKAction waitForDuration:0.05], [SKAction runBlock:^{
        int value = counterNode.text.intValue;
        value++;
        counterNode.text = [NSString stringWithFormat:@"%i", value];
    }]]] count:currentStars]]]];
    
    IELabelButton *nextLevel;
    nextLevel = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:[SKColor whiteColor] selectedColor:[SKColor lightGrayColor]];
    nextLevel.fontSize = 26;
    nextLevel.name = @"restartButton";
    nextLevel.text = @"Try Again";
    nextLevel.alpha = 0;
    nextLevel.delegate = self;
    nextLevel.position = CGPointMake(CGRectGetMidX(self.frame), label.position.y-nextLevel.frame.size.height-20);
    [self addChild:nextLevel];
    [nextLevel runAction:[SKAction fadeAlphaTo:1 duration:0.25]];
    
    IELabelButton *mainMenu = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:[SKColor whiteColor] selectedColor:[SKColor lightGrayColor]];
    mainMenu.fontSize = 26;
    mainMenu.name = @"mainMenuButton";
    mainMenu.text = @"Main Menu";
    mainMenu.alpha = 0;
    mainMenu.delegate = self;
    mainMenu.position = CGPointMake(CGRectGetMidX(self.frame), nextLevel.position.y-mainMenu.frame.size.height-20);
    [self addChild:mainMenu];
    [mainMenu runAction:[SKAction fadeAlphaTo:1 duration:0.25]];
}
#pragma mark - Selection Manager Delgate
/* Called when new point is made on a screen with no other point to pair */
-(void)selectedNewPoint:(CGPoint)point{
    self.selectionSprite.position = point;
    if (!self.selectionSprite.parent&&self.manager.hasSelection)
        [self addChild:self.selectionSprite];
}
/* New point has been deselected leaving no new points on the screen */
-(void)deselectedPoint{
    [self.selectionSprite removeFromParent];
}
/* New connection with two points created */
-(void)didCreateConnection:(IEPointPair *)pair{
    [self touchAnimationAtPoint:pair.first];
    [self touchAnimationAtPoint:pair.second];
    [self.selectionSprite removeFromParent];
    SKSpriteNode *dot1 = [SKSpriteNode spriteNodeWithTexture:self.dotTexture];
    dot1.size = CGSizeMake(5, 5);
    dot1.position = pair.first;
    dot1.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointZero toPoint:CGPointMake(pair.second.x-pair.first.x, pair.second.y-pair.first.y)];
    dot1.physicsBody.categoryBitMask = edgeCategory;
    dot1.physicsBody.collisionBitMask = 0x0;
    dot1.physicsBody.contactTestBitMask = ballCategory | edgeCategory;
    if (noGravity){
        dot1.physicsBody.friction = 0;
        dot1.physicsBody.restitution = 1;
    }
    else{
        dot1.physicsBody.friction = 0.2;
        dot1.physicsBody.restitution = 0.2;
    }
    
    [self addChild:dot1];
    
    SKSpriteNode *dot2 = [SKSpriteNode spriteNodeWithTexture:self.dotTexture];
    dot2.size = dot1.size;
    dot2.position = pair.second;
    [self addChild:dot2];
    
    pair.dot1 = dot1;
    pair.dot2 = dot2;
    SKShapeNode *shape = [SKShapeNode node];
    CGMutablePathRef ref = CGPathCreateMutable();
    CGPathMoveToPoint(ref, NULL, pair.first.x, pair.first.y);
    CGPathAddLineToPoint(ref, NULL, pair.second.x, pair.second.y);
    shape.path = ref;
    shape.fillColor = [SKColor whiteColor];
    shape.strokeColor = [SKColor whiteColor];
    shape.lineWidth = dot1.size.width;
    [self addChild:shape];
    pair.edgeShape = shape;
}
/* Connection that was created before has been removed by the user */
-(void)didRemoveConnection:(IEPointPair *)pair{
    [self.selectionSprite removeFromParent];
    SKAction *fadeAction = [SKAction sequence:@[[SKAction fadeAlphaTo:0 duration:0.25], [SKAction removeFromParent]]];
    [pair.dot1 runAction:fadeAction];
    [pair.dot2 runAction:fadeAction];
    [pair.edgeShape runAction:fadeAction];
}
#pragma mark - IEBUtton Delegate
-(void)buttonWasPressed:(id)button{
    IETextureButton *node = (IETextureButton*)button;
    
    if ([node.name isEqualToString:@"restartButton"]){
        SurvivalScene *scene = [[SurvivalScene alloc] initWithSize:self.view.bounds.size];
        scene.scaleMode = SKSceneScaleModeAspectFill;
        timeLabel.delegate = nil;
        timeLabel = nil;
        [self.view presentScene:scene];
    }
    else if ([node.name isEqualToString:@"mainMenuButton"]){
        MenuScene *scene = [[MenuScene alloc] initWithSize:self.view.bounds.size];
        scene.scaleMode = SKSceneScaleModeAspectFill;
        timeLabel.delegate = nil;
        timeLabel = nil;
        [self.view presentScene:scene];
    }
}
#pragma mark - Generation Algorithms
-(void)timerDidIncrement:(IETimeLabel *)time{
    NSTimeInterval currentTime = (NSTimeInterval)[time currentTimeInSeconds];
    CGFloat probability;
    if (currentPowerups == 0)
        probability = 0.05+currentTime/200.0;
    else if (currentPowerups == 1)
        probability = 0.025+currentTime/500.0;
    else if (currentPowerups == 2)
        probability = 0.01+currentTime/1000.0;
    else
        probability = -1;
    CGFloat rand = randomNumberBetween(1, 0);
    if (rand<probability){
        if (randomNumberBetween(1, 0)<0.5 && !self.powerupExists){
            [self generatePowerup];
            return;
        }
        currentPowerups++;
        [self runAction:[SKAction sequence:@[[SKAction waitForDuration:OBSTACLE_VANISH_TIME], [SKAction runBlock:^{
            currentPowerups--;
        }]]]];
        //Generate random obstacle
        BOOL instaDeath = arc4random()%2;
        CGFloat scale = randomNumberBetween(2, 1);
        
        CGFloat rotation = randomNumberBetween(2*M_PI, 0);
        int type = arc4random()%3;
        SKSpriteNode *sprite = [self obstacleFromType:(ObstacleShape)type instaDeath:instaDeath];
        sprite.zRotation = rotation;
        sprite.xScale = scale;
        sprite.yScale = scale;
        NSDate *date = [NSDate date];
        bool end = false;
        do{
            sprite.position = CGPointMake(randomNumberBetween(self.size.width-circle.size.width/2, circle.size.width/2), randomNumberBetween(self.size.height-circle.size.height/2, circle.size.height));
            
            CGVector velocity = circle.physicsBody.velocity;
            CGFloat resultant = resultantVelocity(velocity);
            if (resultant == 0){
                end = true;
                continue;
            }
            CGFloat theta;
            if (velocity.dy>=0 && velocity.dx>= 0)
                theta = asin(velocity.dy/resultant);
            else if (velocity.dx<0 && velocity.dy >= 0)
                theta = M_PI - asin(velocity.dy/resultant);
            else if (velocity.dx<0 && velocity.dy < 0)
                theta = M_PI+atan(velocity.dy/velocity.dx);
            else
                theta = M_PI*2-acos(velocity.dx/resultant);
            
            CGFloat alpha = M_PI_2+theta;
            CGFloat beta = M_PI+alpha;
            CGFloat r = circle.size.width/2;
            CGFloat ax = r*cosf(alpha);
            CGFloat ay = r*sinf(alpha);
            CGFloat bx = r*cosf(beta);
            CGFloat by = r*sinf(beta);
            
            CGPoint point1 = CGPointMake(circle.position.x-ax, circle.position.y-ay);
            CGPoint point2 = CGPointMake(point1.x+kMaxDistance*cosf(theta), point1.y+kMaxDistance*sinf(theta));
            IELineSegment s = IELineSegmentMake(point1, point2);
            
            CGRect rect = sprite.frame;
            if (IELineSegmentIntersectsRect(s, rect))
                continue;
            
            point1 = CGPointMake(circle.position.x-bx, circle.position.y-by);
            point2 = CGPointMake(point1.x+kMaxDistance*cosf(theta), point1.y+kMaxDistance*sinf(theta));
            s = IELineSegmentMake(point1, point2);
            
            if (IELineSegmentIntersectsRect(s, rect))
                continue;
            end = true;
        }
        while(!end);
        NSLog(@"Generated obstacle in : %f seconds", -date.timeIntervalSinceNow);
        
        [self addChild:sprite];
        [sprite runAction:[SKAction sequence:@[[SKAction waitForDuration:OBSTACLE_VANISH_TIME], [SKAction runBlock:^{
            if ([sprite actionForKey:@"pulsing"]){
                [sprite removeActionForKey:@"pulsing"];
            }
        }],[SKAction repeatAction:[SKAction sequence:@[[SKAction fadeAlphaTo:0 duration:0], [SKAction waitForDuration:0.25], [SKAction fadeAlphaTo:1 duration:0], [SKAction waitForDuration:0.25]]] count:8], [SKAction removeFromParent]]]];
    }
}
-(SKSpriteNode*)obstacleFromType:(ObstacleShape)shape instaDeath:(BOOL)instaDeath{
    UIColor *color;
    if (instaDeath)
        color = [SurvivalScene colorWithR:213 G:69 B:69];
    else
        color = [SKColor whiteColor];
    SKSpriteNode *spriteNode;
    if (shape == ObstacleShapeSquare){
        spriteNode = [SKSpriteNode spriteNodeWithColor:color size:CGSizeMake(self.size.width/DIM_FACTOR_OBSTACLE, self.size.width/DIM_FACTOR_OBSTACLE)];
        spriteNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:spriteNode.size];
    }
    else if (shape == ObstacleShapeCircle){
        SKShapeNode *shapeNode = [SKShapeNode shapeNodeWithCircleOfRadius:250];
        shapeNode.fillColor = color;
        shapeNode.strokeColor = color;
        spriteNode = [SKSpriteNode spriteNodeWithTexture:[self.view textureFromNode:shapeNode]];
        spriteNode.size = CGSizeMake(self.size.width/DIM_FACTOR_OBSTACLE, self.size.width/DIM_FACTOR_OBSTACLE);
        spriteNode.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:spriteNode.size.width/2];
    }
    else if (shape == ObstacleShapeTriangle){
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-25, -25)];
        [path addLineToPoint:CGPointMake(-25, 25)];
        [path addLineToPoint:CGPointMake(25, -25)];
        [path closePath];
        SKShapeNode *shapeNode = [SKShapeNode shapeNodeWithPath:path.CGPath centered:YES];
        shapeNode.strokeColor = color;
        shapeNode.fillColor = color;
        spriteNode = [SKSpriteNode spriteNodeWithTexture:[self.view textureFromNode:shapeNode]];
        spriteNode.physicsBody = [SKPhysicsBody bodyWithPolygonFromPath:path.CGPath];
        spriteNode.size = CGSizeMake(self.size.width/DIM_FACTOR_OBSTACLE, self.size.width/DIM_FACTOR_OBSTACLE);
    }
    else
        return nil;
    if (instaDeath){
        [spriteNode runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction fadeAlphaTo:1 duration:1], [SKAction waitForDuration:0.5], [SKAction fadeAlphaTo:0.5 duration:1], [SKAction waitForDuration:0.5]]]] withKey:@"pulsing"];
        spriteNode.physicsBody.categoryBitMask = instaDeathCategory;
        spriteNode.physicsBody.collisionBitMask = 0x0;
        spriteNode.physicsBody.contactTestBitMask = ballCategory;
        spriteNode.physicsBody.affectedByGravity = NO;
        spriteNode.physicsBody.dynamic = NO;
        spriteNode.zPosition--;
        return spriteNode;
    }
    else{
        spriteNode.physicsBody.categoryBitMask = edgeCategory;
        spriteNode.physicsBody.collisionBitMask = ballCategory;
        spriteNode.physicsBody.contactTestBitMask = 0x0;
        spriteNode.physicsBody.dynamic = NO;
        return spriteNode;
    }
    return spriteNode;
}
-(void)generateStar{
    SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"star.png"]];
    star.size = CGSizeMake(self.size.width/DIM_FACTOR_SMALL_STAR, self.size.width/DIM_FACTOR_SMALL_STAR);
    star.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:star.size];
    star.physicsBody.categoryBitMask = starCategory;
    star.physicsBody.collisionBitMask = 0x0;
    star.physicsBody.contactTestBitMask = ballCategory | invincibleCategory;
    star.physicsBody.affectedByGravity = NO;
    do{
        star.position = CGPointMake(randomNumberBetween(self.size.width-star.size.width-10, star.size.width), randomNumberBetween(self.size.height-star.size.height-20, star.size.height));
    }
    while (distanceFromPointToPoint(star.position, [self childNodeWithName:@"restart"].position)<100);
    [star runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction scaleTo:1.25 duration:1], [SKAction scaleTo:1.0 duration:1]]]]];
    [self addChild:star];
}
-(void)generatePowerup{
    self.powerupExists = YES;
    IEPowerup *powerup;
    int rand = arc4random()%5;
    if (rand == 0)
        powerup = [IEPowerup powerupWithType:IEPowerupAimAndFire shiftPoint:CGPointZero];
    else if (rand == 1)
        powerup = [IEPowerup powerupWithType:IEPowerupGravity shiftPoint:CGPointZero];
    else if (rand == 2)
        powerup = [IEPowerup powerupWithType:IEPowerupKey shiftPoint:CGPointZero];
    else if (rand == 3)
        powerup = [IEPowerup powerupWithType:IEPowerupTilt shiftPoint:CGPointZero];
    else
        powerup = [IEPowerup powerupWithType:IEPowerupImmune shiftPoint:CGPointZero];
    powerup.size = CGSizeMake(self.size.width/DIM_FACTOR_POWERUP, self.size.width/DIM_FACTOR_POWERUP);
    CGPoint position;
    do{
        position = CGPointMake(randomNumberBetween(self.size.width-powerup.size.width, powerup.size.width), randomNumberBetween(self.size.height-powerup.size.height, powerup.size.height));
    }
    while (![self nodeAtPoint:position]);
    if (powerup.powerupType == IEPowerupGravity){
        if (position.x<self.size.width/8)
            powerup.zRotation = M_PI_2;
        else if (position.x>self.size.width-self.size.width/8)
            powerup.zRotation = -M_PI_2;
        else if (position.y<self.size.height/2)
            powerup.zRotation = M_PI;
    }
    powerup.position = position;
    powerup.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:powerup.size];
    powerup.physicsBody.categoryBitMask = powerupCategory;
    powerup.physicsBody.contactTestBitMask = ballCategory | invincibleCategory;
    powerup.physicsBody.collisionBitMask = 0x0;
    powerup.physicsBody.affectedByGravity = NO;
    powerup.physicsBody.dynamic = NO;
    [powerup runAction:[SKAction sequence:@[[SKAction waitForDuration:OBSTACLE_VANISH_TIME], [SKAction repeatAction:[SKAction sequence:@[[SKAction fadeAlphaTo:0 duration:0], [SKAction waitForDuration:0.25], [SKAction fadeAlphaTo:1 duration:0], [SKAction waitForDuration:0.25]]] count:8], [SKAction runBlock:^{
        if (powerup.parent!=nil)
            [powerup removeFromParent];
        self.powerupExists = NO;
    }]]]];
    [self addChild:powerup];
}


#pragma mark - Helper Methods

-(void)touchAnimationAtPoint:(CGPoint)location{
    SKShapeNode *shape = [SKShapeNode shapeNodeWithCircleOfRadius:100];
    //TODO: Match color with new laser color
    if(self.gameState == GameStateWaitingForTouch){
        shape.fillColor = [SKColor redColor];
        shape.strokeColor = [SKColor redColor];
    }
    else{
        shape.fillColor = [SKColor whiteColor];
        shape.strokeColor = [SKColor whiteColor];
    }
    [shape setLineWidth:5];
    shape.antialiased = YES;
    SKTexture *texture = [self.view textureFromNode:shape];
    
    SKSpriteNode *tapNode = [SKSpriteNode spriteNodeWithTexture:texture];
    tapNode.position = location;
    tapNode.size = CGSizeMake(5, 5);
    tapNode.alpha = 0.9;
    [self addChild:tapNode];
    [tapNode runAction:[SKAction sequence:@[[SKAction group:@[[SKAction fadeAlphaTo:0 duration:0.5], [SKAction scaleBy:8 duration:0.5]]], [SKAction removeFromParent]]]];
}
static inline CGFloat getAbsoluteAngle(CGPoint origin, CGPoint point){
    CGPoint diff = CGPointMake(point.x-origin.x, point.y-origin.y);
    CGFloat distance = distanceFromPointToPoint(origin, point);
    if (diff.y<0)
        return 2*M_PI-acosf(diff.x/distance);
    else
        return acosf(diff.x/distance);
}
static inline CGFloat distanceFromPointToPoint(CGPoint first, CGPoint second){
    return sqrtf(powf(first.x-second.x, 2)+powf(first.y-second.y, 2));
}
static inline CGVector createAngledVector(CGFloat magnitude, CGFloat angle){
    return CGVectorMake(magnitude*cosf(angle), magnitude*sinf(angle));
}
static inline CGVector CGVectorZero(){
    return CGVectorMake(0, 0);
}
+(UIColor*)colorWithR:(CGFloat)r G:(CGFloat)g B:(CGFloat)b{
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1];
}
static inline CGFloat randomNumberBetween(CGFloat high, CGFloat low){
    CGFloat random = (CGFloat)rand()/(CGFloat)RAND_MAX;
    return low+random*(high-low);
}
-(void)timerDidFinishCountDown:(IEDecrementTimeLabel *)timeLabel{
    decrement = nil;
}
static inline bool IELineSegmentIntersectsRect(IELineSegment segment, CGRect rect){
    if (CGRectContainsPoint(rect, segment.first)|| CGRectContainsPoint(rect, segment.second))
        return true;
    IELineSegment bottom = IELineSegmentMake(CGPointMake(rect.origin.x, rect.origin.y), CGPointMake(rect.origin.x+rect.size.width, rect.origin.y));
    IELineSegment left = IELineSegmentMake(bottom.first, CGPointMake(rect.origin.x, rect.origin.y+rect.size.height));
    IELineSegment right = IELineSegmentMake(bottom.second, CGPointMake(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height));
    IELineSegment top = IELineSegmentMake(left.second, right.second);
    
    if (IELineSegmentsIntersect(segment, bottom)){
        NSLog(@"Intersects bottom");
        return true;
    }
    if (IELineSegmentsIntersect(segment, top)){
        NSLog(@"Intersects top");
        return true;
    }
    if (IELineSegmentsIntersect(segment, left)){
        NSLog(@"Intersects left");
        return true;
    }
    if (IELineSegmentsIntersect(segment, right)){
        NSLog(@"Intersects right");
        return true;
    }
    
    return false;
}
static inline bool IELineSegmentsIntersect(IELineSegment a, IELineSegment b){
    CGFloat px = det(det(a.first.x, a.first.y, a.second.x, a.second.y), det(a.first.x, 1, a.second.x, 1), det(b.first.x, b.first.y, b.second.x, b.second.y), det(b.first.x, 1, b.second.x, 1));
    CGFloat py = det(det(a.first.x, a.first.y, a.second.x, a.second.y), det(a.first.y, 1, a.second.y, 1), det(b.first.x, b.first.y, b.second.x, b.second.y), det(b.first.y, 1, b.second.y, 1));
    CGFloat den = det(det(a.first.x, 1, a.second.x, 1), det(a.first.y, 1, a.second.y, 1), det(b.first.x, 1, b.second.x, 1), det(b.first.y, 1, b.second.y, 1));
    px/= den;
    py/= den;
    CGFloat larger;
    CGFloat smaller;
    if (a.first.x>a.second.x){
        larger = a.first.x;
        smaller = a.second.x;
    }
    else{
        larger = a.second.x;
        smaller = a.first.x;
    }
    if (px< smaller || px > larger)
        return false;
    
    if (a.first.y>a.second.y){
        larger = a.first.y;
        smaller = a.second.y;
    }
    else{
        larger = a.second.y;
        smaller = a.first.y;
    }
    if (py< smaller || py > larger)
        return false;
    
    if (b.first.x>b.second.x){
        larger = b.first.x;
        smaller = b.second.x;
    }
    else{
        larger = b.second.x;
        smaller = b.first.x;
    }
    if (px< smaller || px > larger)
        return false;
    
    if (b.first.y>b.second.y){
        larger = b.first.y;
        smaller = b.second.y;
    }
    else{
        larger = b.second.y;
        smaller = b.first.y;
    }
    if (py<smaller || py > larger)
        return false;
    
    return true;
}
static inline CGFloat det(CGFloat a1, CGFloat a2, CGFloat b1, CGFloat b2){
    return a1*b2-a2*b1;
}
static inline CGFloat resultantVelocity(CGVector vector){
    return sqrtf(powf(vector.dx, 2)+powf(vector.dy, 2));
}

@end

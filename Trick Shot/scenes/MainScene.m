//
//  MainScene.m
//  Circle Test
//
//  Created by Eric Dufresne on 2015-06-26.
//  Copyright (c) 2015 Eric Dufresne. All rights reserved.
//

#import "MainScene.h"
#import "IEDataManager.h"
#import "NewLevelSelectScene.h"
#import "MenuScene.h"
#import "AppDelegate.h"
#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>
#import "Flurry.h"
#import "IEAudioPlayer.h"

#define BASE_DIM_FACTOR 6.4
#define baseWidth self.size.width/BASE_DIM_FACTOR

#define BASE_RADIUS_FACTOR 20.0
#define baseRadius self.size.width/BASE_RADIUS_FACTOR

#define isIpad UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
#define baseVelocity (1.0+(float)(isIpad))*12.0

#define BALL_ARROW_SPACING 15.0
#define MASS_CONSTANT 0.035744
#define DIM_FACTOR_POWERUP 12
#define KEY_THICKNESS_FACTOR 1/35
#define KEY_BUFFER_FACTOR 1/8
#define FIRE_SPEED_MULTIPLIER 1.5
#define GRAVITY_FIRE_MULTIPLIER 2.9
#define TIMEOUT 3.0
#define SNAP_THRESHOLD 2.0
#define noGravity ((self.physicsWorld.gravity.dx == 0) && (self.physicsWorld.gravity.dy == 0))

#define kFilteringFactor 0.1
#define kVelocityMultiplier 600.0
#define EXIT_BTN_DIM 8.5

@interface MainScene (){
    SKSpriteNode *menuList;
    CGFloat storedTheta;
    SKShapeNode *laserPath;
    NSUInteger currentKeys;
    NSTimer *timeOut;
    BOOL tilt;
    double accelX;
    double accelY;
}
@property BOOL contentCreated;
@property BOOL ghost;
@property (strong, nonatomic) SKTexture *dotTexture;
@property (strong, nonatomic) SKSpriteNode *circle;
@property (strong, nonatomic) SKSpriteNode *hole;

@property (strong, nonatomic) SKLabelNode *currentHitLabel;

@property (strong, nonatomic) IEPointSelectionManager *manager;
@property (strong, nonatomic) NSMutableArray *obstacleSprites;
@property (strong, nonatomic) NSMutableArray *pathSprites;
@property (strong, nonatomic) NSMutableArray *sparkTextures;
@property (strong, nonatomic) NSMutableArray *angles;

@property (strong, nonatomic) SKSpriteNode *selectionSprite;
@property (strong, nonatomic) SKShapeNode *dragShape;

@property (assign, nonatomic) NSUInteger currentHits;

@property (strong, nonatomic) CMMotionManager *motionManager;

@property (strong, nonatomic) SKTextureAtlas *popupAtlas;
@property (strong, nonatomic) SKSpriteNode *popup;
@property (strong, nonatomic) SKSpriteNode *blackMask;
@end

@implementation MainScene
@synthesize circle, hole, ghost;
static const uint32_t edgeCategory =        0x1 << 0;
static const uint32_t ballCategory =        0x1 << 1;
static const uint32_t holeCategory =        0x1 << 2;

static const uint32_t noClickCategory =     0x1 << 3;
static const uint32_t solidCategory =       0x1 << 4;
static const uint32_t instaDeathCategory =  0x1 << 5;

static const uint32_t powerupCategory =     0x1 << 6;
static const uint32_t invincibleCategory =  0x1 << 7;

/*All Methods that initially create content for the game */
#pragma mark - Startup
/*Method called when the scene is presented to an SKView. Initializes enums and calls createSceneContent */
-(void)didMoveToView:(SKView *)view{
    if (!self.contentCreated){
        [Flurry logEvent:@"Played Game" withParameters:[NSDictionary dictionaryWithObject:@"Level" forKey:[NSNumber numberWithInteger:self.controller.levelNumber]] timed:YES];
        self.popupAtlas = [SKTextureAtlas atlasNamed:@"dialogue.atlas"];
        self.gameState = GameStatePlacingItems;
        self.menuState = MenuStateHidden;
        self.contentCreated = YES;
        [self createSceneContent];
    }
}

/*Method that is only called once per scene. Initializes all sprites as well as the appearance of the scene and also all data objects that are going to be held in the game */
-(void)createSceneContent{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        IEAudioPlayer *player = [IEAudioPlayer sharedPlayer];
        if (![player isPreloaded:@"powerup.wav"])
            [player preloadSoundWithName:@"powerup.wav" waitForCompletion:NO];
        
        if (![player isPreloaded:@"swoosh.mp3"])
            [player preloadSoundWithName:@"swoosh.mp3" waitForCompletion:NO];
        
        if (![player isPreloaded:@"suction-trimmed.mp3"])
            [player preloadSoundWithName:@"suction-trimmed.mp3" waitForCompletion:NO];
        if (![player isPreloaded:@"beep.mp3"])
            [player preloadSoundWithName:@"beep.mp3" waitForCompletion:NO];
        if (![player isPreloaded:@"shoot.mp3"])
            [player preloadSoundWithName:@"shoot.mp3" waitForCompletion:NO];
    });
    //Manager Initialization
    for (UIGestureRecognizer *recognizer in self.view.gestureRecognizers){
        [self.view removeGestureRecognizer:recognizer];
    }
    self.manager = [[IEPointSelectionManager alloc] init];
    self.manager.delegate = self;
    self.manager.maxDistance = 20;
    self.angles = [NSMutableArray arrayWithObjects:[NSNumber numberWithInt:0], [NSNumber numberWithInt:90], [NSNumber numberWithInt:180], [NSNumber numberWithInt:270],[NSNumber numberWithInt:360], nil];
    
    //Game data and physics world initialization plus contact delegate assignment
    self.currentHits = 0;
    self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
    self.physicsBody.categoryBitMask = edgeCategory;
    self.physicsBody.collisionBitMask = ballCategory;
    self.physicsWorld.contactDelegate = self;
    self.physicsWorld.gravity = CGVectorZero();
    //Background appearance
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    self.backgroundColor = [delegate.arrayOfColors objectAtIndex:self.colorIndex];
    //Ball Shape texture creation. Uses color index of app delegate for appearance
    SKShapeNode *shape = [SKShapeNode shapeNodeWithCircleOfRadius:256];
    shape.fillColor = [SKColor whiteColor];
    if ([delegate hasDarkColorSchemeForIndex:self.colorIndex])
        shape.strokeColor = [SKColor darkGrayColor];
    else
        shape.strokeColor = [SKColor whiteColor];
    shape.antialiased = YES;
    shape.lineWidth = 20;
    //Title message initialization. Message is created and self deletes itselfafter 1.75s. Gets variables from controller
    SKNode *node = [SKNode node];
    node.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    SKLabelNode *firstLine = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    firstLine.text = [NSString stringWithFormat:@"Level %i", (int)self.controller.levelNumber];
    firstLine.fontSize = 30;
    if ([delegate hasDarkColorSchemeForIndex:self.colorIndex])
        firstLine.fontColor = [SKColor darkGrayColor];
    else
        firstLine.fontColor = [SKColor whiteColor];
    firstLine.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    firstLine.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    firstLine.position = CGPointZero;
    [node addChild:firstLine];
    SKLabelNode *secondLine = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    secondLine.text = [NSString stringWithFormat:@"%@", self.controller.levelName];
    secondLine.fontSize = 20;
    if ([delegate hasDarkColorSchemeForIndex:self.colorIndex])
        secondLine.fontColor = [SKColor darkGrayColor];
    else
        secondLine.fontColor = [SKColor whiteColor];
    secondLine.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    secondLine.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    secondLine.position = CGPointMake(0, -firstLine.frame.size.height/2-5-secondLine.frame.size.height/2);
    [node addChild:secondLine];
    [self addChild:node];
    [node runAction:[SKAction sequence:@[[SKAction waitForDuration:1], [SKAction fadeAlphaTo:0 duration:0.75], [SKAction removeFromParent]]]];
    node.zPosition = 10;
    //Menu button initialization in top left corner
    SKSpriteNode *menuButton;
    if ([delegate hasDarkColorSchemeForIndex:self.colorIndex])
        menuButton = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"menu_selected.png"]];
    else
        menuButton = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"menu.png"]];
    menuButton.size = CGSizeMake(25, 25);
    menuButton.position = CGPointMake(menuButton.size.width/2+5, self.size.height-menuButton.size.height/2-5);
    menuButton.name = @"restart";
    menuButton.zPosition = 10;
    [self addChild:menuButton];
    //Current hit label initialization. Position changes depending on the placement of the ball. Color depends on delegate color index
    self.currentHitLabel = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    self.currentHitLabel.text = [NSString stringWithFormat:@"Hits Left: %i", (int)self.controller.starQuantitys.min];
    self.currentHitLabel.fontSize = 16;
    self.currentHitLabel.zPosition = 10;
    if(self.controller.ballLocation != IEObjectLayoutTopRight && self.controller.holeLayout != IEObjectLayoutTopRight)
        self.currentHitLabel.position = CGPointMake(self.size.width-self.currentHitLabel.frame.size.width/2-5, menuButton.position.y);
    else if (self.controller.ballLocation != IEObjectLayoutTop && self.controller.holeLayout != IEObjectLayoutTop)
        self.currentHitLabel.position = CGPointMake(CGRectGetMidX(self.frame), menuButton.position.y);
    else
        self.currentHitLabel.position = CGPointMake(self.currentHitLabel.frame.size.width/2+5, menuButton.position.y);
    
    if ([delegate hasDarkColorSchemeForIndex:self.colorIndex])
        self.currentHitLabel.fontColor = [SKColor darkGrayColor];
    else
        self.currentHitLabel.fontColor = [SKColor whiteColor];
    [self addChild:self.currentHitLabel];
    /*Circle node initialization with physics body. Layout is determined from the controller*/
    SKTexture *texture = [self.view textureFromNode:shape];
    circle = [SKSpriteNode spriteNodeWithTexture:texture];
    circle.size = CGSizeMake(baseRadius*2*self.controller.ballRadius, baseRadius*2*self.controller.ballRadius);
    
    if (self.controller.ballLocation == IEObjectLayoutCustom){
        CGPoint shiftPoint = [delegate getShiftPointForIntegerKey:self.controller.levelNumber ball:YES];
        circle.position = CGPointMake(shiftPoint.x*self.size.width, shiftPoint.y*self.size.height);
    }
    else
        circle.position = [self positionFromLayout:self.controller.ballLocation];
    circle.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:circle.size.width/2];
    circle.physicsBody.linearDamping = 0;
    circle.physicsBody.angularDamping = 0;
    circle.physicsBody.restitution = 1;
    circle.physicsBody.friction = 0;
    circle.physicsBody.dynamic = YES;
    circle.physicsBody.allowsRotation = YES;
    circle.physicsBody.categoryBitMask = ballCategory;
    circle.physicsBody.collisionBitMask = solidCategory;
    circle.physicsBody.contactTestBitMask = edgeCategory | holeCategory | solidCategory;
    circle.physicsBody.mass = MASS_CONSTANT;
    circle.name = @"circle";
    [self addChild:circle];
    /*Arrow on top of node */
    SKSpriteNode *arrow = [[SKSpriteNode alloc] initWithTexture:[SKTexture textureWithImageNamed:@"arrow_light"]];
    arrow.position = CGPointMake(circle.position.x+cosf(self.controller.ballAngle)*(BALL_ARROW_SPACING+circle.size.width/2), circle.position.y+sinf(self.controller.ballAngle)*(BALL_ARROW_SPACING+circle.size.width/2));
    arrow.size = CGSizeMake(13, 11);
    arrow.alpha = 0.4;
    arrow.name = @"arrow";
    arrow.zPosition = 10;
    [arrow runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction fadeAlphaTo:0.7 duration:2], [SKAction fadeAlphaTo:0.4 duration:2]]]]];
    [arrow runAction:[SKAction rotateByAngle:self.controller.ballAngle duration:0]];
    [self addChild:arrow];
    
    [circle runAction:[SKAction rotateByAngle:self.controller.ballAngle duration:0]];
    /*Circle is changed to black to create texture for the hole */
    shape.fillColor = [SKColor blackColor];
    shape.strokeColor = [SKColor blackColor];
    texture = [self.view textureFromNode:shape];
    /*Hole initialization with new texture. Position is determined from the layout from the controller of the hole*/
    hole = [SKSpriteNode spriteNodeWithTexture:texture];
    hole.size = circle.size;
    hole.name = @"hole";
    if (self.controller.holeLayout == IEObjectLayoutCustom){
        AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
        CGPoint shiftPoint = [delegate getShiftPointForIntegerKey:self.controller.levelNumber ball:NO];
        hole.position = CGPointMake(self.size.width*shiftPoint.x, self.size.height*shiftPoint.y);
    }
    else
        hole.position = [self positionFromLayout:self.controller.holeLayout];
    hole.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:hole.size.width/2];
    hole.physicsBody.dynamic = YES;
    hole.physicsBody.affectedByGravity = NO;
    hole.physicsBody.categoryBitMask = holeCategory;
    hole.physicsBody.collisionBitMask = 0x0;
    hole.physicsBody.contactTestBitMask = 0x0;
    [self addChild:hole];
    /*Texture creation for the dot at the end of each created edge to give all edges the rounded look*/
    SKShapeNode *dot = [SKShapeNode shapeNodeWithCircleOfRadius:128];
    dot.fillColor = [SKColor whiteColor];
    dot.strokeColor = dot.fillColor;
    dot.antialiased = YES;
    self.dotTexture = [self.view textureFromNode:dot];
    dot.glowWidth = 2;
    /*Selection sprite is also created from the dot texture but has an added scale pulse action added to it */
    self.selectionSprite = [SKSpriteNode spriteNodeWithTexture:self.dotTexture];
    self.selectionSprite.size = CGSizeMake(5, 5);
    [self.selectionSprite runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction scaleTo:2 duration:1], [SKAction scaleTo:1 duration:1]]]]];
    /*Objects are decoded from the controller and sprites are created from each object point pair. These objects are added, scaled, rotated and then put in the array */
    NSArray *array = self.controller.decodedPairs;
    self.obstacleSprites = [NSMutableArray array];
    self.pathSprites = [NSMutableArray array];
    for (IEObjectPointPair *pair in array){
        SKSpriteNode *sprite = [self obstacleFromPair:pair];
        sprite.position = CGPointMake(self.size.width*pair.shiftPoint.x, self.size.height*pair.shiftPoint.y);
        [self addChild: sprite];
        [self.obstacleSprites addObject:sprite];
        [sprite runAction:[SKAction rotateByAngle:pair.rotation duration:0]];
    }
    for (IECustomPath *path in self.controller.decodedPaths){
        SKShapeNode *sprite = [self obstacleFromPath:path];
        [self addChild:sprite];
        [self.pathSprites addObject:sprite];
    }
    NSDictionary *powerupKeys = [[IEDataManager sharedManager] powerupMap];
    currentKeys = 0;
    IEPowerupType *type = NULL;
    for (IEPowerup *powerup in self.controller.decodedPowerups){
        if (powerup.powerupType == IEPowerupKey)
            currentKeys++;
        powerup.position = CGPointMake(self.size.width*powerup.shiftPoint.x, self.size.height*powerup.shiftPoint.y);
        powerup.size = CGSizeMake(self.size.width/DIM_FACTOR_POWERUP, self.size.width/DIM_FACTOR_POWERUP);
        powerup.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:powerup.size];
        powerup.physicsBody.affectedByGravity = NO;
        powerup.physicsBody.categoryBitMask = powerupCategory;
        powerup.physicsBody.collisionBitMask = 0x0;
        powerup.physicsBody.contactTestBitMask = ballCategory;
        powerup.physicsBody.fieldBitMask = 0x0;
        [powerup runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction scaleTo:1.15 duration:1], [SKAction scaleTo:1 duration:1]]]]];
        [self addChild:powerup];
        NSNumber *number = [powerupKeys objectForKey:[IEDataManager keyForPowerupType:powerup.powerupType]];
        if (!number.boolValue && type == NULL){
            IEPowerupType val = powerup.powerupType;
            type = &val;
        }
    }
    if (currentKeys != 0)
        [self setupKeys];
    if (type!=NULL){
        self.popup = [self createPopUpWithType:*type];
        self.blackMask = [SKSpriteNode spriteNodeWithColor:[SKColor blackColor] size:self.size];
        self.blackMask.alpha = 0;
        self.blackMask.position = CGPointMake(self.size.width/2, self.size.height/2);
        self.blackMask.zPosition = 100;
        self.popup.zPosition = 101;
        [self addChild:self.blackMask];
        [self addChild:self.popup];
        
        [self.popup runAction:[SKAction moveToY:self.size.height/2 duration:0.125]];
        [self.blackMask runAction:[SKAction fadeAlphaTo:0.5 duration:0.25]];
        [[IEDataManager sharedManager] viewedPowerup:*type];
    }
}
-(void)dismissPopup{
    [self.blackMask runAction:[SKAction fadeAlphaTo:0 duration:0.25]];
    [self.popup runAction:[SKAction moveToY:-self.popup.size.height/2 duration:0.125]];
    [self.blackMask runAction:[SKAction sequence:@[[SKAction fadeAlphaTo:0 duration:0.25], [SKAction runBlock:^{
        [self.blackMask removeFromParent];
        self.blackMask = nil;
    }]]]];
    [self.popup runAction:[SKAction sequence:@[[SKAction moveToY:-self.popup.size.height/2 duration:0.125], [SKAction runBlock:^{
        [self.popup removeFromParent];
        self.popup = nil;
    }]]]];
}
-(void)setupKeys{
    for (int k = 0;k<currentKeys;k++){
        const CGFloat thickness = self.hole.size.width*KEY_THICKNESS_FACTOR;
        const CGFloat buffer = self.hole.size.width*KEY_BUFFER_FACTOR;
        UIBezierPath *path = [UIBezierPath bezierPath];
        CGFloat innerRadius = self.hole.size.width/2+buffer*(k+1)+thickness*k;
        CGFloat outerRadius = innerRadius+thickness;
        [path moveToPoint:CGPointMake(-outerRadius*4, 0)];
        [path addArcWithCenter:CGPointZero radius:outerRadius*4 startAngle:M_PI endAngle:0 clockwise:NO];
        [path addArcWithCenter:CGPointZero radius:outerRadius*4 startAngle:0 endAngle:M_PI clockwise:NO];
        [path addLineToPoint:CGPointMake(-innerRadius*4, 0)];
        [path addArcWithCenter:CGPointZero radius:innerRadius*4 startAngle:M_PI endAngle:0 clockwise:YES];
        [path addArcWithCenter:CGPointZero radius:innerRadius*4 startAngle:0 endAngle:M_PI clockwise:YES];
        [path closePath];
        
        SKShapeNode *shape = [SKShapeNode shapeNodeWithPath:path.CGPath centered:YES];
        shape.fillColor = [SKColor whiteColor];
        shape.strokeColor = [SKColor whiteColor];
        
        SKSpriteNode *key = [SKSpriteNode spriteNodeWithTexture:[self.view textureFromNode:shape]];
        key.position = CGPointZero;
        key.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:key.size.width/2];
        key.physicsBody.categoryBitMask = edgeCategory;
        key.physicsBody.collisionBitMask = ballCategory;
        key.physicsBody.contactTestBitMask = 0x0;
        [key runAction: [SKAction scaleBy:0.25 duration:0]];
        [self.hole addChild:key];
    }
}

/*Event listeners for in game events. These are for all touches, touch pull offs, and touch movement as well as contact between objects in game */
#pragma mark - Event Listeners
/*Registers collisions between object and does various code depending on what category bit mask the two bodies have. If the ball is in a moving state this method detects its collisions with all walls and edges to decrease the hit amount as well as the hole. Also if the player is making edges it detects if an edge intersects an obstacle and the edge is deleted */
-(void)printDebug:(SKPhysicsContact*)contact{
    NSString *string;
    switch (contact.bodyA.categoryBitMask) {
        case edgeCategory:
            string = @"EdgeCategory";
            break;
        case solidCategory:
            string = @"SoldCategory";
            break;
        case ballCategory:
            string  = @"BallCategory";
            break;
        case holeCategory:
            string = @"HoleCategory";
            break;
        case instaDeathCategory:
            string = @"InstaDeathCategory";
            break;
        case powerupCategory:
            string = @"PowerupCategory";
            break;
        case invincibleCategory:
            string = @"InvincibleCategory";
            break;
        default:
            string = @"";
            break;
    }
    NSString *string2;
    switch (contact.bodyB.categoryBitMask){
        case edgeCategory:
            string2 = @"EdgeCategory";
            break;
        case solidCategory:
            string2 = @"SoldCategory";
            break;
        case ballCategory:
            string2  = @"BallCategory";
            break;
        case holeCategory:
            string2 = @"HoleCategory";
            break;
        case instaDeathCategory:
            string2 = @"InstaDeathCategory";
            break;
        case powerupCategory:
            string2 = @"PowerupCategory";
            break;
        case invincibleCategory:
            string2 = @"InvincibleCategory";
            break;
        default:
            string2 = @"";
            break;
    }
    string = [NSString stringWithFormat:@"%@ w %@", string, string2];
    NSLog(@"%@", string);
}
-(void)didBeginContact:(SKPhysicsContact *)contact{
    if (self.gameState == GameStateBallMoving){
        if (contact.bodyA.categoryBitMask == instaDeathCategory || contact.bodyB.categoryBitMask == instaDeathCategory){
            if ([contact.bodyA.node isEqualToNode:self.circle]||[contact.bodyB.node isEqualToNode:self.circle]){
                self.currentHitLabel.fontColor = [SKColor redColor];
                self.gameState = GameStateLost;
                self.circle.physicsBody.contactTestBitMask = 0x0;
                [self.circle runAction:[SKAction sequence:@[[SKAction scaleTo:0 duration:0.25], [SKAction removeFromParent]]]];
                [self handleEndingState];
            }
        }
        else if (contact.bodyA.categoryBitMask == powerupCategory || contact.bodyB.categoryBitMask == powerupCategory){
            IEAudioPlayer *player = [IEAudioPlayer sharedPlayer];
            [self runAction:[player soundActionWithname:@"powerup.wav"]];
            IEPowerup *powerup;
            if (contact.bodyA.categoryBitMask == powerupCategory)
                powerup = (IEPowerup*)contact.bodyA.node;
            else
                powerup = (IEPowerup*)contact.bodyB.node;
            powerup.physicsBody = nil;
            IEPowerupType type = powerup.powerupType;
            if (type == IEPowerupAimAndFire){
                tilt = NO;
                if (self.motionManager){
                    [self.motionManager stopAccelerometerUpdates];
                    self.motionManager = nil;
                }
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
                    self.gameState = GameStateBallMoving;
                    CGFloat speed;
                    if (noGravity)
                        speed = baseVelocity * FIRE_SPEED_MULTIPLIER;
                    else
                        speed = baseVelocity * GRAVITY_FIRE_MULTIPLIER;
                    [self.circle.physicsBody applyImpulse:createAngledVector(speed, storedTheta)];
                    self.circle.physicsBody.affectedByGravity = YES;
                    [self runAction:[[IEAudioPlayer sharedPlayer] soundActionWithname:@"swoosh.mp3"]];
                }]]]];
                SKAction *playSound = [[IEAudioPlayer sharedPlayer] soundActionWithname:@"beep.mp3"];
                SKAction *shootSound = [[IEAudioPlayer sharedPlayer] soundActionWithname:@"shoot.mp3"];
                SKAction *firstAction = [SKAction repeatAction:[SKAction sequence:@[[SKAction waitForDuration:0.5], playSound]] count:4];
                [self runAction:[SKAction sequence:@[firstAction,shootSound]]];
            }
            else if (type == IEPowerupGhost){
                
                if (!ghost){
                    ghost = YES;
                    self.circle.alpha = 0.5;
                    self.circle.physicsBody.collisionBitMask = edgeCategory | noClickCategory;
                    self.circle.physicsBody.contactTestBitMask = noClickCategory | edgeCategory | holeCategory;
                }
                else{
                    ghost = NO;
                    self.circle.alpha = 1;
                    self.circle.physicsBody.collisionBitMask = edgeCategory | solidCategory;
                    self.circle.physicsBody.contactTestBitMask = edgeCategory | solidCategory | holeCategory;
                }
                
            }
            else if (type == IEPowerupGravity){
                tilt = NO;
                if (self.motionManager){
                    [self.motionManager stopAccelerometerUpdates];
                    self.motionManager = nil;
                }
                
                self.physicsBody.friction = 0.2;
                self.physicsBody.restitution = 0.2;
                
                self.circle.physicsBody.restitution = 0.2;
                self.circle.physicsBody.friction = 0.2;
                self.circle.physicsBody.linearDamping = 0.1;
                self.physicsWorld.gravity = CGVectorMake(9.8*cosf(powerup.zRotation+M_PI*3/2), 9.8*sinf(powerup.zRotation+M_PI*3/2));
                for (SKShapeNode *path in self.pathSprites){
                    path.physicsBody.restitution = 0.2;
                    path.physicsBody.friction = 0.2;
                }
                for (SKSpriteNode *obstacle in self.obstacleSprites){
                    obstacle.physicsBody.restitution = 0.2;
                    obstacle.physicsBody.friction = 0.2;
                }
                for (IEPointPair *pair in self.manager.connections){
                    SKNode *node = pair.dot1;
                    node.physicsBody.restitution = 0.2;
                    node.physicsBody.friction = 0.2;
                }
                self.currentHitLabel.text = @"Hits Left: --";
                
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
            else if (type == IEPowerupKey){
                SKSpriteNode *sprite;
                for (SKSpriteNode *temp in self.hole.children){
                    if(![temp.name isEqualToString:@"removed"])
                        sprite = temp;
                }
                if (sprite == nil)
                    return;
                
                sprite.name = @"removed";
                sprite.physicsBody = nil;
                [sprite runAction:[SKAction sequence:@[[SKAction fadeAlphaTo:0 duration:0.25], [SKAction removeFromParent]]]];
                currentKeys--;
            }
            else if (type == IEPowerupNegateHits){
                self.currentHits = self.controller.starQuantitys.min;
                self.currentHitLabel.text = [NSString stringWithFormat:@"%i", (int)self.currentHits];
            }
            else if (type == IEPowerupSmaller){
                self.controller.ballRadius /=2;
                self.circle.xScale /=2;
                self.circle.yScale /=2;
            }
            else if (type == IEPowerupTilt){
                tilt = YES;
                self.physicsBody.friction = 0.2;
                self.physicsBody.restitution = 0.2;
                self.circle.physicsBody.restitution = 0;
                self.circle.physicsBody.friction = 0.2;
                self.circle.physicsBody.linearDamping = 0.3;
                for (SKShapeNode *path in self.pathSprites){
                    path.physicsBody.restitution = 0.2;
                    path.physicsBody.friction = 0.2;
                }
                for (SKSpriteNode *obstacle in self.obstacleSprites){
                    obstacle.physicsBody.restitution = 0.2;
                    obstacle.physicsBody.friction = 0.2;
                }
                NSMutableArray *array = [NSMutableArray arrayWithArray:self.manager.connections];
                for (IEPointPair *pair in array){
                    [self.manager removePair:pair];
                }
                self.currentHitLabel.text = @"Hits Left: --";
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
            [powerup runAction:[SKAction sequence:@[[SKAction group:@[[SKAction fadeAlphaTo:0 duration:1], [SKAction scaleTo:1.4 duration:1]]], [SKAction removeFromParent]]]];
        }
        else if (contact.bodyA.categoryBitMask == holeCategory || contact.bodyB.categoryBitMask == holeCategory){
            IEAudioPlayer *player = [IEAudioPlayer sharedPlayer];
            [self runAction:[player soundActionWithname:@"suction-trimmed.mp3"]];
            // This is when the hole and the ball collide. The game is won and the black ball is scaled down and removed while the sphere is scaled up. this ending state is also handled by the same method
            self.gameState = GameStateWon;
            self.circle.physicsBody.contactTestBitMask = 0x0;
            [self.circle runAction:[SKAction sequence:@[[SKAction scaleTo:1 duration:0.214], [SKAction scaleBy:1.4 duration:0.0857]]]];
            [self.hole runAction:[SKAction sequence:@[[SKAction scaleTo:0 duration:0.3], [SKAction removeFromParent]]]];
            [self handleEndingState];
        }
        else{
            //Bounces off any non hole object. Changes label
            
            if (noGravity&& !tilt){
                IEAudioPlayer *player = [IEAudioPlayer sharedPlayer];
                [self runAction:[player soundActionWithname:@"tick.mp3"]];
                self.currentHits++;
                self.currentHitLabel.text = [NSString stringWithFormat:@"Hits Left: %i", (int)(self.controller.starQuantitys.min-self.currentHits)];
            }
            
            if (self.currentHits>self.controller.starQuantitys.min){
                //If the number of hits is below the minimum for the level the game is lost and the ending state is handled by handleEndingState method
                self.currentHitLabel.fontColor = [SKColor redColor];
                self.gameState = GameStateLost;
                self.circle.physicsBody.contactTestBitMask = 0x0;
                [self.circle runAction:[SKAction sequence:@[[SKAction scaleTo:0 duration:0.25], [SKAction removeFromParent]]]];
                [self handleEndingState];
                return;
            }
            // Decreases the size of the sphere every hit //
            [self.circle runAction:[SKAction scaleTo:1-((float)self.currentHits/((float)self.controller.starQuantitys.min+1)) duration:0.25]];
        }
        
    }
    else if (self.gameState == GameStatePlacingItems){
        //Intersection between an obstacle and a created edge has occured and is deleted after the edge turns red and fades away. The created connection is removed from the manager
        if (contact.bodyA.categoryBitMask == edgeCategory || contact.bodyA.categoryBitMask == noClickCategory){
            SKNode *node;
            if (contact.bodyA.categoryBitMask == edgeCategory)
                node = contact.bodyA.node;
            else
                node = contact.bodyB.node;
            
            IEPointPair *pair;
            for (IEPointPair *object in self.manager.connections){
                if ([object.dot1 isEqualToNode:node]||[object.dot2 isEqualToNode:node]){
                    pair = object;
                    break;
                }
            }
            
            pair.edgeShape.fillColor = [SKColor redColor];
            pair.edgeShape.strokeColor = [SKColor redColor];
            pair.dot1.physicsBody = nil;
            [pair.dot1 runAction:[SKAction colorizeWithColor:[SKColor redColor] colorBlendFactor:1 duration:1]];
            SKAction *fade = [SKAction sequence:@[[SKAction fadeAlphaTo:0 duration:1], [SKAction removeFromParent]]];
            [pair.edgeShape runAction:fade];
            [pair.dot1 runAction:fade];
            [pair.dot2 runAction:fade];
            [self.manager.connections removeObject:pair];
        }
    }
}
-(void)update:(NSTimeInterval)currentTime{
    if (!noGravity && !timeOut.valid && timeOut == nil && fabs(self.circle.physicsBody.velocity.dx) <= 0.25 && fabs(self.circle.physicsBody.velocity.dy) <= 0.25 && self.gameState == GameStateBallMoving &&!tilt){
        timeOut = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(checkTimeout) userInfo:nil repeats:NO];
    }
}
-(void)checkTimeout{
    CGFloat dx = fabs(self.circle.physicsBody.velocity.dx);
    CGFloat dy = fabs(self.circle.physicsBody.velocity.dy);
    if (dx <= 0.1 && dy <= 0.1 && self.gameState == GameStateBallMoving){
        self.gameState = GameStateLost;
        self.circle.physicsBody.categoryBitMask = 0x0;
        self.currentHitLabel.fontColor = [SKColor redColor];
        [self handleEndingState];
    }
    [timeOut invalidate];
    timeOut = nil;
}

/*Registers the start of any touch. Handles almost all touch events. If the touch is on the menu button the contentList is shown if the menu is not already showing or the game is not over. If the circle is pressed the gameState changes and an impulse is added to the ball. If the touch does not fall on these a new selected point is created and a drag shape is created to that point for possible drag edge creation. */
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    SKNode *node = [self nodeAtPoint:location];
    [self touchAnimationAtPoint:location];
    if (self.popup && !CGRectContainsPoint(self.popup.frame, location)){
        [self dismissPopup];
    }
    if ([node.name isEqualToString:@"restart"]&&!(self.gameState == GameStateLost||self.gameState == GameStateWon)&&self.menuState==MenuStateHidden){
        // Menu button clicked
        [self showContentList];
        return;
    }
    else if (self.menuState == MenuStateShowing&&!CGRectContainsPoint(menuList.frame, location)){
        //Touch on game screen not on menu. menu is hidden
        [self hideContentList];
        return;
    }
    if (self.gameState == GameStateWaitingForTouch && self.menuState != MenuStateShowing){
        CGFloat distance = sqrtf(powf(self.size.width/2, 2)+powf(self.size.height/2, 2));
        storedTheta = getAbsoluteAngle(self.circle.position, location);
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(self.circle.position.x, self.circle.position.y)];
        
        [path addLineToPoint:CGPointMake(self.circle.position.x+distance*cosf(storedTheta), self.circle.position.y+distance*sinf(storedTheta))];
        laserPath.path = path.CGPath;
        return;
    }
    else if (self.gameState == GameStatePlacingItems &&self.menuState != MenuStateShowing){
        CGFloat distance = distanceFromPointToPoint(location, self.circle.position);
        if (distance<self.circle.size.width/2+self.manager.maxDistance){
            //Makes all obstacles not dynamic to avoid movement from collisions. The arrow is removed from the sphere and any selected point without a pair is removed and the game state is changed
            for (SKSpriteNode *sprite in self.obstacleSprites){
                sprite.physicsBody.dynamic = NO;
            }
            for (SKShapeNode *sprite in self.pathSprites){
                sprite.physicsBody.dynamic = NO;
            }
            for (SKNode *node in self.hole.children){
                node.physicsBody.dynamic = NO;
            }
            circle.physicsBody.collisionBitMask = edgeCategory | solidCategory;
            [circle.physicsBody applyImpulse:createAngledVector(baseVelocity,self.controller.ballAngle)];
            SKNode *label = [self childNodeWithName:@"titleLabel"];
            [label removeFromParent];
            SKNode *arrow = [self childNodeWithName:@"arrow"];
            [arrow removeFromParent];
            if (self.selectionSprite)
                [self.selectionSprite runAction:[SKAction sequence:@[[SKAction fadeAlphaTo:0 duration:1], [SKAction removeFromParent]]]];
            
            self.gameState = GameStateBallMoving;
            [self runAction:[[IEAudioPlayer sharedPlayer] soundActionWithname:@"swoosh.mp3"]];
            return;
        }
        else if (!self.dragShape&&![node.name isEqualToString:@"hole"]){
            // Point selection that is not on the hole node. Does not bypass deletion of another edge. If the distance is far away from all edges creates a selection point
            SKNode *menu = [self childNodeWithName:@"restart"];
            CGFloat distance = distanceFromPointToPoint(menu.position, location);
            if (distance<self.manager.maxDistance+menu.frame.size.width/2)
                [self showContentList];
            else
                [self.manager selectPoint:location pressed:YES];
        }
        // Touch circle animation that happens on all game touches
    }
}

/*Registers touch movement. During the edge placing the user can drag their finger to another area to create a new node */
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    if (self.gameState == GameStatePlacingItems&&self.menuState == MenuStateHidden){
        int degrees = (int)roundf(radToDeg(getAngleFromHorizontal(self.manager.firstTouch, location)));
        float distance = distanceFromPointToPoint(self.manager.firstTouch, location);
        NSNumber *n = nil;
        int closestDistance = SNAP_THRESHOLD;
        for (NSNumber *number in self.angles){
            int value = number.intValue;
            if (abs(value-degrees)<closestDistance){
                closestDistance = abs(value-degrees);
                n = number;
            }
        }
        if (n){
            float newTheta = n.floatValue;
            newTheta *= M_PI/180.0;
            location = CGPointMake(self.manager.firstTouch.x+distance*cosf(newTheta), self.manager.firstTouch.y+distance*sinf(newTheta));
        }
        if (!self.dragShape&&self.manager.inTouch){
            //If the drag shape has not been created adn the manager has a selection it is initialized.
            self.dragShape = [SKShapeNode node];
            self.dragShape.strokeColor = [SKColor whiteColor];
            self.dragShape.glowWidth = 2;
            [self addChild:self.dragShape];
        }
        // The drag shape has been already created so its path changes to the current touch of the user.
        CGMutablePathRef pathToDraw = CGPathCreateMutable();
        CGPathMoveToPoint(pathToDraw, NULL, self.manager.firstTouch.x , self.manager.firstTouch.y);
        CGPathAddLineToPoint(pathToDraw, NULL, location.x, location.y);
        self.dragShape.path = pathToDraw;
    }
    else if (self.gameState == GameStateWaitingForTouch && self.menuState == MenuStateHidden){
        CGFloat distance = sqrtf(powf(self.size.width/2, 2)+powf(self.size.height/2, 2));
        storedTheta = getAbsoluteAngle(self.circle.position, location);
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(self.circle.position.x, self.circle.position.y)];
        
        [path addLineToPoint:CGPointMake(self.circle.position.x+distance*cosf(storedTheta), self.circle.position.y+distance*sinf(storedTheta))];
        laserPath.path = path.CGPath;
    }
}

/*Goes along with touchesMoved. This is called after the end of the user drag to create a new connection.*/
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    if (self.gameState == GameStatePlacingItems&&self.menuState!=MenuStateShowing){
        UITouch *touch = [touches anyObject];
        CGPoint location = [touch locationInNode:self];
        if (self.dragShape){
            [self.dragShape removeFromParent];
            self.dragShape = nil;
        }
        int degrees = (int)roundf(radToDeg(getAngleFromHorizontal(self.manager.firstTouch, location)));
        float distance = distanceFromPointToPoint(self.manager.firstTouch, location);
        
        NSNumber *n = nil;
        int clostestDistance = SNAP_THRESHOLD;
        for (NSNumber *number in self.angles){
            int value = number.intValue;
            if (abs(value-degrees)<clostestDistance){
                clostestDistance = abs(value-degrees);
                n = number;
            }
        }
        if (n){
            float newTheta = n.floatValue;
            newTheta *= M_PI/180.0;
            location = CGPointMake(self.manager.firstTouch.x+distance*cosf(newTheta), self.manager.firstTouch.y+distance*sinf(newTheta));
        }
        else{
            float newTheta = (float)degrees;
            newTheta *= M_PI/180.0;
            location = CGPointMake(self.manager.firstTouch.x+distance*cosf(newTheta), self.manager.firstTouch.y+distance*sinf(newTheta));
        }
        [self.manager selectPoint:location pressed:NO];
    }
}

/* Methods for doing repeatitive tasks on the scene. This includes showing and hidng the menu and handling a win or a loss */
#pragma mark - View Manager Methods
-(SKSpriteNode*)createPopUpWithType:(IEPowerupType)type{
        SKTexture *texture;
        if (type == IEPowerupAimAndFire)
            texture = [self.popupAtlas textureNamed:@"dialogue_aimandfire"];
        else if (type == IEPowerupGhost)
            texture = [self.popupAtlas textureNamed:@"dialogue_ghost"];
        else if (type == IEPowerupGravity)
            texture = [self.popupAtlas textureNamed:@"dialogue_gravity"];
        else if (type == IEPowerupKey)
            texture = [self.popupAtlas textureNamed:@"dialogue_key"];
        else if (type == IEPowerupTilt)
            texture = [self.popupAtlas  textureNamed:@"dialogue_tilt"];
        else
            texture = [self.popupAtlas textureNamed:@"dialogue_immunity"];
        SKSpriteNode *spriteNode = [SKSpriteNode spriteNodeWithTexture:texture];
        //Insert specific popup for specific type
        spriteNode.size = CGSizeMake(self.size.width*3/4, self.size.width/2);
        spriteNode.position = CGPointMake(self.size.width/2, -spriteNode.size.height/2);
        SKTexture *exitTexture = [SKTexture textureWithImageNamed:@"exit_button"];
        IETextureButton *exitButton = [IETextureButton buttonWithDefaultTexture:exitTexture selectedTexture:exitTexture];
        exitButton.delegate = self;
        exitButton.size = CGSizeMake(spriteNode.size.height/EXIT_BTN_DIM, spriteNode.size.height/EXIT_BTN_DIM);
        exitButton.name = @"exitButton";
        exitButton.position = CGPointMake(-spriteNode.size.width/2+exitButton.size.width/2, spriteNode.size.height/2-exitButton.size.height/2);
        [spriteNode addChild:exitButton];
        return spriteNode;
}
/*Shows menu if the menu is not showing from the left of the screen */
-(void)showContentList{
    static BOOL initialized = NO;
    //Only initalizes the menu once using a static boolean
    if (!initialized){
        menuList = [SKSpriteNode spriteNodeWithColor:[MainScene colorWithR:53 G:53 B:53] size:CGSizeMake(self.size.width/5, self.size.height)];
        menuList.anchorPoint = CGPointZero;
        menuList.alpha = 0.5;
        menuList.position = CGPointMake(-menuList.size.width, 0);
        
        IETextureButton *restart = [IETextureButton buttonWithDefaultTexture:[SKTexture textureWithImageNamed:@"restart.png"] selectedTexture:[SKTexture textureWithImageNamed:@"restart_selected.png"]];
        restart.name = @"restartButton";
        restart.size = CGSizeMake(menuList.size.width*3/4, menuList.size.width*3/4);
        restart.delegate = self;
        restart.position = CGPointMake(menuList.size.width/2, menuList.size.height*3/4);
        restart.alpha = 2;
        [menuList addChild:restart];
        
        IETextureButton *levelSelect = [IETextureButton buttonWithDefaultTexture:[SKTexture textureWithImageNamed:@"level.png"] selectedTexture:[SKTexture textureWithImageNamed:@"level_selected.png"]];
        levelSelect.name = @"levelSelectButton";
        levelSelect.size = CGSizeMake(menuList.size.width*3/4, menuList.size.width*3/4);
        levelSelect.delegate = self;
        levelSelect.position = CGPointMake(menuList.size.width/2, menuList.size.height/2);
        levelSelect.alpha = 2;
        [menuList addChild:levelSelect];
        
        IETextureButton *menuButton = [IETextureButton buttonWithDefaultTexture:[SKTexture textureWithImageNamed:@"menu.png"] selectedTexture:[SKTexture textureWithImageNamed:@"menu_selected.png"]];
        menuButton.name = @"mainMenuButton";
        menuButton.size = levelSelect.size;
        menuButton.delegate = self;
        menuButton.position = CGPointMake(levelSelect.position.x, menuList.size.height*1/4);
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
/*Hides the content list from the view */
-(void)hideContentList{
    if (menuList){
        self.menuState = MenuStateHidden;
        [menuList runAction:[SKAction moveByX:-menuList.size.width y:0 duration:0.25]];
    }
}
/*Called after the gameState has been changed to winning or loosing. Certain tasks are done depending on the outcome */
-(void)handleEndingState{
    [self hideContentList];
    if (self.motionManager){
        [self.motionManager stopAccelerometerUpdates];
        self.motionManager = nil;
    }
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    if (!delegate.adsRemoved)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"showInterstitial" object:nil];
    
    SKSpriteNode *black = [SKSpriteNode spriteNodeWithColor:[MainScene colorWithR:54 G:54 B:54] size:self.size];
    black.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    black.alpha = 0;
    [self addChild:black];
    [black runAction:[SKAction fadeAlphaTo:0.5 duration:0.25]];
    SKLabelNode *label = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    label.fontSize = 35;
    label.fontColor = [SKColor whiteColor];
    label.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    label.alpha = 0;
    [self addChild:label];
    [label runAction:[SKAction fadeAlphaTo:1 duration:0.25]];
    
    IELabelButton *nextLevel;
    if (self.controller.levelNumber<[IEDataManager sharedManager].localLevelCount&&self.gameState == GameStateWon){
        nextLevel = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:[SKColor whiteColor] selectedColor:[SKColor lightGrayColor]];
        nextLevel.fontSize = 26;
        nextLevel.name = @"nextLevelButton";
        nextLevel.text = @"Next Level";
        nextLevel.alpha = 0;
        nextLevel.delegate = self;
        nextLevel.position = CGPointMake(CGRectGetMidX(self.frame), label.position.y-nextLevel.frame.size.height-20);
        [self addChild:nextLevel];
        [nextLevel runAction:[SKAction fadeAlphaTo:1 duration:0.25]];
    }
    else if (self.gameState == GameStateLost){
        nextLevel = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:[SKColor whiteColor] selectedColor:[SKColor lightGrayColor]];
        nextLevel.fontSize = 26;
        nextLevel.name = @"restartButton";
        nextLevel.text = @"Try Again";
        nextLevel.alpha = 0;
        nextLevel.delegate = self;
        nextLevel.position = CGPointMake(CGRectGetMidX(self.frame), label.position.y-nextLevel.frame.size.height-20);
        [self addChild:nextLevel];
        [nextLevel runAction:[SKAction fadeAlphaTo:1 duration:0.25]];
    }
    IELabelButton *levelSelect = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:[SKColor whiteColor] selectedColor:[SKColor lightGrayColor]];
    levelSelect.fontSize = 26;
    levelSelect.name = @"levelSelectButton";
    levelSelect.text = @"Level Select";
    levelSelect.alpha = 0;
    levelSelect.delegate = self;
    if (nextLevel)
        levelSelect.position = CGPointMake(CGRectGetMidX(self.frame), nextLevel.position.y-levelSelect.frame.size.height-20);
    else
        levelSelect.position = CGPointMake(CGRectGetMidX(self.frame), label.position.y-levelSelect.frame.size.height-20);
    [self addChild:levelSelect];
    [levelSelect runAction:[SKAction fadeAlphaTo:1 duration:0.25]];
    
    IELabelButton *mainMenu = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:[SKColor whiteColor] selectedColor:[SKColor lightGrayColor]];
    mainMenu.fontSize = 26;
    mainMenu.name = @"mainMenuButton";
    mainMenu.text = @"Main Menu";
    mainMenu.alpha = 0;
    mainMenu.delegate = self;
    mainMenu.position = CGPointMake(CGRectGetMidX(self.frame), levelSelect.position.y-mainMenu.frame.size.height-20);
    [self addChild:mainMenu];
    [mainMenu runAction:[SKAction fadeAlphaTo:1 duration:0.25]];
    
    
    NSMutableArray *starArray = [NSMutableArray array];
    if (self.gameState == GameStateWon){
        NSInteger stars = 1;
        if(self.currentHits<=self.controller.starQuantitys.threeStars)
            stars = 3;
        else if (self.currentHits<=self.controller.starQuantitys.twoStars)
            stars = 2;
        [Flurry endTimedEvent:@"Played Game" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"Level", [NSNumber numberWithInteger:self.controller.levelNumber], @"Stars", [NSNumber numberWithInteger:stars], @"Did Exit", [NSNumber numberWithBool:NO], nil]];
        IEDataManager *manager = [IEDataManager sharedManager];
        [manager completedLevel:self.controller.levelNumber withStars:stars];
        label.text = [NSString stringWithFormat:@"Level: %i Completed!", (int)self.controller.levelNumber];
        if (stars == 1){
            SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"star.png"]];
            star.size = CGSizeMake(75, 75);
            star.position = CGPointMake(CGRectGetMidX(self.frame), self.size.height+star.size.height/2);
            [starArray addObject:star];
        }
        else if (stars == 2){
            SKSpriteNode *star1 = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"star.png"]];
            star1.size = CGSizeMake(75, 75);
            star1.position = CGPointMake(CGRectGetMidX(self.frame)-star1.size.width/2-10, self.size.height+star1.size.height/2);
            [starArray addObject:star1];
            
            SKSpriteNode *star2 = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"star.png"]];
            star2.size = star1.size;
            star2.position = CGPointMake(CGRectGetMidX(self.frame)+star2.size.width/2+10, star1.position.y);
            [starArray addObject:star2];
        }
        else{
            for (int k = 0;k<stars;k++){
                SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"star.png"]];
                star.size = CGSizeMake(75, 75);
                if (k == 0)
                    star.position = CGPointMake(CGRectGetMidX(self.frame)-star.size.width-20, self.size.height+star.size.height/2);
                else if (k == 1)
                    star.position = CGPointMake(CGRectGetMidX(self.frame), self.size.height+star.size.height/2);
                else
                    star.position = CGPointMake(CGRectGetMidX(self.frame)+star.size.width+20, self.size.height+star.size.height/2);
                [starArray addObject:star];
            }
        }
        for (int k = 0;k<starArray.count;k++){
            SKSpriteNode *sprite = (SKSpriteNode*)[starArray objectAtIndex:k];
            [self addChild:sprite];
            [sprite runAction:[SKAction sequence:@[[SKAction waitForDuration:0.5+0.25*k], [SKAction moveByX:0 y:-sprite.size.height/2-self.size.height*1/4 duration:0.25]]]];
        }
        SKAction *swoosh = [[IEAudioPlayer sharedPlayer] soundActionWithname:@"swoosh.mp3"];
        [self runAction:[SKAction sequence:@[[SKAction waitForDuration:0.5], [SKAction repeatAction:[SKAction sequence:@[swoosh, [SKAction waitForDuration:0.25]]] count:starArray.count]]]];
    }
    else
        [Flurry endTimedEvent:@"Played Game" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"Level", [NSNumber numberWithInteger:self.controller.levelNumber], @"Stars", [NSNumber numberWithInteger:0], @"Exited", [NSNumber numberWithBool:NO], nil]];
}

/*Selection Manager delegate calls methods on user point selection and connection creation */
#pragma mark - Selection Manager Delegate
/* Called when new point is made on a screen with no other point to pair */
-(void)selectedNewPoint:(CGPoint)point{
    self.selectionSprite.position = point;
    if (!self.selectionSprite.parent&&self.manager.inTouch)
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
    dot1.physicsBody.contactTestBitMask = ballCategory | edgeCategory | solidCategory | noClickCategory;
    dot1.physicsBody.friction = 0;
    dot1.physicsBody.restitution = 1;
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
    
    int degrees = (int)roundf(radToDeg(getAngleFromHorizontal(pair.first, pair.second)));
    if (degrees%90!=0)
        [self.angles addObject:[NSNumber numberWithInt:degrees]];
}
/* Connection that was created before has been removed by the user */
-(void)didRemoveConnection:(IEPointPair *)pair{
    [self.selectionSprite removeFromParent];
    SKAction *fadeAction = [SKAction sequence:@[[SKAction fadeAlphaTo:0 duration:0.25], [SKAction removeFromParent]]];
    [pair.dot1 runAction:fadeAction];
    [pair.dot2 runAction:fadeAction];
    [pair.edgeShape runAction:fadeAction];
    
    int degrees = (int)roundf(radToDeg(getAngleFromHorizontal(pair.dot1.position, pair.dot2.position)));
    NSMutableArray *array = [NSMutableArray array];
    for (NSNumber *number in self.angles){
        BOOL contains = NO;
        for (NSNumber *n in array){
            if (n.intValue == number.intValue){
                contains = YES;
                break;
            }
        }
        if (number.intValue == degrees && number.intValue%90 != 0 && !contains){
            [array addObject:number];
        }
    }
    [self.angles removeObjectsInArray:array];
}

#pragma mark - IEButton Delegate
/*When any button was pressed by the user. Passes the id of the button */
-(void)buttonWasPressed:(id)button{
    IETextureButton *node = (IETextureButton*)button;
    if (self.popup && [node.name isEqualToString:@"exitButton"]){
        [self dismissPopup];
        return;
    }
    if (self.gameState != GameStateWon && self.gameState != GameStateLost)
        [Flurry endTimedEvent:@"Played Level" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"Level", [NSNumber numberWithInteger:self.controller.levelNumber], @"Stars", [NSNumber numberWithInteger:0], @"Exited", [NSNumber numberWithBool:YES], nil]];
    
    if ([node.name isEqualToString:@"restartButton"]){
        MainScene *scene = [[MainScene alloc] initWithSize:self.view.bounds.size];
        scene.colorIndex = self.colorIndex;
        scene.scaleMode = SKSceneScaleModeAspectFill;
        scene.controller = self.controller;
        [self.view presentScene:scene];
    }
    else if ([node.name isEqualToString:@"levelSelectButton"]){
        [[NSNotificationCenter defaultCenter] postNotificationName:@"showPageControl" object:nil];
        NewLevelSelectScene *scene = [[NewLevelSelectScene alloc] initWithSize:self.view.bounds.size];
        scene.pageIndex = self.colorIndex;
        scene.rows = 5;
        scene.columns = 4;
        scene.scaleMode = self.scaleMode;
        [self.view presentScene:scene];
    }
    else if ([node.name isEqualToString:@"mainMenuButton"]){
        MenuScene *scene = [[MenuScene alloc] initWithSize:self.view.bounds.size];
        scene.scaleMode = SKSceneScaleModeAspectFill;
        [self.view presentScene:scene];
    }
    else if ([node.name isEqualToString:@"nextLevelButton"]){
        MainScene *scene = [[MainScene alloc] initWithSize:self.view.bounds.size];
        if (self.controller.levelNumber%20==0)
            scene.colorIndex=self.colorIndex+1;
        else
            scene.colorIndex = self.colorIndex;
        scene.controller = [IEBounceLevelController controllerWithLevelNumber:self.controller.levelNumber+1];
        scene.scaleMode = SKSceneScaleModeAspectFill;
        [self.view presentScene:scene];
    }
}

/*Helper method that make the code more readable and small */
#pragma mark - Helper Methods
/*Converts a point pair to a sprite for an obstacle. */
-(SKSpriteNode*)obstacleFromPair:(IEObjectPointPair*)pair{
    SKSpriteNode *sprite;
    UIColor *color;
    if ([pair.textureName isEqualToString:IETextureTypeSolid]||[pair.textureName isEqualToString:IETextureTypeNoClick])
        color = [SKColor whiteColor];
    else if ([pair.textureName isEqualToString:IETextureTypeInstaDeath])
        color = [MainScene colorWithR:213 G:69 B:69];
    else if ([pair.textureName isEqualToString:IETextureTypeCharged])
        color = [MainScene colorWithR:70 G:113 B:255];
    
    if ([pair.shapeName isEqualToString:@"square"]){
        sprite = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:CGSizeMake(baseWidth*pair.scale, baseWidth*pair.scale)];
        sprite.color = color;
        sprite.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:sprite.size];
    }
    else if ([pair.shapeName isEqualToString:@"rectangle_short"]){
        sprite = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:CGSizeMake(2*baseWidth*pair.scale, baseWidth*pair.scale)];
        sprite.color = color;
        sprite.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:sprite.size];
    }
    else if([pair.shapeName isEqualToString:@"rectangle_long"]){
        sprite = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:CGSizeMake(4*baseWidth*pair.scale, baseWidth*pair.scale)];
        sprite.color = color;
        sprite.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:sprite.size];
    }
    else if([pair.shapeName isEqualToString:@"rectangle_longest"]){
        sprite = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:CGSizeMake(6*baseWidth*pair.scale, baseWidth*pair.scale)];
        sprite.color = color;
        sprite.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:sprite.size];
    }
    else if ([pair.shapeName isEqualToString:@"rectangle_thin"]){
        sprite = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:CGSizeMake(8*baseWidth*pair.scale, baseWidth*pair.scale/2)];
        sprite.color = color;
        sprite.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:sprite.size];
    }
    else if ([pair.shapeName isEqualToString:IEShapeNameTriangleEquilateral]){
        
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-baseWidth*pair.scale/2, -baseWidth*pair.scale/2)];
        [path addLineToPoint:CGPointMake(0, baseWidth*pair.scale/2)];
        [path addLineToPoint:CGPointMake(baseWidth*pair.scale/2, -baseWidth*pair.scale/2)];
        [path closePath];
        SKShapeNode *shape = [SKShapeNode shapeNodeWithPath:path.CGPath centered:YES];
        shape.fillColor = color;
        shape.strokeColor = color;
        SKTexture *texture = [self.view textureFromNode:shape];
        
        sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        sprite.size = CGSizeMake(baseWidth*pair.scale, baseWidth*pair.scale);
        sprite.physicsBody = [SKPhysicsBody bodyWithPolygonFromPath:shape.path];
    }
    else if ([pair.shapeName isEqualToString:@"triangle_right"]){
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-baseWidth*pair.scale/2, -baseWidth*pair.scale/2)];
        [path addLineToPoint:CGPointMake(-baseWidth*pair.scale/2, baseWidth*pair.scale/2)];
        [path addLineToPoint:CGPointMake(baseWidth*pair.scale/2, -baseWidth*pair.scale/2)];
        [path closePath];
        SKShapeNode *shape = [SKShapeNode shapeNodeWithPath:path.CGPath centered:YES];
        shape.fillColor = color;
        shape.strokeColor = color;
        SKTexture *texture = [self.view textureFromNode:shape];
        
        sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        sprite.size = CGSizeMake(baseWidth*pair.scale, baseWidth*pair.scale);
        sprite.physicsBody = [SKPhysicsBody bodyWithTexture:texture size:sprite.size];
    }
    else if ([pair.shapeName isEqualToString:IEShapeNameTrianglePointy]){
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-baseWidth*pair.scale/2, baseWidth*pair.scale*2)];
        [path addLineToPoint:CGPointMake(0, baseWidth*pair.scale*2)];
        [path addLineToPoint:CGPointMake(baseWidth*pair.scale/2, -baseWidth*pair.scale*2)];
        [path closePath];
        
        SKShapeNode *shape = [SKShapeNode shapeNodeWithPath:path.CGPath centered:YES];
        shape.fillColor = color;
        shape.strokeColor = color;
        SKTexture *texture = [self.view textureFromNode:shape];
        
        sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        sprite.size = CGSizeMake(baseWidth*pair.scale, 4*baseWidth*pair.scale);
        sprite.physicsBody = [SKPhysicsBody bodyWithTexture:texture size:sprite.size];
    }
    else if ([pair.shapeName isEqualToString:@"circle"]){
        SKShapeNode *shape = [SKShapeNode shapeNodeWithCircleOfRadius:256];
        shape.fillColor = color;
        shape.strokeColor = color;
        SKTexture *texutre = [self.view textureFromNode:shape];
        
        if (isIpad && self.controller.levelNumber == 14)
            pair.scale /= 2;
        sprite = [SKSpriteNode spriteNodeWithTexture:texutre];
        sprite.size = CGSizeMake(baseWidth*pair.scale, baseWidth*pair.scale);
        sprite.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:baseWidth/2*pair.scale];
    }
    else if ([pair.shapeName isEqualToString:@"corner_thin"]){
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-baseWidth/2*pair.scale, -baseWidth/2*pair.scale)];
        [path addLineToPoint:CGPointMake(-baseWidth/2*pair.scale, baseWidth/2*pair.scale)];
        [path addLineToPoint:CGPointMake(-0.37*baseWidth*pair.scale, baseWidth/2*pair.scale)];
        [path addLineToPoint:CGPointMake(-0.37*baseWidth*pair.scale, -0.37*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(baseWidth/2*pair.scale, -0.37*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(baseWidth/2*pair.scale, -baseWidth/2*pair.scale)];
        [path closePath];
        
        SKShapeNode *shape = [SKShapeNode shapeNodeWithPath:path.CGPath];
        shape.fillColor = color;
        shape.strokeColor = color;
        SKTexture *texture = [self.view textureFromNode:shape];
        
        sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        sprite.size = CGSizeMake(baseWidth*pair.scale, baseWidth*pair.scale);
        sprite.physicsBody = [SKPhysicsBody bodyWithTexture:texture size:sprite.size];
    }
    else if ([pair.shapeName isEqualToString:@"corner_thick"]){
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-2*baseWidth*pair.scale, -2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-2*baseWidth*pair.scale, 2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-baseWidth*pair.scale, 2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-baseWidth*pair.scale, -baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(2*baseWidth*pair.scale, -baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(2*baseWidth*pair.scale, -2*baseWidth*pair.scale)];
        [path closePath];
        SKShapeNode *shape = [SKShapeNode shapeNodeWithPath:path.CGPath];
        shape.fillColor = color;
        shape.strokeColor = color;
        SKTexture *texture = [self.view textureFromNode:shape];
        
        sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        sprite.size = CGSizeMake(baseWidth*pair.scale, baseWidth*pair.scale);
        sprite.physicsBody = [SKPhysicsBody bodyWithTexture:texture size:sprite.size];
    }
    else if ([pair.shapeName isEqualToString:IEShapeNameSquareBox]){
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-2*baseWidth*pair.scale, -2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-2*baseWidth*pair.scale, 2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(2*baseWidth*pair.scale, 2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(2*baseWidth*pair.scale, -2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-3*baseWidth/2*pair.scale, -2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-3*baseWidth/2*pair.scale, -3*baseWidth/2*pair.scale)];
        [path addLineToPoint:CGPointMake(2*baseWidth/2*pair.scale, -3*baseWidth/2*pair.scale)];
        [path addLineToPoint:CGPointMake(3*baseWidth/2*pair.scale, 3*baseWidth/2*pair.scale)];
        [path addLineToPoint:CGPointMake(-3*baseWidth/2*pair.scale, 3*baseWidth/2*pair.scale)];
        [path addLineToPoint:CGPointMake(-3*baseWidth/2*pair.scale, -2*baseWidth*pair.scale)];
        [path closePath];
        SKShapeNode *shape = [SKShapeNode shapeNodeWithPath:path.CGPath];
        shape.fillColor = color;
        shape.strokeColor = color;
        SKTexture *texture = [self.view textureFromNode:shape];
        sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        sprite.size = CGSizeMake(baseWidth*pair.scale, baseWidth*pair.scale);
        sprite.physicsBody = [SKPhysicsBody bodyWithTexture:texture size:sprite.size];
    }
    else if ([pair.shapeName isEqualToString:IEShapeNameRectangleBox]){
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-2*baseWidth*pair.scale, -6*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-2*baseWidth*pair.scale, 6*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(2*baseWidth*pair.scale, 6*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(2*baseWidth*pair.scale, -6*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-3*baseWidth/2*pair.scale, -6*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-3*baseWidth/2*pair.scale, -5.5*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(3*baseWidth/2*pair.scale, -5.5*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(3*baseWidth/2*pair.scale, 5.5*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-3*baseWidth/2*pair.scale, 5*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-3*baseWidth/2*pair.scale, -6*baseWidth*pair.scale)];
        [path closePath];
        
        SKShapeNode *shape = [SKShapeNode shapeNodeWithPath:path.CGPath];
        shape.fillColor = color;
        shape.strokeColor = color;
        SKTexture *texture = [self.view textureFromNode:shape];
        sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        sprite.size = CGSizeMake(baseWidth*pair.scale, baseWidth*pair.scale);
        sprite.physicsBody = [SKPhysicsBody bodyWithTexture:texture size:sprite.size];
    }
    else if ([pair.shapeName isEqualToString:IEShapeNameSquareBoxOpen]){
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-3*baseWidth/2*pair.scale, -2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-2*baseWidth*pair.scale, -2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(-2*baseWidth*pair.scale, 2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(2*baseWidth*pair.scale, 2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(2*baseWidth*pair.scale, -2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(3*baseWidth/2*pair.scale, -2*baseWidth*pair.scale)];
        [path addLineToPoint:CGPointMake(3*baseWidth/2*pair.scale, 3*baseWidth/2*pair.scale)];
        [path addLineToPoint:CGPointMake(-3*baseWidth/2*pair.scale, 3*baseWidth/2*pair.scale)];
        [path closePath];
        
        SKShapeNode *shape = [SKShapeNode shapeNodeWithPath:path.CGPath];
        shape.fillColor = color;
        shape.strokeColor = color;
        SKTexture *texture = [self.view textureFromNode:shape];
        sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        sprite.size = CGSizeMake(4*baseWidth*pair.scale, 4*baseWidth*pair.scale);
        sprite.physicsBody = [SKPhysicsBody bodyWithTexture:texture size:sprite.size];
        [sprite runAction:[SKAction scaleBy:0.25 duration:0]];
    }
    else if ([pair.shapeName isEqualToString:IEShapeNameArcHalf]){
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-2*baseWidth*pair.scale, 0)];
        [path addArcWithCenter:CGPointZero radius:2*baseWidth*pair.scale startAngle:M_PI endAngle:0 clockwise:NO];
        [path addLineToPoint:CGPointMake(1.7*baseWidth*pair.scale, 0)];
        [path addArcWithCenter:CGPointZero radius:1.7*baseWidth*pair.scale startAngle:0 endAngle:M_PI clockwise:YES];
        [path closePath];
        SKShapeNode *shapeNode = [SKShapeNode shapeNodeWithPath:path.CGPath centered:YES];
        shapeNode.fillColor = color;
        shapeNode.strokeColor = color;
        SKTexture *texture = [self.view textureFromNode:shapeNode];
        sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        sprite.physicsBody = [SKPhysicsBody bodyWithTexture:texture size:sprite.size];
    }
    else if ([pair.shapeName isEqualToString:IEShapeNameArcQuarter]){
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-2*baseWidth*cosf(M_PI_4)*pair.scale, 2*baseWidth*sinf(M_PI_4)*pair.scale)];
        [path addArcWithCenter:CGPointZero radius:2*baseWidth*pair.scale startAngle:M_PI-M_PI_4 endAngle:M_PI_4 clockwise:NO];
        [path addLineToPoint:CGPointMake(1.7*baseWidth*cosf(M_PI_4)*pair.scale, 1.7*baseWidth*sinf(M_PI_4)*pair.scale)];
        [path addArcWithCenter:CGPointZero radius:1.7*baseWidth*pair.scale startAngle:M_PI_4 endAngle:M_PI-M_PI_4 clockwise:YES];
        [path closePath];
        SKShapeNode *shapeNode = [SKShapeNode shapeNodeWithPath:path.CGPath centered:YES];
        shapeNode.fillColor = color;
        shapeNode.strokeColor = color;
        SKTexture *texture = [self.view textureFromNode:shapeNode];
        sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        sprite.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
        sprite.physicsBody = [SKPhysicsBody bodyWithPolygonFromPath:shapeNode.path];
    }
    else if ([pair.shapeName isEqualToString:IEShapeNameArcThird]){
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(-2*baseWidth*cosf(M_PI/3)*pair.scale, 2*baseWidth*sinf(M_PI/3)*pair.scale)];
        [path addArcWithCenter:CGPointZero radius:2*baseWidth*pair.scale startAngle:M_PI*2/3 endAngle:M_PI/3 clockwise:NO];
        [path addLineToPoint:CGPointMake(1.7*baseWidth*cosf(M_PI/3)*pair.scale, 1.7*baseWidth*sinf(M_PI/3)*pair.scale)];
        [path addArcWithCenter:CGPointZero radius:1.7*baseWidth*pair.scale startAngle:M_PI/3 endAngle:M_PI*2/3 clockwise:YES];
        [path closePath];
        SKShapeNode *shapeNode = [SKShapeNode shapeNodeWithPath:path.CGPath centered:YES];
        shapeNode.fillColor = [SKColor whiteColor];
        shapeNode.strokeColor = [SKColor whiteColor];
        SKTexture *texture = [self.view textureFromNode:shapeNode];
        sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        sprite.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
        sprite.physicsBody = [SKPhysicsBody bodyWithPolygonFromPath:shapeNode.path];
    }
    sprite.physicsBody.affectedByGravity = NO;
    sprite.physicsBody.fieldBitMask = 0x0;
    if ([pair.textureName isEqualToString:IETextureTypeSolid]){
        sprite.physicsBody.categoryBitMask = solidCategory;
        sprite.physicsBody.collisionBitMask = 0x0;
        sprite.physicsBody.contactTestBitMask = edgeCategory;
        sprite.name = @"Solid";
        sprite.physicsBody.friction = 0;
        sprite.physicsBody.restitution = 1;
    }
    else if ([pair.textureName isEqualToString:IETextureTypeNoClick]){
        sprite.alpha = 0.75;
        sprite.zPosition--;
        sprite.physicsBody.categoryBitMask = noClickCategory;
        sprite.physicsBody.collisionBitMask = 0x0;
        sprite.physicsBody.contactTestBitMask = edgeCategory;
        sprite.name = @"NoClick";
        
    }
    else if ([pair.textureName isEqualToString:IETextureTypeInstaDeath]){
        sprite.alpha = 0.5;
        sprite.zPosition--;
        sprite.physicsBody.categoryBitMask = instaDeathCategory;
        sprite.physicsBody.collisionBitMask = 0x0;
        sprite.physicsBody.contactTestBitMask = ballCategory | edgeCategory;
        [sprite runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction fadeAlphaTo:1 duration:1], [SKAction waitForDuration:0.5], [SKAction fadeAlphaTo:0.5 duration:1], [SKAction waitForDuration:0.5]]]]];
        sprite.name = @"InstaDeath";
    }
    else if ([pair.textureName isEqualToString:IETextureTypeFriction]){
        sprite.physicsBody.categoryBitMask = solidCategory;
        sprite.physicsBody.collisionBitMask = 0x0;
        sprite.physicsBody.contactTestBitMask = ballCategory | edgeCategory;
        sprite.physicsBody.friction = 0.4;
        sprite.physicsBody.restitution = 0.3;
        sprite.name = @"Friction";
    }
    else if ([pair.textureName isEqualToString:IETextureTypeCharged]){
        sprite.physicsBody.categoryBitMask = solidCategory;
        sprite.physicsBody.collisionBitMask = 0x0;
        sprite.physicsBody.contactTestBitMask = ballCategory | edgeCategory;
        sprite.name = @"Charge";
    }
    
    return sprite;
}
-(SKShapeNode*)obstacleFromPath:(IECustomPath*)path{
    UIBezierPath *bezierPath = [path pathInView:self.view scale:4];
    SKShapeNode *shapeNode = [SKShapeNode shapeNodeWithPath:bezierPath.CGPath centered:NO];
    if ([path.textureName isEqualToString:IETextureTypeSolid]){
        shapeNode.fillColor = [SKColor whiteColor];
        shapeNode.strokeColor = [SKColor whiteColor];
    }
    else if ([path.textureName isEqualToString:IETextureTypeNoClick]){
        shapeNode.fillColor = [SKColor colorWithWhite:1 alpha:0.5];
        shapeNode.strokeColor = [SKColor colorWithWhite:1 alpha:0.01];
    }
    else if ([path.textureName isEqualToString:IETextureTypeInstaDeath]){
        shapeNode.fillColor = [SKColor colorWithRed:1 green:69.0/255.0 blue:69.0/255.0 alpha:0.5];
        shapeNode.strokeColor = [SKColor colorWithRed:1 green:69.0/255.0 blue:69.0/255.0 alpha:0.01];
    }
    shapeNode.physicsBody = [SKPhysicsBody bodyWithPolygonFromPath:shapeNode.path];
    shapeNode.physicsBody.affectedByGravity = NO;
    shapeNode.physicsBody.fieldBitMask = 0x0;
    if ([path.textureName isEqualToString:IETextureTypeSolid]){
        shapeNode.physicsBody.categoryBitMask = solidCategory;
        shapeNode.physicsBody.collisionBitMask = 0x0;
        shapeNode.physicsBody.contactTestBitMask = edgeCategory | ballCategory;
        shapeNode.physicsBody.resting = YES;
        shapeNode.physicsBody.friction = 0;
    }
    else if ([path.textureName isEqualToString:IETextureTypeNoClick]){
        shapeNode.physicsBody.categoryBitMask = noClickCategory;
        shapeNode.physicsBody.collisionBitMask = 0x0;
        shapeNode.physicsBody.contactTestBitMask = edgeCategory;
    }
    else if ([path.textureName isEqualToString:IETextureTypeInstaDeath]){
        shapeNode.physicsBody.categoryBitMask = instaDeathCategory;
        shapeNode.physicsBody.collisionBitMask = 0x0;
        shapeNode.physicsBody.contactTestBitMask = edgeCategory | ballCategory;
        shapeNode.zPosition--;
        [shapeNode runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction fadeAlphaTo:1 duration:1], [SKAction waitForDuration:0.5], [SKAction fadeAlphaTo:0.5 duration:1], [SKAction waitForDuration:0.5]]]]];
    }
    shapeNode.xScale = 0.25;
    shapeNode.yScale = 0.25;
    return shapeNode;
}
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
/*Returns a color in which the developer can pass integer values instead of floats */
+(UIColor*)colorWithR:(CGFloat)r G:(CGFloat)g B:(CGFloat)b{
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1];
}
/*Returns a zero vector */
static inline CGVector CGVectorZero(){
    return CGVectorMake(0, 0);
}
static inline CGFloat getAbsoluteAngle(CGPoint origin, CGPoint point){
    CGPoint diff = CGPointMake(point.x-origin.x, point.y-origin.y);
    CGFloat distance = distanceFromPointToPoint(origin, point);
    if (diff.y<0)
        return 2*M_PI-acosf(diff.x/distance);
    else
        return acosf(diff.x/distance);
}
/*Physics method that creates a 2d vector with a magnitude and an angle from 0 rad */
static inline CGVector createAngledVector(CGFloat magnitude, CGFloat angle){
    return CGVectorMake(magnitude*cosf(angle), magnitude*sinf(angle));
}
/*Calculates float value of the distance between two 2d points */
static inline CGFloat distanceFromPointToPoint(CGPoint first, CGPoint second){
    return sqrtf(powf(first.x-second.x, 2)+powf(first.y-second.y, 2));
}
/*Converts an IEObject layout variable to a usable point for the scene */
-(CGPoint)positionFromLayout:(IEObjectLayout)layout{
    switch (layout) {
        case IEObjectLayoutBottom:
            return CGPointMake(CGRectGetMidX(self.frame), circle.size.height/2);
            break;
        case IEObjectLayoutTop:
            return CGPointMake(CGRectGetMidX(self.frame), self.size.height-circle.size.height/2);
            break;
        case IEObjectLayoutMiddle:
            return CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
            break;
        case IEObjectLayoutLeft:
            return CGPointMake(circle.size.width/2, CGRectGetMidY(self.frame));
            break;
        case IEObjectLayoutBottomLeft:
            return CGPointMake(circle.size.width/2, circle.size.height/2);
            break;
        case IEObjectLayoutBottomRight:
            return CGPointMake(self.size.width-circle.size.width/2, circle.size.height/2);
            break;
        case IEObjectLayoutDiagonalBottomleft:
            return CGPointMake(self.size.width/4, self.size.height/4);
            break;
        case IEObjectLayoutDiagonalBottomRight:
            return CGPointMake(self.size.width*3/4, self.size.height/4);
            break;
        case IEObjectLayoutDiagonalTopLeft:
            return CGPointMake(self.size.width/4, self.size.height*3/4);
            break;
        case IEObjectLayoutDiagonalTopRight:
            return CGPointMake(self.size.width*3/4, self.size.height*3/4);
            break;
        case IEObjectLayoutMiddleBottom:
            return CGPointMake(CGRectGetMidX(self.frame), self.size.height/4);
            break;
        case IEObjectLayoutMiddleLeft:
            return CGPointMake(self.size.width/4, CGRectGetMidY(self.frame));
            break;
        case IEObjectLayoutMiddleRight:
            return CGPointMake(self.size.width*3/4, CGRectGetMidY(self.frame));
            break;
        case IEObjectLayoutMiddleTop:
            return CGPointMake(CGRectGetMidX(self.frame), self.size.height*3/4);
            break;
        case IEObjectLayoutRight:
            return CGPointMake(self.size.width-circle.size.width/2, CGRectGetMidY(self.frame));
            break;
        case IEObjectLayoutTopLeft:
            return CGPointMake(circle.size.width/2, self.size.height-circle.size.height/2);
            break;
        case IEObjectLayoutTopRight:
            return CGPointMake(self.size.width-circle.size.width/2, self.size.height-circle.size.height/2);
            break;
        case IEObjectLayoutBottomLeftMiddle:
            return CGPointMake(circle.size.width/2, self.size.height/4);
            break;
        case IEObjectLayoutBottomRightMiddle:
            return CGPointMake(self.size.width-circle.size.width/2, self.size.height/4);
            break;
        case IEObjectLayoutTopLeftMiddle:
            return CGPointMake(circle.size.width/2, self.size.height*3/4);
            break;
            case IEObjectLayoutTopRightMiddle:
            return CGPointMake(self.size.width-circle.size.width/2, self.size.height*3/4);
        default:
            return CGPointZero;
            break;
    }
}
static inline CGFloat radToDeg(CGFloat radians){
    return radians*180.0/M_PI;
}
static inline CGFloat getAngleFromHorizontal(CGPoint first, CGPoint second){ 
    CGFloat x = second.x-first.x;
    CGFloat y = second.y-first.y;
    CGFloat r = distanceFromPointToPoint(first, second);
    if (y>=0&&x>=0)
        return asinf(y/r);
    else if (y>=0&&x<0)
        return M_PI-asinf(y/r);
    else if (x<0 && y< 0)
        return M_PI+asinf(-y/r);
    else
        return (M_PI*2)-asinf(-y/r);
}
@end
//
//  MenuScene.m
//  Circle Test
//
//  Created by Eric Dufresne on 2015-06-30.
//  Copyright (c) 2015 Eric Dufresne. All rights reserved.
//

#import "MenuScene.h"
#import "AppDelegate.h"
#import "NewLevelSelectScene.h"
#import "ViewController.h"
#import "SettingsScene.h"
#import "SurvivalScene.h"

@interface MenuScene (){
    NSTimer *timer;
}
@property BOOL contentCreated;
@end
@implementation MenuScene
static const uint32_t contactCategory = 0x1 << 0;

-(void)didMoveToView:(SKView *)view{
    if (!self.contentCreated){
        self.contentCreated = YES;
        [self createSceneContent];
    }
}
-(void)createSceneContent{
    self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
    self.physicsBody.restitution = 1;
    self.physicsBody.categoryBitMask = contactCategory;
    self.physicsBody.collisionBitMask = 0xFFFFFF;
    self.physicsBody.contactTestBitMask = contactCategory;
    self.physicsBody.friction = 0;
    self.physicsWorld.gravity = CGVectorMake(0, 0);
    
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    int index = arc4random()%delegate.arrayOfColors.count;
    self.backgroundColor = [delegate.arrayOfColors objectAtIndex:index];
    UIColor *baseColor;
    UIColor *selectedColor;
    if (index <=4){
        baseColor = [SKColor darkGrayColor];
        selectedColor = [SKColor lightGrayColor];
    }
    else{
        baseColor = [SKColor whiteColor];
        selectedColor = [SKColor lightGrayColor];
    }
    
    SKLabelNode *labelNode = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    labelNode.fontColor = baseColor;
    labelNode.fontSize = 50;
    labelNode.text = @"Trick Shot";
    labelNode.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame)+100);
    labelNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:labelNode.frame.size center:CGPointMake(0, labelNode.frame.size.height/2)];
    labelNode.physicsBody.friction = 0;
    labelNode.physicsBody.restitution = 1;
    labelNode.physicsBody.categoryBitMask = contactCategory;
    labelNode.physicsBody.contactTestBitMask = contactCategory;
    labelNode.physicsBody.collisionBitMask = 0xFFFFFF;
    labelNode.physicsBody.dynamic = NO;
    [self addChild:labelNode];
    
    
    IELabelButton *playNode = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:baseColor selectedColor:selectedColor];
    playNode.delegate = self;
    playNode.fontSize = 26;
    playNode.text = @"Play";
    playNode.position = CGPointMake(CGRectGetMidX(self.frame), labelNode.position.y-100);
    playNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:playNode.frame.size center:CGPointMake(0, playNode.frame.size.height/2)];
    playNode.physicsBody.friction = 0;
    playNode.name = @"play";
    playNode.physicsBody.restitution = 1;
    playNode.physicsBody.categoryBitMask = contactCategory;
    playNode.physicsBody.contactTestBitMask = contactCategory;
    playNode.physicsBody.collisionBitMask = 0xFFFFFF;
    playNode.physicsBody.dynamic = NO;
    [self addChild:playNode];
    
    IELabelButton *survivalNode = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:baseColor selectedColor:selectedColor];
    survivalNode.delegate = self;
    survivalNode.fontSize = 26;
    survivalNode.text = @"Survival Mode";
    survivalNode.position = CGPointMake(self.size.width/2, playNode.position.y-50);
    survivalNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:survivalNode.frame.size center:CGPointMake(0, survivalNode.frame.size.height/2)];
    survivalNode.physicsBody.friction = 0;
    survivalNode.name = @"survivalMode";
    survivalNode.physicsBody.resting = 1;
    survivalNode.physicsBody.categoryBitMask = contactCategory;
    survivalNode.physicsBody.collisionBitMask = 0xFFFFFF;
    survivalNode.physicsBody.dynamic = NO;
    [self addChild:survivalNode];
    
    IELabelButton *leaderboardsNode = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:baseColor selectedColor:selectedColor];
    leaderboardsNode.delegate = self;
    leaderboardsNode.fontSize = 26;
    leaderboardsNode.text = @"Leaderboards";
    leaderboardsNode.name = @"leaderboards";
    leaderboardsNode.position = CGPointMake(CGRectGetMidX(self.frame), survivalNode.position.y-50);
    leaderboardsNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:leaderboardsNode.frame.size center:CGPointMake(0, leaderboardsNode.frame.size.height/2)];
    leaderboardsNode.physicsBody.friction = 0;
    leaderboardsNode.physicsBody.restitution = 1;
    leaderboardsNode.physicsBody.categoryBitMask = contactCategory;
    leaderboardsNode.physicsBody.contactTestBitMask = contactCategory;
    leaderboardsNode.physicsBody.collisionBitMask = 0xFFFFFF;
    leaderboardsNode.physicsBody.dynamic = NO;
    [self addChild:leaderboardsNode];
    
    IELabelButton *rateNode = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:baseColor selectedColor:selectedColor];
    rateNode.delegate = self;
    rateNode.fontSize = 20;
    rateNode.text = @"Rate";
    rateNode.name = @"rate";
    if (!delegate.adsRemoved)
        rateNode.position = CGPointMake(CGRectGetMinX(leaderboardsNode.frame)+rateNode.frame.size.width/2, leaderboardsNode.position.y-50);
    else
        rateNode.position = CGPointMake(CGRectGetMidX(self.frame), leaderboardsNode.position.y-50);
    rateNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:rateNode.frame.size center:CGPointMake(0, rateNode.frame.size.height/2)];
    rateNode.physicsBody.friction = 0;
    rateNode.physicsBody.restitution = 1;
    rateNode.physicsBody.categoryBitMask = contactCategory;
    rateNode.physicsBody.contactTestBitMask = contactCategory;
    rateNode.physicsBody.collisionBitMask = 0xFFFFFF;
    rateNode.physicsBody.dynamic = NO;
    [self addChild:rateNode];
    
    if (!delegate.adsRemoved){
        IELabelButton *removeAdsNode = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:baseColor selectedColor:selectedColor];
        removeAdsNode.delegate = self;
        removeAdsNode.fontSize = 20;
        removeAdsNode.text = @"Remove Ads";
        removeAdsNode.name = @"removeAds";
        removeAdsNode.position = CGPointMake(CGRectGetMaxX(leaderboardsNode.frame)-removeAdsNode.frame.size.width/2, rateNode.position.y);
        removeAdsNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:removeAdsNode.frame.size center:CGPointMake(0, removeAdsNode.frame.size.height/2)];
        removeAdsNode.physicsBody.friction = 0;
        removeAdsNode.physicsBody.restitution = 1;
        removeAdsNode.physicsBody.categoryBitMask = contactCategory;
        removeAdsNode.physicsBody.contactTestBitMask = contactCategory;
        removeAdsNode.physicsBody.collisionBitMask = 0xFFFFFF;
        removeAdsNode.physicsBody.dynamic = NO;
        [self addChild:removeAdsNode];
    }
    IELabelButton *helpButton = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:baseColor selectedColor:selectedColor];
    helpButton.delegate = self;
    helpButton.fontSize = 35;
    helpButton.text = @"?";
    helpButton.name = @"helpButton";
    helpButton.position = CGPointMake(self.size.width-helpButton.frame.size.width/2-5, self.size.height-helpButton.frame.size.height-5);
    helpButton.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:helpButton.frame.size center:CGPointMake(0, helpButton.frame.size.height/2)];
    helpButton.physicsBody.categoryBitMask = contactCategory;
    helpButton.physicsBody.contactTestBitMask = contactCategory;
    helpButton.physicsBody.collisionBitMask = 0xFFFFFF;
    helpButton.physicsBody.affectedByGravity = NO;
    helpButton.physicsBody.dynamic = NO;
    [self addChild:helpButton];
    
    SKShapeNode *shape = [SKShapeNode shapeNodeWithCircleOfRadius:256];
    shape.fillColor = [SKColor whiteColor];
    shape.strokeColor = baseColor;
    shape.lineWidth = 20;
    shape.antialiased = YES;
    SKTexture *texture = [self.view textureFromNode:shape];
    
    SKSpriteNode *ball = [SKSpriteNode spriteNodeWithTexture:texture];
    ball.size = CGSizeMake(32, 32);
    ball.position = CGPointMake(CGRectGetMidX(self.frame), ball.size.height/2+25);
    ball.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:16];
    ball.physicsBody.friction = 0;
    ball.physicsBody.restitution = 1;
    ball.physicsBody.linearDamping = 0;
    ball.physicsBody.angularDamping = 0;
    ball.physicsBody.contactTestBitMask = contactCategory;
    ball.physicsBody.collisionBitMask = 0xFFFFFF;
    ball.physicsBody.contactTestBitMask = contactCategory;
    ball.name = @"ball";
    [self addChild:ball];
    
    [ball.physicsBody applyImpulse:getVectorWithResultantVelocity(5)];
}
-(void)tick{
    static int index = 0;
    index++;
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    if (index==delegate.arrayOfColors.count)
        index = 0;
    self.backgroundColor = [delegate.arrayOfColors objectAtIndex:index];
}
#pragma mark - Touch Events
-(void)buttonWasReleased:(id)button{
    IELabelButton *released = (IELabelButton*)button;
    if([released.name isEqualToString:@"play"]){
        [[NSNotificationCenter defaultCenter] postNotificationName:@"showPageControl" object:nil];
        NewLevelSelectScene *scene = [[NewLevelSelectScene alloc] initWithSize:self.view.bounds.size];
        NSNumber *lastPage = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastPage"];
        scene.scaleMode = SKSceneScaleModeAspectFill;
        ViewController *vc = (ViewController*)self.view.window.rootViewController;
        if (lastPage){
            scene.pageIndex = lastPage.integerValue;
            vc.pageControl.currentPage = lastPage.integerValue;
        }
        else{
            scene.pageIndex = 0;
            vc.pageControl.currentPage = 0;
        }
        vc.backButton.titleLabel.textColor = [SKColor blackColor];
        scene.rows = 5;
        scene.columns = 4;
        [self.view presentScene:scene];
    }
    else if ([released.name isEqualToString:@"survivalMode"]){
        SurvivalScene *scene = [[SurvivalScene alloc] initWithSize:self.view.bounds.size];
        scene.scaleMode = SKSceneScaleModeAspectFill;
        [self.view presentScene:scene];
    }
    else if ([released.name isEqualToString:@"leaderboards"]){
        ViewController *vc = (ViewController*)self.view.window.rootViewController;
        [vc attemptAuthenticateForLeaderboard];
    }
    else if ([released.name isEqualToString:@"rate"]){
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://itunes.apple.com/app/id1059196616"]];
    }
    else if ([released.name isEqualToString:@"removeAds"]){
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Remove Ads" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [controller addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        __weak MenuScene *weakself = self;
        [controller addAction:[UIAlertAction actionWithTitle:@"Purchase" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            ViewController *vc = (ViewController*)weakself.view.window.rootViewController;
            [vc purchaseRemoveAds];
        }]];
        [controller addAction:[UIAlertAction actionWithTitle:@"Restore Purchases" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            ViewController *vc = (ViewController*)weakself.view.window.rootViewController;
            [vc restorePurchases];
        }]];
        [self.view.window.rootViewController presentViewController:controller animated:YES completion:nil];
    }
    else if ([released.name isEqualToString:@"helpButton"]){
        ViewController *controller = (ViewController*)self.view.window.rootViewController;
        controller.backButton.hidden = NO;
        SettingsScene *scene = [[SettingsScene alloc] initWithSize:self.view.bounds.size];
        scene.scaleMode = self.scaleMode;
        [self.view presentScene:scene];
    }
}
-(void)didBeginContact:(SKPhysicsContact *)contact{
    NSLog(@"Play Noise");
}
#pragma mark - Helper and C style methods
+(UIColor*)colorWithR:(CGFloat)r G:(CGFloat)g b:(CGFloat)b{
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1];
}
static inline CGVector getVectorWithResultantVelocity(float velocity){
    CGFloat x = getRandomNumber(velocity, -velocity);
    CGFloat y = sqrtf(pow(velocity, 2)-pow(x,2));
    return CGVectorMake(x, y);
}
static inline CGFloat getRandomNumber(float high, float low){
    float random = (float)rand()/(float)RAND_MAX;
    return low+random*(high-low);
}
@end

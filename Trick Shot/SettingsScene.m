//
//  SettingsScene.m
//  Trick Shot
//
//  Created by Eric Dufresne on 2015-11-18.
//  Copyright © 2015 Eric Dufresne. All rights reserved.
//

#import "SettingsScene.h"
#import "AppDelegate.h"
#import "ViewController.h"
#import "IEPowerup.h"
#define ICON_DIM_FACTOR 6.5
#define EXIT_BTN_DIM 8.5

@interface SettingsScene ()
@property BOOL contentCreated;
@property BOOL popupVisible;
@property (strong, nonatomic) SKSpriteNode *blackMask;
@property (strong, nonatomic) SKSpriteNode *popup;
@property (strong, nonatomic) SKTextureAtlas *popupAtlas;
@end

@implementation SettingsScene
-(void)didMoveToView:(SKView *)view{
    if (!self.contentCreated){
        self.contentCreated = YES;
        self.popupVisible = NO;
        [self createSceneContent];
    }
}
-(void)createSceneContent{
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
    IELabelButton *aboutUs = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:baseColor selectedColor:selectedColor];
    aboutUs.fontSize = 20;
    aboutUs.delegate = self;
    aboutUs.position = CGPointMake(self.size.width/2, self.size.height/2+200);
    aboutUs.name = @"aboutUs";
    aboutUs.text = @"About";
    aboutUs.fontColor = baseColor;
    [self addChild:aboutUs];
    
    ViewController *controller = (ViewController*)self.view.window.rootViewController;
    controller.backButton.titleLabel.textColor = aboutUs.fontColor;
    
    IELabelButton *button = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:baseColor selectedColor:selectedColor];
    button.fontSize = 20;
    button.delegate = self;
    button.position = CGPointMake(self.size.width/2, self.size.height/2+100);
    button.name = @"showTutorial";
    button.text = @"Replay Tutorial";
    button.fontColor = baseColor;
    [self addChild:button];
    
    SKLabelNode *node = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    node.fontSize = 15;
    node.position = CGPointMake(self.size.width/2, self.size.height*7/16);
    node.text = @"Powerup Info:";
    node.fontColor = baseColor;
    [self addChild:node];
    
    SKTextureAtlas *atlas = [SKTextureAtlas atlasNamed:@"icon.atlas"];
    const CGFloat buffer = self.size.width/3.0;
    for (int k = 0;k<2;k++){
        for (int i = 0;i<3;i++){
            CGFloat y = self.size.height*(3-k)/8;
            CGFloat x = buffer/2+buffer*i;
            SKTexture *texture = [atlas textureNamed:[[IEPowerup textureNamesInOrder] objectAtIndex:3*k+i]];
            IETextureButton *button = [IETextureButton buttonWithDefaultTexture: texture selectedTexture:texture];
            button.delegate = self;
            button.size = CGSizeMake(self.size.width/ICON_DIM_FACTOR, self.size.width/ICON_DIM_FACTOR);
            button.position = CGPointMake(x, y);
            NSString *powerupString = [[IEPowerup powerupTypeStrings] objectAtIndex:i+3*k];
            button.name = powerupString;
            
            SKLabelNode *node = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
            node.fontSize = 15;
            node.fontColor = baseColor;
            node.text = [[IEPowerup powerupDescriptionsInOrder] objectAtIndex:i+3*k];
            node.position = CGPointMake(0, -button.size.height/2-node.frame.size.height/2-5);
            [button addChild:node];
            
            [self addChild:button];
        }
    }
    SKShapeNode *shapeNode = [SKShapeNode shapeNodeWithRectOfSize:self.size];
    shapeNode.fillColor = [SKColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1];
    shapeNode.strokeColor = [SKColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1];
    self.blackMask = [SKSpriteNode spriteNodeWithTexture:[self.view textureFromNode:shapeNode]];
    self.blackMask.position = CGPointMake(self.size.width/2, self.size.height/2);
    self.blackMask.alpha = 0;
    [self addChild: self.blackMask];
    self.popupAtlas = [SKTextureAtlas atlasNamed:@"dialogue.atlas"];
}
-(void)buttonWasPressed:(id)button{
    if ([button isKindOfClass:[IELabelButton class]]){
        IELabelButton *labelButton = (IELabelButton*)button;
        if ([labelButton.name isEqualToString: @"showTutorial"]){
            ViewController *controller = (ViewController*)self.view.window.rootViewController;
            [controller showTutorial];
        }
        else if ([labelButton.name isEqualToString:@"aboutUs"]){
            SKSpriteNode *spriteNode = [self createPopUpWithType:NULL];
        }
    }
    else if ([button isKindOfClass: [IETextureButton class]]){
        IETextureButton *textureButton = (IETextureButton*)button;
        if ([textureButton.name isEqualToString:@"exitButton"]||[textureButton.parent isEqual:self.popup]){
            [self dismissPopup];
            return;
        }
        else if (!self.popupVisible){
            self.popupVisible = YES;
            NSUInteger integer = textureButton.name.integerValue;
            IEPowerupType powerupType = (IEPowerupType)integer;
            
            self.popup = [self createPopUpWithType:&powerupType];
            [self addChild:self.popup];
            [self.popup runAction:[SKAction moveToY:self.size.height/2 duration:0.25]];
            [self.blackMask runAction:[SKAction fadeAlphaTo:0.5 duration:0.25]];
        }
    }
}
-(void)dismissPopup{
    [self.blackMask runAction:[SKAction fadeAlphaTo:0 duration:0.25]];
    [self.popup runAction:[SKAction moveToY:-self.popup.size.height/2 duration:0.25]];
    self.popupVisible = NO;
}
#pragma mark Helper Method
-(SKSpriteNode*)createPopUpWithType:(IEPowerupType*)type{
    if (type == NULL){
        NSLog(@"About us");
        return nil;
    }
    else{
        SKTexture *texture;
        if (*type == IEPowerupAimAndFire)
            texture = [self.popupAtlas textureNamed:@"dialogue_aimandfire"];
        else if (*type == IEPowerupGhost)
            texture = [self.popupAtlas textureNamed:@"dialogue_ghost"];
        else if (*type == IEPowerupGravity)
            texture = [self.popupAtlas textureNamed:@"dialogue_gravity"];
        else if (*type == IEPowerupKey)
            texture = [self.popupAtlas textureNamed:@"dialogue_key"];
        else if (*type == IEPowerupTilt)
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
}
@end

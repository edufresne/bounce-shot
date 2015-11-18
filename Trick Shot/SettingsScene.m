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

@interface SettingsScene ()
@property BOOL contentCreated;
@end

@implementation SettingsScene
-(void)didMoveToView:(SKView *)view{
    if (!self.contentCreated){
        self.contentCreated = YES;
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
    IELabelButton *button = [IELabelButton buttonWithFontName:@"Roboto-Thin" defaultColor:baseColor selectedColor:selectedColor];
    button.fontSize = 20;
    button.delegate = self;
    button.position = CGPointMake(self.size.width/2, self.size.height/2+100);
    button.name = @"showTutorial";
    button.text = @"Replay Tutorial";
    [self addChild:button];
    
    SKLabelNode *node = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
    node.fontSize = 20;
    node.position = CGPointMake(self.size.width/2, self.size.height/2);
    node.text = @"Powerup Info:";
    [self addChild:button];
    
    NSArray *iconNames = [NSArray arrayWithObjects:@"Aim and Fire", @"Gravity", @"Key", @"Ghost", @"Immunity", @"Tilt", nil];
    NSArray *textureNames = [NSArray arrayWithObjects:@"icon_aim", @"icon_gravity", @"", nil];
    SKTextureAtlas *atlas = [SKTextureAtlas atlasNamed:@"icon.atlas"];
    IEPowerupType* arr_ptr = powerupsInOrder();
    
}
-(void)buttonWasReleased:(id)button{
    if ([button isKindOfClass:[IELabelButton class]]){
        ViewController *controller = (ViewController*)self.view.window.rootViewController;
        [controller showTutorial];
    }
    else if ([button isKindOfClass: [IETextureButton class]]){
        
    }
}
@end

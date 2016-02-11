//
//  NewLevelSelectScene.m
//  trickshotfix
//
//  Created by Eric Dufresne on 2015-11-04.
//  Copyright © 2015 Eric Dufresne. All rights reserved.
//

#import "NewLevelSelectScene.h"
#import "IEDataManager.h"
#import "AppDelegate.h"
#import "MainScene.h"
#import "ViewController.h"

#define DIM_FACTOR 6.0
#define DIM_FACTOR_IPAD 8.0
#define STAR_DIM_FACTOR 4.0
#define STAR_DIM_FACTOR_IPAD 5
#define isIpad UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad

@interface NewLevelSelectScene ()
@property (strong, nonatomic) UISwipeGestureRecognizer *left;
@property (strong, nonatomic) UISwipeGestureRecognizer *right;
@end

@implementation NewLevelSelectScene
-(void)didMoveToView:(SKView *)view{
    [self initialize];
    [self createLevels];
}
#pragma mark - Touch Actions
-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    SKNode *node = [self nodeAtPoint:[[touches anyObject] locationInNode:self]];
    if ([node.name hasPrefix:@"Button"]){
        NSString *levelText = node.name;
        levelText = [levelText stringByTrimmingCharactersInSet:[NSCharacterSet letterCharacterSet]];
        NSInteger levelNumber = levelText.integerValue;
        if (levelNumber<=[[IEDataManager sharedManager] highestUnlock]){
            [self prepareToLeave];
            MainScene *scene = [[MainScene alloc] initWithSize:self.view.bounds.size];
            scene.controller = [IEBounceLevelController controllerWithLevelNumber:levelNumber];
            scene.colorIndex = self.pageIndex;
            scene.scaleMode = self.scaleMode;
            [self.view presentScene:scene];
        }
        else{
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Level %i is locked", (int)levelNumber] message:[NSString stringWithFormat:@"Skip level %i", (int)[IEDataManager sharedManager].highestUnlock] preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Skip Level" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                __weak ViewController *vc = (ViewController*)self.view.window.rootViewController;
                [vc skipLevelPressed:nil];
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
            ViewController *vc = (ViewController*)self.view.window.rootViewController;
            [vc presentViewController:alertController animated:YES completion:nil];
        }
    }
}
-(void)prepareToLeave{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:self.pageIndex] forKey:@"lastPage"];
    [self.view removeGestureRecognizer:self.left];
    [self.view removeGestureRecognizer:self.right];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"hidePageControl" object:nil];
}
#pragma mark - Gesture Recogniztion actions
-(void)swipeLeft{
    NSInteger last = self.rows*self.columns*(self.pageIndex+1);
    if (last>=[[IEDataManager sharedManager] localLevelCount])
        return;
    
    NewLevelSelectScene *scene = [[NewLevelSelectScene alloc] initWithSize:self.view.bounds.size];
    scene.scaleMode = self.scaleMode;
    scene.pageIndex = self.pageIndex+1;
    scene.rows = self.rows;
    scene.columns = self.columns;
    [self.view presentScene:scene transition:[SKTransition pushWithDirection:SKTransitionDirectionLeft duration:0.25]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"incrementPageControl" object:nil];
}
-(void)swipeRight{
    if (self.pageIndex == 0)
        return;
    
    NewLevelSelectScene *scene = [[NewLevelSelectScene alloc] initWithSize:self.view.bounds.size];
    scene.scaleMode = self.scaleMode;
    scene.pageIndex = self.pageIndex-1;
    scene.rows = self.rows;
    scene.columns = self.columns;
    [self.view presentScene:scene transition:[SKTransition pushWithDirection:SKTransitionDirectionRight duration:0.25]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"decrementPageControl" object:nil];
}
#pragma mark - Helper Methods
-(void)initialize{
    AppDelegate *delgate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    self.backgroundColor = [delgate.arrayOfColors objectAtIndex:self.pageIndex];
    self.left = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeft)];
    self.right = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRight)];
    self.left.direction = UISwipeGestureRecognizerDirectionLeft;
    self.right.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:self.left];
    [self.view addGestureRecognizer:self.right];
}
-(void)createLevels{
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    const CGFloat bufferTopBottom = self.size.height/15;
    CGFloat bufferX = self.size.width/self.columns;
    CGFloat bufferY = (self.size.height-2*bufferTopBottom)/self.rows;
    
    NSInteger firstNumber = self.pageIndex*(self.rows*self.columns)+1;
    
    NSUInteger currentNumber = firstNumber;
    BOOL stop = NO;
    for (int k = 0;k<self.rows;k++){
        for (int i = 0;i<self.columns;i++){
            if(currentNumber>[[IEDataManager sharedManager] localLevelCount]){
                stop = YES;
                break;
            }
            CGPoint location = CGPointMake(bufferX/2+bufferX*i, self.size.height-bufferTopBottom-bufferY/2-bufferY*k);
            SKSpriteNode *sprite;
            if (isIpad)
                sprite = [[SKSpriteNode alloc] initWithColor:[SKColor whiteColor] size:CGSizeMake(self.size.width/DIM_FACTOR_IPAD, self.size.width/DIM_FACTOR_IPAD)];
            else
                sprite = [[SKSpriteNode alloc] initWithColor:[SKColor whiteColor] size:CGSizeMake(self.size.width/DIM_FACTOR, self.size.width/DIM_FACTOR)];
            
            sprite.position = location;
            SKShapeNode *shape = [SKShapeNode node];
            if (isIpad)
                shape.path = CGPathCreateWithRoundedRect(CGRectMake(-self.size.width/DIM_FACTOR_IPAD, -self.size.width/DIM_FACTOR_IPAD, self.size.width/DIM_FACTOR_IPAD*2, self.size.width/DIM_FACTOR_IPAD*2), 12, 12, NULL);
            else
                shape.path = CGPathCreateWithRoundedRect(CGRectMake(-self.size.width/DIM_FACTOR, -self.size.width/DIM_FACTOR, self.size.width/DIM_FACTOR*2, self.size.width/DIM_FACTOR*2), 12, 12, NULL);
            
            if (![delegate hasDarkColorSchemeForIndex:self.pageIndex]){
                shape.fillColor = [SKColor whiteColor];
                shape.strokeColor = [SKColor whiteColor];
            }
            else{
                shape.fillColor = [SKColor darkGrayColor];
                shape.strokeColor = [SKColor darkGrayColor];
            }
            SKTexture *texture = [self.view textureFromNode:shape];
            sprite.texture = texture;
            sprite.name = [NSString stringWithFormat:@"Button%i", (int)currentNumber];
            [self addChild:sprite];
            
            SKLabelNode *label = [SKLabelNode labelNodeWithFontNamed:@"Roboto-Thin"];
            label.fontColor = self.backgroundColor;
            if (isIpad)
                label.fontSize = 50;
            else
                label.fontSize = 25;
            label.text = [NSString stringWithFormat:@"%i", (int)currentNumber];
            [label setHorizontalAlignmentMode:SKLabelHorizontalAlignmentModeCenter];
            [label setVerticalAlignmentMode:SKLabelVerticalAlignmentModeCenter];
            label.name = [NSString stringWithFormat:@"Button%i", (int) currentNumber];
            label.position = CGPointZero;
            [sprite addChild:label];
            NSInteger stars = [[IEDataManager sharedManager] starsForLevel:currentNumber];
            
            if ([IEDataManager sharedManager].highestUnlock<currentNumber){
                SKShapeNode *black = [SKShapeNode node];
                black.path = shape.path;
                black.fillColor = [SKColor blackColor];
                black.strokeColor = [SKColor blackColor];
                texture = [self.view textureFromNode:black];
                SKSpriteNode *blackMask = [SKSpriteNode spriteNodeWithTexture:texture];
                blackMask.alpha = 0.5;
                blackMask.position = CGPointZero;
                blackMask.size = sprite.size;
                SKSpriteNode *lock = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"lockicon.png"]];
                lock.size = CGSizeMake(sprite.size.width/2, sprite.size.width/2);
                lock.position = CGPointZero;
                blackMask.name = [NSString stringWithFormat:@"Button%i", (int)currentNumber];
                lock.name = [NSString stringWithFormat:@"Button%i", (int)currentNumber];
                [blackMask addChild:lock];
                [sprite addChild:blackMask];
            }
            currentNumber++;
            if (stars == 1){
                SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"star.png"]];
                if (isIpad)
                    star.size = CGSizeMake(sprite.size.width/STAR_DIM_FACTOR_IPAD, sprite.size.height/STAR_DIM_FACTOR_IPAD);
                else
                    star.size = CGSizeMake(sprite.size.width/STAR_DIM_FACTOR, sprite.size.height/STAR_DIM_FACTOR);
                star.position = CGPointMake(0, -sprite.size.height/2-star.size.height/2);
                [sprite addChild:star];
                star.name = [NSString stringWithFormat:@"Button%i", (int)currentNumber];
            }
            else if (stars == 2){
                SKSpriteNode *star1 = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"star.png"]];
                if (isIpad)
                    star1.size = CGSizeMake(sprite.size.width/STAR_DIM_FACTOR_IPAD, sprite.size.height/STAR_DIM_FACTOR_IPAD);
                else
                    star1.size = CGSizeMake(sprite.size.width/STAR_DIM_FACTOR, sprite.size.height/STAR_DIM_FACTOR);
                star1.position = CGPointMake(-sprite.size.width/6, -sprite.size.height/2-star1.size.height/2);
                star1.name = [NSString stringWithFormat:@"Button%i", (int)currentNumber];
                SKSpriteNode *star2 = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"star.png"]];
                if (isIpad)
                    star2.size = CGSizeMake(sprite.size.width/STAR_DIM_FACTOR_IPAD, sprite.size.height/STAR_DIM_FACTOR_IPAD);
                else
                    star2.size = CGSizeMake(sprite.size.width/STAR_DIM_FACTOR, sprite.size.height/STAR_DIM_FACTOR);
                star2.position = CGPointMake(+sprite.size.width/6, -sprite.size.height/2-star2.size.height/2);
                star2.name = [NSString stringWithFormat:@"Button%i", (int)currentNumber];
                [sprite addChild:star1];
                [sprite addChild:star2];
            }
            else if (stars == 3){
                for (int k = 0;k<stars;k++){
                    SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"star.png"]];
                    if (isIpad)
                        star.size = CGSizeMake(sprite.size.width/STAR_DIM_FACTOR_IPAD, sprite.size.height/STAR_DIM_FACTOR_IPAD);
                    else
                        star.size = CGSizeMake(sprite.size.width/STAR_DIM_FACTOR, sprite.size.height/STAR_DIM_FACTOR);
                    if (k == 0)
                        star.position = CGPointMake(0, -star.size.height/2-sprite.size.height/2);
                    else if (k == 1)
                        star.position = CGPointMake(-star.size.width-sprite.size.width/11, -star.size.height/2-sprite.size.height/2);
                    else
                        star.position = CGPointMake(+star.size.width+sprite.size.width/11, -star.size.height/2-sprite.size.height/2);
                    star.name = [NSString stringWithFormat:@"Button%i", (int)currentNumber];
                    [sprite addChild:star];
                }
            }
        }
        if (stop)
            break;
    }
}
@end

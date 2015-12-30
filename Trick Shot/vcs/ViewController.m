//
//  ViewController.m
//  Circle Test
//
//  Created by Eric Dufresne on 2015-06-25.
//  Copyright (c) 2015 Eric Dufresne. All rights reserved.
//

#import "ViewController.h"
#import "MenuScene.h"
#import "IEBounceLevelController.h"
#import "IEDataManager.h"
#import "AppDelegate.h"
#define scenedebug YES

@interface ViewController ()
{
    NSTimer *tutorialTimer;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    SKView *view = (SKView*)self.view;
    self.pageControl.hidden = YES;
    const int rows = 5;
    const int columns = 4;
    self.pageControl.numberOfPages = (NSInteger)(ceil((double)[[IEDataManager sharedManager] localLevelCount]/(double)(rows*columns)));
    self.pageControl.currentPageIndicatorTintColor = [UIColor darkGrayColor];
    self.pageControl.pageIndicatorTintColor = [UIColor colorWithRed:0.666 green:0.666 blue:0.666 alpha:0.5];
    
    if (scenedebug){
        view.showsFPS = YES;
        view.showsNodeCount = YES;
        view.showsDrawCount = YES;
        view.showsPhysics = YES;
    }
    
    IEDataManager *manager = [IEDataManager sharedManager];
    if (manager.showTutorial)
        tutorialTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(showTutorial) userInfo:nil repeats:NO];
    
    MenuScene *scene = [[MenuScene alloc] initWithSize:self.view.bounds.size];
    scene.scaleMode = SKSceneScaleModeAspectFill;
    [view presentScene:scene];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:@"incrementPageControl" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:@"decrementPageControl" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:@"hidePageControl" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:@"showPageControl" object:nil];
}
-(BOOL)prefersStatusBarHidden{
    return YES;
}
-(void)handleNotification:(NSNotification*)notification{
    if ([notification.name isEqualToString:@"incrementPageControl"])
        self.pageControl.currentPage++;
    else if ([notification.name isEqualToString:@"decrementPageControl"])
        self.pageControl.currentPage--;
    else if ([notification.name isEqualToString:@"hidePageControl"])
        self.pageControl.hidden = YES;
    else if ([notification.name isEqualToString:@"showPageControl"])
        self.pageControl.hidden = NO;
}
-(void)showTutorial{
    /*
    [self performSegueWithIdentifier:@"showTutorial" sender:self];
    [tutorialTimer invalidate];
    tutorialTimer = nil;
     */
}

@end

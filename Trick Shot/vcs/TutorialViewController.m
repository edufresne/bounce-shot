//
//  TutorialViewController.m
//  Trick Shot
//
//  Created by Eric Dufresne on 2015-10-15.
//  Copyright (c) 2015 Eric Dufresne. All rights reserved.
//

#import "TutorialViewController.h"
#import "TutorialContentViewController.h"
#import "AppDelegate.h"
#import "IEDataManager.h"

@implementation TutorialViewController
-(BOOL)prefersStatusBarHidden{
    return YES;
}
-(void)viewDidLoad{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.863 green:0.910 blue:0.922 alpha:1.00];
    NSMutableArray *array = [NSMutableArray array];
    for (int k = 1;k<=6;k++){
        [array addObject:[NSString stringWithFormat:@"tutscreen%i.jpg", k]];
    }
    self.imageNames = [NSArray arrayWithArray:array];
    
    //Instantiates View controller
    self.pageController = [self.storyboard instantiateViewControllerWithIdentifier:@"PageController"];
    self.pageController.dataSource = self;
    //Sets initial view controller for page controller.
    TutorialContentViewController *viewController = [self viewControllerAtIndex:0];
    NSArray *vcs = @[viewController];
    [self.pageController setViewControllers:vcs direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
    
    //Adds room for UIPageControl and title at top
    self.pageController.view.frame = CGRectMake(7.5, 30, self.view.frame.size.width-15, self.view.frame.size.height-30);
    
    //Settings pages parent view controller, parent view and calling didMove method
    [self addChildViewController:self.pageController];
    [self.view addSubview:self.pageController.view];
    [self.pageController didMoveToParentViewController:self];
}
-(void)viewWillLayoutSubviews{
    [super viewWillLayoutSubviews];
    
}
- (IBAction)pressedSkip:(id)sender {
    IEDataManager *manager = [IEDataManager sharedManager];
    manager.showTutorial = NO;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"showTutorial"];
    NSLog(@"%i", manager.showTutorial);
    [self.pageController.view removeFromSuperview];
    [self.pageController removeFromParentViewController];
    [self dismissViewControllerAnimated:YES completion:nil];
}
#pragma mark - UIPageViewController Data Source
-(UIViewController*)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController{
    
    TutorialContentViewController *vc = (TutorialContentViewController*)viewController;
    NSInteger index = vc.pageIndex;
    if (index == NSNotFound)
        return nil;
    index++;
    if (index == self.imageNames.count)
        return nil;
    return [self viewControllerAtIndex:index];
}
-(UIViewController*)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController{
    TutorialContentViewController *vc = (TutorialContentViewController*)viewController;
    NSInteger index = vc.pageIndex;
    if (index == 0 || index == NSNotFound)
        return nil;
    index--;
    return [self viewControllerAtIndex:index];
}
-(NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController{
    return self.imageNames.count;
}
-(NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController{
    return 0;
}

#pragma mark - Helper Index
-(TutorialContentViewController*)viewControllerAtIndex:(NSInteger)index{
    if (index<0 || index>=self.imageNames.count)
        return nil;
    
    TutorialContentViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"ContentController"];
    vc.imageName = [self.imageNames objectAtIndex:index];
    vc.pageIndex = index;
    return vc;
}
@end

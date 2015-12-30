//
//  TutorialViewController.h
//  Trick Shot
//
//  Created by Eric Dufresne on 2015-10-15.
//  Copyright (c) 2015 Eric Dufresne. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TutorialViewController : UIViewController <UIPageViewControllerDataSource>
@property (strong, nonatomic) UIPageViewController *pageController;
@property (strong, nonatomic) NSArray *imageNames;
- (IBAction)pressedSkip:(id)sender;
@end

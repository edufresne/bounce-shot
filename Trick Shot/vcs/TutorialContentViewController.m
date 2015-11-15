//
//  TutorialContentViewController.m
//  Trick Shot
//
//  Created by Eric Dufresne on 2015-10-15.
//  Copyright (c) 2015 Eric Dufresne. All rights reserved.
//

#import "TutorialContentViewController.h"
#import "AppDelegate.h"

@interface TutorialContentViewController ()

@end

@implementation TutorialContentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    self.view.backgroundColor = [delegate.arrayOfColors objectAtIndex:0];
    self.imageView.image = [UIImage imageNamed:self.imageName];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

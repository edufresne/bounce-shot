//
//  TutorialContentViewController.h
//  Trick Shot
//
//  Created by Eric Dufresne on 2015-10-15.
//  Copyright (c) 2015 Eric Dufresne. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TutorialContentViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) NSString *imageName;
@property (assign, nonatomic) NSUInteger pageIndex;
@end

//
//  ViewController.h
//  Circle Test
//
//  Created by Eric Dufresne on 2015-06-25.
//  Copyright (c) 2015 Eric Dufresne. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>
#import <StoreKit/StoreKit.h>

@import GoogleMobileAds;
@interface ViewController : UIViewController <GKGameCenterControllerDelegate, SKProductsRequestDelegate, SKPaymentTransactionObserver, GADInterstitialDelegate>

// Page control that is the current selected page if NewLevelSelectScene is active
@property (weak, nonatomic) IBOutlet UIPageControl *pageControl;

// Skip levels button that is present if NewLevelSelectScene is active
@property (weak, nonatomic) IBOutlet UIButton *skipLevels;

// Button that navigates from NewLevelSelectScene to MenuScene
@property (weak, nonatomic) IBOutlet UIButton *backButton;

// IAPs
@property (strong, nonatomic) SKProduct *removeAds;
@property (strong, nonatomic) SKProduct *buySkips;

// Action methods
- (IBAction)backButtonPressed:(id)sender;
- (IBAction)skipLevelPressed:(id)sender;

// Methods called for handling GameCenter or IAP requests by user.
-(void)attemptAuthenticateForLeaderboard;
-(void)purchaseRemoveAds;
-(void)restorePurchases;

//Shows tutorial from SettingsScene
-(void)showTutorial;
@end


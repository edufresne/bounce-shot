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
#import "NewLevelSelectScene.h"
//Set to YES if FPS and other debug info should be shown 
#define scenedebug NO
#define SESSIONS_PER_AD 4

@interface ViewController ()
{
    NSTimer *tutorialTimer;
    GADInterstitial *interstitial;
}
@end

@implementation ViewController

//viewDidLoad is the first method called. View controller subviews hidden and initial scene is presented. Observing notifications for UIPageControl, interstitial ads.
- (void)viewDidLoad {
    [super viewDidLoad];
    self.backButton.hidden = YES;
    self.skipLevels.hidden = YES;
    [self getProducts];
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
    
    MenuScene *scene = [[MenuScene alloc] initWithSize:self.view.bounds.size];
    scene.scaleMode = SKSceneScaleModeAspectFill;
    [view presentScene:scene];
    
    
    if ([IEDataManager sharedManager].showTutorial)
        tutorialTimer = [NSTimer scheduledTimerWithTimeInterval:1.25 target:self selector:@selector(showTutorial) userInfo:nil repeats:NO];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:@"incrementPageControl" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:@"decrementPageControl" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:@"hidePageControl" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:@"showPageControl" object:nil];
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    if (!delegate.adsRemoved){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:@"showInterstitial" object:nil];
        [self createInterstitial];
    }
}

//viewDidLayoutSubviews initializes level skip text as IEDataManager is a heavy computation to load and must be done after this is loaded
-(void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    self.skipLevels.titleLabel.text = [NSString stringWithFormat:@"Level Skips: %i", (int)[IEDataManager sharedManager].levelSkips];
}

//requests hidden status bar
-(BOOL)prefersStatusBarHidden{
    return YES;
}

//handles all notifications for 'showInterstitial' 'pageControlIncrement' 'pageControlDecrement' 'hidePageControl' 'showPageControl' calls respective methods
-(void)handleNotification:(NSNotification*)notification{
    if ([notification.name isEqualToString:@"incrementPageControl"])
        self.pageControl.currentPage++;
    else if ([notification.name isEqualToString:@"decrementPageControl"])
        self.pageControl.currentPage--;
    else if ([notification.name isEqualToString:@"hidePageControl"]){
        self.backButton.hidden = YES;
        self.skipLevels.hidden = YES;
        self.pageControl.hidden = YES;
    }
    else if ([notification.name isEqualToString:@"showPageControl"]){
        self.skipLevels.hidden = NO;
        self.backButton.hidden = NO;
        self.pageControl.hidden = NO;
    }
    else if ([notification.name isEqualToString:@"showInterstitial"]){
        [self performSelector:@selector(showInterstitial) withObject:nil afterDelay:1.0];
    }
}

//performs segue to TutorialViewController
-(void)showTutorial{
    NSLog(@"Show tutorial");
    [self performSegueWithIdentifier:@"showTutorial" sender:self];
    [tutorialTimer invalidate];
    tutorialTimer = nil;
}

////methods that respond to back button and skip level buttons being pressed.
#pragma mark - Action methods

//called if back button is pressed. Goes back to MainMenuScene
- (IBAction)backButtonPressed:(id)sender {
    SKView *view = (SKView*)self.view;
    NewLevelSelectScene *scene = (NewLevelSelectScene*)view.scene;
    [scene prepareToLeave];
    MenuScene *newScene = [[MenuScene alloc] initWithSize:self.view.bounds.size];
    newScene.scaleMode = scene.scaleMode;
    [view presentScene:newScene];
}

//starts alertcontroller if no skips left, or confirms use of level skip if skips left. If passed nil as sender no confirmation is given.
- (IBAction)skipLevelPressed:(id)sender {
    __weak ViewController *weakself = self;
    IEDataManager *manager = [IEDataManager sharedManager];
    if (manager.levelSkips==0){
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.formatterBehavior = NSNumberFormatterBehavior10_4;
        formatter.numberStyle = NSNumberFormatterCurrencyStyle;
        formatter.locale = self.buySkips.priceLocale;
        NSString *priceString = [formatter stringFromNumber:self.buySkips.price];

        UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Out of Level Skips" message:[NSString stringWithFormat:@"Buy 3 for %@", priceString] preferredStyle:UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:@"No Thanks" style:UIAlertActionStyleCancel handler:nil]];
        [controller addAction:[UIAlertAction actionWithTitle:@"Buy More" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakself purchaseSkips];
        }]];
        [self presentViewController:controller animated:YES completion:nil];
    }
    else{
        if (sender != nil){
            UIAlertController *controller = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Skip level %i", (int)[IEDataManager sharedManager].highestUnlock] message:@"Are you sure?" preferredStyle:UIAlertControllerStyleAlert];
            [controller addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [controller addAction:[UIAlertAction actionWithTitle:@"Skip Level" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[IEDataManager sharedManager] skippedLevel];
                dispatch_async(dispatch_get_main_queue(), ^{
                    SKView *view = (SKView*)weakself.view;
                    NewLevelSelectScene *scene = [[NewLevelSelectScene alloc] initWithSize:self.view.bounds.size];
                    NewLevelSelectScene *currentScene = (NewLevelSelectScene*)view.scene;
                    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:currentScene.pageIndex] forKey:@"lastPage"];
                    scene.scaleMode = currentScene.scaleMode;
                    scene.pageIndex = currentScene.pageIndex;
                    scene.rows = currentScene.rows;
                    scene.columns = currentScene.columns;
                    [view presentScene:scene];
                    weakself.skipLevels.titleLabel.text = [NSString stringWithFormat:@"Level Skips: %i", (int)[IEDataManager sharedManager].levelSkips];
                });
            }]];
            [self presentViewController:controller animated:YES completion:nil];
        }
        else{
            [[IEDataManager sharedManager] skippedLevel];

            SKView *view = (SKView*)self.view;
            NewLevelSelectScene *scene = [[NewLevelSelectScene alloc] initWithSize:self.view.bounds.size];
            NewLevelSelectScene *currentScene = (NewLevelSelectScene*)view.scene;
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:currentScene.pageIndex] forKey:@"lastPage"];
            scene.scaleMode = currentScene.scaleMode;
            scene.pageIndex = currentScene.pageIndex;
            scene.rows = currentScene.rows;
            scene.columns = currentScene.columns;
            [view presentScene:scene];
            self.skipLevels.titleLabel.text = [NSString stringWithFormat:@"Level Skips: %i", (int)[IEDataManager sharedManager].levelSkips];
        }
        
    }
}

////methods for GameKit leaderboard
#pragma mark - Game Center

//first method called by MenuScene if leaderboard is pressed. Presents AppDelegate's game center view controller if user is not authenticated. If authenticated showLeaderboard is called.
-(void)attemptAuthenticateForLeaderboard{
    if ([GKLocalPlayer localPlayer].isAuthenticated)
        [self showLeaderboard];
    else{
        AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
        if (delegate.reachable){
            if (delegate.gameCenterViewController!=nil)
                [self presentViewController:delegate.gameCenterViewController animated:YES completion:nil];
        }
        else{
            UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Cannot Connect to Game Center" message:@"No Internet Connection" preferredStyle:UIAlertControllerStyleAlert];
            [controller addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:controller animated:YES completion:nil];
        }
    }
}

//Creates new leaderboard view controller and presents it. Reports score
-(void)showLeaderboard{
    GKGameCenterViewController *vc = [[GKGameCenterViewController alloc] init];
    if (vc!=nil){
        vc.gameCenterDelegate = self;
        vc.viewState = GKGameCenterViewControllerStateLeaderboards;
        vc.leaderboardIdentifier = @"BounceDraw_Leaderboard";
        IEDataManager *manager = [IEDataManager sharedManager];
        NSNumber *number = [NSNumber numberWithUnsignedInteger:manager.starCount];
        GKScore *score = [[GKScore alloc] initWithLeaderboardIdentifier:vc.leaderboardIdentifier];
        score.value = (int64_t)number.unsignedIntegerValue;
        [self presentViewController:vc animated:YES completion:nil];
        [GKScore reportScores:@[score] withCompletionHandler:^(NSError * _Nullable error) {
            if (error)
                NSLog(@"failed reporting scores");
        }];
    }
}

//Delegate method. Dismisses game center view controller
-(void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController{
    [self dismissViewControllerAnimated:YES completion:nil];
}

////methods for IAPs (In app purchases)
#pragma mark - Store Kit Methods

//first method that fetches products from itunes
-(void)getProducts{
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObjects:@"BounceDraw.RemoveAds", @"BounceDraw.SkipLevel", nil]];
    request.delegate = self;
    [request start];
}

//Called once products have been fetched. Either prints invalid identifiers or sets removeAds and buySkips SKProducts to their in app purchases.
-(void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    NSArray *products = [response products];
    if (products.count == 0){
        NSLog(@"Invalid Product identifiers");
        NSArray *invalidProducts = [response invalidProductIdentifiers];
        for (NSString *string in invalidProducts){
            NSLog(@"%@", string);
        }
    }
    else{
        for (SKProduct *product in products){
            if ([product.productIdentifier isEqualToString:@"BounceDraw.RemoveAds"])
                self.removeAds = product;
            else if ([product.productIdentifier isEqualToString:@"BounceDraw.SkipLevel"])
                self.buySkips = product;
        }
    }
}

//Called from MenuScene if user presses Remove Ads button. Adds SKPayment with removeAds to queue
-(void)purchaseRemoveAds{
    if (self.removeAds != nil){
        SKPayment *payment = [SKPayment paymentWithProduct:self.removeAds];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

//Called from skipLevelPressed: and adds SKPayment for buySkips.
-(void)purchaseSkips{
    if (self.buySkips != nil){
        SKPayment *payment = [SKPayment paymentWithProduct:self.buySkips];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

//Called if restore button is pressed. Attempts to restore any old purchases the user has bought.
-(void)restorePurchases{
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

//Handler method during in app purchase process. Notifies if transaction has failed or cancelled. Calls finishTransactionWithIdentifier: if completed
-(void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    for (SKPaymentTransaction *transaction in transactions){
        SKPaymentTransactionState state = transaction.transactionState;
        if (state == SKPaymentTransactionStateRestored || state == SKPaymentTransactionStatePurchased){
            [self finishTransactionWithIdentifier:transaction.payment.productIdentifier state:state];
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
        else if ( state == SKPaymentTransactionStateFailed){
            if (transaction.error.code == SKErrorPaymentCancelled){
                UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Transaction Not Completed" message:@"Transactoin Cancelled" preferredStyle:UIAlertControllerStyleAlert];
                [controller addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:controller animated:YES completion:nil];
            }
            else{
                UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Transaction Not Completed" message:transaction.error.description preferredStyle:UIAlertControllerStyleAlert];
                [controller addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:controller animated:YES completion:nil];
            }
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
    }
}

//Handles behaviour of both in app purchases. Saves the in app purchase data in IEDataManager
-(void)finishTransactionWithIdentifier:(NSString*)identifier state:(SKPaymentTransactionState) state{
    if ([identifier isEqualToString:@"BounceDraw.RemoveAds"]){
        AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
        delegate.adsRemoved = YES;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"adsRemoved"];
        
        SKView *view = (SKView*)self.view;
        MenuScene *scene = (MenuScene*)view.scene;
        SKNode *node = [scene childNodeWithName:@"removeAds"];
        
        if (node)
            [node removeFromParent];
        node = [scene childNodeWithName:@"rate"];
        if (node)
            node.position = CGPointMake(scene.size.width/2, node.position.y);
        @try {
            [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:@"showInterstitial"];
        }
        @catch (NSException *exception) {}
        interstitial = nil;
        
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Remove Ads Purchased" message:@"Ads Removed" preferredStyle:UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:controller animated:YES completion:nil];
    }
    else if ([identifier isEqualToString:@"BounceDraw.SkipLevel"]){
        IEDataManager *manager = [IEDataManager sharedManager];
        [manager purchasedSkips];
        self.skipLevels.titleLabel.text = [NSString stringWithFormat:@"Level Skips: %i", (int)manager.levelSkips];
    }
    if (state == SKPaymentTransactionStateRestored){
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Successfully Restored Purchases" message:@"Ads Removed" preferredStyle:UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:controller animated:YES completion:nil];
    }
}

//Methods for ad delivery
#pragma mark - Interstitial Ads

//Initializes interstitial ad if adsRemoved = NO. Must be called each time interstitial is used up.
-(void)createInterstitial{
    interstitial = [[GADInterstitial alloc] initWithAdUnitID:@"ca-app-pub-5566434891389365/6212715534"];
    interstitial.delegate = self;
#warning change to legitimate ad request for deployment
    GADRequest *request = [GADRequest request];
    request.testDevices = @[ @"d58b8364c21cbbb0cd6e615c9f9feeb3" ];
    [interstitial loadRequest:request];
}

//Shows the interstitial if it is ready and if the number of calls is in the interval of SESSIONS_PER_AD. This variable is how many games must be won/lost before an ad is shown.
-(void)showInterstitial{
    static int numberOfSessions = 0;
    numberOfSessions++;
    if (numberOfSessions%SESSIONS_PER_AD== 0 && interstitial){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (interstitial.isReady)
                [interstitial presentFromRootViewController:self];
        });
    }
}

//Delegate method called after x is pressed on ad. Creates new interstitial.
-(void)interstitialDidDismissScreen:(GADInterstitial *)ad{
    [self createInterstitial];
}
@end

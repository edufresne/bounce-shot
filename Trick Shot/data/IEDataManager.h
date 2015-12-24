//
//  IEDataManager.h
//  Circle Test
//
//  Created by Eric Dufresne on 2015-07-03.
//  Copyright (c) 2015 Eric Dufresne. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>
#import "IEBounceLevelController.h"

@interface IEDataManager : NSObject
@property (assign, nonatomic) NSUInteger highestUnlock;
@property (assign, nonatomic) BOOL hasRanBefore;
@property (assign, nonatomic) BOOL isLoaded;
@property (assign, nonatomic) BOOL showTutorial;
@property (assign, nonatomic) NSUInteger localLevelCount;
@property (assign, nonatomic) NSUInteger levelSkips;
@property (strong, nonatomic) NSMutableDictionary *powerupMap;
+(IEDataManager*)sharedManager;
-(void)completedLevel:(NSUInteger)level withStars:(NSUInteger)stars;
-(void)skippedLevel;
-(void)purchasedSkips;
-(NSUInteger)starsForLevel:(NSUInteger)level;
-(NSUInteger)starCount;
+(NSString*)keyForPowerupType:(IEPowerupType)type;

@end

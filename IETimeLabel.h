//
//  IETimeLabel.h
//  Trick Shot
//
//  Created by Eric Dufresne on 2015-12-20.
//  Copyright © 2015 Eric Dufresne. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@class IETimeLabel;
@class IEDecrementTimeLabel;

@protocol IETimeLabelDelegate <NSObject>
@optional
-(void)timerDidIncrement:(IETimeLabel*)timeLabel;
-(void)timerDidDecrement:(IEDecrementTimeLabel*)timeLabel;
-(void)timerDidFinishCountDown:(IEDecrementTimeLabel*)timeLabel;
@end

@interface IETimeLabel : SKLabelNode
@property (weak, nonatomic) id<IETimeLabelDelegate> delegate;
@property (assign, nonatomic) NSInteger seconds;
@property (assign, nonatomic) NSInteger minutes;
@property (assign, nonatomic) NSInteger hours;
@property (assign, nonatomic) BOOL started;
-(NSInteger)currentTimeInSeconds;
-(void)start;
-(void)stop;
-(void)restart;
+(instancetype)timeLabel;
@end

@interface IEDecrementTimeLabel : IETimeLabel
-(id)initWithFontNamed:(NSString*)fontName seconds:(NSInteger)seconds;
+(instancetype)timeLabelWithFontNamed:(NSString*)fontName seconds:(NSInteger)seconds;
@end
@interface IETimeValue : NSObject
@property (assign, nonatomic) NSInteger seconds;
@property (assign, nonatomic) NSInteger minutes;
@property (assign, nonatomic) NSInteger hours;
-(id)initWithHours:(NSInteger)hours minutes:(NSInteger)minutes seconds:(NSInteger)seconds;
+(instancetype)timeValueWithHours:(NSInteger)hours minutes:(NSInteger)minutes seconds:(NSInteger)seconds;
@end

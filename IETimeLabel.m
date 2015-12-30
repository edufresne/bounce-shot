//
//  IETimeLabel.m
//  Trick Shot
//
//  Created by Eric Dufresne on 2015-12-20.
//  Copyright © 2015 Eric Dufresne. All rights reserved.
//

#import "IETimeLabel.h"

@interface IETimeLabel ()
{
    NSTimer *timer;
}
@end

@implementation IETimeLabel
-(id)initWithFontNamed:(NSString *)fontName{
    if (self = [super initWithFontNamed:fontName]){
        self.hours = 0;
        self.minutes = 0;
        self.seconds = 0;
        self.started = NO;
        self.text = @"00:00:00";
        self.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
        self.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    }
    return self;
}
+(instancetype)timeLabel{
    return [[self alloc] init];
}
-(void)start{
    timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    self.started = YES;
}
-(void)stop{
    [timer invalidate];
    self.started = NO;
}
-(void)restart{
    [timer invalidate];
    self.hours = 0;
    self.minutes = 0;
    self.seconds = 0;
    self.started = NO;
    self.text = @"00:00:00";
}
#pragma mark - Private Methods
-(void)tick{
    [self increment];
    self.text = [self description];
    if (self.delegate&& [self.delegate respondsToSelector:@selector(timerDidIncrement:)])
        [self.delegate timerDidIncrement:self];
}
-(void)increment{
    self.seconds++;
    while(self.seconds>=60 || self.minutes >= 60 || self.hours >= 60){
        if (self.seconds>= 60){
            self.seconds-=60;
            self.minutes++;
        }
        if (self.minutes>= 60){
            self.minutes-=60;
            self.hours++;
        }
    }
}
-(NSInteger)currentTimeInSeconds{
    return self.seconds+self.minutes*60+self.hours*3600;
}
-(NSString*)description{
    NSString *hoursString;
    NSString *minutesString;
    NSString *secondsString;
    if (self.hours<10)
        hoursString = [NSString stringWithFormat:@"0%i", (int)self.hours];
    else
        hoursString = [NSString stringWithFormat:@"%i", (int)self.hours];
    if (self.minutes<10)
        minutesString = [NSString stringWithFormat:@"0%i", (int)self.minutes];
    else
        minutesString = [NSString stringWithFormat:@"%i", (int)self.minutes];
    if (self.seconds<10)
        secondsString = [NSString stringWithFormat:@"0%i", (int)self.seconds];
    else
        secondsString = [NSString stringWithFormat:@"%i", (int)self.seconds];
    return [NSString stringWithFormat:@"%@:%@:%@", hoursString, minutesString, secondsString];
}
@end

@interface IEDecrementTimeLabel ()
{
    NSTimer *timer;
    NSInteger startSeconds;
}
@end
@implementation IEDecrementTimeLabel
-(id)initWithFontNamed:(NSString *)fontName{
    @throw [NSException exceptionWithName:NSGenericException reason:@"Operation init in decrement timer not supported unless start time is provided" userInfo:nil];
}
-(id)initWithFontNamed:(NSString *)fontName seconds:(NSInteger)seconds{
    if (self = [super initWithFontNamed:fontName]){
        self.seconds = seconds;
        startSeconds = seconds;
        self.text = [NSString stringWithFormat:@"%i", (int)seconds];
    }
    return self;
}
+(instancetype)timeLabelWithFontNamed:(NSString *)fontName seconds:(NSInteger)seconds{
    return [[self alloc] initWithFontNamed:fontName seconds:seconds];
}
-(void)start{
    timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    self.started = YES;
}
-(void)stop{
    [timer invalidate];
    self.started = NO;
}
-(void)restart{
    self.seconds = startSeconds;
    self.started = NO;
    [timer invalidate];
}
-(void)tick{
    [self decrement];
    if (self.delegate && [self.delegate respondsToSelector:@selector(timerDidDecrement:)])
        [self.delegate timerDidDecrement:self];
    self.text = [self description];
    if (self.text.intValue < 0){
        [timer invalidate];
        if (self.delegate && [self.delegate respondsToSelector:@selector(timerDidFinishCountDown:)])
            [self.delegate timerDidFinishCountDown:self];
        [self removeFromParent];
    }
}
-(void)decrement{
    self.seconds--;
}
-(NSString*)description{
    return [NSString stringWithFormat:@"%i", (int)self.seconds];
}
@end
@implementation IETimeValue
-(id)initWithHours:(NSInteger)hours minutes:(NSInteger)minutes seconds:(NSInteger)seconds{
    if (self = [super init]){
        self.hours = hours;
        self.minutes = minutes;
        self.seconds = seconds;
        
        if (self.hours<0 || self.minutes < 0 || self.seconds<0)
            @throw  [NSException exceptionWithName:NSInvalidArgumentException reason:@"Negative Time is Forbidden" userInfo:nil];
        
        [self normalize];
    }
    return self;
}
+(instancetype)timeValueWithHours:(NSInteger)hours minutes:(NSInteger)minutes seconds:(NSInteger)seconds{
    return [[self alloc] initWithHours:hours minutes:minutes seconds:seconds];
}
-(void)normalize{
    while (self.seconds>=60||self.minutes>=60||self.hours>=60){
        if (self.seconds>=60){
            self.seconds-=60;
            self.minutes++;
        }
        if (self.minutes>=60){
            self.minutes-=60;
            self.hours++;
        }
    }
}
-(NSString*)description{
    NSString *hoursString;
    NSString *minutesString;
    NSString *secondsString;
    if (self.hours>=10)
        hoursString = [NSString stringWithFormat:@"%i", (int)self.hours];
    else
        hoursString = [NSString stringWithFormat:@"0%i", (int)self.hours];
    if (self.minutes>=10)
        minutesString = [NSString stringWithFormat:@"%i", (int)self.minutes];
    else
        minutesString = [NSString stringWithFormat:@"0%i", (int)self.minutes];
    if (self.seconds>=10)
        secondsString = [NSString stringWithFormat:@"%i", (int)self.seconds];
    else
        secondsString = [NSString stringWithFormat:@"0%i", (int)self.seconds];
    return [NSString stringWithFormat:@"%@:%@:%@", hoursString, minutesString, secondsString];
}

@end

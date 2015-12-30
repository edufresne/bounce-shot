//
//  IEPointSelectionManager.m
//  Trick Shot
//
//  Created by Eric Dufresne on 2015-07-20.
//  Copyright (c) 2015 Eric Dufresne. All rights reserved.
//

#import "IEPointSelectionManager.h"

IELineSegment IELineSegmentMake(CGPoint first, CGPoint second){
    IELineSegment segment;
    segment.first = first;
    segment.second = second;
    return segment;
}
CGFloat distanceFromPoints(CGPoint first, CGPoint second){
    return sqrtf(powf(first.x-second.x, 2)+powf(first.y-second.y, 2));
}
CGFloat distanceFromPointToLine(IELineSegment segment, CGPoint point){
    
    CGFloat distance = distanceFromPoints(segment.first,segment.second);
    
    CGFloat result = fabs((segment.second.y-segment.first.y)*point.x-(segment.second.x-segment.first.x)*point.y+segment.second.x*segment.first.y-segment.first.x*segment.second.y)/distance;
    return result;
}
bool segmentInRangeFromPoint(IELineSegment segment, CGPoint point, CGFloat threshold){
    CGFloat distance = distanceFromPointToLine(segment, point);
    if (distance<=threshold)
    {
        CGFloat higherX;
        CGFloat higherY;
        CGFloat lowerX;
        CGFloat lowerY;
        if (segment.first.x>segment.second.x){
            higherX = segment.first.x;
            lowerX = segment.second.x;
        }
        else{
            higherX = segment.second.x;
            lowerX = segment.first.x;
        }
        if (segment.first.y>segment.second.y){
            higherY = segment.first.y;
            lowerY = segment.second.y;
        }
        else{
            higherY = segment.second.y;
            lowerY = segment.first.y;
        }
        bool result = (point.x<=higherX&&point.x>=lowerX)||(point.y>=lowerY&&point.y<=higherY);
        return result;
    }
    return false;
    
}
@implementation IEPointSelectionManager
-(id)init{
    if (self = [super init]){
        self.connections = [NSMutableArray array];
        self.hasSelection =NO;
        self.maxDistance = 20;
        self.selectedPoint = CGPointMake(-99, -99);
    }
    return self;
}
-(void)selectPoint:(CGPoint)point pressed:(BOOL)pressed{
    if (pressed){
        self.inTouch = YES;
        self.firstTouch = point;
        if (self.delegate&&[self.delegate respondsToSelector:@selector(selectedNewPoint:)])
            [self.delegate selectedNewPoint:point];
    }
    else{
        CGFloat distance = distanceFromPoints(point, self.firstTouch);
        if (distance>self.maxDistance){
            [self confirmPoint:point bypassDeletion: YES];
        }
        else{
            if (self.delegate&&[self.delegate respondsToSelector:@selector(deselectedPoint)])
                [self.delegate deselectedPoint];
            [self confirmPoint:point bypassDeletion:NO];
        }
    }
}
-(void)confirmPoint:(CGPoint)point bypassDeletion:(BOOL)bypass{
    if (bypass){
        IEPointPair *pair = [IEPointPair pairWithPoints:self.firstTouch second:point];
        BOOL notAllowed = pair.first.x<0||pair.first.x<0||pair.first.y<0||pair.second.y<0;
        self.hasSelection = NO;
        self.firstTouch = CGPointMake(-99, -99);
        if (![self containsPair:pair]&&!notAllowed)
            [self addPair:pair];
    }
    else{
        for (IEPointPair *pair in self.connections){
            IELineSegment segment = IELineSegmentMake(pair.first, pair.second);
            bool result = segmentInRangeFromPoint(segment, point, self.maxDistance);
            if (result){
                [self removePair:pair];
                break;
            }
        }
    }
}
-(BOOL)containsPair:(IEPointPair *)pair{
    for (IEPointPair *pairIndex in self.connections){
        if ([pairIndex equalsPointPair:pair])
            return true;
    }
    return false;
}
-(void)addPair:(IEPointPair *)pair{
    [self.connections addObject:pair];
    if (self.delegate&&[self.delegate respondsToSelector:@selector(didCreateConnection:)])
        [self.delegate didCreateConnection:pair];
}
-(void)removePair:(IEPointPair *)pair{
    [self.connections removeObject:pair];
    if (self.delegate&&[self.delegate respondsToSelector:@selector(didRemoveConnection:)])
        [self.delegate didRemoveConnection:pair];
}
-(IEPointPair*)connectionClosestToPoint:(CGPoint)point{
    CGFloat shortestDistance = self.maxDistance;
    IEPointPair *closestPair;
    for (IEPointPair *pair in self.connections){
        IELineSegment segment = IELineSegmentMake(pair.first, pair.second);
        CGFloat distance = distanceFromPointToLine(segment, point);
        if (distance<shortestDistance){
            shortestDistance = distance;
            closestPair = pair;
        }
    }
    return closestPair;
}
@end

@implementation IEPointPair
-(id)initWithPoints:(CGPoint)first second:(CGPoint)second{
    if (self = [super init]){
        self.first = first;
        self.second = second;
    }
    return self;
}
+(instancetype)pairWithPoints:(CGPoint)first second:(CGPoint)second{
    return [[self alloc] initWithPoints:first second:second];
}
-(BOOL)containsNode:(SKNode*)node{
    return [self.edgeShape isEqualToNode:node];
}
-(BOOL)equalsPointPair:(IEPointPair *)pair{
    bool pointResult = (pair.first.x==self.first.x&&pair.first.y==self.first.y&&pair.second.x==self.second.x&&pair.second.y==self.second.y)||(pair.first.x==self.second.x&&pair.second.x==self.first.x&&pair.first.y==self.first.y&&pair.second.y==self.first.y);
    return pointResult&&[self.dot1 isEqualToNode:pair.dot1]&&[self.dot2 isEqualToNode:pair.dot2]&&[pair.edgeShape isEqualToNode:self.edgeShape];
}
@end
@implementation IESimpleSelectionManager
-(id)init{
    if (self = [super init]){
        self.connections = [[NSMutableArray alloc] init];
        self.hasSelection = NO;
        self.selectedPoint = CGPointMake(-99, -99);
        self.minimumDrawDistance = 20.0;
    }
    return self;
}
-(void)startedSelection:(CGPoint)point{
    if (self.hasSelection)
        return;
    
    self.hasSelection = YES;
    self.selectedPoint = point;
    if (self.delegate && [self.delegate respondsToSelector:@selector(selectedNewPoint:)])
        [self.delegate selectedNewPoint:self.selectedPoint];
}
-(void)finishedSelection:(CGPoint)point{
    if (!self.hasSelection)
        return;
    if (distanceFromPoints(self.selectedPoint, point)>self.minimumDrawDistance){
        IEPointPair *pair = [IEPointPair pairWithPoints:self.selectedPoint second:point];
        self.selectedPoint = CGPointMake(-99, -99);
        self.hasSelection = NO;
        [self.connections addObject:pair];
        if (self.delegate && [self.delegate respondsToSelector:@selector(didCreateConnection:)])
            [self.delegate didCreateConnection:pair];
    }
    else{
        self.hasSelection = NO;
        if (self.delegate && [self.delegate respondsToSelector:@selector(deselectedPoint)])
            [self.delegate deselectedPoint];
        self.selectedPoint = CGPointMake(-99, -99);
    }
}
-(void)addPair:(IEPointPair *)pair{
    [self.connections addObject:pair];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didCreateConnection:)])
        [self.delegate didCreateConnection:pair];
}
-(void)removePair:(IEPointPair *)pair{
    [self.connections removeObject:pair];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didRemoveConnection:)])
        [self.delegate didRemoveConnection:pair];
}
-(IEPointPair*)connectionClosestToPoint:(CGPoint)point{
    CGFloat minDistance = self.minimumDrawDistance;
    IEPointPair *saved = nil;
    for (IEPointPair *pair in self.connections){
        IELineSegment segment = IELineSegmentMake(pair.first, pair.second);
        CGFloat distance = distanceFromPointToLine(segment, point);
        if (distance<minDistance){
            minDistance = distance;
            saved = pair;
        }
    }
    return saved;
}


@end

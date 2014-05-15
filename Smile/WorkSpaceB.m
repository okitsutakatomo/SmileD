//
//  WorkSpaceB.m
//  Smile
//
//  Created by Takatomo Okitsu on 2014/01/24.
//  Copyright (c) 2014年 Takatomo Okitsu. All rights reserved.
//

#import "WorkSpaceB.h"
#import "CAKeyframeAnimation+AHEasing.h"
#import <easing.h>
#import "SKBounceAnimation.h"
#import "CAAnimation+Blocks.h"

#define LOGO_TIMEOUT 120

@interface WorkSpaceB ()

@property (nonatomic, strong) NSMutableArray *logos;

@end

@implementation WorkSpaceB {
//    C4Shape *bigCircle;
    C4Timer *bgTimer;
    int backgroundId;
    C4Shape *hole;
    
}

-(void)setup {
    [super setup];
    
    self.logos = [NSMutableArray array];
    
    for (int i = 0; i < 30; i ++) {
        [self makeLogo:CGPointMake(self.canvas.width/2, self.canvas.height/2)];
    }

    self.canvas.backgroundColor = [super getBackgroundColor:backgroundId];
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(didReceiveData:) name:kNotificationKey object:nil];
    
    [self createHole];
    
    [self launchAdvertiser];
}

- (void)createHole
{
    CGRect space = CGRectMake(0,0,75,25);
    hole = [C4Shape ellipse:space];
    hole.center = CGPointMake(self.canvas.width/2, self.canvas.height - 40);
    hole.fillColor = [UIColor blackColor];
    hole.strokeColor = [UIColor blackColor];
    [self.canvas addShape:hole];
}

- (void)updateBg:(int)bgid
{
    UIColor *nextColor = [super getBackgroundColor:bgid];
    
    self.canvas.animationDuration = 0.25;
    self.canvas.backgroundColor = nextColor;
}

-(void)makeLogo:(CGPoint)position {
    C4Image *image = [C4Image imageNamed:@"d_small"];
    image.center = position;
    [self.canvas addImage:image];
    
    [self.logos addObject:image];
    [self runMethod:@"newPlace:" withObject:image afterDelay:0.0f];

    image.tag = [[NSDate date] timeIntervalSince1970];
}

-(void)newPlace: (C4Image *)sender {
    if (self.logos.count > 1 && sender.tag < [[NSDate date] timeIntervalSince1970] - LOGO_TIMEOUT) {
        [self.logos removeObject:sender]; //本当はhideLogoでやりたいがここでしょうがなく
        [self hideLogo:sender];
        return;
    }
    
    CGFloat time = ([C4Math randomInt:250]/100.0f) + 1.0f;
    sender.animationDuration = time;
    sender.center = CGPointMake(
                                [C4Math randomIntBetweenA:50 andB:self.canvas.width - 50],
                                [C4Math randomIntBetweenA:50 andB:self.canvas.height - 100]
                                );
    [self runMethod:@"newPlace:" withObject:sender afterDelay:time];
}

- (void)didReceiveData:(NSNotification *)notification
{
    NSDictionary *pointData = notification.userInfo;
    
    float startPointX = [[[pointData objectForKey:kStartPoint] objectForKey:@"x"] floatValue];
    float startPointY = [[[pointData objectForKey:kStartPoint] objectForKey:@"y"] floatValue];
    float endPointX = [[[pointData objectForKey:kEndPoint] objectForKey:@"x"] floatValue];
    float endPointY = [[[pointData objectForKey:kEndPoint] objectForKey:@"y"] floatValue];
    float controlPointX = [[[pointData objectForKey:kControlPoint] objectForKey:@"x"] floatValue];
    float controlPointY = [[[pointData objectForKey:kControlPoint] objectForKey:@"y"] floatValue];
    int bgid = [[pointData objectForKey:kBackgroundId] intValue];
    
    CGPoint originalStartPoint = CGPointMake(startPointX, startPointY);
    CGPoint originalEndPoint = CGPointMake(endPointX, endPointY);
    CGPoint originalControlPoint = CGPointMake(controlPointX, controlPointY);
    backgroundId = bgid;

    [self updateBg:backgroundId];

    CGPoint startPoint = CGPointMake(0, originalEndPoint.y);
    
    float controlX = MAX(originalStartPoint.x, originalControlPoint.x) -  MIN(originalStartPoint.x, originalControlPoint.x);
    float controlY = (originalEndPoint.y - originalControlPoint.y) * 2 + originalEndPoint.y;
    CGPoint contronPoint = CGPointMake(controlX, controlY);
    
    CGPoint endPoint = CGPointMake([C4Math randomIntBetweenA:300 andB:500], [C4Math randomIntBetweenA:500 andB:700]);
    
    [self addSmile:startPoint endPoint:endPoint controlPoint:contronPoint];
}

- (void)addSmile:(CGPoint)startPoint endPoint:(CGPoint)endPoint controlPoint:(CGPoint)controlPoint
{
    UIImageView *smileImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"d_small"]];
    smileImageView.center = startPoint;
    [self.canvas addSubview:smileImageView];
    
    [CATransaction begin];
    
    // move
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:startPoint];
    [path addQuadCurveToPoint:endPoint controlPoint:controlPoint];
    
    CAKeyframeAnimation *animation;
    animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    animation.duration = 2.0;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.path = path.CGPath;
    [animation setCompletion:^(BOOL finished) {
        [self makeLogo:smileImageView.center];
        [smileImageView removeFromSuperview];
    }];
    smileImageView.layer.position = endPoint;
    [smileImageView.layer addAnimation:animation forKey:nil];
    
    [CATransaction commit];

}

- (void)hideLogo:(C4Image*)image
{
    image.animationDuration = 2.0f;
    image.rotation += TWO_PI * 4;
    image.center = hole.center;
    
    CABasicAnimation *animation2;
    animation2 = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    animation2.fillMode = kCAFillModeForwards;
    animation2.removedOnCompletion = NO;
    animation2.duration = 2.0;
    animation2.toValue = @(0.2);
    animation2.fromValue = @(1.0);
    animation2.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    [animation2 setCompletion:^(BOOL finished) {
//        [self.logos removeObject:image];
        [image removeFromSuperview];
    }];
    [image.layer addAnimation:animation2 forKey:nil];
}

@end

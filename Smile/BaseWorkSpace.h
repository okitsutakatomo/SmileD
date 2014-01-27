//
//  BaseWorkSpace.h
//  Smile
//
//  Created by Takatomo Okitsu on 2014/01/24.
//  Copyright (c) 2014年 Takatomo Okitsu. All rights reserved.
//

#import "C4CanvasController.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

// Service name must be < 16 characters
static NSString * const kServiceName = @"multipeer";
static NSString * const kMessageKey = @"message";
static NSString * const kNotificationKey = @"notification";

static NSString * const kStartPoint = @"startpoint";
static NSString * const kEndPoint = @"endpoint";
static NSString * const kControlPoint = @"controlpoint";
static NSString * const kBackgroundId = @"backgroundid";


//    20:16 babazono 黄色RGB  253,200,47
//    20:16 babazono ピンクRGB  220,4,81
//    20:17 babazono 青緑RGB  91,187,183
//    20:17 babazono オレンジRGB  255,121,0

#define RGB(r, g, b) [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1]
#define RGBA(r, g, b, a) [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a]

#define COLOR_YELLOW RGB(253, 200, 47);
#define COLOR_PINK   RGB(220, 4, 81);
#define COLOR_GREEN  RGB(91, 187, 183);
#define COLOR_ORANGE RGB(255, 121, 0);

@interface BaseWorkSpace : C4CanvasController

// Required for both Browser and Advertiser roles
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;

-(void)setup;
-(void)launchBrowser;
-(void)launchAdvertiser;
- (void)showAlert:(NSString*)message;
- (UIColor*)getBackgroundColor:(int)backgroundId;

@end

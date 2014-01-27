//
//  BaseWorkSpace.m
//  Smile
//
//  Created by Takatomo Okitsu on 2014/01/24.
//  Copyright (c) 2014年 Takatomo Okitsu. All rights reserved.
//

#import "BaseWorkSpace.h"
#import <MBProgressHUD.h>
#import "UIAlertView+BlocksKit.h"

#define ADVERTISER_NAME @"Smile Advertiser"

@interface BaseWorkSpace () <MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate>

@property (nonatomic, strong) MCNearbyServiceBrowser *nearbyBrowser;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *nearbyAdvertiser;

//@property (nonatomic, strong) MCAdvertiserAssistant *advertiserAssistant;

@end

@implementation BaseWorkSpace

-(void)setup {
//    [self createP2PConfigButton];
}

#pragma mark -
- (void)launchBrowser {
    _peerID = [[MCPeerID alloc] initWithDisplayName:@"Browser"];
    _session = [[MCSession alloc] initWithPeer:_peerID];
    _session.delegate = self;
//    _browserView = [[MCBrowserViewController alloc] initWithServiceType:kServiceName
//                                                                session:_session];
//    _browserView.delegate = self;
//    [self presentViewController:_browserView animated:YES completion:nil];
    
    _nearbyBrowser = [[MCNearbyServiceBrowser alloc]
                                             initWithPeer:_peerID
                                             serviceType:kServiceName];
    
    _nearbyBrowser.delegate = self;
    [_nearbyBrowser startBrowsingForPeers];
    
    [self showLoading];
}

- (void)launchAdvertiser {
    _peerID = [[MCPeerID alloc] initWithDisplayName:ADVERTISER_NAME];
    _session = [[MCSession alloc] initWithPeer:_peerID];
    _session.delegate = self;
//    _advertiserAssistant = [[MCAdvertiserAssistant alloc] initWithServiceType:kServiceName
//                                                                discoveryInfo:nil
//                                                                      session:_session];
//    [_advertiserAssistant start];
    
    _nearbyAdvertiser = [[MCNearbyServiceAdvertiser alloc]
                         initWithPeer:_peerID
                         discoveryInfo:nil
                         serviceType:kServiceName];
    
    _nearbyAdvertiser.delegate = self;
    
    [_nearbyAdvertiser startAdvertisingPeer];

    
    [self showLoading];
}

//#pragma mark - MCBrowserViewControllerDelegate
//
//- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
//    [self dismissViewControllerAnimated:YES completion:^{
//        [_browserView.browser stopBrowsingForPeers];
//    }];
//}
//
//- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
//    [self dismissViewControllerAnimated:YES completion:^{
//        [_browserView.browser stopBrowsingForPeers];
//    }];
//}

#pragma mark - MCSessionDelegate

// MCSessionDelegate methods are called on a background queue, if you are going to update UI
// elements you must perform the actions on the main queue.

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch (state) {
        case MCSessionStateConnected: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideLoading];
                [self showAlert:@"セットアップが正しく完了しました"];
            });
            
            // This line only necessary for the advertiser. We want to stop advertising our services
            // to other browsers when we successfully connect to one.
//            [_advertiserAssistant stop];
            [_nearbyAdvertiser stopAdvertisingPeer];
            break;
        }
        case MCSessionStateNotConnected: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideLoading];
                [self showAlert:@"接続が切れました。一旦アプリのプロセスを停止し、再度起動しなおしてください。"];
            });
            break;
        }
        default:
            break;
    }
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler
{
    invitationHandler(YES, _session);
}

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    [browser invitePeer:peerID toSession:_session withContext:nil timeout:0]; //timeout = 30sec
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    NSLog(@"lostPeer: display name:%@", peerID.displayName);
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    NSLog(@"%@", error);
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    NSPropertyListFormat format;
    NSDictionary *receivedData = [NSPropertyListSerialization propertyListWithData:data
                                                                           options:0
                                                                            format:&format
                                                                             error:NULL];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter postNotificationName:kNotificationKey object:self userInfo:receivedData];
    });
}

// Required MCSessionDelegate protocol methods but are unused in this application.

- (void)session:(MCSession *)session
didStartReceivingResourceWithName:(NSString *)resourceName
       fromPeer:(MCPeerID *)peerID
   withProgress:(NSProgress *)progress {
    
}

- (void)session:(MCSession *)session
didReceiveStream:(NSInputStream *)stream
       withName:(NSString *)streamName
       fromPeer:(MCPeerID *)peerID {
    
}

- (void)session:(MCSession *)session
didFinishReceivingResourceWithName:(NSString *)resourceName
       fromPeer:(MCPeerID *)peerID
          atURL:(NSURL *)localURL
      withError:(NSError *)error {
    
}

- (void)showAlert:(NSString*)message
{
    UIAlertView *messageAlert = [[UIAlertView alloc] initWithTitle:nil
                                                           message:message
                                                          delegate:self
                                                 cancelButtonTitle:@"OK"
                                                 otherButtonTitles:nil];
    [messageAlert show];
}

- (void)showLoading
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES].labelText = @"iPad同士を接続中です。もう片方のiPadを起動してください。";
}

- (void)hideLoading
{
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
}


//-(void)createP2PConfigButton {
//    CGRect shapeFrame = CGRectMake(0, self.canvas.height - 50, 50, 50);
//    C4Shape *switchButton = [C4Shape rect:shapeFrame];
//    switchButton.fillColor = [UIColor clearColor];
//    switchButton.strokeColor = [UIColor clearColor];
//    
//    [switchButton addGesture:LONGPRESS name:@"longPress" action:@"pressedLong"];
//    
//    [self.canvas addShape:switchButton];
//    
//    [self listenFor:@"pressedLong" fromObject:switchButton andRunMethod:@"p2pButtonPressed:"];
//}
//
//-(void)p2pButtonPressed: (NSNotification *)notification
//{
//    UIAlertView *alert = [UIAlertView bk_alertViewWithTitle:@"Launch Browser or Advertiser?"];
//    [alert bk_addButtonWithTitle:@"Browser" handler:^{
//        [self launchBrowser];
//    }];
//    [alert bk_addButtonWithTitle:@"Advertiser" handler:^{
//        [self launchAdvertiser];
//    }];
//    [alert bk_addButtonWithTitle:@"Cancel" handler:^{
//        //cancel
//    }];
//    [alert show];
//}

- (UIColor*)getBackgroundColor:(int)backgroundId
{
    UIColor *color;
    switch (backgroundId) {
        case 0:
            color = RGB(253, 200, 47);
            break;
        case 1:
            color = RGB(220, 4, 81);
            break;
        case 2:
            color = RGB(91, 187, 183);
            break;
        case 3:
            color = RGB(255, 121, 0);
            break;
        default:
            color = RGB(253, 200, 47);
            break;
    }
    return color;
}

@end

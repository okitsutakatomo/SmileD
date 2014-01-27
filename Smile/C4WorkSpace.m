//
//  C4WorkSpace.m
//  Smile
//
//  Created by Takatomo Okitsu on 2014/01/22.
//

#import "C4Workspace.h"
#import "EntranceWorkSpace.h"
#import "WorkSpaceA.h"
#import "WorkSpaceB.h"
#import "UIAlertView+BlocksKit.h"

@implementation C4WorkSpace {
    EntranceWorkSpace *entranceWorkspace;
    WorkSpaceA *workspaceA;
    WorkSpaceB *workspaceB;
    C4View *currentView;
    C4Shape *switchButton;
}

-(void)setup {
    [self createWorkSpaces];
}

-(void)createWorkSpaces {
    entranceWorkspace = [[EntranceWorkSpace alloc] initWithNibName:@"EntranceWorkSpace" bundle:[NSBundle mainBundle]];
    workspaceA = [[WorkSpaceA alloc] initWithNibName:@"WorkSpaceA" bundle:[NSBundle mainBundle]];
    workspaceB = [[WorkSpaceB alloc] initWithNibName:@"WorkSpaceB" bundle:[NSBundle mainBundle]];
    
    entranceWorkspace.canvas.frame = self.canvas.frame;
    workspaceA.canvas.frame = self.canvas.frame;
    workspaceB.canvas.frame = self.canvas.frame;
    
    [entranceWorkspace setup];
    
    [self.canvas addSubview:entranceWorkspace.canvas];
    currentView = (C4View *)entranceWorkspace.canvas;
    
    UIAlertView *alert = [UIAlertView bk_alertViewWithTitle:@"このiPadは、左右どちらのiPadですか？"];
    [alert bk_addButtonWithTitle:@"左" handler:^{
        [self showA];
    }];
    [alert bk_addButtonWithTitle:@"右" handler:^{
        [self showB];
    }];
    [alert show];
}

-(void)showA
{
    [workspaceA setup];
    [self displayWorkSpace:workspaceA];
}

-(void)showB
{
    [workspaceB setup];
    [self displayWorkSpace:workspaceB];
}

-(void)displayWorkSpace:(C4CanvasController*)workspace
{
    C4View *nextView = (C4View*)workspace.canvas;
    [UIView transitionFromView:currentView
                        toView:nextView
                      duration:0.75f
                       options:UIViewAnimationOptionTransitionFlipFromLeft
                    completion:^(BOOL finished) {
                        currentView = nextView;
                        finished = YES;
                    }];
}

@end
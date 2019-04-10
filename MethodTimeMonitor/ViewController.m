//
//  ViewController.m
//  GeekTimePractise
//
//  Created by Chengwen.Y on 2019/3/14.
//  Copyright © 2019 Chengwen. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "CWCallStack.h"
#import "CWMethodTimeMonitor.h"

@interface ViewController ()

@end


@implementation ViewController

- (void)foo {
    while (true) {
        sleep(3);
        break;
    }
}

- (void)bar {
//    while (true) {
//        ;
//    }
    while (true) {
        sleep(3);
        break;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
   
    
    [self foo];
    [self bar];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    
    [[CWMethodTimeMonitor sharedInstance] showCallStack];
}


@end

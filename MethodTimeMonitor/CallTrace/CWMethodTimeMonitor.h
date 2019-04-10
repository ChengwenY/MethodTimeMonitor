//
//  MethodTimeMonitor.h
//  GeekTimePractise
//
//  Created by Chengwen.Y on 2019/4/8.
//  Copyright © 2019 Chengwen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CWMethodTimeMonitor : NSObject

+ (instancetype)sharedInstance;

- (void)beginRecord;
- (void)showCallStack;

@end

NS_ASSUME_NONNULL_END

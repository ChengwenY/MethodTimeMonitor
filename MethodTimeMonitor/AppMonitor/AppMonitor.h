//
//  AppMonitor.h
//  MethodTimeMonitor
//
//  Created by Chengwen.Y on 2019/4/17.
//  Copyright © 2019 Chengwen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^CWFpsBlock)(NSInteger);

@interface AppMonitor : NSObject

+ (integer_t)cpuUsage;

- (void)startFps:(CWFpsBlock)block;

+ (uint64_t)memoryUsage;

@end

NS_ASSUME_NONNULL_END

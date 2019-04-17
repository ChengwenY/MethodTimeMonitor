//
//  AppMonitor.m
//  MethodTimeMonitor
//
//  Created by Chengwen.Y on 2019/4/17.
//  Copyright © 2019 Chengwen. All rights reserved.
//

#import "AppMonitor.h"
#include <mach/thread_info.h>
#include <mach/thread_act.h>
#include <mach/task.h>
#include <mach/mach_init.h>
#include <mach/vm_map.h>

@interface AppMonitor ()

@property (nonatomic, assign) NSTimeInterval lastTime;
@property (nonatomic, assign) NSInteger fps;

@property (nonatomic, copy) CWFpsBlock fpsBlock;

@end

static int total = 0;

@implementation AppMonitor

+ (instancetype)sharedInstance
{
    static AppMonitor *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[AppMonitor alloc] init];
    });
    
    return shared;
}

+ (integer_t)cpuUsage
{
    thread_act_array_t threads;
    mach_msg_type_number_t threadCount = 0;
    kern_return_t kr = task_threads(mach_task_self(), &threads, &threadCount);
    
    if (kr != KERN_SUCCESS)
    {
        return 0;
    }
    integer_t totalUsage = 0;
    for (int i = 0; i < threadCount; i++) {
        
        thread_basic_info_t basicInfo;
        thread_info_data_t threadInfo;
        mach_msg_type_number_t threadInfoCount = THREAD_INFO_MAX;
        kern_return_t kr = thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)threadInfo, &threadInfoCount);
        if (kr == KERN_SUCCESS)
        {
            basicInfo = (thread_basic_info_t)threadInfo;
            
            totalUsage += basicInfo->cpu_usage;
        }
    }
    assert(vm_deallocate(mach_task_self(), (vm_address_t)threads, threadCount* sizeof(thread_t)) == KERN_SUCCESS);
    
    return totalUsage;
    
}

- (void)startFps:(CWFpsBlock)block
{
    self.fpsBlock = block;
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(fpsCount:)];
    [link addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)fpsCount:(CADisplayLink *)link
{
    if (self.lastTime == 0)
    {
        self.lastTime = link.timestamp;
    }
    else
    {
        total ++;
        NSTimeInterval now = link.timestamp;
        NSInteger timeDuration = now - self.lastTime;
        if (timeDuration < 1)
        {
            return;
        }
        self.fps = total/timeDuration;
        self.lastTime = now;
        total = 0;
        if (self.fpsBlock)
        {
            self.fpsBlock(self.fps);
        }
    }
}

+ (uint64_t)memoryUsage
{
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kr = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vmInfo, &count);
    if (kr != KERN_SUCCESS)
    {
        return 0;
    }
    return  vmInfo.phys_footprint;
}


@end

//
//  MethodTimeMonitor.m
//  GeekTimePractise
//
//  Created by Chengwen.Y on 2019/4/8.
//  Copyright © 2019 Chengwen. All rights reserved.
//

#import "CWMethodTimeMonitor.h"
#import "CWMethodExecuteInfo.h"
#import "CWCallStack.h"

@interface CWMethodTimeMonitor ()

@property (nonatomic, strong) NSMutableDictionary *methodMap;
@property (nonatomic, strong) NSMutableArray *recordArray;

@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, weak) NSThread *timerThread;

@end

@implementation CWMethodTimeMonitor

const float timerInterval = 0.01;

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        
    }
    return self;
}

+ (instancetype)sharedInstance
{
    static CWMethodTimeMonitor *sharedObject = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedObject = [[CWMethodTimeMonitor alloc] init];
    });
    
    return sharedObject;
}

- (void)beginRecord
{
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, timerInterval * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.timer, ^{
        
        [self recordCallTrace];
    });
    dispatch_resume(self.timer);
}

- (void)recordCallTrace
{
    [self saveCallStackDict:[CWCallStack callStackDictOfMainThread]];
}

- (void)cancelTimer
{
    dispatch_source_cancel(self.timer);
}

- (void)showCallStack
{
    [self cancelTimer];
    NSMutableString *string = [NSMutableString stringWithFormat:@"\n"];
    
    [self.methodMap enumerateKeysAndObjectsUsingBlock:^(NSString *key, CWMethodExecuteInfo *info, BOOL * _Nonnull stop) {
       
        [string appendString:info.methodDesc];
        [string appendString:[NSString stringWithFormat:@" %@ 方法耗时：%.2f\n", key, info.time]];
    }];
    
    NSLog(@"%@", string);
}

- (void)saveCallStackDict:(NSDictionary *)stacks
{
    for (NSString *key in stacks.allKeys) {
        
        CWMethodExecuteInfo *info = [self.methodMap objectForKey:key];
        CWMethodExecuteInfo *origInfo = [stacks objectForKey:key];

        if (info != nil) {
            info.time += timerInterval;
        }
        else {
            
            CWMethodExecuteInfo *info = [[CWMethodExecuteInfo alloc] init];
            info.address = origInfo.address;
            info.methodDesc = origInfo.methodDesc;
            info.time = timerInterval;
            [self.methodMap setObject:info forKey:key];
        }
    }
}

- (NSMutableDictionary *)methodMap
{
    if (!_methodMap)
    {
        _methodMap = @{}.mutableCopy;
    }
    return _methodMap;
}

- (NSMutableArray *)recordArray
{
    if (!_recordArray)
    {
        _recordArray = @[].mutableCopy;
    }
    
    return _recordArray;
}

@end

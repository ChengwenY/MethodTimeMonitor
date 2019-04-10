//
//  CWCallStack.h
//  GeekTimePractise
//
//  Created by Chengwen.Y on 2019/3/15.
//  Copyright © 2019 Chengwen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CWCallHeader.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ThreadType) {
    EThreadAll,
    EThreadMain,
    EThreadCurrent,
};

@interface CWCallStack : NSObject

+ (NSString *)callStack:(ThreadType)type;

+ (NSDictionary *)callStackDictOfMainThread;

extern NSString * outputLog(const Dl_info * const info, const uintptr_t address, const int entryNum);

@end

NS_ASSUME_NONNULL_END

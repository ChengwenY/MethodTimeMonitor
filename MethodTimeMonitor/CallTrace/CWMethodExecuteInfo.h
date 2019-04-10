//
//  CWMethodExecuteInfo.h
//  GeekTimePractise
//
//  Created by Chengwen.Y on 2019/4/9.
//  Copyright © 2019 Chengwen. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <dlfcn.h>

NS_ASSUME_NONNULL_BEGIN

@interface CWMethodExecuteInfo : NSObject

@property (nonatomic, assign) float time;
@property (nonatomic, assign) const uintptr_t address;
@property (nonatomic, copy) NSString *methodDesc;

@end

NS_ASSUME_NONNULL_END

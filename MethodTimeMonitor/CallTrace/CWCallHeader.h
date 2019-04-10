//
//  CWCallHeader.h
//  GeekTimePractise
//
//  Created by Chengwen.Y on 2019/3/19.
//  Copyright © 2019 Chengwen. All rights reserved.
//

#ifndef CWCallHeader_h
#define CWCallHeader_h

#include <mach/mach.h>

#include <mach/task.h>
#include <mach/vm_map.h>
#include <mach/mach_init.h>
#include <mach/thread_act.h>
#include <mach/thread_info.h>

#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <pthread/pthread.h>

#ifdef __LP64__
typedef struct mach_header_64     machHeaderByCPU;
typedef struct segment_command_64 segmentComandByCPU;
typedef struct section_64         sectionByCPU;
typedef struct nlist_64           nlistByCPU;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64

#else
typedef struct mach_header        machHeaderByCPU;
typedef struct segment_command    segmentComandByCPU;
typedef struct section            sectionByCPU;
typedef struct nlist              nlistByCPU;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

#endif /* CWCallHeader_h */

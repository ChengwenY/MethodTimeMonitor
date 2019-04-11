//
//  CWCallStack.m
//  GeekTimePractise
//
//  Created by Chengwen.Y on 2019/3/15.
//  Copyright © 2019 Chengwen. All rights reserved.
//

#import "CWCallStack.h"
#import "CWMethodExecuteInfo.h"

@interface CWCallStack()

@end

static mach_port_t mainThreadId;

typedef struct CWThreadUsageInfo{
    double userTime;
    integer_t cpuUsage;
} CWThreadUsageInfo;

typedef struct StackFrame {
    const struct StackFrame *const preStackFrame;
    const uintptr_t returnAddress;
} StackFrame;

@implementation CWCallStack

+ (void)load
{
    mainThreadId = mach_thread_self();
}

+ (NSString *)callStack:(ThreadType)type
{
    switch (type) {
        case EThreadAll:
        {
            thread_act_array_t threads;
            mach_msg_type_name_t thread_count = 0;
            
            kern_return_t kr = task_threads(mach_task_self(), &threads, &thread_count);
            if (kr != KERN_SUCCESS)
            {
                return @"Fail get threads";
            }
            NSMutableString *ret = [NSMutableString string];
            for (int i = 0; i < thread_count; i++) {
                
                NSString *retStr = outputCallStackOfThread(threads[i]);
                [ret appendString:retStr];
            }
            return [ret copy];
        }
        case EThreadMain:
        {
            CWThreadUsageInfo threadUsageInfo = threadBasicInfo(mainThreadId);
            NSLog(@"%@", [NSString stringWithFormat:@"Thread %d:\n CPU usage:%.1d\nUser time: %@ microseconds\n", mainThreadId, threadUsageInfo.cpuUsage/10, @(threadUsageInfo.userTime)].mutableCopy);

            NSString *retStr = outputCallStackOfThread(mainThreadId);
            
            assert(vm_deallocate(mach_task_self(), (vm_address_t)mainThreadId, 1 * sizeof(thread_t)) == KERN_SUCCESS);

            return retStr;
        }
        case EThreadCurrent:
        {
            //当前线程
            char name[256];
            mach_msg_type_number_t count;
            thread_act_array_t list;
            //根据当前 task 获取所有线程
            task_threads(mach_task_self(), &list, &count);
            NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
            NSThread *nsthread = [NSThread currentThread]; //当前执行的指令
            NSString *originName = [nsthread name];
            [nsthread setName:[NSString stringWithFormat:@"%f",currentTimestamp]];
            NSString *reStr = @"";
            
            for (int i = 0; i < count; ++i) {
                //_np 是指 not POSIX ，这里的 POSIX 是指操作系统的一个标准，特别是与 Unix 兼容的操作系统。np 表示与标准不兼容
                pthread_t pt = pthread_from_mach_thread_np(list[i]);
                if (pt) {
                    name[0] = '\0';
                    //获得线程名字
                    pthread_getname_np(pt, name, sizeof name);
                    if (!strcmp(name, [nsthread name].UTF8String)) {
                        [nsthread setName:originName];
                        reStr = outputCallStackOfThread(list[i]);
                        assert(vm_deallocate(mach_task_self(), (vm_address_t)list[i], 1 * sizeof(thread_t)) == KERN_SUCCESS);
                        NSLog(@"%@",reStr);
                        return [reStr copy];
                    }
                }
            }
            [nsthread setName:originName];
            reStr = outputCallStackOfThread(mach_thread_self());
            NSLog(@"%@",reStr);
            return [reStr copy];
        }
        default:
            break;
    }
    
    return @"";
}

+ (NSDictionary *)callStackDictOfMainThread
{
    return callStackDictOfThread(mainThreadId);
}

/*
 
 kern_return_t thread_info
 (
 thread_inspect_t target_act,
 thread_flavor_t flavor, //通过传入不同的宏定义获取不同的线程信息
 thread_info_t thread_info_out,
 mach_msg_type_number_t *thread_info_outCnt
 );
 */

//struct thread_basic_info {
//    time_value_t    user_time;      /* user run time */
//    time_value_t    system_time;    /* system run time */
//    integer_t       cpu_usage;      /* scaled cpu usage percentage */
//    policy_t        policy;         /* scheduling policy in effect */
//    integer_t       run_state;      /* run state (see below) */
//    integer_t       flags;          /* various flags (see below) */
//    integer_t       suspend_count;  /* suspend count for thread */
//    integer_t       sleep_time;     /* number of seconds that thread
//                                     has been sleeping */
//};
//
//typedef struct thread_basic_info  thread_basic_info_data_t;
//typedef struct thread_basic_info  *thread_basic_info_t;

// 获取thread 基本信息
CWThreadUsageInfo threadBasicInfo(thread_t thread)
{
    thread_basic_info_t threadBasicInfo;
    thread_info_data_t threadInfoOut;
    mach_msg_type_number_t threadInfoCount = THREAD_INFO_MAX;
    CWThreadUsageInfo threadUsageInfo = {0};
    
    //获取当前线程cpuTime userTime
    if (thread_info((thread_act_t)thread, THREAD_BASIC_INFO, (thread_info_t)threadInfoOut, &threadInfoCount) == KERN_SUCCESS)
    {
        threadBasicInfo = (thread_basic_info_t)threadInfoOut;
        
        if (!(threadBasicInfo->flags & TH_FLAGS_IDLE))
        {
            threadUsageInfo.cpuUsage = threadBasicInfo->cpu_usage;
            threadUsageInfo.userTime = threadBasicInfo->system_time.microseconds;
        }
    }
    return threadUsageInfo;
}

int callStackAddressOfThread(thread_t thread, uintptr_t* callstackBuffer)
{
    // _STRUCT_MCONTEXT 结构
    //    _STRUCT_MCONTEXT64
    //    {
    //        _STRUCT_ARM_EXCEPTION_STATE64    __es;
    //        _STRUCT_ARM_THREAD_STATE64    __ss; 调用栈存储在__ss中
    //        _STRUCT_ARM_NEON_STATE64    __ns;
    //    };
    //    typedef _STRUCT_MCONTEXT64    *mcontext_t;
    
    //    _STRUCT_ARM_THREAD_STATE64
    //    {
    //        __uint64_t    __x[29];    /* General purpose registers x0-x28 */
    //        void*         __opaque_fp;    /* Frame pointer x29 */
    //        void*         __opaque_lr;    /* Link register x30 */
    //        void*         __opaque_sp;    /* Stack pointer x31 */
    //        void*         __opaque_pc;    /* Program counter */
    //        __uint32_t    __cpsr;    /* Current program status register */
    //        __uint32_t    __opaque_flags;    /* Flags describing structure format */
    //    };
//    uintptr_t callstackBuffer[50];
    int i = 0;
    
    _STRUCT_MCONTEXT machineContext;
    if (!fillThreadStateIntoMachineState(thread, &machineContext))
    {
        NSLog(@"Fail get thread: %d\n", thread);
    }
    
    /* 调用栈结构
        ------------------       <--| high address
        pc/rip 指令寄存器             |   |
        lr                          |   |
        sp                          |   |
        fp                          |   |
        main argument argc          |   main stack frame
        main argument argc          |   |
        local variable i = 10       |   |
        j = 5                       |   |
        func2                       |   |
  fp->  ------------------    <--|  |   |
        pc                       |  |   |
        lr                       |  |   |
        sp    -------------------|  |   func2 stack frame
        fp    ----------------------|   |
        func2 parameter1:               |
        func2 parameter2:               V
  sp->  ----------------------         low address

     */
    
    /*
     while(fp)
     {
        pc = *(fp+1);
        fp = *fp;
     }
     */
    
    // 指令寄存器 指向处理器下条等待执行的指令地址，每次执行完相应的汇编指令eip的值就会增加，因此此处地址是当前执行指令的地址
    const uintptr_t instructionAddress = cwGetInstructionAddress(&machineContext);
    callstackBuffer[i] = instructionAddress;
    i++;
    
    //  当前函数返回地址 lr寄存器存储当前函数返回地址
    const uintptr_t linkRegisterAddress = cwMachThreadGetLinkRegisterPointerByCPU(&machineContext);
    
    if (linkRegisterAddress)
    {
        callstackBuffer[i] = linkRegisterAddress;
        i++;
    }
    
    if (instructionAddress == 0)
    {
        return 0;
    }
    
    StackFrame frame = {0};
    
    // 获取当前fp地址
    const uintptr_t framePointer = cwGetFramePointerAddress(&machineContext);
    //
    if (framePointer == 0 || cwMachCopyMem((void *)framePointer, &frame, sizeof(frame)) != KERN_SUCCESS)
    {
        return 0;
    }
    for (; i< 8; i++) {
        
        callstackBuffer[i] = frame.returnAddress;
        if (callstackBuffer[i] == 0 ||frame.preStackFrame == 0 || cwMachCopyMem(frame.preStackFrame, &frame, sizeof(frame)) != KERN_SUCCESS)
        {
            break;
        }
    }
    
    return i;
}

NSMutableDictionary* callStackDictOfThread(thread_t thread)
{
    uintptr_t callstackBuffer[50] = {0};
    int backtraceLength = callStackAddressOfThread(thread, callstackBuffer);
    
    Dl_info symbolicated[backtraceLength];
    cw_symbolicate(callstackBuffer, symbolicated, backtraceLength, 0);
    
    NSMutableDictionary *dlInfos = @{}.mutableCopy;

    for (uint32_t i = 0; i < backtraceLength; i++) {
        
        Dl_info info = symbolicated[i];
        uintptr_t address = info.dli_saddr;
        
        CWMethodExecuteInfo *mInfo = [[CWMethodExecuteInfo alloc] init];
        mInfo.address = address;
        mInfo.methodDesc = outputFunctionDesc(&info);

        
        NSString *key = [NSString stringWithFormat:@"0x%08"PRIxPTR, address];
        [dlInfos setObject:mInfo forKey:key];
    }
    
    return dlInfos;
}

NSString  *outputFunctionDesc(const Dl_info *info)
{
    const char * name = info->dli_fname;
    NSString *fName = @"";

    if (name != NULL)
    {
        char *lastFile = strrchr(info->dli_fname, '/'); // /GeekTimePractise 返回
        if (lastFile == NULL) {
            fName = [NSString stringWithFormat:@"%-30s", name];
        }
        else {
            fName = [NSString stringWithFormat:@"%-30s", lastFile + 1];
        }
    }
    
    const char * sname = info->dli_sname;
    
    if (sname == NULL)
    {
        sname = "";
    }
    return [NSString stringWithFormat:@"%@ %s", fName, sname];
}

NSString * outputCallStackOfThread(thread_t thread)
{
    // 符号解析
    //1. 找到地址所在的image
    //2. 找到image中的符号表
    //3. 根据地址转换对应的函数名 symbol address = frame point address + slide
    
    uintptr_t callstackBuffer[50] = {0};

    int backtraceLength = callStackAddressOfThread(thread, callstackBuffer);
    
    // 存储函数信息的结构体
    //typedef struct dl_info {
    //    const char      *dli_fname;     /* Pathname of shared object */ 路径名 如：/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/Sy
    //    void            *dli_fbase;     /* Base address of shared object */ 共享对象的起始地址， 如：CoreFoundation
    //    const char      *dli_sname;     /* Name of nearest symbol */ 符号名字
    //    void            *dli_saddr;     /* Address of nearest symbol */ 符号地址
    //} Dl_info;
    Dl_info symbolicated[backtraceLength];
    
    cw_symbolicate(callstackBuffer, symbolicated, backtraceLength, 0);
    
    NSMutableString *retStr = [NSMutableString string];
    for (uint32_t i = 0; i < backtraceLength; i++) {
        [retStr appendString:outputLog(&symbolicated[i], callstackBuffer[i], i)];
    }
    return retStr;
    
}

NSString * outputLog(const Dl_info * const info, const uintptr_t address, const int entryNum)
{
    const char * name = info->dli_fname;
    if (name == NULL)
    {
        return  @"";
    }
    //获取路径最后文件名
    //strrchr 查找某字符在字符串中最后一次出现的位置
    char *lastFile = strrchr(info->dli_fname, '/'); // /GeekTimePractise 返回
    NSString *fName = @"";
    if (lastFile == NULL) {
        fName = [NSString stringWithFormat:@"%-30s", name];
    }
    else {
        fName = [NSString stringWithFormat:@"%-30s", lastFile + 1];
    }
    
    uintptr_t offset = address - (uintptr_t)info->dli_saddr;
    const char * sname = info->dli_sname;
    
    if (sname == NULL) {
        return  @"";
    }
    return [NSString stringWithFormat:@"%@ 0x%08" PRIxPTR " %s + %lu\n", fName, (uintptr_t)address, sname, offset];

}

void cw_symbolicate(const uintptr_t *const backtraceBuffer,
                    Dl_info *symbolBuffer,
                    const int stackLen, const int skippedEntries)
{
    //获取每条指令的地址，所有的地址存在于callstackBuffer数组中，其中第0个元素存储当前执行指令的地址即指令寄存器pc/eip所存储的地址，
    //第1个元素存储的是当前函数的返回地址即父函数调用本函数地址，也就是lr寄存器存储的值，以后元素存储的是framePointer 的地址。
    //如果获取每条指令的地址，除了第0个元素外，instructionAddr = callstackBuffer[i] - 1;
    
    int i = 0;
    if (!skippedEntries && i < stackLen)
    {
        cwDladdr(backtraceBuffer[i], &symbolBuffer[i]);
    }
    
    for (; i < stackLen; i++) {
        
        // 获取指令地址 相当于 address - 1 不同架构cpu获取这个值得方式不同
        uintptr_t instructionAddr = cwInstructionAddressByCPU(backtraceBuffer[i]);
        
        cwDladdr(instructionAddr, &symbolBuffer[i]);
    }
    
}

BOOL cwDladdr(const uintptr_t address, Dl_info * const info)
{
    info->dli_fbase = NULL;
    info->dli_fname = NULL;
    info->dli_saddr = NULL;
    info->dli_sname = NULL;
    
    // 获取image index
    uint32_t imageIdx = imageIndexContainsAddress(address);
    
    if (imageIdx == UINT_MAX)
    {
        return false;
    }
    
    const struct mach_header *header = _dyld_get_image_header(imageIdx);
    //随机偏移量
    const uintptr_t imageVMAddSlide = _dyld_get_image_vmaddr_slide(imageIdx);
    //??????
    //虚拟地址偏移量 = 虚拟地址-文件偏移量
    const uintptr_t addressWithSlide = address - imageVMAddSlide;
    // 链接时程序的基址 uintptr_t linkedit_base = (uintptr_t)slide + linkedit_segment->vmaddr - linkedit_segment->fileoff;
    
    // 符号表的地址 = 基址 + 符号表偏移量 nlist_t *symtab = (nlist_t *)(linkedit_base + symtab_cmd->symoff);
    // 字符串表的地址 = 基址 + 字符串表偏移量 char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);
    
    // 动态符号表地址 = 基址 + 动态符号表偏移量 uint32_t *indirect_symtab = (uint32_t *)(linkedit_base + dysymtab_cmd->indirectsymoff);
        const uintptr_t segmentBase = cwSegmentBaseOfImageIndex(imageIdx) + imageVMAddSlide;
    
    if (segmentBase == 0)
    {
        return false;
    }
    
    info->dli_fname = _dyld_get_image_name(imageIdx);
    info->dli_fbase = (void *)header;
    
    //符号表是一个连续的列表 每一项都是一个nlist
    // 位于系统库 头文件中 struct nlist {
//    union {
//        //符号名在字符串表中的偏移量     uint32_t n_strx;
//    } n_un;
//    uint8_t n_type;
//    uint8_t n_sect;
//    int16_t n_desc;
//    uint32_t n_value; //符号在内存中的地址，类似于函数指针
//};
    
    const nlistByCPU *bestMatch = NULL;
    uintptr_t bestDistance = ULONG_MAX;
    uintptr_t cmdPtr = cwFirstCmdAfterHeader(header);
    
    if (cmdPtr == 0)
    {
        return false;
    }
    
    for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
        
        // struct load_command {
//        uint32_t cmd;        /* type of load command */
//        uint32_t cmdsize;    /* total size of command in bytes */
//    };
        const struct load_command *loadCmd = (struct load_command *)cmdPtr;
        
        if (loadCmd->cmd == LC_SYMTAB) {
            const struct symtab_command *symtabCmd = (struct symtab_command *)loadCmd;
            //符号表 n_list 数组
            const nlistByCPU *symbolTable = (nlistByCPU *)(segmentBase + symtabCmd->symoff);
            //字符串表
            const uintptr_t stringTable = segmentBase + symtabCmd->stroff;
            
            //遍历符号表 找到
            for (uint32_t iSym = 0; iSym < symtabCmd->nsyms; iSym ++)
            {
                if (symbolTable[iSym].n_value != 0) {
                    uintptr_t symbolBase = symbolTable[iSym].n_value;
                    uintptr_t currentDistance = addressWithSlide - symbolBase;
                    
                    if ((addressWithSlide >= symbolBase) && (currentDistance <= bestDistance))
                    {
                        bestDistance = currentDistance;
                        bestMatch = symbolTable + iSym;
                    }
                }
            }
            if (bestMatch != NULL) {
                //将虚拟内存偏移量添加到 __LINKEDIT segment 的虚拟内存地址可以提供字符串和符号表的内存 address。
                info->dli_saddr = (void*)(bestMatch->n_value + imageVMAddSlide);
                info->dli_sname = (char*)((intptr_t)stringTable + (intptr_t)bestMatch->n_un.n_strx);
                if (*info->dli_sname == '_') {
                    info->dli_sname++;
                }
                //所有的 symbols 已经被处理好了
                if (info->dli_saddr == info->dli_fbase && bestMatch->n_type == 3) {
                    info->dli_sname = NULL;
                }
                break;
                
            }
        }
        
        cmdPtr += loadCmd->cmdsize;
    }
    
    return true;
}

uintptr_t cwSegmentBaseOfImageIndex(const uint32_t idx)
{
    const struct mach_header *machHeader = _dyld_get_image_header(idx);
    
    uintptr_t cmdPtr = cwFirstCmdAfterHeader(machHeader);
    
    if (cmdPtr == 0)
    {
        return 0;
    }
    
    for (uint32_t i = 0; i < machHeader->ncmds; i++) {
        
        const struct load_command *loadCmd = (struct load_command *)cmdPtr;
        
        const segmentComandByCPU *segmentCmd = (segmentComandByCPU *)cmdPtr;
        if (strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0)
        {
            //返回segment 地址
            return  (uintptr_t)(segmentCmd->vmaddr - segmentCmd->fileoff);
        }
        cmdPtr += loadCmd->cmdsize;
    }
    
    return  0;
}

uint32_t imageIndexContainsAddress(const uintptr_t address)
{
    uint32_t imageCount = _dyld_image_count();
    
    const struct mach_header *header = 0;
    
    // 循环遍历image
    for (uint32_t i = 0; i < imageCount; i++) {
        
        //获取image的header
        header = _dyld_get_image_header(i);
        if (header != NULL)
        {
            // 根据随机偏移量获取实际内存地址
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            
            uintptr_t addressWSlide = address - slide;
            
            uintptr_t cmdPointer = cwFirstCmdAfterHeader(header);
            
            if (cmdPointer == 0)
            {
                continue;
            }
            for (uint32_t iCmd = 0; iCmd < header -> ncmds; iCmd ++) {
                
                const struct load_command * loadCmd = (struct load_command *)cmdPointer;
                if (loadCmd->cmd == LC_SEGMENT)
                {
                    const struct segment_command *segCmd = (struct segment_command*)cmdPointer;
                    if (addressWSlide > segCmd->vmaddr && addressWSlide < segCmd->vmaddr + segCmd->vmsize)
                    {
                        return i;
                    }
                }
                else if (loadCmd->cmd == LC_SEGMENT_64)
                {
                    const struct segment_command_64 *segCmd = (struct segment_command_64 *)cmdPointer;
                    if (addressWSlide > segCmd->vmaddr && addressWSlide < segCmd->vmaddr + segCmd->vmsize)
                    {
                        return i;
                    }
                }
                
                cmdPointer += loadCmd->cmdsize;
            }
        }
    }
    
    return UINT_MAX;
}

kern_return_t cwMachCopyMem(const void *const src, void *const dst, const size_t numBytes)
{
    vm_size_t bytesCopied = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)src, (vm_size_t)numBytes, (vm_address_t)dst, &bytesCopied);
}

// 获取thread 信息
BOOL fillThreadStateIntoMachineState(thread_act_t thread, _STRUCT_MCONTEXT *machineContext)
{
    /*
     typedef    natural_t    *thread_state_t;     //Variable-length array
     
     kern_return_t thread_get_state
     (
     thread_act_t target_act,
     thread_state_flavor_t flavor,
     thread_state_t old_state, //int 数组

     mach_msg_type_number_t *old_stateCnt
     );
     */
    
    mach_msg_type_number_t stateCount = cwThreadStateCountByCPU();

    kern_return_t kr = thread_get_state((thread_act_t)thread, cwThreadStateByCPU(), (thread_state_t)&machineContext->__ss, &stateCount);
    
    return kr == KERN_SUCCESS;
}



// 获取指令寄存器地址 当前执行指令的地址
uintptr_t cwGetInstructionAddress(mcontext_t const machineContext)
{
#if defined(__arm64__)
    return machineContext->__ss.__pc;
#elif defined(__arm__)
    return machineContext->__ss.__pc;
#elif defined(__x86_64__)
    return machineContext->__ss.__rip;
#elif defined(__i386__)
    return machineContext->__ss.__eip;
#endif
}

// 获取栈基指针地址
uintptr_t cwGetFramePointerAddress(mcontext_t const machineContext)
{
#if defined(__arm64__)
    return machineContext->__ss.__fp;
#elif defined(__arm__)
    return machineContext->__ss.__r[7];
#elif defined(__x86_64__)
    return machineContext->__ss.__rbp;
#elif defined(__i386__)
    return machineContext->__ss.__ebp;
#endif
}

// 获取栈顶指针地址
uintptr_t cwGetStackPointerAddress(mcontext_t const machineContext)
{
#if defined(__arm64__)
    return machineContext->__ss.__sp;
#elif defined(__arm__)
    return machineContext->__ss.__sp;
#elif defined(__x86_64__)
    return machineContext->__ss.__rsp;
#elif defined(__i386__)
    return machineContext->__ss.__esp;
#endif
}

uintptr_t cwInstructionAddressByCPU(const uintptr_t address) {
#if defined(__arm64__)
    const uintptr_t reAddress = ((address) & ~(3UL));
#elif defined(__arm__)
    const uintptr_t reAddress = ((address) & ~(1UL));
#elif defined(__x86_64__)
    const uintptr_t reAddress = (address);
#elif defined(__i386__)
    const uintptr_t reAddress = (address);
#endif
    return reAddress - 1;
}

//获取lr地址  lr 地址是当前调用函数返回地址 也就是上一个函数调用本函数的地址
uintptr_t cwMachThreadGetLinkRegisterPointerByCPU(mcontext_t const machineContext) {
#if defined(__i386__)
    return 0;
#elif defined(__x86_64__)
    return 0;
#else
    return machineContext->__ss.__lr;
#endif
}

thread_state_flavor_t cwThreadStateByCPU()
{
#if defined(__arm64__)
    return ARM_THREAD_STATE64;
#elif defined(__arm__)
    return ARM_THREAD_STATE;
#elif defined(__x86_64__)
    return x86_THREAD_STATE64;
#elif defined(__i386__)
    return x86_THREAD_STATE32;
#endif
}

mach_msg_type_number_t cwThreadStateCountByCPU()
{
#if defined(__arm64__)
    return ARM_THREAD_STATE64_COUNT;
#elif defined(__arm__)
    return ARM_THREAD_STATE_COUNT;
#elif defined(__x86_64__)
    return x86_THREAD_STATE64_COUNT;
#elif defined(__i386__)
    return x86_THREAD_STATE32_COUNT;
#endif
}

uintptr_t cwFirstCmdAfterHeader(const struct mach_header* const header) {
    switch(header->magic) {
        case MH_MAGIC:
        case MH_CIGAM:
            return (uintptr_t)(header + 1);
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            return (uintptr_t)(((struct mach_header_64*)header) + 1);
        default:
            return 0;  // Header is corrupt
    }
}
@end


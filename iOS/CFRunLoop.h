/*
 * Copyright (c) 2014 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

/*	CFRunLoop.h
	Copyright (c) 1998-2013, Apple Inc. All rights reserved.
*/

#if !defined(__COREFOUNDATION_CFRUNLOOP__)
#define __COREFOUNDATION_CFRUNLOOP__ 1

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFDate.h>
#include <CoreFoundation/CFString.h>
#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)) || (TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)
#include <mach/port.h>
#endif

CF_EXTERN_C_BEGIN

// 结构体重新定义了名字

// runloop实例：
typedef struct __CFRunLoop * CFRunLoopRef;

// runloop的源：
typedef struct __CFRunLoopSource * CFRunLoopSourceRef;

// runloop的观察者：
typedef struct __CFRunLoopObserver * CFRunLoopObserverRef;

// runloop的定时器：
typedef struct __CFRunLoopTimer * CFRunLoopTimerRef;

// Runloop运行时的的状态
/* Reasons for CFRunLoopRunInMode() to Return */
enum {
    kCFRunLoopRunFinished = 1,  // 结束
    kCFRunLoopRunStopped = 2,   // 暂停
    kCFRunLoopRunTimedOut = 3, // 超时
    kCFRunLoopRunHandledSource = 4  // 处理源的事务？？
};

// 作为一个观察能获取到的runloop的模式
// CFOptionFlags是个什么鬼，肯定是一种数据类型
/* Run Loop Observer Activities */
typedef CF_OPTIONS(CFOptionFlags, CFRunLoopActivity) {
    kCFRunLoopEntry = (1UL << 0),
    kCFRunLoopBeforeTimers = (1UL << 1),
    kCFRunLoopBeforeSources = (1UL << 2),
    kCFRunLoopBeforeWaiting = (1UL << 5),
    kCFRunLoopAfterWaiting = (1UL << 6),
    kCFRunLoopExit = (1UL << 7),
    kCFRunLoopAllActivities = 0x0FFFFFFFU
};

// runloop默认模式
CF_EXPORT const CFStringRef kCFRunLoopDefaultMode;
// runloop的CommonModes，注意这里是modes，是个S啊
CF_EXPORT const CFStringRef kCFRunLoopCommonModes;

// 返回当前CFRunLoop的类ID
CF_EXPORT CFTypeID CFRunLoopGetTypeID(void);

// 获得当前的runloop
CF_EXPORT CFRunLoopRef CFRunLoopGetCurrent(void);

// 获取main线程的runloop
CF_EXPORT CFRunLoopRef CFRunLoopGetMain(void);

// 获取入参CFRunLoopRef的Mode
CF_EXPORT CFStringRef CFRunLoopCopyCurrentMode(CFRunLoopRef rl);

// 这个runloop里面所有的mode，看到没有是和数组类型
CF_EXPORT CFArrayRef CFRunLoopCopyAllModes(CFRunLoopRef rl);

// 看起来像是把一个runloop的实例..???
CF_EXPORT void CFRunLoopAddCommonMode(CFRunLoopRef rl, CFStringRef mode);

// runloop实例某个模式下一个timer触发的时间
CF_EXPORT CFAbsoluteTime CFRunLoopGetNextTimerFireDate(CFRunLoopRef rl, CFStringRef mode);

// runloop运行起来
CF_EXPORT void CFRunLoopRun(void);

// 指定的mode下面去执行
CF_EXPORT SInt32 CFRunLoopRunInMode(CFStringRef mode, CFTimeInterval seconds, Boolean returnAfterSourceHandled);

// runloop是否在等待
CF_EXPORT Boolean CFRunLoopIsWaiting(CFRunLoopRef rl);

// 叫醒一个runloop
CF_EXPORT void CFRunLoopWakeUp(CFRunLoopRef rl);

// 暂停一个runloop
CF_EXPORT void CFRunLoopStop(CFRunLoopRef rl);

#if __BLOCKS__
// 让某个block在某个mode下去执行block的内容
CF_EXPORT void CFRunLoopPerformBlock(CFRunLoopRef rl, CFTypeRef mode, void (^block)(void)) CF_AVAILABLE(10_6, 4_0); 
#endif

// runloop在指定的mode下存在某个source吗
CF_EXPORT Boolean CFRunLoopContainsSource(CFRunLoopRef rl, CFRunLoopSourceRef source, CFStringRef mode);

// 添加一个source在某个ruanloop的mode下面
CF_EXPORT void CFRunLoopAddSource(CFRunLoopRef rl, CFRunLoopSourceRef source, CFStringRef mode);

// 添加一个source在某个ruanloop下面
CF_EXPORT void CFRunLoopRemoveSource(CFRunLoopRef rl, CFRunLoopSourceRef source, CFStringRef mode);

// runloop在指定的mode下存在某个souobserverrce吗
CF_EXPORT Boolean CFRunLoopContainsObserver(CFRunLoopRef rl, CFRunLoopObserverRef observer, CFStringRef mode);

// 添加一个observer在某个ruanloop的mode下面
CF_EXPORT void CFRunLoopAddObserver(CFRunLoopRef rl, CFRunLoopObserverRef observer, CFStringRef mode);

// 删除一个observer在某个ruanloop的mode下面
CF_EXPORT void CFRunLoopRemoveObserver(CFRunLoopRef rl, CFRunLoopObserverRef observer, CFStringRef mode);

// runloop在指定的mode下存在某个timer吗
CF_EXPORT Boolean CFRunLoopContainsTimer(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFStringRef mode);

// 添加一个timer在某个ruanloop的mode下面
CF_EXPORT void CFRunLoopAddTimer(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFStringRef mode);

// 删除一个timer在某个ruanloop的mode下面
CF_EXPORT void CFRunLoopRemoveTimer(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFStringRef mode);

typedef struct {
    CFIndex	version;
    void *	info;
    const void *(*retain)(const void *info);
    void	(*release)(const void *info);
    CFStringRef	(*copyDescription)(const void *info);
    Boolean	(*equal)(const void *info1, const void *info2);
    CFHashCode	(*hash)(const void *info);
    void	(*schedule)(void *info, CFRunLoopRef rl, CFStringRef mode); // 核心的执行方法
    void	(*cancel)(void *info, CFRunLoopRef rl, CFStringRef mode);
    void	(*perform)(void *info);
} CFRunLoopSourceContext;   // runloop运行的上下文，感觉是source0

typedef struct {
    CFIndex	version;
    void *	info;
    const void *(*retain)(const void *info);
    void	(*release)(const void *info);
    CFStringRef	(*copyDescription)(const void *info);
    Boolean	(*equal)(const void *info1, const void *info2);
    CFHashCode	(*hash)(const void *info);
#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)) || (TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)
    mach_port_t	(*getPort)(void *info);
    void *	(*perform)(void *msg, CFIndex size, CFAllocatorRef allocator, void *info);
#else
    void *	(*getPort)(void *info);
    void	(*perform)(void *info);
#endif
} CFRunLoopSourceContext1;  // runloop运行的上下文，感觉是source1，里面提到了mach_port_t

// 获取LoopSource类型ID
CF_EXPORT CFTypeID CFRunLoopSourceGetTypeID(void);

// 创建一个runloop的Source
CF_EXPORT CFRunLoopSourceRef CFRunLoopSourceCreate(CFAllocatorRef allocator, CFIndex order, CFRunLoopSourceContext *context);

// 获取source在runloop中的index
CF_EXPORT CFIndex CFRunLoopSourceGetOrder(CFRunLoopSourceRef source);

// 让某个soure无效
CF_EXPORT void CFRunLoopSourceInvalidate(CFRunLoopSourceRef source);

// 某个soure是否有效
CF_EXPORT Boolean CFRunLoopSourceIsValid(CFRunLoopSourceRef source);

// 根据传参source来获取当前Context
CF_EXPORT void CFRunLoopSourceGetContext(CFRunLoopSourceRef source, CFRunLoopSourceContext *context);

// 应该是让source去发射一个信号
CF_EXPORT void CFRunLoopSourceSignal(CFRunLoopSourceRef source);

typedef struct {
    CFIndex	version;
    void *	info;
    const void *(*retain)(const void *info);
    void	(*release)(const void *info);
    CFStringRef	(*copyDescription)(const void *info);
} CFRunLoopObserverContext; // Observer的context

// observer的回调
typedef void (*CFRunLoopObserverCallBack)(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info);

// CF框架里面的东西不用管
CF_EXPORT CFTypeID CFRunLoopObserverGetTypeID(void);

// 创建一个Observer
CF_EXPORT CFRunLoopObserverRef CFRunLoopObserverCreate(CFAllocatorRef allocator, CFOptionFlags activities, Boolean repeats, CFIndex order, CFRunLoopObserverCallBack callout, CFRunLoopObserverContext *context);

// 支持block的回调
#if __BLOCKS__
CF_EXPORT CFRunLoopObserverRef CFRunLoopObserverCreateWithHandler(CFAllocatorRef allocator, CFOptionFlags activities, Boolean repeats, CFIndex order, void (^block) (CFRunLoopObserverRef observer, CFRunLoopActivity activity)) CF_AVAILABLE(10_7, 5_0);
#endif

// observer的Activitie
CF_EXPORT CFOptionFlags CFRunLoopObserverGetActivities(CFRunLoopObserverRef observer);

// observer是否是repeat的
CF_EXPORT Boolean CFRunLoopObserverDoesRepeat(CFRunLoopObserverRef observer);

// observer是否是repeat的Order也就是index
CF_EXPORT CFIndex CFRunLoopObserverGetOrder(CFRunLoopObserverRef observer);

// 让这个observer无效
CF_EXPORT void CFRunLoopObserverInvalidate(CFRunLoopObserverRef observer);

// 让这个observer生效
CF_EXPORT Boolean CFRunLoopObserverIsValid(CFRunLoopObserverRef observer);

// 参数代入会带出observer的context
CF_EXPORT void CFRunLoopObserverGetContext(CFRunLoopObserverRef observer, CFRunLoopObserverContext *context);

typedef struct {
    CFIndex	version;
    void *	info;
    const void *(*retain)(const void *info);
    void	(*release)(const void *info);
    CFStringRef	(*copyDescription)(const void *info);
} CFRunLoopTimerContext;    // timer的rContext

// 定义一个callback的block
typedef void (*CFRunLoopTimerCallBack)(CFRunLoopTimerRef timer, void *info);

CF_EXPORT CFTypeID CFRunLoopTimerGetTypeID(void);

// 创建一个Timer
CF_EXPORT CFRunLoopTimerRef CFRunLoopTimerCreate(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval, CFOptionFlags flags, CFIndex order, CFRunLoopTimerCallBack callout, CFRunLoopTimerContext *context);

// 创建一个Timer回调是block
#if __BLOCKS__
CF_EXPORT CFRunLoopTimerRef CFRunLoopTimerCreateWithHandler(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval, CFOptionFlags flags, CFIndex order, void (^block) (CFRunLoopTimerRef timer)) CF_AVAILABLE(10_7, 5_0);
#endif

// 这个timer在runloop里面下一次触发的时间
CF_EXPORT CFAbsoluteTime CFRunLoopTimerGetNextFireDate(CFRunLoopTimerRef timer);

// 设置timer在runloop里面下次fireDate的时间
CF_EXPORT void CFRunLoopTimerSetNextFireDate(CFRunLoopTimerRef timer, CFAbsoluteTime fireDate);

// 让timer无效
CF_EXPORT CFTimeInterval CFRunLoopTimerGetInterval(CFRunLoopTimerRef timer);

// timer是否循环
CF_EXPORT Boolean CFRunLoopTimerDoesRepeat(CFRunLoopTimerRef timer);

// timer的order顺序
CF_EXPORT CFIndex CFRunLoopTimerGetOrder(CFRunLoopTimerRef timer);

// 让这个timer无效
CF_EXPORT void CFRunLoopTimerInvalidate(CFRunLoopTimerRef timer);

// timer是否有效
CF_EXPORT Boolean CFRunLoopTimerIsValid(CFRunLoopTimerRef timer);

// timer在这个runloop里面活动的上下文
CF_EXPORT void CFRunLoopTimerGetContext(CFRunLoopTimerRef timer, CFRunLoopTimerContext *context);

// Setting a tolerance for a timer allows it to fire later than the scheduled fire date, improving the ability of the system to optimize for increased power savings and responsiveness. The timer may fire at any time between its scheduled fire date and the scheduled fire date plus the tolerance. The timer will not fire before the scheduled fire date. For repeating timers, the next fire date is calculated from the original fire date regardless of tolerance applied at individual fire times, to avoid drift. The default value is zero, which means no additional tolerance is applied. The system reserves the right to apply a small amount of tolerance to certain timers regardless of the value of this property.
// As the user of the timer, you will have the best idea of what an appropriate tolerance for a timer may be. A general rule of thumb, though, is to set the tolerance to at least 10% of the interval, for a repeating timer. Even a small amount of tolerance will have a significant positive impact on the power usage of your application. The system may put a maximum value of the tolerance.
// 就是给timer增加一个容忍度
CF_EXPORT CFTimeInterval CFRunLoopTimerGetTolerance(CFRunLoopTimerRef timer) CF_AVAILABLE(10_9, 7_0);
CF_EXPORT void CFRunLoopTimerSetTolerance(CFRunLoopTimerRef timer, CFTimeInterval tolerance) CF_AVAILABLE(10_9, 7_0);

CF_EXTERN_C_END

#endif /* ! __COREFOUNDATION_CFRUNLOOP__ */


//
//  RACScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACImmediateScheduler.h"
#import "RACScheduler+Private.h"
#import "RACSubscriptionScheduler.h"
#import "RACTargetQueueScheduler.h"

static NSInteger count  = 0;

// The key for the thread-specific current scheduler.
NSString * const RACSchedulerCurrentSchedulerKey = @"RACSchedulerCurrentSchedulerKey";

@interface RACScheduler ()
@property (nonatomic, readonly, copy) NSString *name;
@end

@implementation RACScheduler

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> %@", self.class, self, self.name];
}

#pragma mark Initializers

- (id)initWithName:(NSString *)name {
	self = [super init];
	if (self == nil) return nil;

	if (name == nil) {
		_name = [NSString stringWithFormat:@"com.ReactiveCocoa.%@.anonymousScheduler", self.class];
	} else {
		_name = [name copy];
	}

	return self;
}

#pragma mark Schedulers

+ (instancetype)immediateScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *immediateScheduler;
	dispatch_once(&onceToken, ^{
		immediateScheduler = [[RACImmediateScheduler alloc] init];
	});
	
	return immediateScheduler;
}

+ (instancetype)mainThreadScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *mainThreadScheduler;
	dispatch_once(&onceToken, ^{
		mainThreadScheduler = [[RACTargetQueueScheduler alloc] initWithName:@"com.ReactiveCocoa.RACScheduler.mainThreadScheduler" targetQueue:dispatch_get_main_queue()];
	});
	
	return mainThreadScheduler;
}

+ (instancetype)schedulerWithPriority:(RACSchedulerPriority)priority name:(NSString *)name {
	return [[RACTargetQueueScheduler alloc] initWithName:name targetQueue:dispatch_get_global_queue(priority, 0)];
}

+ (instancetype)schedulerWithPriority:(RACSchedulerPriority)priority {
	return [self schedulerWithPriority:priority name:@"com.ReactiveCocoa.RACScheduler.backgroundScheduler"];
}

+ (instancetype)scheduler {
	return [self schedulerWithPriority:RACSchedulerPriorityDefault];
}

+ (instancetype)subscriptionScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *subscriptionScheduler;
	dispatch_once(&onceToken, ^{
		subscriptionScheduler = [[RACSubscriptionScheduler alloc] init];
	});

	return subscriptionScheduler;
}

+ (BOOL)isOnMainThread {
	return [NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue] || [NSThread isMainThread];
}

+ (instancetype)currentScheduler {
	RACScheduler *scheduler = NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey];
	if (scheduler != nil) return scheduler;
	if ([self.class isOnMainThread]) return RACScheduler.mainThreadScheduler;

	return nil;
}

#pragma mark Scheduling

- (RACDisposable *)schedule:(void (^)(void))block {
	NSCAssert(NO, @"%@ must be implemented by subclasses.", NSStringFromSelector(_cmd));
	return nil;
}

- (RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block {
	NSCAssert(NO, @"%@ must be implemented by subclasses.", NSStringFromSelector(_cmd));
	return nil;
}

- (RACDisposable *)afterDelay:(NSTimeInterval)delay schedule:(void (^)(void))block {
	return [self after:[NSDate dateWithTimeIntervalSinceNow:delay] schedule:block];
}

- (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block {
	NSCAssert(NO, @"%@ must be implemented by subclasses.", NSStringFromSelector(_cmd));
	return nil;
}

- (RACDisposable *)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock {
	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

	[self scheduleRecursiveBlock:[recursiveBlock copy] addingToDisposable:disposable];
	return disposable;
}

- (void)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock addingToDisposable:(RACCompoundDisposable *)disposable {
	@autoreleasepool {
        // 为什么要使用selfDisposable这个玩意呢？
        // 此处schedulingDisposable必须需要别人持有那么为了不强引用，那么就找个弱的引用来持有
        //                                              weakSelfDisposable
        //                                                          |弱
        // 持有的关系为disposable (强)->  selfDisposable (强)-> schedulingDisposable
        // 然后删除的时候通过删除weakSelfDisposable来删除selfDisposable找个持有器
		RACCompoundDisposable *selfDisposable = [RACCompoundDisposable compoundDisposable];
        
        // 外面传进来的disposable去添加了管理新生成的这个Disposable
		[disposable addDisposable:selfDisposable];

        // 此处又弱引用Disposable真是搞不明白为什么？
		__weak RACDisposable *weakSelfDisposable = selfDisposable;
        
        count ++;

		RACDisposable *schedulingDisposable = [self schedule:^{
            
			@autoreleasepool {
				// At this point, we've been invoked, so our disposable is now useless.
                // 纯粹为了删除selfDisposable，真不知道什么
				[disposable removeDisposable:weakSelfDisposable];
			}

			if (disposable.disposed) return;

			void (^reallyReschedule)(void) = ^{
				if (disposable.disposed) return;
				[self scheduleRecursiveBlock:recursiveBlock addingToDisposable:disposable];
			};

			// Protects the variables below.
			//
			// This doesn't actually need to be __block qualified, but Clang
			// complains otherwise. :C
			__block NSLock *lock = [[NSLock alloc] init];
			lock.name = [NSString stringWithFormat:@"%@ %s", self, sel_getName(_cmd)];

			__block NSUInteger rescheduleCount = 0;

			// Set to YES once synchronous execution has finished. Further
			// rescheduling should occur immediately (rather than being
			// flattened).
			__block BOOL rescheduleImmediately = NO;
            
            
			@autoreleasepool {
                // 此处通过回调之前的block来执行之前代码里面对Sequence的操作的代码，sequence里面代码不是本次研究的重点后面在研究
                // 之前的block里面有一个回调的参数reschedule()来调用此处的作为参数的block的代码，然后通过是否执行这个作为参数的block
                // 后面来判断rescheduleCount的值，然后来决定是否继续去回调
				recursiveBlock(^{
					[lock lock];
					BOOL immediate = rescheduleImmediately;
					if (!immediate) ++rescheduleCount;
					[lock unlock];

					if (immediate) reallyReschedule();
				});
			}

			[lock lock];
			NSUInteger synchronousCount = rescheduleCount;
			rescheduleImmediately = YES;
			[lock unlock];
            
			for (NSUInteger i = 0; i < synchronousCount; i++) {
                // 此处添加重新调用本方法都会按顺序的被添加到执行的队列中去【self schedule.....】
				reallyReschedule();
			}
		}];

		[selfDisposable addDisposable:schedulingDisposable];
	}
}

- (void)performAsCurrentScheduler:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	// If we're using a concurrent queue, we could end up in here concurrently,
	// in which case we *don't* want to clear the current scheduler immediately
	// after our block is done executing, but only *after* all our concurrent
	// invocations are done.

	RACScheduler *previousScheduler = RACScheduler.currentScheduler;
	NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey] = self;

	@autoreleasepool {
		block();
	}

	if (previousScheduler != nil) {
		NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey] = previousScheduler;
	} else {
		[NSThread.currentThread.threadDictionary removeObjectForKey:RACSchedulerCurrentSchedulerKey];
	}
}

@end

@implementation RACScheduler (Deprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

+ (instancetype)schedulerWithQueue:(dispatch_queue_t)queue name:(NSString *)name {
	NSCParameterAssert(queue != NULL);

	return [[RACTargetQueueScheduler alloc] initWithName:name targetQueue:queue];
}

#pragma clang diagnostic pop

@end

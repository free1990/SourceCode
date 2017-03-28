//
//  RACCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCommand.h"
#import "RACEXTScope.h"
#import "NSArray+RACSequenceAdditions.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACMulticastConnection.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSequence.h"
#import "RACSignal+Operations.h"
#import <libkern/OSAtomic.h>

NSString * const RACCommandErrorDomain = @"RACCommandErrorDomain";
NSString * const RACUnderlyingCommandErrorKey = @"RACUnderlyingCommandErrorKey";

const NSInteger RACCommandErrorNotEnabled = 1;

@interface RACCommand () {
	// The mutable array backing `activeExecutionSignals`.
	//
	// This should only be used while synchronized on `self`.
	NSMutableArray *_activeExecutionSignals;

    // 并行的条件
	// Atomic backing variable for `allowsConcurrentExecution`.
	volatile uint32_t _allowsConcurrentExecution;
}

// An array of signals representing in-flight executions, in the order they
// began.
//
// This property is KVO-compliant.
@property (atomic, copy, readonly) NSArray *activeExecutionSignals;

// `enabled`, but without a hop to the main thread.
//
// Values from this signal may arrive on any thread.
@property (nonatomic, strong, readonly) RACSignal *immediateEnabled;

// The signal block that the receiver was initialized with.
@property (nonatomic, copy, readonly) RACSignal * (^signalBlock)(id input);

// Adds a signal to `activeExecutionSignals` and generates a KVO notification.
- (void)addActiveExecutionSignal:(RACSignal *)signal;

// Removes a signal from `activeExecutionSignals` and generates a KVO
// notification.
- (void)removeActiveExecutionSignal:(RACSignal *)signal;

@end

@implementation RACCommand

#pragma mark Properties

// 允许并行执行的setter和getter方法
- (BOOL)allowsConcurrentExecution {
	return _allowsConcurrentExecution != 0;
}

- (void)setAllowsConcurrentExecution:(BOOL)allowed {
	[self willChangeValueForKey:@keypath(self.allowsConcurrentExecution)];

	if (allowed) {
		OSAtomicOr32Barrier(1, &_allowsConcurrentExecution);
	} else {
		OSAtomicAnd32Barrier(0, &_allowsConcurrentExecution);
	}

	[self didChangeValueForKey:@keypath(self.allowsConcurrentExecution)];
}


// 所有激活执行的的信号s
- (NSArray *)activeExecutionSignals {
	@synchronized (self) {
		return [_activeExecutionSignals copy];
	}
}

// 给实例添加一个激活的信号
- (void)addActiveExecutionSignal:(RACSignal *)signal {
	NSCParameterAssert([signal isKindOfClass:RACSignal.class]);

	@synchronized (self) {
		// The KVO notification has to be generated while synchronized, because
		// it depends on the index remaining consistent.
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:_activeExecutionSignals.count];
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
		[_activeExecutionSignals addObject:signal];
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
	}
}

// 移除一个激活的代码
- (void)removeActiveExecutionSignal:(RACSignal *)signal {
	NSCParameterAssert([signal isKindOfClass:RACSignal.class]);

	@synchronized (self) {
		// The indexes have to be calculated and the notification generated
		// while synchronized, because they depend on the indexes remaining
		// consistent.
		NSIndexSet *indexes = [_activeExecutionSignals indexesOfObjectsPassingTest:^ BOOL (RACSignal *obj, NSUInteger index, BOOL *stop) {
			return obj == signal;
		}];

		if (indexes.count == 0) return;

		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
		[_activeExecutionSignals removeObjectsAtIndexes:indexes];
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
	}
}

#pragma mark Lifecycle

// 原始的初始化方法被废弃
- (id)init {
	NSCAssert(NO, @"Use -initWithSignalBlock: instead");
	return nil;
}

// 用一个返回RACSignal类型的信号的block来创建这个Cammand
- (id)initWithSignalBlock:(RACSignal * (^)(id input))signalBlock {
	return [self initWithEnabled:nil signalBlock:signalBlock];
}

// 用激活的信号和返回RACSignal类型的信号的block来创建这个Cammand
// 里面7个信号，初始化的内容相当的复杂
// ???
- (id)initWithEnabled:(RACSignal *)enabledSignal signalBlock:(RACSignal * (^)(id input))signalBlock {
	NSCParameterAssert(signalBlock != nil);
    
	self = [super init];
	if (self == nil) return nil;
    
    // 初始化激活执行的信号的数组
	_activeExecutionSignals = [[NSMutableArray alloc] init];
	_signalBlock = [signalBlock copy];

    // 新活跃执行的信号
	// A signal of additions to `activeExecutionSignals`.
    
    RACSignal *tempSignals =  [
                               //
                               // 暂时不研究这个keypath如何生成signal ???
                               //  观察了activeExecutionSignals这个属性
                               [self rac_valuesAndChangesForKeyPath:@keypath(self.activeExecutionSignals)
                                                            options:NSKeyValueObservingOptionNew observer:nil]
                               
                               reduceEach:^(id _, NSDictionary *change) {
                                   NSArray *signals = change[NSKeyValueChangeNewKey];
                                   if (signals == nil) return [RACSignal empty];
                                   
                                   return [signals.rac_sequence signalWithScheduler:RACScheduler.immediateScheduler];
                               }];
    
    RACSignal *temp2Signals = [tempSignals concat];
    
	RACSignal *newActiveExecutionSignals = [[temp2Signals publish] autoconnect];

    // 新生成的信号，信号都发送到主线程上去执行，如果是个错误的信号就变成empty信号发送
	_executionSignals = [[[newActiveExecutionSignals
		map:^(RACSignal *signal) {
			return [signal catchTo:[RACSignal empty]];
		}]
		deliverOn:RACScheduler.mainThreadScheduler]
		setNameWithFormat:@"%@ -executionSignals", self];
	
	// `errors` needs to be multicasted so that it picks up all
	// `activeExecutionSignals` that are added.
	//
	// In other words, if someone subscribes to `errors` _after_ an execution
	// has started, it should still receive any error from that execution.
    // 只是将信号中的所有的错误 NSError 转换成了 RACEmptySignal 对象，并派发到主线程上。
	RACMulticastConnection *errorsConnection = [[[newActiveExecutionSignals
		flattenMap:^(RACSignal *signal) {
			return [[signal
				ignoreValues]
				catch:^(NSError *error) { // TODO:catch方法很有意思
					return [RACSignal return:error];
				}];
		}]
		deliverOn:RACScheduler.mainThreadScheduler]
		publish];
	
	_errors = [errorsConnection.signal setNameWithFormat:@"%@ -errors", self];
	[errorsConnection connect];

	RACSignal *immediateExecuting = [RACObserve(self, activeExecutionSignals) map:^(NSArray *activeSignals) {
		return @(activeSignals.count > 0);
	}];

   // executing 是一个表示当前是否有任务执行的信号，这个信号使用了在上一节中介绍的临时变量作为数据源：
	_executing = [[[[[immediateExecuting
		deliverOn:RACScheduler.mainThreadScheduler]
		// This is useful before the first value arrives on the main thread.
		startWith:@NO]
		distinctUntilChanged]
		replayLast]
		setNameWithFormat:@"%@ -executing", self];

	RACSignal *moreExecutionsAllowed = [RACSignal
		if:RACObserve(self, allowsConcurrentExecution)
		then:[RACSignal return:@YES]
		else:[immediateExecuting not]];
	
	if (enabledSignal == nil) {
		enabledSignal = [RACSignal return:@YES];
	} else {
		enabledSignal = [[[enabledSignal
			startWith:@YES]
			takeUntil:self.rac_willDeallocSignal]
			replayLast];
	}
	
	_immediateEnabled = [[RACSignal
		combineLatest:@[ enabledSignal, moreExecutionsAllowed ]]
		and];
	
    // 判断这个comand是否可以执行，
	_enabled = [[[[[self.immediateEnabled
		take:1]
		concat:[[self.immediateEnabled skip:1] deliverOn:RACScheduler.mainThreadScheduler]]
		distinctUntilChanged]
		replayLast]
		setNameWithFormat:@"%@ -enabled", self];

	return self;
}

#pragma mark Execution
// 也没有研究明白
- (RACSignal *)execute:(id)input {
	// `immediateEnabled` is guaranteed to send a value upon subscription, so
	// -first is acceptable here.
	BOOL enabled = [[self.immediateEnabled first] boolValue];
	if (!enabled) {
		NSError *error = [NSError errorWithDomain:RACCommandErrorDomain code:RACCommandErrorNotEnabled userInfo:@{
			NSLocalizedDescriptionKey: NSLocalizedString(@"The command is disabled and cannot be executed", nil),
			RACUnderlyingCommandErrorKey: self
		}];

		return [RACSignal error:error];
	}

    // 最外面的block返回的signal，此时excute的值已经被传进这个信号的subscriber的block里面了
	RACSignal *signal = self.signalBlock(input);
	NSCAssert(signal != nil, @"nil signal returned from signal block for value: %@", input);

	// We subscribe to the signal on the main thread so that it occurs _after_
	// -addActiveExecutionSignal: completes below.
	//
	// This means that `executing` and `enabled` will send updated values before
	// the signal actually starts performing work.
    
    // 用最外面返回的single去生成connnection
    
    // 想不通为什么这个地方要用connection来去包装
    RACSignal *fristSignal = [signal subscribeOn:RACScheduler.mainThreadScheduler];
    
    RACMulticastConnection *connection = [fristSignal multicast:[RACReplaySubject  subject ]];
	
	@weakify(self);
    // -execute: 方法是唯一一个为 addedExecutionSignalsSubject 生产信息的方法。
    // 此处会引起newActiveExecutionSignals的变化，因为上面KVO这个属性
    
	[self addActiveExecutionSignal:connection.signal];
    
    // [connection connect]; 能清理添加进去需要执行的RACSignal
	[connection.signal subscribeError:^(NSError *error) {
		@strongify(self);
		[self removeActiveExecutionSignal:connection.signal];
	} completed:^{
		@strongify(self);
		[self removeActiveExecutionSignal:connection.signal];
	}];

	[connection connect];
	return [connection.signal setNameWithFormat:@"%@ -execute: %@", self, [input rac_description]];
}

#pragma mark NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
	// Generate all KVO notifications manually to avoid the performance impact
	// of unnecessary swizzling.
	return NO;
}

@end

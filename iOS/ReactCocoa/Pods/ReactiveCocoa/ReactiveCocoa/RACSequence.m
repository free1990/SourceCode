//
//  RACSequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACSequence.h"
#import "RACArraySequence.h"
#import "RACDynamicSequence.h"
#import "RACEagerSequence.h"
#import "RACEmptySequence.h"
#import "RACScheduler.h"
#import "RACSignal.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACUnarySequence.h"

// An enumerator over sequences.
@interface RACSequenceEnumerator : NSEnumerator

// The sequence the enumerator is enumerating.
//
// This will change as the enumerator is exhausted. This property should only be
// accessed while synchronized on self.
@property (nonatomic, strong) RACSequence *sequence;

@end

@interface RACSequence ()

// Performs one iteration of lazy binding, passing through values from `current`
// until the sequence is exhausted, then recursively binding the remaining
// values in the receiver.
//
// Returns a new sequence which contains `current`, followed by the combined
// result of all applications of `block` to the remaining values in the receiver.
- (instancetype)bind:(RACStreamBindBlock)block passingThroughValuesFromSequence:(RACSequence *)current;

@end

@implementation RACSequenceEnumerator

- (id)nextObject {
	id object = nil;
	
	@synchronized (self) {
		object = self.sequence.head;
		self.sequence = self.sequence.tail;
	}
	
	return object;
}

@end

@implementation RACSequence

#pragma mark Lifecycle

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock {
	return [[RACDynamicSequence sequenceWithHeadBlock:headBlock tailBlock:tailBlock] setNameWithFormat:@"+sequenceWithHeadBlock:tailBlock:"];
}

#pragma mark Class cluster primitives

- (id)head {
	NSCAssert(NO, @"%s must be overridden by subclasses", __func__);
	return nil;
}

- (RACSequence *)tail {
	NSCAssert(NO, @"%s must be overridden by subclasses", __func__);
	return nil;
}

#pragma mark RACStream

+ (instancetype)empty {
	return RACEmptySequence.empty;
}

+ (instancetype)return:(id)value {
	return [RACUnarySequence return:value];
}

// 绑定的玩法
- (instancetype)bind:(RACStreamBindBlock (^)(void))block {
	RACStreamBindBlock bindBlock = block();
	return [[self bind:bindBlock passingThroughValuesFromSequence:nil] setNameWithFormat:@"[%@] -bind:", self.name];
}

// bind的核心实现的部分，从结果上看的话是生成了一个RACDynamicSequence这个对象
- (instancetype)bind:(RACStreamBindBlock)bindBlock passingThroughValuesFromSequence:(RACSequence *)passthroughSequence {
	// Store values calculated in the dependency here instead, avoiding any kind
	// of temporary collection and boxing.
    //
	// This relies on the implementation of RACDynamicSequence synchronizing
	// access to its head, tail, and dependency, and we're only doing it because
	// we really need the performance.
	__block RACSequence *valuesSeq = self;
	__block RACSequence *current = passthroughSequence;
	__block BOOL stop = NO;

    // 整个block是就是Dependency，会在执行head和tail的时候使用
	RACSequence *sequence = [RACDynamicSequence sequenceWithLazyDependency:^ id {
		while (current.head == nil) {
			if (stop) return nil;

			// We've exhausted the current sequence, create a sequence from the
			// next value.
			id value = valuesSeq.head;

			if (value == nil) {
				// We've exhausted all the sequences.
				stop = YES;
				return nil;
			}

			current = (id)bindBlock(value, &stop);
			if (current == nil) {
				stop = YES;
				return nil;
			}

			valuesSeq = valuesSeq.tail;
		}

		NSCAssert([current isKindOfClass:RACSequence.class], @"-bind: block returned an object that is not a sequence: %@", current);
		return nil;
	} headBlock:^(id _) {
		return current.head;
	} tailBlock:^ id (id _) {
		if (stop) return nil;

		return [valuesSeq bind:bindBlock passingThroughValuesFromSequence:current.tail];
	}];

	sequence.name = self.name;
	return sequence;
}

// 这不会到怎么操作的
- (instancetype)concat:(RACStream *)stream {
	NSCParameterAssert(stream != nil);

	return [[[RACArraySequence sequenceWithArray:@[ self, stream ] offset:0]
		flatten]
		setNameWithFormat:@"[%@] -concat: %@", self.name, stream];
}

// 不知道怎么压缩的
- (instancetype)zipWith:(RACSequence *)sequence {
	NSCParameterAssert(sequence != nil);

	return [[RACSequence
		sequenceWithHeadBlock:^ id {
			if (self.head == nil || sequence.head == nil) return nil;
			return RACTuplePack(self.head, sequence.head);
		} tailBlock:^ id {
			if (self.tail == nil || [[RACSequence empty] isEqual:self.tail]) return nil;
			if (sequence.tail == nil || [[RACSequence empty] isEqual:sequence.tail]) return nil;

			return [self.tail zipWith:sequence.tail];
		}]
		setNameWithFormat:@"[%@] -zipWith: %@", self.name, sequence];
}

#pragma mark Extended methods
// sequence转化成array
- (NSArray *)array {
	NSMutableArray *array = [NSMutableArray array];
	for (id obj in self) {
		[array addObject:obj];
	}

	return [array copy];
}

// 返回一个迭代器
- (NSEnumerator *)objectEnumerator {
	RACSequenceEnumerator *enumerator = [[RACSequenceEnumerator alloc] init];
	enumerator.sequence = self;
	return enumerator;
}

// 直接生成一个signal信号
- (RACSignal *)signal {
    // RACSequence类型转化出一个RACSignal类型的便利方法
    // 那么是怎么用一个sequence实例转化出出来一个signal信号的呢
    // 这边的实现是使用一个RACScheduler作为参数来操作的
	return [[self signalWithScheduler:[RACScheduler scheduler]] setNameWithFormat:@"[%@] -signal", self.name];
}

// 通过一个执行器来返回一个信号的实例，看代码好像是一种递归执行的感觉
- (RACSignal *)signalWithScheduler:(RACScheduler *)scheduler {
    // RACSignal 首先要明白的就是这个地方返回的是一个信号，从sequence到信号，神奇的操作啊
    // 居然整个传参进去的block是一个RACDisposable类型，那么就需要返回一个RACDisposable
    // 这个block里面{}就是didSubscribe的内容
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACSequence *sequence = self;

        // 此处返回的是一个RACDisposable，
		return [scheduler scheduleRecursiveBlock:^(void (^reschedule)(void)) {
            
			if (sequence.head == nil) {
				[subscriber sendCompleted];
				return;
			}

            NSLog(@"subscriber = %@", sequence.head);
			[subscriber sendNext:sequence.head];

			sequence = sequence.tail;
			reschedule();
		}];
	}] setNameWithFormat:@"[%@] -signalWithScheduler: %@", self.name, scheduler];
}

// 从左向右把对象里面内容挨个执行reduce
- (id)foldLeftWithStart:(id)start reduce:(id (^)(id, id))reduce {
	NSCParameterAssert(reduce != NULL);

	if (self.head == nil) return start;
	
	for (id value in self) {
		start = reduce(start, value);
	}
	
	return start;
}

// 通过RACSequence来递归迭代执行
- (id)foldRightWithStart:(id)start reduce:(id (^)(id, RACSequence *))reduce {
	NSCParameterAssert(reduce != NULL);

	if (self.head == nil) return start;
	
	RACSequence *rest = [RACSequence sequenceWithHeadBlock:^{
		return [self.tail foldRightWithStart:start reduce:reduce];
	} tailBlock:nil];
	
	return reduce(self.head, rest);
}

// 看不懂怎么玩的
- (BOOL)any:(BOOL (^)(id))block {
	NSCParameterAssert(block != NULL);

	return [self objectPassingTest:block] != nil;
}

// 检查这个sequence里面所有的value能够通过block的条件
- (BOOL)all:(BOOL (^)(id))block {
	NSCParameterAssert(block != NULL);
	
	NSNumber *result = [self foldLeftWithStart:@YES reduce:^(NSNumber *accumulator, id value) {
		return @(accumulator.boolValue && block(value));
	}];
	
	return result.boolValue;
}

- (id)objectPassingTest:(BOOL (^)(id))block {
	NSCParameterAssert(block != NULL);

	return [self filter:block].head;
}

// 返回一个饥渴的sequence
- (RACSequence *)eagerSequence {
	return [RACEagerSequence sequenceWithArray:self.array offset:0];
}

// 返回一个懒的sequence
- (RACSequence *)lazySequence {
	return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark NSCoding

- (Class)classForCoder {
	// Most sequences should be archived as RACArraySequences.
	return RACArraySequence.class;
}

- (id)initWithCoder:(NSCoder *)coder {
	if (![self isKindOfClass:RACArraySequence.class]) return [[RACArraySequence alloc] initWithCoder:coder];

	// Decoding is handled in RACArraySequence.
	return [super init];
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:self.array forKey:@"array"];
}

#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len {
	if (state->state == ULONG_MAX) {
		// Enumeration has completed.
		return 0;
	}

	// We need to traverse the sequence itself on repeated calls to this
	// method, so use the 'state' field to track the current head.
	RACSequence *(^getSequence)(void) = ^{
		return (__bridge RACSequence *)(void *)state->state;
	};

	void (^setSequence)(RACSequence *) = ^(RACSequence *sequence) {
		// Release the old sequence and retain the new one.
		CFBridgingRelease((void *)state->state);

		state->state = (unsigned long)CFBridgingRetain(sequence);
	};

	void (^complete)(void) = ^{
		// Release any stored sequence.
		setSequence(nil);
		state->state = ULONG_MAX;
	};

	if (state->state == 0) {
		// Since a sequence doesn't mutate, this just needs to be set to
		// something non-NULL.
		state->mutationsPtr = state->extra;

		setSequence(self);
	}

	state->itemsPtr = stackbuf;

	NSUInteger enumeratedCount = 0;
	while (enumeratedCount < len) {
		RACSequence *seq = getSequence();

		// Because the objects in a sequence may be generated lazily, we want to
		// prevent them from being released until the enumerator's used them.
		__autoreleasing id obj = seq.head;
		if (obj == nil) {
			complete();
			break;
		}

		stackbuf[enumeratedCount++] = obj;

		if (seq.tail == nil) {
			complete();
			break;
		}

		setSequence(seq.tail);
	}

	return enumeratedCount;
}

#pragma mark NSObject

- (NSUInteger)hash {
	return [self.head hash];
}

- (BOOL)isEqual:(RACSequence *)seq {
	if (self == seq) return YES;
	if (![seq isKindOfClass:RACSequence.class]) return NO;

	for (id<NSObject> selfObj in self) {
		id<NSObject> seqObj = seq.head;

		// Handles the nil case too.
		if (![seqObj isEqual:selfObj]) return NO;

		seq = seq.tail;
	}

	// self is now depleted -- the argument should be too.
	return (seq.head == nil);
}

@end

@implementation RACSequence (Deprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (id)foldLeftWithStart:(id)start combine:(id (^)(id accumulator, id value))combine {
	return [self foldLeftWithStart:start reduce:combine];
}

- (id)foldRightWithStart:(id)start combine:(id (^)(id first, RACSequence *rest))combine {
	return [self foldRightWithStart:start reduce:combine];
}

#pragma clang diagnostic pop

@end

# BlocksKit(1)-基本类型的分类
BlocksKit是一个用block的方式来解决我们日常用对集合对象遍历、对象快速生成使用、block作为委托对象的一种综合便利封装库。这个库主要分三个大块Core、DynamicDelegate、UIKit三块内容，先分析一下第一部分Core，这个部门里面都是对基本类型的提供的分类接口，能够提供使用的便利。
### 集合类型提供的分类
代码提供了数组、字典、集合等类型的封装，以最常用的NSMutableArray+BlockKit来作为事例看一下：

```
- (void)bk_performSelect:(BOOL (^)(id obj))block;
- (void)bk_performReject:(BOOL (^)(id obj))block;
- (void)bk_performMap:(id (^)(id obj))block;
```

这些个方法，都是利用enumerateObjectsUsingBlock或者indexesOfObjectsPassingTest这些个方法去把block放到里面去进行遍历，然后决定计算出那些值或者是返回那些路径，在整个集合部分的话大概都是这种思路

-------

### 便利的AssociatedObjects
在"NSObject+BKAssociatedObjects.h文件中提供了，便利的绑定方法，我们可以提供一个value和一个key直接就可以在NSObject中绑定属性，省去自己去编写objc_setAssociatedObject和 objc_getAssociatedObject(self, key)的不便利，这里面感觉虽然是放在BlockKit里面其实感觉并无和BlockKit关系不是很大，毕竟NSObject是非常常用的。另外，提供了不同关键字类型的绑定，亮点是实现了weak类型的属性的绑定，这里并没有使用OBJC_ASSOCIATION_ASSIGN这个关键字去绑定，而是把这个weak的value去绑定到一个OBJC_ASSOCIATION_RETAIN_NONATOMIC的对象上。避免使用了OBJC_ASSOCIATION_ASSIGN对使用的时候weak值的不确定性，原因移步（http://www.cocoachina.com/ios/20150629/12299.html），所以作者这个种做法非常的聪明。看一下代码：

```
- (void)bk_weaklyAssociateValue:(__autoreleasing id)value withKey:(const void *)key
{
	_BKWeakAssociatedObject *assoc = objc_getAssociatedObject(self, key);
	if (!assoc) {
		assoc = [_BKWeakAssociatedObject new];
		[self bk_associateValue:assoc withKey:key];
	}
	assoc.value = value;
}

- (id)bk_associatedValueForKey:(const void *)key
{
	id value = objc_getAssociatedObject(self, key);
	if (value && [value isKindOfClass:[_BKWeakAssociatedObject class]]) {
		return [(_BKWeakAssociatedObject *)value value];
	}
	return value;
}

```
_BKWeakAssociatedObject就是weak对象寄存的对象。


-------
### 便利的AssociatedObjects
在开发的时候，block需要不同的执行的情况不同执行。这里为我们提供一些便利的方案，比如，指定block在某个线程上延迟多少时间执行或者在后台执行这些场景。看一下这部分实现的核心的代码：

```
- (id)bk_performBlock:(void (^)(id obj))block onQueue:(dispatch_queue_t)queue afterDelay:(NSTimeInterval)delay
{
	NSParameterAssert(block != nil);
	
	__block BOOL cancelled = NO;
	
	void (^wrapper)(BOOL) = ^(BOOL cancel) {
		if (cancel) {
			cancelled = YES;
			return;
		}
		if (!cancelled) block(self);
	};
	
	dispatch_after(BKTimeDelay(delay), queue, ^{
		wrapper(NO);
	});
	
	return [wrapper copy];
}

```
代码很简单，用了dispatch_after来处理接口传入的数据，然后返回一个叫wrapper的block，这点很好，这个任务能不能被取消就靠它了。一般在使用的时候我们都会保存这个返回的block，当需要取消这个操作的时候，那么就需要调用：

```
+ (void)bk_cancelBlock:(id)block
{
	NSParameterAssert(block != nil);
	void (^wrapper)(BOOL) = block;
	wrapper(YES);
}

```
这个时候传入进去了一个yes，导致在执行的时候，直接就返回，block里面内容就不会被执行，从而达到取消的情况。


-------
### Block版的KVO
在日常的操作中，使用KVO的地方还是很多，但是KVO使用起来，苹果原生的API并没有那么便利，在这里面就提供了另外一种方式的封装，然我们作为开发者能够方便的使用KVO。
看一下最简单的添加观察的接口：

```
- (NSString *)bk_addObserverForKeyPath:(NSString *)keyPath task:(void (^)(id target))task
{
	NSString *token = [[NSProcessInfo processInfo] globallyUniqueString];
	[self bk_addObserverForKeyPaths:@[ keyPath ] identifier:token options:0 context:BKObserverContextKey task:task];
	return token;
}
```
就是传一个keypath和一个block实现绑定的功能，这里面生成token的方法很有意思，生成一个唯一的字符串，作为这一次观察的标记。后面用这个标记加上keypath还可以移除这个观察。

看一下具体的实现代码：


```
- (void)bk_addObserverForKeyPaths:(NSArray *)keyPaths identifier:(NSString *)identifier options:(NSKeyValueObservingOptions)options context:(BKObserverContext)context task:(id)task
{
	NSParameterAssert(keyPaths.count);
	NSParameterAssert(identifier.length);
	NSParameterAssert(task);
    // 第一部分
    Class classToSwizzle = self.class;
    NSMutableSet *classes = self.class.bk_observedClassesHash;
    @synchronized (classes) {
        NSString *className = NSStringFromClass(classToSwizzle);
        if (![classes containsObject:className]) {
            SEL deallocSelector = sel_registerName("dealloc");
            
			__block void (*originalDealloc)(__unsafe_unretained id, SEL) = NULL;
            
			id newDealloc = ^(__unsafe_unretained id objSelf) {
                [objSelf bk_removeAllBlockObservers];
                
                if (originalDealloc == NULL) {
                    struct objc_super superInfo = {
                        .receiver = objSelf,
                        .super_class = class_getSuperclass(classToSwizzle)
                    };
                    
                    void (*msgSend)(struct objc_super *, SEL) = (__typeof__(msgSend))objc_msgSendSuper;
                    msgSend(&superInfo, deallocSelector);
                } else {
                    originalDealloc(objSelf, deallocSelector);
                }
            };
            
            IMP newDeallocIMP = imp_implementationWithBlock(newDealloc);
            
            if (!class_addMethod(classToSwizzle, deallocSelector, newDeallocIMP, "v@:")) {
                // The class already contains a method implementation.
                Method deallocMethod = class_getInstanceMethod(classToSwizzle, deallocSelector);
                
                // We need to store original implementation before setting new implementation
                // in case method is called at the time of setting.
                originalDealloc = (void(*)(__unsafe_unretained id, SEL))method_getImplementation(deallocMethod);
                
                // We need to store original implementation again, in case it just changed.
                originalDealloc = (void(*)(__unsafe_unretained id, SEL))method_setImplementation(deallocMethod, newDeallocIMP);
            }
            
            [classes addObject:className];
        }
    }   
    // 第二部分
	NSMutableDictionary *dict;
	_BKObserver *observer = [[_BKObserver alloc] initWithObservee:self keyPaths:keyPaths context:context task:task];
	[observer startObservingWithOptions:options];

	@synchronized (self) {
		dict = [self bk_observerBlocks];

		if (dict == nil) {
			dict = [NSMutableDictionary dictionary];
			[self bk_setObserverBlocks:dict];
		}
	}

	dict[identifier] = observer;
}
```

这个代码主要分成两个部分：
一个部分是如何去把观察的类的dealloc去swizzle掉，为要这样做呢，就是为了让添加的observer去执行一个remove的操作，去掉之前观察的那些path，防止由于使用者没有移除而导致的崩溃。如果做过这样的处理，那么就会把这个类的名字记录到self.class.bk_observedClassesHash这个NSMutableSet里面去。用于控制不至于把方法替换多遍。
第二部分是如何添加一个_BKObserver对象，这个对象就是一个具体的实例，用来持有我们需要的观察对象，并具体的进行观察的动作，这里要特别注意的是在_BKObserver的对象里面self.observee到底是谁。这个_BKObserver会被通过AssociatedObject方法去绑定到对象上，如果想要彻底的移除，一方面是要移除_BKObserver里面观察的那些个keypath的对象，另一方面是吧_BKObserver从对象绑定的字典里面移除去。
那么看一下_BKObserver的如何实现对keypath的观察：

```
- (void)startObservingWithOptions:(NSKeyValueObservingOptions)options
{
	@synchronized(self) {
		if (_isObserving) return;

		[self.keyPaths bk_each:^(NSString *keyPath) {
			[self.observee addObserver:self forKeyPath:keyPath options:options context:BKBlockObservationContext];
		}];

		_isObserving = YES;
	}
}
```

这里面self.observee就是我们现在操作观察的对象本身，然后呢self就是上面说的生成的_BKObserver（这个对象属性是unsafe_unretained），接着keyPath就是那些传进去的值，这里就是真正添加观察的地方了。然后就，值变化，再接着就回调传进来的block了。最后移除的流程就很简单了，按照上面说的移除流程，就可以了。

到这里，关于Core部门的代码就差不多都看了，很多的时候，这种通过分类去解决问题的思路是需要好好的体会的。通过绑定属性作为中间值，完成一些复杂的操作，按照这种思路都能在开发的过程中解决很多的稍微复杂而且重复的工作。



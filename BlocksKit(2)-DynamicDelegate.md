# BlocksKit(2)-DynamicDelegate
动态代理可以说是这个Block里面最精彩的一部分了，可以通过自己给一个类的的协议方法指定对应的block来实现让这个协议的回调都直接在block里面去执行，那么为什么要这样做呢？从功能的实现上来说，其实所实现的功能是一样，但是在代码的结构上却是非常大的区别。在平常是delegate的时候，我们把一个对象的delegate交给一个弱引用的对象，最常见的就是tableview的实现，然后在这个tableview里面去实现这些协议，对比使用blockkit的方式，代码明显要集中，当一个对象要实现很多个委托的时候，这个时候就会写很多的代码。通过BlockKit的这种实现方式，能够让代码集中起来，而且在比如MVVM或者是函数式编程的风格中，很明显都是更好的选择。这是我个人对为什么要做这个动态代理功能实现的一点体会，知识有限，希望有大侠能够指点出更深层次的东西。那么来看一下这个动态代理到底是怎么实现的呢？


-------
### A2DynamicDelegate
以UIAlertView为例来看一下：

```
[dd implementMethod:@selector(alertView:willDismissWithButtonIndex:) withBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
    NSLog(@"You pushed button #%ld (%@)", buttonIndex, [alertView buttonTitleAtIndex:buttonIndex]);
}];
```
这个地方用用一个block实现了alertView:willDismissWithButtonIndex:这个协议方法的回调，这里面有个implementMethod:withBlock:这个方法，看一下具体的实现：

```
- (void)implementMethod:(SEL)selector withBlock:(id)block
{
	NSCAssert(selector, @"Attempt to implement or remove NULL selector");
	BOOL isClassMethod = self.isClassProxy;

	if (!block) {
		[self.invocationsBySelectors bk_removeObjectForSelector:selector];
		return;
	}

	struct objc_method_description methodDescription = protocol_getMethodDescription(self.protocol, selector, YES, !isClassMethod);
	if (!methodDescription.name) methodDescription = protocol_getMethodDescription(self.protocol, selector, NO, !isClassMethod);

	A2BlockInvocation *inv = nil;
	if (methodDescription.name) {
		NSMethodSignature *protoSig = [NSMethodSignature signatureWithObjCTypes:methodDescription.types];
		inv = [[A2BlockInvocation alloc] initWithBlock:block methodSignature:protoSig];
	} else {
		inv = [[A2BlockInvocation alloc] initWithBlock:block];
	}

	[self.invocationsBySelectors bk_setObject:inv forSelector:selector];
}
```

1. 先是判断是不是类方法，接着判断参数block是否为空
2. 然后根据协议里面selector去取关于这个method的相关的参数信息
3. 如果说名字存在，那么根据这个method的types信息来生成一个方法签名，如果不存在那么就用另外一个初始化方法来初始化一个A2BlockInvocation对象，两个初始化方法的区别后面再进行比较
4. 最后一步把A2BlockInvocation对象作为object，selector作为key的NSHashMap中去，这里面为什么要要用NSHashMap呢，主要这个里面有内存管理的条件选项，并且可以指定一下描述、是否相等的方法，用起来比NSMutableSet要强大的多，再一点要说明额是selector作为key实际是先被包装成一个指针类型，然后再通过桥接成id的方式去生成一个对象，单纯的selector不是对象，是不能作为key来存在的
上面的这段代码就是为了创建一个A2BlockInvocation对象，到这里看到这个对象的名字，想到了为什么动态转发的实际实现其实就是把根据Runtime里面消息转发的规则，然后去拦截，重新生成新的调用对象和方法签名，那继续看文件里面有没有实现消息转发的两个方法呢？果然存在：

```
- (void)forwardInvocation:(NSInvocation *)outerInv；
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
```
验证了我们的想法，所以上面的那一步就是在为这个一步做准备。看一下这两个方法的具体的实现：

```
- (void)forwardInvocation:(NSInvocation *)outerInv
{
	SEL selector = outerInv.selector;
	A2BlockInvocation *innerInv = nil;
	if ((innerInv = [self.invocationsBySelectors bk_objectForSelector:selector])) {
		[innerInv invokeWithInvocation:outerInv];
	} else if ([self.realDelegate respondsToSelector:selector]) {
		[outerInv invokeWithTarget:self.realDelegate];
	}
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	A2BlockInvocation *invocation = nil;
	if ((invocation = [self.invocationsBySelectors bk_objectForSelector:aSelector]))
		return invocation.methodSignature;
	else if ([self.realDelegate methodSignatureForSelector:aSelector])
		return [self.realDelegate methodSignatureForSelector:aSelector];
	else if (class_respondsToSelector(object_getClass(self), aSelector))
		return [object_getClass(self) methodSignatureForSelector:aSelector];
	return [[NSObject class] methodSignatureForSelector:aSelector];
}

```
这两个里面都是根据Selector去到self.invocationsBySelectors里面去拿A2BlockInvocation或者methodSignature，如果取不到A2BlockInvocation的话，就走self.realDelegate来进行处理，如果方法签名拿不到就转发给类方法，再不行就用NSObject来生成一个。

还有A2DynamicDelegate类是继承自NSProxy，这个类本身就是一个处理消息转发的东西并且遵守NSObject的协议，这里面有实现了一些常用的方法：

```
- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
	return protocol_isEqual(aProtocol, self.protocol) || [super conformsToProtocol:aProtocol];
}
- (BOOL)respondsToSelector:(SEL)selector
{
	return [self.invocationsBySelectors bk_objectForSelector:selector] || class_respondsToSelector(object_getClass(self), selector) || [self.realDelegate respondsToSelector:selector];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
	[NSException raise:NSInvalidArgumentException format:@"-[%s %@]: unrecognized selector sent to instance %p", object_getClassName(self), NSStringFromSelector(aSelector), (__bridge void *)self];
}
```
这个文件里面，还有A2DynamicClassDelegate这个类，其实原理是一样的，这里就不再说明，另外有一个获取用户协议的方法有意思：


```
static Protocol *a2_classProtocol(Class _cls, NSString *suffix, NSString *description)
{
	Class cls = _cls;
	while (cls) {
		NSString *className = NSStringFromClass(cls);
		NSString *protocolName = [className stringByAppendingString:suffix];
		Protocol *protocol = objc_getProtocol(protocolName.UTF8String);
		if (protocol) return protocol;

		cls = class_getSuperclass(cls);
	}

	NSCAssert(NO, @"Specify protocol explicitly: could not determine %@ protocol for class %@ (tried <%@>)", description, NSStringFromClass(_cls), [NSStringFromClass(_cls) stringByAppendingString:suffix]);
	return nil;
}
```

这里面是一个while的循环，就是在本类上去找又没有这个协议，如果没有就继续向上在父类的里面去找，如果还是是在找不到那就走断言。
这差不多就把A2DynamicDelegate这个类讲的差不多了。

-------
### A2BlockInvocation
上面的多次提到这个类，现在就这个类来讨论一下，这个类主要是用来干啥的呢？就是存储方法签名和block的方法签名具体执行的block的一个类。刚刚说到两个初始化方法的区别，就是差一个签名参数没传，这个签名参数是要被block代替的那个selector的方法。那如果是自己生成和穿进去的区别就是，这个block没有拦截消息的事件，他本身就是他本身。如以下代码：

```
- (instancetype)initWithBlock:(id)block
{
   //如果不传进来，怎么办，那就自己生成一个
	NSParameterAssert(block);
	NSMethodSignature *blockSignature = [[self class] typeSignatureForBlock:block];
	NSMethodSignature *methodSignature = [[self class] methodSignatureForBlockSignature:blockSignature];
	NSAssert(methodSignature, @"Incompatible block: %@", block);
	return (self = [self initWithBlock:block methodSignature:methodSignature blockSignature:blockSignature]);
}

- (instancetype)initWithBlock:(id)block methodSignature:(NSMethodSignature *)methodSignature
{
	NSParameterAssert(block);
	NSMethodSignature *blockSignature = [[self class] typeSignatureForBlock:block];
	if (![[self class] isSignature:methodSignature compatibleWithSignature:blockSignature]) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Attempted to create block invocation with incompatible signatures" userInfo:@{A2IncompatibleMethodSignatureKey: methodSignature}];
	}
	return (self = [self initWithBlock:block methodSignature:methodSignature blockSignature:blockSignature]);
}

```
这里面有几个方法的实现是我们不常见的，比如
typeSignatureForBlock:block和isSignature:compatibleWithSignature:blockSignature这个连个方法，一个是根据block来生成一个方法签名，另一个是判断协议方法签名和block的方法签名是否兼容。要想明白这个两个方法的实现，就需要了解block内部的数据结构到底是什么样子的。看一下代码：


```
// block的内存结构，在苹果官方的源码中能够找到具体的数据结构，BK的作者只是写了一个
// 一样的结构体
typedef struct _BKBlock {
	__unused Class isa;
	BKBlockFlags flags;
	__unused int reserved;
	void (__unused *invoke)(struct _BKBlock *block, ...);
	struct {
		unsigned long int reserved;
		unsigned long int size;
		// requires BKBlockFlagsHasCopyDisposeHelpers
		void (*copy)(void *dst, const void *src);
		void (*dispose)(const void *);
		// requires BKBlockFlagsHasSignature
		const char *signature;
		const char *layout;
	} *descriptor;
	// imported variables
} *BKBlockRef;

+ (NSMethodSignature *)typeSignatureForBlock:(id)block __attribute__((pure, nonnull(1)))
{
	BKBlockRef layout = (__bridge void *)block;
    // 通过flag标记来判断是够拥有签名
	if (!(layout->flags & BKBlockFlagsHasSignature))
		return nil;
    // 存在的话就行就去到descriptor里面去找
	void *desc = layout->descriptor;
	desc += 2 * sizeof(unsigned long int);

	if (layout->flags & BKBlockFlagsHasCopyDisposeHelpers)
		desc += 2 * sizeof(void *);

	if (!desc)
		return nil;
    //上面通过位移来找到signature的指针
	const char *signature = (*(const char **)desc);
    // 生成NSMethodSignature
	return [NSMethodSignature signatureWithObjCTypes:signature];
}

// 通过参数的数量和返回值判断block的签名和协议方法签名事是否能够兼容
+ (BOOL)isSignature:(NSMethodSignature *)signatureA compatibleWithSignature:(NSMethodSignature *)signatureB __attribute__((pure))
{
	if (!signatureA || !signatureB) return NO;
	if ([signatureA isEqual:signatureB]) return YES;
	if (signatureA.methodReturnType[0] != signatureB.methodReturnType[0]) return NO;

	NSMethodSignature *methodSignature = nil, *blockSignature = nil;
	if (signatureA.numberOfArguments > signatureB.numberOfArguments) {
		methodSignature = signatureA;
		blockSignature = signatureB;
	} else if (signatureB.numberOfArguments > signatureA.numberOfArguments) {
		methodSignature = signatureB;
		blockSignature = signatureA;
	} else {
		return NO;
	}

	NSUInteger numberOfArguments = methodSignature.numberOfArguments;
	for (NSUInteger i = 2; i < numberOfArguments; i++) {
		if ([methodSignature getArgumentTypeAtIndex:i][0] != [blockSignature getArgumentTypeAtIndex:i - 1][0])
			return NO;
	}

	return YES;
}

/// Creates a method signature compatible with a given block signature.
+ (NSMethodSignature *)methodSignatureForBlockSignature:(NSMethodSignature *)original
{
	if (!original) return nil;
    
	if (original.numberOfArguments < 1) {
		return nil;
	}

	if (original.numberOfArguments >= 2 && strcmp(@encode(SEL), [original getArgumentTypeAtIndex:1]) == 0) {
		return original;
	}

	// initial capacity is num. arguments - 1 (@? -> @) + 1 (:) + 1 (ret type)
	// optimistically assuming most signature components are char[1]
	NSMutableString *signature = [[NSMutableString alloc] initWithCapacity:original.numberOfArguments + 1];
    
	const char *retTypeStr = original.methodReturnType;
	// 返回类型，id 类型(self @)，选择子类型(SEL :)
	[signature appendFormat:@"%s%s%s", retTypeStr, @encode(id), @encode(SEL)];
    // signature = (返回类型)@:根据具体的类型继续拼接如@"\TableView\"
	for (NSUInteger i = 1; i < original.numberOfArguments; i++) {
		const char *typeStr = [original getArgumentTypeAtIndex:i];
		NSString *type = [[NSString alloc] initWithBytesNoCopy:(void *)typeStr length:strlen(typeStr) encoding:NSUTF8StringEncoding freeWhenDone:NO];
		[signature appendString:type];
	}

	return [NSMethodSignature signatureWithObjCTypes:signature.UTF8String];
}
```
接下来看一下一个消息收到之后是如何被转发到block上的

```
- (BOOL)invokeWithInvocation:(NSInvocation *)outerInv returnValue:(out NSValue **)outReturnValue setOnInvocation:(BOOL)setOnInvocation
{
	NSParameterAssert(outerInv);

	NSMethodSignature *sig = self.methodSignature;

	if (![outerInv.methodSignature isEqual:sig]) {
		NSAssert(0, @"Attempted to invoke block invocation with incompatible frame");
		return NO;
	}

	NSInvocation *innerInv = [NSInvocation invocationWithMethodSignature:self.blockSignature];

	void *argBuf = NULL;
    // 由于self.methodSignature的隐藏参数有两个就从2开始
    // 然后循环参数传递给block的参数列列表
	for (NSUInteger i = 2; i < sig.numberOfArguments; i++) {
		const char *type = [sig getArgumentTypeAtIndex:i];
		NSUInteger argSize;
		NSGetSizeAndAlignment(type, &argSize, NULL);

		if (!(argBuf = reallocf(argBuf, argSize))) {
			return NO;
		}

		[outerInv getArgument:argBuf atIndex:i];
		//block的Signature签名参数只有一个隐藏，所以要减一
		[innerInv setArgument:argBuf atIndex:i - 1];
	}
    
    // 调用的target设置为block
	[innerInv invokeWithTarget:self.block];

    // 设置返回值
	NSUInteger retSize = sig.methodReturnLength;
	if (retSize) {
		if (outReturnValue || setOnInvocation) {
			if (!(argBuf = reallocf(argBuf, retSize))) {
				return NO;
			}
        
			[innerInv getReturnValue:argBuf];

			if (setOnInvocation) {
				[outerInv setReturnValue:argBuf];
			}

			if (outReturnValue) {
				*outReturnValue = [NSValue valueWithBytes:argBuf objCType:sig.methodReturnType];
			}
		}
	} else {
		if (outReturnValue) {
			*outReturnValue = nil;
		}
	}

	free(argBuf);

	return YES;
}
```

设置了参数和返回值，然后调用，我们block就跑起来，完成了刚开开始的目的



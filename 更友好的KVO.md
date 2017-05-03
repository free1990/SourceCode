# 更友好的KVO
> 前言

观察者模式是大家在开发过程中每个人都要使用的一种设计模式，在iOS的开发流程中，KVO则是这一开发模式的主要实践手段，观察一个属性，当属性值发生变化的就能能够拿到这个属性的新、老、初始化等行为事件，这种模式对于处理model反馈给Controller层是很实用的，在MVC和MVVM等设计模式中都是有着很广泛的应用。但是苹果提供的KVO的API没有那么的友好，在我们的使用中要写一大堆的代码，还需要在delloc的时候进行移除，这样对于工程代码来说，很明显就是一种“坏味”，问题就出现了，怎么解决这个KVO代码复杂的问题呢？Facebook的工程师给出了他们的方案->KVOController,这个方案很好的解决了上面说的问题，KVO变的非常好用，而且不用自己去移除，只能说太棒了。

> KVOController分析

看一下这个库的文件有那些
* KVOController.h
* FBKVOController.h
* NSObject+FBKVOController.h

文件只有三个，一个头文件、一个给NSObject快速生成KVOController文件、最后一个是具体的实现。只能用短小精悍来形容这个库，接着分析一下后两个文件。

### NSObject+FBKVOController.h
这个里面运用了runtime里面的AssociatedObject技术，能够快速的生成FBKVOController，这里面分两种，一种是对object本身产生引用的，一种是对object本身不产生引用的，我们看一下代码上的区别：

```
// 两个不同的地方就是用了不同的初始化方法，在这个文件看来
// 就仅仅如此，具体的不同在另外的文件中去分析
- (FBKVOController *)KVOController
{
  id controller = objc_getAssociatedObject(self, NSObjectKVOControllerKey);
  
  // lazily create the KVOController
  if (nil == controller) {
    controller = [FBKVOController controllerWithObserver:self];
    self.KVOController = controller;
  }
  
  return controller;
}

- (FBKVOController *)KVOControllerNonRetaining
{
  id controller = objc_getAssociatedObject(self, NSObjectKVOControllerNonRetainingKey);
  
  if (nil == controller) {
    // 不同点就是这里，使用不同的初始化方法
    controller = [[FBKVOController alloc] initWithObserver:self retainObserved:NO];
    self.KVOControllerNonRetaining = controller;
  }
  
  return controller;
}

```
这就是这个文件的所有的内容了，另外关于AssociatedObject技术的，这次不做解释


### FBKVOController.h
提供了对开发者调用的API，使用这个库，基本上都是这个这个文件打交道，那么看一下为什么这个库这么好用，具体的实现是怎么样的。
那么我们来看一下，为什么用户使用FBKVOController来处理添加了一个观察的路径，这个路径就能和系统的一样给我们提供观察回调呢？以最常用的

```
- (void)observe:(nullable id)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(FBKVONotificationBlock)block;
```
```
```
为入口，来进行分析。

```
- (void)observe:(nullable id)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(FBKVONotificationBlock)block
{
  NSAssert(0 != keyPath.length && NULL != block, @"missing required parameters observe:%@ keyPath:%@ block:%p", object, keyPath, block);
  if (nil == object || 0 == keyPath.length || NULL == block) {
    return;
  }
  
  // create info
  _FBKVOInfo *info = [[_FBKVOInfo alloc] initWithController:self keyPath:keyPath options:options block:block];
  
  // observe object with info
  [self _observe:object info:info];
}
```

这个代码看到的的是，发现添加观察路径的时候，主要是生成了一个叫_FBKVOInfo的东西，然后又调用[self _observe:object info:info];这个方法，就能完成功能了。先看一下_FBKVOInfo：


```
- (instancetype)initWithController:(FBKVOController *)controller
                           keyPath:(NSString *)keyPath
                           options:(NSKeyValueObservingOptions)options
                             block:(nullable FBKVONotificationBlock)block
                            action:(nullable SEL)action
                           context:(nullable void *)context
{
  self = [super init];
  if (nil != self) {
    _controller = controller;
    _block = [block copy];
    _keyPath = [keyPath copy];
    _options = options;
    _action = action;
    _context = context; // 用于额外信息的传递，不用过度纠结
  }
  return self;
}
```
这个里面记录了观察者、路径、时间处理的block和action以及NSKeyValueObservingOptions和一个context，主要就是信息记录的一个类，需要注意的是_controller是一个弱引用，不会产生循环引用，这个类也就是这个功能，很简单。

接着看一下[self _observe:object info:info]这个方法


```
- (void)_observe:(id)object info:(_FBKVOInfo *)info
{
  // lock
  OSSpinLockLock(&_lock);
  
  NSMutableSet *infos = [_objectInfosMap objectForKey:object];
  
  // check for info existence
  _FBKVOInfo *existingInfo = [infos member:info];
  if (nil != existingInfo) {
    // observation info already exists; do not observe it again
    
    // unlock and return
    OSSpinLockUnlock(&_lock);
    return;
  }
  
  // lazilly create set of infos
  if (nil == infos) {
    infos = [NSMutableSet set];
    [_objectInfosMap setObject:infos forKey:object];
  }
  
  // add info and oberver
  [infos addObject:info];
  
  // unlock prior to callout
  OSSpinLockUnlock(&_lock);
  
  [[_FBKVOSharedController sharedController] observe:object info:info];
}
```

首先看到的是给一个NSMapTable加锁，保证数据读写安全，然后去用object作为key去获取一个_FBKVOInfo的集合，然后判断这个_FBKVOInfo是否已经集合中存在，此处需要注意的是_FBKVOInfo重写了equial方法，如果不是，就把这个_FBKVOInfo添加到集合中去，然后开锁，这里要提到，此处为什么要使用NSMapTable，一个重要的愿意是用NSMapTable能够以弱引用的方式存储值，这一点在常见的字典和数值中都做不到的（http://www.tuicool.com/articles/NRJNJjr）。最后，调用
[[_FBKVOSharedController sharedController] observe:object info:info];继续去完成观察的绑定。那接下来就看这个方法：


```

- (void)observe:(id)object info:(nullable _FBKVOInfo *)info
{
  if (nil == info) {
    return;
  }
  
  // register info
  OSSpinLockLock(&_lock);
  [_infos addObject:info];
  OSSpinLockUnlock(&_lock);
  
  // add observer
  [object addObserver:self forKeyPath:info->_keyPath options:info->_options context:(void *)info];

  if (info->_state == _FBKVOInfoStateInitial) {
    info->_state = _FBKVOInfoStateObserving;
  } else if (info->_state == _FBKVOInfoStateNotObserving) {
    // this could happen when `NSKeyValueObservingOptionInitial` is one of the NSKeyValueObservingOptions,
    // and the observer is unregistered within the callback block.
    // at this time the object has been registered as an observer (in Foundation KVO),
    // so we can safely unobserve it.
    [object removeObserver:self forKeyPath:info->_keyPath context:(void *)info];
  }
}

```

这里吧info添加到_infos这个NSHashTable（key是weak的）对象中去，然后执行真长的添加观察者的操作，可以看到，在这个FBKVO里面所有的观察的都是在这个_FBKVOSharedController单例里面完成的，如果info里面是不观察，就移除掉这个keypath，另外context:(void *)info这点需要注意，直接关系到回调的执行。最后就是执行的代码了：

```
- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSString *, id> *)change
                       context:(nullable void *)context
{
  NSAssert(context, @"missing context keyPath:%@ object:%@ change:%@", keyPath, object, change);
  
  _FBKVOInfo *info;
  
  {
    // lookup context in registered infos, taking out a strong reference only if it exists
    OSSpinLockLock(&_lock);
    info = [_infos member:(__bridge id)context];
    OSSpinLockUnlock(&_lock);
  }
  
  if (nil != info) {
    
    // take strong reference to controller
    FBKVOController *controller = info->_controller;
    if (nil != controller) {
      
      // take strong reference to observer
      id observer = controller.observer;
      if (nil != observer) {
        
        // dispatch custom block or action, fall back to default action
        if (info->_block) {
          info->_block(observer, object, change);
        } else if (info->_action) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
          [observer performSelector:info->_action withObject:change withObject:object];
#pragma clang diagnostic pop
        } else {
          [observer observeValueForKeyPath:keyPath ofObject:object change:change context:info->_context];
        }
      }
    }
  }
}

```

很简单，就是拿到info的信息，根据里面记录的变量的值来进行处理回调等事件，到这里一个完整的观察流程就完成了，要说明的是，这个单例会存在在内存中，KVOController会管理自己管理添加进去的key，在释放的会unobserveAll，也就是把自己添加到单例里面的全部取出来。至于如何去除观察，原理是同样的。

### 总结一下
这个库代码很简单，里面很能体现作者在内存方面的考虑，防止内存引用循环，另外，当初里面会有个单例在里面是我没有想到的，这个单例能让所有的观察都在同一地方，对代码的控制是相当的有功力，我相信简化KVO的思路大家都有过，但是真的把这个东西能完美的做出来，还是需要花费挺大的心思。真的很感谢这些开源代码的贡献者，由衷的敬佩。

总体的架构是：
FBKVO
一个object想要观察自己的path，就把用FBKVOC用一个NSMapTable以这个object对象做为key，然后把这些信息包装成一个kvoinfo去放到一个Set里面，然后作为value存到NSMapTable（字典一样，加个内存控制的条件）里面。
shareKVO
然后在一个单例里面去建立观察，这个时候需要object把观察者设置成单例来处理
_infos是hashmap就像是个集合一样，加内存控制的条件，然后记录KVOInfo的信息
 [object addObserver:self forKeyPath:info->_keyPath options:info->_options context:(void *)info];
 接着在回调的时候：
FBKVOController *controller = info->_controller;
id observer = controller.observer;
if (info->_block) {info->_block(observer, object, change);}
或者
[observer performSelector:info->_action withObject:change withObject:object];
执行，回调的时候时候添加的那个observer。



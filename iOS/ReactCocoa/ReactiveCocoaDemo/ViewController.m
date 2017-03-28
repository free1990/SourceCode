//
//  ViewController.m
//  ReactiveCocoaDemo
//
//  Created by Mr.LuDashi on 15/10/12.
//  Copyright © 2015年 ZeluLi. All rights reserved.
//

#import "ViewController.h"
#import "VCViewModel.h"
#import "LoginSuccessViewController.h"

#import "RACSignalViewController.h"

typedef void(^SignInRespongse)(BOOL result);

@interface ViewController ()
@property (strong, nonatomic) IBOutlet UITextField *userNameTextField;
@property (strong, nonatomic) IBOutlet UITextField *passwordTextField;

@property (strong, nonatomic) IBOutlet UIButton *loginButton;

@property (nonatomic, strong) VCViewModel *viewModel;
@property (nonatomic, strong) NSArray *dataSource;

@property (nonatomic, strong) UIButton *RACSignalButton;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [self bindModel];
//    
//    [self onClick];
//
    
//    [self uppercaseString];
//    [self signalSwitch];
    
//    [self subjectLearn];
//    [self sequenceLearn];
    
//    [self signalLearn];
    
//    [self raccommand];    // 还没搞明白
    
//    [self multicastConnectionLearn];
    
    [self channelTest];
    
    [self addButton];
}

- (void)addButton {
    UIButton *signalButton = [UIButton buttonWithType:UIButtonTypeCustom];
    signalButton.frame = CGRectMake(20, 300, 50, 50);
    [signalButton setTitle:@"signal" forState:UIControlStateNormal];
    [signalButton addTarget:self action:@selector(jumpToSignal) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:signalButton];
}

- (void)jumpToSignal {
    RACSignalViewController *vc = [[RACSignalViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

//关联ViewModel
- (void)bindModel {
    _viewModel = [[VCViewModel alloc] init];
    
    
    RAC(self.viewModel, userName) = self.userNameTextField.rac_textSignal;
    RAC(self.viewModel, password) = self.passwordTextField.rac_textSignal;
    RAC(self.loginButton, enabled) = [_viewModel buttonIsValid];
    
    @weakify(self);
    
    //登录成功要处理的方法
    [self.viewModel.successObject subscribeNext:^(NSArray * x) {
        @strongify(self);
        LoginSuccessViewController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"LoginSuccessViewController"];
        vc.userName = x[0];
        vc.password = x[1];
        [self presentViewController:vc animated:YES completion:^{
            
        }];
    }];
    
    //fail
    [self.viewModel.failureObject subscribeNext:^(id x) {
        
    }];
    
    //error
    [self.viewModel.errorObject subscribeNext:^(id x) {
        
    }];

}
- (void)onClick {
    //按钮点击事件
    [[self.loginButton rac_signalForControlEvents:UIControlEventTouchUpInside]
     subscribeNext:^(id x) {
         [_viewModel login];
     }];
}


//uppercaseString use map
- (void)uppercaseString {
    
    RACSequence *sequence = [@[@"you", @"are", @"beautiful"] rac_sequence];

    // 这个方法相当于把sequence自身作为内容穿进去了，通过去处理head何tail来对每个元素来处理
    // sequence -> signal转化
    RACSignal *signal =  sequence.signal;
    
    // RACSignal -> 如何订阅下来，返回了一个RACDisposable，但是超出{}范围就会释放
    // 需要看一下string是如何返回的，通过在前面生成的signal里面有个回调去通过sequence的head的递归去不断的调用
    // 这里面有两个需要注意的点，就是此方法的执行由两个部分发起，一个是self.didsubscribe发起执行，还有一个是signal的一个循环调用的执行器
//    [signal subscribeNext:^(NSString * x) {
//        NSLog(@"signal --- %@", x);
//    }];
//
    // 表面上看，这个是在原有的信号的基础之上去生成一个新的信号！！！
    // 具体实现是在生成这个新的信号capitalizedSignal的时候，map里面通过不断的方法回调，创建了这个信号，但是在creatSignal的时候
    // 里面做了操作，让以前老的signal传输的信号去生成一个新的信号去处理这个穿进去的blcok
    RACSignal *capitalizedSignal = [signal map:^id(NSString * value) {
                               return [value capitalizedString];
                            }];
    
    
    [capitalizedSignal subscribeNext:^(NSString * x) {
        NSLog(@"capitalizedSignal --- %@", x);
    }];
    
    
//    [[[@[@"you", @"are", @"beautiful"] rac_sequence].signal
//     map:^id(NSString * value) {
//        return [value capitalizedString];
//    }] subscribeNext:^(id x) {
//        NSLog(@"capitalizedSignal --- %@", x);
//    }];
}



//信号开关Switch
- (void)signalSwitch {
    
    //创建3个自定义信号
    RACSubject *google = [RACSubject subject];
    RACSubject *baidu = [RACSubject subject];
    RACSubject *signalOfSignal = [RACSubject subject];
    
    //获取开关信号：这个是怎么实现的呢？
    RACSignal *switchSignal = [signalOfSignal switchToLatest];
    
    //对通过开关的信号量进行操作
    [[switchSignal  map:^id(NSString * value) {
        return [@"https//www." stringByAppendingFormat:@"%@", value];
    }] subscribeNext:^(NSString * x) {
        NSLog(@"%@", x);
    }];
    
    
    //通过开关打开baidu
    [signalOfSignal sendNext:baidu];
    [baidu sendNext:@"baidu.com"];
    [google sendNext:@"google.com"];
//
//    //通过开关打开google
//    [signalOfSignal sendNext:google];
//    [baidu sendNext:@"baidu.com/"];
//    [google sendNext:@"google.com/"];
}


//组合信号
- (void)combiningLatest{
    RACSubject *letters = [RACSubject subject];
    RACSubject *numbers = [RACSubject subject];
    
    [[RACSignal
     combineLatest:@[letters, numbers]
     reduce:^(NSString *letter, NSString *number){
         return [letter stringByAppendingString:number];
     }]
     subscribeNext:^(NSString * x) {
         NSLog(@"%@", x);
     }];
    
    //B1 C1 C2
    [letters sendNext:@"A"];
    [letters sendNext:@"B"];
    [numbers sendNext:@"1"];
    [letters sendNext:@"C"];
    [numbers sendNext:@"2"];
}


//合并信号
- (void)merge {
    RACSubject *letters = [RACSubject subject];
    RACSubject *numbers = [RACSubject subject];
    RACSubject *chinese = [RACSubject subject];
    
    [[RACSignal
     merge:@[letters, numbers, chinese]]
     subscribeNext:^(id x) {
        NSLog(@"merge:%@", x);
    }];
    
    [letters sendNext:@"AAA"];
    [numbers sendNext:@"666"];
    [chinese sendNext:@"你好！"];
}

- (void)doNextThen{
    //doNext, then
    RACSignal *lettersDoNext = [@"A B C D E F G H I" componentsSeparatedByString:@" "].rac_sequence.signal;
    
    [[[lettersDoNext
      doNext:^(NSString *letter) {
          NSLog(@"doNext-then:%@", letter);
      }]
      then:^{
          return [@"1 2 3 4 5 6 7 8 9" componentsSeparatedByString:@" "].rac_sequence.signal;
      }]
      subscribeNext:^(id x) {
          NSLog(@"doNextThenSub:%@", x);
      }];

}

- (void)flattenMap {
    //flattenMap
    RACSequence *numbersFlattenMap = [@"1 2 3 4 5 6 7 8 9" componentsSeparatedByString:@" "].rac_sequence;
    
    [[numbersFlattenMap
      flattenMap:^RACStream *(NSString * value) {
        if (value.intValue % 2 == 0) {
            return [RACSequence empty];
        } else {
            NSString *newNum = [value stringByAppendingString:@"_"];
            return [RACSequence return:newNum];
        }
      }].signal
     subscribeNext:^(id x) {
        NSLog(@"flattenMap:%@", x);
     }];

}

- (void) flatten {
    //Flattening:合并两个RACSignal, 多个Subject共同持有一个Signal
    RACSubject *letterSubject = [RACSubject subject];
    RACSubject *numberSubject = [RACSubject subject];
    
    RACSignal *signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:letterSubject];
        [subscriber sendNext:numberSubject];
        [subscriber sendCompleted];
        return nil;
    }];
    
    RACSignal *flatternSignal = [signal flatten];
    [flatternSignal subscribeNext:^(id x) {
        NSLog(@"%@", x);
    }];
    
    //发信号
    [numberSubject sendNext:@(1111)];
    [numberSubject sendNext:@(1111)];
    [letterSubject sendNext:@"AAAA"];
    [numberSubject sendNext:@(1111)];
}

//输入框过滤
- (void)inputTextFilter{
    //过滤
    [[_userNameTextField.rac_textSignal
      filter:^BOOL(id value) {
          NSString *text = value;
          //长度大于5才执行下方的打印方法
          return text.length > 5;
      }]
     subscribeNext:^(id x) {
         NSLog(@">=5%@", x);
     }];

}
-(void)inputTextViewObserv {
    [_userNameTextField.rac_textSignal subscribeNext:^(id x) {
        NSLog(@"first---%@", x);
    }];
}

//映射和过滤
- (void)mapAndFilter {
    //映射
    [[[_userNameTextField.rac_textSignal
       map:^id(NSString * value) {
           return @(value.length);
       }]
      filter:^BOOL(NSNumber * value) {
          return [value integerValue] > 5;
      }]
     subscribeNext:^(id x) {
         NSLog(@"%@", x);
     }];
}

//RAC的使用
- (void)userRACSetValue {
    //当输入长度超过5时，使用RAC()使背景颜色变化
    RAC(self.view, backgroundColor) = [_userNameTextField.rac_textSignal map:^id(NSString * value) {
        return value.length > 5 ? [UIColor yellowColor] : [UIColor greenColor];
    }];
}


- (void)combineLatestTextField {
    __weak ViewController *copy_self = self;
    //把两个输入框的信号合并成一个信号量，并把其用来改变button的可用性
    RAC(self.loginButton, enabled) = [RACSignal
                                      combineLatest:@[copy_self.userNameTextField.rac_textSignal,
                                                      copy_self.passwordTextField.rac_textSignal]
                                      reduce:^(NSString *userName, NSString *password) {
                                          return @(userName.length > 0 && password.length > 0);
                                      }];

}

- (void)subscribeNext {
    RACSignal *letters = [@"A B C D E F G H I" componentsSeparatedByString:@" "].rac_sequence.signal;
    // Outputs: A B C D E F G H I
    [letters subscribeNext:^(NSString *x) {
        NSLog(@"subscribeNext: %@", x);
    }];

}

- (void)subscribeCompleted {
    
    //Subscription
    __block unsigned subscriptions = 0;
    
    RACSignal *loggingSignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        subscriptions ++;
        [subscriber sendCompleted];
        return nil;
    }];
    
    [loggingSignal subscribeCompleted:^{
        NSLog(@"Subscription1: %d", subscriptions);
    }];
    
    [loggingSignal subscribeCompleted:^{
        NSLog(@"Subscription2: %d", subscriptions);
    }];


}

- (void)sequence {
    //Map：映射
    RACSequence *letter = [@"A B C D E F G H I" componentsSeparatedByString:@" "].rac_sequence;
    
    // Contains: AA BB CC DD EE FF GG HH II
    RACSequence *mapped = [letter map:^(NSString *value) {
        return [value stringByAppendingString:value];
    }];
    [mapped.signal subscribeNext:^(id x) {
        //NSLog(@"Map: %@", x);
    }];
    
    
    //Filter：过滤器
    RACSequence *numberFilter = [@"1 2 3 4 5 6 7 8" componentsSeparatedByString:@" "].rac_sequence;
    //Filter: 2 4 6 8
    [[numberFilter.signal
      filter:^BOOL(NSString * value) {
          return (value.integerValue) % 2 == 0;
      }]
     subscribeNext:^(NSString * x) {
         //NSLog(@"filter: %@", x);
     }];
    
    

    //Combining streams:连接两个RACSequence
    //Combining streams: A B C D E F G H I 1 2 3 4 5 6 7 8
    RACSequence *concat = [letter concat:numberFilter];
    [concat.signal subscribeNext:^(NSString * x) {
       // NSLog(@"concat: %@", x);
    }];
    
    
    //Flattening:合并两个RACSequence
    //A B C D E F G H I 1 2 3 4 5 6 7 8
    RACSequence * flattened = @[letter, numberFilter].rac_sequence.flatten;
    [flattened.signal subscribeNext:^(NSString * x) {
        NSLog(@"flattened: %@", x);
    }];

}

- (void)signalLearn {
    
    RACSignal *signal = [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
        [subscriber sendNext:@1];
        [subscriber sendNext:@2];
        [subscriber sendNext:@3];
        [subscriber sendCompleted];
        return nil;
    }];
    NSLog(@"%@", signal.toArray.rac_sequence);
    
}

- (void)subjectLearn {
    // 本身这个玩意也就是继承自RACSignal这个玩意
//    RACSubject *subject = [RACSubject subject];
//    
//    // Subscriber 1
//    [subject subscribeNext:^(id  _Nullable x) {
//        NSLog(@"1st Sub: %@", x);
//    }];
//    [subject sendNext:@1];
//    
//    // Subscriber 2
//    [subject subscribeNext:^(id  _Nullable x) {
//        NSLog(@"2nd Sub: %@", x);
//    }];
//    [subject sendNext:@2];
//    
//    // Subscriber 3
//    [subject subscribeNext:^(id  _Nullable x) {
//        NSLog(@"3rd Sub: %@", x);
//    }];
//    [subject sendNext:@3];
//    [subject sendCompleted];
    
    
    // RACBehaviorSubject 所有的订阅者发送最新的消息
//    RACBehaviorSubject *bsubject = [RACBehaviorSubject subject];
//    [bsubject subscribeNext:^(id  _Nullable x) {
//        NSLog(@"1st Sub: %@", x);
//    }];
//    [bsubject sendNext:@1];
//    
//    [bsubject subscribeNext:^(id  _Nullable x) {
//        NSLog(@"2nd Sub: %@", x);
//    }];
//    [bsubject sendNext:@2];
//    
//    [bsubject subscribeNext:^(id  _Nullable x) {
//        NSLog(@"3rd Sub: %@", x);
//    }];
//    [bsubject sendNext:@3];
//    [bsubject sendCompleted];
    
    // 先发送现在的信号，然后再所有信号（包括刚刚新来的这个）
    RACReplaySubject *subject = [RACReplaySubject subject];
    
    [subject subscribeNext:^(id  _Nullable x) {
        NSLog(@"1st Subscriber: %@", x);
    }];
    [subject sendNext:@1];
    
    [subject subscribeNext:^(id  _Nullable x) {
        NSLog(@"2nd Subscriber: %@", x);
    }];
    [subject sendNext:@2];

    [subject subscribeNext:^(id  _Nullable x) {
        NSLog(@"3rd Subscriber: %@", x);
    }];
    [subject sendNext:@3];
    [subject sendCompleted];
}

- (void)sequenceLearn {
//    RACSequence *sequence = [RACSequence sequenceWithHeadBlock:^id _Nullable{
//        return @1;
//    } tailBlock:^RACSequence * _Nonnull{
//        return [RACSequence sequenceWithHeadBlock:^id _Nullable{
//            return @2;
//        } tailBlock:^RACSequence * _Nonnull{
//            return [RACSequence return:@3];
//        }];
//    }];
//    RACSequence *bindSequence = [sequence bind:^RACStreamBindBlock _Nonnull{
//        // 此处的block会在bind的block里面去使用
//        return ^(NSNumber *value, BOOL *stop) {
//            NSLog(@"RACSequenceBindBlock: %@", value);
//            value = @(value.integerValue * 2);
//            return [RACSequence return:value];
//        };
//    }];
//    NSLog(@"sequence:     head = (%@), tail=(%@)", sequence.head, sequence.tail);
//    NSLog(@"BindSequence: head = (%@), tail=(%@)", bindSequence.head, bindSequence.tail);
    
    RACSequence *sequence = @[@1, @2, @3].rac_sequence;
    NSNumber *sum = [sequence foldLeftWithStart:0 reduce:^id _Nullable(NSNumber * _Nullable accumulator, NSNumber * _Nullable value) {
        return @(accumulator.integerValue + value.integerValue);
    }];
    NSLog(@"%@", sum);
    
}

- (void)raccommand {
    RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(NSNumber * _Nullable input) {
        
        
        return [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
            NSLog(@"我是最外面的那个block啊");
            NSInteger integer = [input integerValue];
            for (NSInteger i = 0; i < integer; i++) {
                [subscriber sendNext:@(i)];
            }
            [subscriber sendCompleted];
            return nil;
        }];
        
        
    }];
    
    // switchToLatest操作信号的信号
    [[command.executionSignals switchToLatest] subscribeNext:^(id  _Nullable x) {
        NSLog(@"--- >  %@", x);
    }];
    
    [command execute:@1];
//    [RACScheduler.mainThreadScheduler afterDelay:0.1
//                                        schedule:^{
//                                            [command execute:@2];
//                                        }];
//    [RACScheduler.mainThreadScheduler afterDelay:0.2
//                                        schedule:^{
//                                            [command execute:@3];
//                                        }];
}

- (void)multicastConnectionLearn {
    // 如果我想多次订阅这个requestSignal那么每次订阅的时候就会执行这个信号block里面的内容
    // 如果在网络请求的时候，这样就很尴尬了，每个订阅都要执行一遍，真的很讨厌，我想在这个请求返回的时候，执行多了订阅，那就需要别的方案，所以引入了multicastConnection
//    RACSignal *requestSignal = [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
//        NSLog(@"我执行了！！！！！！！");
//        [subscriber sendNext:@1];
//        [subscriber sendNext:@2];
//        [subscriber sendNext:@3];
//        [subscriber sendCompleted];
//        return nil;
//    }];
//
//    [requestSignal subscribeNext:^(id  _Nullable x) {
//        NSLog(@"product: %@", x);
//    }];
//    
//    [requestSignal subscribeNext:^(id  _Nullable x) {
//        NSLog(@"product: %@", x);
//    }];
    
//    // publish这个方法相当于与把源信号封装起来，然后把所有的subscribeNext{}都放到RACSubject里面去
//    RACMulticastConnection *connection = [[RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
//        NSLog(@"我执行了！！！！！！！");
//        
//        // 模拟网路请求的延迟
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [subscriber sendNext:@1];
//            [subscriber sendNext:@2];
//            [subscriber sendCompleted];
//        });
//        
//        return nil;
//    }] publish];
//    
//    [connection.signal subscribeNext:^(id  _Nullable x) {
//        NSLog(@"product: %@", x);
//    }];
//    
//    [connection.signal subscribeNext:^(id  _Nullable x) {
//        NSNumber *number = x;
//        NSLog(@"productId: %ld", [number integerValue] * 2);
//    }];
//    
//    [connection connect];
    
    // 如果想要在connect之后也能收到消息，那该怎么办呢，就要从RACSubject里面动手
    RACSignal *sourceSignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSLog(@"我执行了！！！！！！！");
        
        // 模拟网路请求的延迟
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [subscriber sendNext:@1];
            [subscriber sendNext:@2];
            [subscriber sendCompleted];
        });
        
        return nil;
    }];
    
    // 和上一个例子不一样就是把RACReplaySubject
    RACMulticastConnection *connection = [sourceSignal multicast:[RACReplaySubject subject]];
    [connection.signal subscribeNext:^(id  _Nullable x) {
        NSLog(@"product: %@", x);
    }];
    
    [connection connect];
    
    [connection.signal subscribeNext:^(id  _Nullable x) {
        NSNumber *number = x;
        NSLog(@"productId: %ld", [number integerValue] * 2);
    }];
}

- (void)channelTest {
    RACChannelTerminal *integerChannelT = RACChannelTo(self, dataSource, @[@42]);
    [integerChannelT sendNext:@[@5]]; // (1)
    
    [integerChannelT subscribeNext:^(id value) { // (2)
        NSLog(@"value: %@", value);
    }];
}

- (IBAction)tapGestureRecognizer:(id)sender {
    [self.view endEditing:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

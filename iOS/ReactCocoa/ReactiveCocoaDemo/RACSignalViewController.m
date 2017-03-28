//
//  RACSignalViewController.m
//  ReactiveCocoaDemo
//
//  Created by John on 17/3/28.
//  Copyright © 2017年 ZeluLi. All rights reserved.
//

#import "RACSignalViewController.h"

@interface RACSignalViewController ()

@end

@implementation RACSignalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 自己创建一个Signal
    // 添加map事件
    // 设置订阅的回调
    RACSignal *capitalizedSignal = [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSLog(@"capitalizedSignal run !");
        
        [subscriber sendNext:@"TesT"];
        
        return [RACDisposable disposableWithBlock:^{
            NSLog(@"disposableWithBlock");
        }];
    }] map:^id(id value) {
        return [value lowercaseString];
    }];
    
    [capitalizedSignal subscribeNext:^(NSString * x) {
        NSLog(@"capitalizedSignal --- %@", x);
    }];
    
    [capitalizedSignal subscribeNext:^(NSString * x) {
        NSLog(@"capitalizedSignal 2 --- %@", x);
    }];
    
    NSLog(@"------------------------------startEagerlyWithScheduler");
    // 第二种
    RACSignal *secondRac = [RACSignal startEagerlyWithScheduler:[RACScheduler mainThreadScheduler] block:^(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"哈哈"];
    }];
    [secondRac subscribeNext:^(NSString * x) {
        NSLog(@"secondRac --- %@", x);
    }];
    
    NSLog(@"------------------------------startLazilyWithScheduler");
    // 第二种
    RACSignal *thirdRac = [RACSignal startLazilyWithScheduler:[RACScheduler mainThreadScheduler] block:^(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"卧槽"];
    }];
    [thirdRac subscribeNext:^(NSString * x) {
        NSLog(@"thirdRac --- %@", x);
    }];
    
    NSLog(@"------------------------------concat");
    RACSignal *concatSignal = [secondRac concat:thirdRac];
    [concatSignal subscribeNext:^(NSString * x) {
        NSLog(@"concatSignal --- %@", x);
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

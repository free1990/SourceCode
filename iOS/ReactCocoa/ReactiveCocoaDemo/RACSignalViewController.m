//
//  RACSignalViewController.m
//  ReactiveCocoaDemo
//
//  Created by John on 17/3/28.
//  Copyright © 2017年 ZeluLi. All rights reserved.
//

#import "RACSignalViewController.h"
#import <SDWebImage/UIImageView+WebCache.h>


@interface RACSignalViewController ()

@property (nonatomic, strong) UIImageView *imageView;

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
    
//    _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
//    _imageView.center = self.view.center;
//    _imageView.backgroundColor = [UIColor redColor];
//    [self.view addSubview:_imageView];
//    
//    NSURL *url = [NSURL URLWithString:@"http://d.vpimg1.com/upcb/2017/04/06/18/4_hlbd_570x273_90.jpg"];
//    [_imageView sd_setImageWithURL:url placeholderImage:nil options:SDWebImageHighPriority progress:^(NSInteger receivedSize, NSInteger expectedSize) {
//        NSLog(@"receivedSize = %ld, expectedSize = %ld ", receivedSize, expectedSize);
//    } completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
//        NSLog(@"imageURL = %@, expectedSize = %@ ", imageURL, image);
//    }];
    
    
    NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Application Support/"]];
    NSLog(@"dirEnum == %@", dirEnum);
    
    NSString* path = [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Application Support/"];
    NSURL *pathUrl = [NSURL URLWithString:path];
    NSDirectoryEnumerator *urlEnum = [[NSFileManager defaultManager] enumeratorAtURL:pathUrl includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL]
    ;
    NSLog(@"urlEnum == %@", urlEnum);
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

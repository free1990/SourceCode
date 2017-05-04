//
//  ViewController.m
//  ThirdBeautifulCode
//
//  Created by John on 17/4/19.
//  Copyright © 2017年 John. All rights reserved.
//

#import "ViewController.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import "SDImageCache.h"
#import "BlocksKit.h"
#import "A2DynamicDelegate.h"
#import "UIAlertView+BlocksKit.h"



@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:@"123" forKey:@"zhaoyang"];
    [dic setObject:@"234" forKey:@"zhaoyang"];
    
    id obj = [dic objectForKey:@"zhaoyang"];
    NSLog(@"obj = %@", obj);
    
    
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    imageView.center = self.view.center;
    imageView.backgroundColor = [UIColor redColor];
    [self.view addSubview:imageView];
    
    NSURL *url = [NSURL URLWithString:@"https://ss2.baidu.com/6ONYsjip0QIZ8tyhnq/it/u=1387759763,495806737&fm=58"];
    [imageView sd_setImageWithURL:url placeholderImage:nil options:SDWebImageProgressiveDownload progress:^(NSInteger receivedSize, NSInteger expectedSize) {
        NSLog(@"receivedSize = %ld, expectedSize = %ld ", receivedSize, expectedSize);
    } completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        NSLog(@"imageURL = %@, expectedSize = %@ ", imageURL, image);
    }];
    
    url = [NSURL URLWithString:@"https://ss2.baidu.com/6ON"];
    [imageView sd_setImageWithURL:url placeholderImage:nil options:SDWebImageProgressiveDownload progress:^(NSInteger receivedSize, NSInteger expectedSize) {
        NSLog(@"receivedSize = %ld, expectedSize = %ld ", receivedSize, expectedSize);
    } completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        NSLog(@"imageURL = %@, expectedSize = %@ ", imageURL, image);
    }];
    
    [self bk_addObserverForKeyPath:@"title" task:^(id target) {
        NSLog(@"ahsdhahsdhahsd");
    }];
    
    self.title = @"yyyyy";
    self.title = @"xxxxx";
    
    
    // Create an alert view
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:@"Hello World!"
                              message:@"This alert's delegate is implemented using blocks. That's so cool!"
                              delegate:nil
                              cancelButtonTitle:@"Meh."
                              otherButtonTitles:@"Woo!",@"asdas", nil];
    
    // Get the dynamic delegate
    A2DynamicDelegate *dd = alertView.bk_dynamicDelegate;
    
    // Implement -alertViewShouldEnableFirstOtherButton:
    [dd implementMethod:@selector(alertViewShouldEnableFirstOtherButton:) withBlock:^(UIAlertView *alertView) {
        NSLog(@"Message: %@", alertView.message);
        return YES;
    }];
    
    // Implement -alertView:willDismissWithButtonIndex:
    [dd implementMethod:@selector(alertView:willDismissWithButtonIndex:) withBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
        NSLog(@"zhaoyang - You pushed button #%ld (%@)", buttonIndex, [alertView buttonTitleAtIndex:buttonIndex]);
    }];
     //Set the delegate
    alertView.delegate = dd;
    
    [alertView bk_setWillDismissBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
        NSLog(@"zhaoyang - You pushed button #%ld (%@)", buttonIndex, [alertView buttonTitleAtIndex:buttonIndex]);
    }];
    
    
    
    [alertView show];
    
//    NSString *test = AFPercentEscapedStringFromString(@":-#-[]-@-,!-$-&-'-(-)-*-+-,-;-=-");
//    NSString *test = AFPercentEscapedStringFromString(@"😔");
//    NSLog(@"encode == %@", test);
    
//    NSMutableArray *acceptLanguagesComponents = [NSMutableArray array];
//    [[NSLocale preferredLanguages] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//        float q = 1.0f - (idx * 0.1f);
//        [acceptLanguagesComponents addObject:[NSString stringWithFormat:@"%@;q=%0.1g", obj, q]];
//        *stop = q <= 0.5f;
//    }];
//    NSLog(@"acceptLanguagesComponents = %@", acceptLanguagesComponents); // "en;q=1"
    
    NSLog(@"AFCreateMultipartFormBoundary = %@", AFCreateMultipartFormBoundary());
    NSLog(@"AFCreateMultipartFormBoundary = %@", AFCreateMultipartFormBoundary());
    NSLog(@"AFCreateMultipartFormBoundary = %@", AFCreateMultipartFormBoundary());
}

static NSString * AFCreateMultipartFormBoundary() {
    return [NSString stringWithFormat:@"Boundary+%08X%08X", arc4random(), arc4random()];
}

static NSString * AFPercentEscapedStringFromString(NSString *string) {
    static NSString * const kAFCharactersGeneralDelimitersToEncode = @":#[]@"; // does not include "?" or "/" due to RFC 3986 - Section 3.4
    static NSString * const kAFCharactersSubDelimitersToEncode = @"!$&'()*+,;=";
    
    NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedCharacterSet removeCharactersInString:[kAFCharactersGeneralDelimitersToEncode stringByAppendingString:kAFCharactersSubDelimitersToEncode]];
    
    // FIXME: https://github.com/AFNetworking/AFNetworking/pull/3028
    // return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
    
    static NSUInteger const batchSize = 50;
    
    NSUInteger index = 0;
    NSMutableString *escaped = @"".mutableCopy;
    
    while (index < string.length) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wgnu"
        NSUInteger length = MIN(string.length - index, batchSize);
#pragma GCC diagnostic pop
        NSRange range = NSMakeRange(index, length);
        
        // To avoid breaking up character sequences such as 👴🏻👮🏽
        range = [string rangeOfComposedCharacterSequencesForRange:range];
        
        NSString *substring = [string substringWithRange:range];
        NSString *encoded = [substring stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
        [escaped appendString:encoded];
        
        index += range.length;
    }
    
    return escaped;
}

- (void)test:(NSInteger)testNumber {
    NSLog(@"testNumber = %ld", testNumber);
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

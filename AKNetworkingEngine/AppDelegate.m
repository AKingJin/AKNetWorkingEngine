//
//  AppDelegate.m
//  AKNetworkingEngine
//
//  Created by AKing on 16/4/19.
//  Copyright © 2016年 AKing. All rights reserved.
//

#import "AppDelegate.h"
#import <AFNetworking.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.

    NSString *URLString = @"http://example.com";
    NSDictionary *parameters = @{@"foo": @"bar", @"baz": @"1"};
    
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"GET" URLString:URLString parameters:parameters error:nil];
//    GET URL: http://example.com?baz=1&foo=bar
//    
//    URL Form Parameter Encoding
    
    NSMutableURLRequest *request1 = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"POST" URLString:URLString parameters:parameters error:nil];
    NSString *str1 = [[NSString alloc] initWithData:request1.HTTPBody encoding:NSUTF8StringEncoding];;
//    POST http://example.com/
//    Content-Type: application/x-www-form-urlencoded
//    baz=1&foo=bar
//    
//    JSON Parameter Encoding
//    
    NSMutableURLRequest *request2 = [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST" URLString:URLString parameters:parameters error:nil];
    NSString *str2 = [[NSString alloc] initWithData:request2.HTTPBody encoding:NSUTF8StringEncoding];;
//    POST http://example.com/
//    Content-Type: application/json
//    {"foo":"bar","baz":"1"}
    
    NSMutableURLRequest *request3 = [[AFJSONRequestSerializer serializer] requestWithMethod:@"GET" URLString:URLString parameters:parameters error:nil];
    
    NSLog(@"request1.HTTPBody:%@...\n request2.HTTPBody:%@,,,",str1,str2);
    /**
     (lldb) po request
     <NSMutableURLRequest: 0x7f9b2b755480> { URL: http://example.com?baz=1&foo=bar }
     
     (lldb) po request1
     <NSMutableURLRequest: 0x7f9b2b755950> { URL: http://example.com }
     
     (lldb) po str1
     baz=1&foo=bar
     
     (lldb) po request2
     <NSMutableURLRequest: 0x7f9b2b46bd10> { URL: http://example.com }
     
     (lldb) po str2
     {"foo":"bar","baz":"1"}
     
     (lldb) po request3
     <NSMutableURLRequest: 0x7f9b2b753a30> { URL: http://example.com?baz=1&foo=bar }
     
     2016-04-20 17:13:58.442 AKNetworkingEngine[10144:255352] request1.HTTPBody:baz=1&foo=bar...
     request2.HTTPBody:{"foo":"bar","baz":"1"},,,
     */
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end

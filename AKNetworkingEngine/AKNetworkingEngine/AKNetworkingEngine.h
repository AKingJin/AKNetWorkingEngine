//
//  AKNetworkingEngine.h
//  AKNetworkingEngine
//
//  Created by AKing on 16/4/19.
//  Copyright © 2016年 AKing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
/**
 *  基于AFNetworking 3.x（NSURLSession）的封装
 */

// 项目打包上线都不会打印日志，因此可放心。
#ifdef DEBUG
#define AKLog(s, ... ) NSLog( @"[%@ in line %d] ===============>%@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define AKLog(s, ... )
#endif

typedef NS_ENUM(NSUInteger, AKBOOLType) {
    AKBOOLTypeGlobalValue = 1, // 默认使用全局的的配置值
    AKBOOLTypeInverseGlobalValue  = 2, // 使用取反的全局配置值
};

/*
 请求格式
 
 AFHTTPRequestSerializer            二进制格式
 AFJSONRequestSerializer            JSON
 AFPropertyListRequestSerializer    PList(是一种特殊的XML,解析起来相对容易)
 
 返回格式
 
 AFHTTPResponseSerializer           二进制格式
 AFJSONResponseSerializer           JSON
 AFXMLParserResponseSerializer      XML,只能返回XMLParser,还需要自己通过代理方法解析
 AFXMLDocumentResponseSerializer (Mac OS X)
 AFPropertyListResponseSerializer   PList
 AFImageResponseSerializer          Image
 AFCompoundResponseSerializer       组合
 */


typedef NS_ENUM(NSUInteger, AKResponseType) {
    AKResponseTypeJSON = 1, // 默认
    AKResponseTypeXML  = 2, // XML
    AKResponseTypeData = 3 //二进制数据
};

typedef NS_ENUM(NSUInteger, AKRequestType) {
    AKRequestTypeData  = 1, // 二进制格式
    AKRequestTypeJSON = 2, // 
    
};

typedef NSURLSessionTask AKAFURLSessionData;
typedef NSURLSessionUploadTask AKAFURLSessionUpload;
typedef NSURLSessionDownloadTask AKAFURLSessionDownload;

typedef void(^AKResponseSuccess)(id response);
typedef void(^AKResponseFail)(id response);

typedef void (^AKProgress)(NSProgress *progress);

typedef AKProgress AKGetProgress;
typedef AKProgress AKPostProgress;
typedef AKProgress AKUploadProgress;
typedef AKProgress AKDownloadProgress;

@interface AKNetworkingEngine : NSObject

#pragma mark - 全局配置
/**
 *  保存并且更新网络请求的baseUrl（当已存在baseUrl时替换更新，用于处理不同接口来源于不同服务器）， 通常在AppDelegate中启动时就设置一次（当不同接口的服务器不同时要再次调用）
 *
 *  @param urlStr 接口服务器的基础url
 */
+ (void)saveAndUpdateBaseUrl:(NSString *)urlStr;

+ (NSString *)baseUrl;

+ (void)autoEncodeUrl:(BOOL)encode;

+ (void)configRequestType:(AKRequestType)requestType responseType:(AKResponseType)responseType;

+ (void)configHttpHeaders:(NSDictionary *)httpHeaders;

+ (void)cacheGetRequest:(BOOL)isCacheGet cachePost:(BOOL)isCachePost;

+ (void)enableDebug:(BOOL)isDebug;

#pragma mark - 请求接口
/**
 *  <#Description#>
 *
 *  @param relativeUrlStr 也可以传入绝对url
 *  @param shouldEncode   <#shouldEncode description#>
 *  @param refresh        <#refresh description#>
 *  @param params         <#params description#>
 *  @param progress       <#progress description#>
 *  @param success        <#success description#>
 *  @param fail           <#fail description#>
 *
 *  @return <#return value description#>
 */
+ (AKAFURLSessionData *)getWithUrl:(NSString *)relativeUrlStr
                shouldEncodeUrl:(AKBOOLType)shouldEncode
                    shouldCache:(AKBOOLType)shouldCache
                   refreshCache:(BOOL)refresh
                         params:(NSDictionary *)params
                       progress:(AKGetProgress)progress
                        success:(AKResponseSuccess)success
                           fail:(AKResponseFail)fail;

+ (AKAFURLSessionData *)postWithUrl:(NSString *)relativeUrlStr
                 shouldEncodeUrl:(AKBOOLType)shouldEncode
                     shouldCache:(AKBOOLType)shouldCache
                    refreshCache:(BOOL)refresh
                          params:(NSDictionary *)params
                        progress:(AKPostProgress)progress
                         success:(AKResponseSuccess)success
                            fail:(AKResponseFail)fail;

+ (AKAFURLSessionData *)uploadImage:(UIImage *)image
                             url:(NSString *)relativeUrlStr
                 shouldEncodeUrl:(AKBOOLType)shouldEncode
                        filename:(NSString *)filename
                            name:(NSString *)name
                        mimeType:(NSString *)mimeType
                          params:(NSDictionary *)params
                        progress:(AKUploadProgress)progress
                         success:(AKResponseSuccess)success
                            fail:(AKResponseFail)fail;

+ (AKAFURLSessionUpload *)uploadFile:(NSString *)file
                            url:(NSString *)relativeUrlStr
                shouldEncodeUrl:(AKBOOLType)shouldEncode
                       progress:(AKUploadProgress)progress
                        success:(AKResponseSuccess)success
                           fail:(AKResponseFail)fail;

+ (AKAFURLSessionDownload *)downloadWithUrl:(NSString *)relativeUrlStr
                     shouldEncodeUrl:(AKBOOLType)shouldEncode
                          saveToPath:(NSString *)saveToPath
                            progress:(AKDownloadProgress)progress
                             success:(AKResponseSuccess)success
                                fail:(AKResponseFail)fail;

#pragma mark - 其他操作
+ (void)cancelAllRequest;

+ (void)cancelRequestWithUrl:(NSString *)urlStr;

+ (unsigned long long)totalCacheSize;

+ (void)clearCaches;





























@end

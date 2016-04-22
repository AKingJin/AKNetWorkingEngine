//
//  AKNetworkingEngine.m
//  AKNetworkingEngine
//
//  Created by AKing on 16/4/19.
//  Copyright © 2016年 AKing. All rights reserved.
//

#import "AKNetworkingEngine.h"
#import <AFNetworking.h>
#import <AFNetworkActivityIndicatorManager.h>

#import <CommonCrypto/CommonDigest.h>
@interface NSString (Utility)

+ (NSString *)networking_md5:(NSString *)string;
- (NSString *)removeWhiteSpacesFromString;

@end

@implementation NSString (Utility)

+ (NSString *)networking_md5:(NSString *)string {
    if (string == nil || [string length] == 0) {
        return nil;
    }
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
    CC_MD5([string UTF8String], (int)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
    NSMutableString *ms = [NSMutableString string];
    
    for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [ms appendFormat:@"%02x", (int)(digest[i])];
    }
    
    return [ms copy];
}

// remove white spaces from String
- (NSString *)removeWhiteSpacesFromString
{
    NSString *trimmedString = [self stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmedString;
}

@end


#define AK_IS_STRING_NIL(str)  (([[str removeWhiteSpacesFromString] isEqualToString:@""] || \
                                str == nil || \
                                [str isEqualToString:@"(null)"]) ? YES : NO) || \
                                [str isKindOfClass:[NSNull class]]

//默认全局设置（静态变量实现）。。
static NSString *sg_privateNetworkBaseUrl = nil;
static BOOL sg_isEnableDebug = NO;
static BOOL sg_shouldAutoEncode = NO;
static NSDictionary *sg_givenHttpHeaders = nil;//set the value of the given HTTP header field.，，
static NSDictionary *sg_addHttpHeaders = nil;//Adds an HTTP header field..设置自身业务所需的请求头
static AKResponseType sg_responseType = AKResponseTypeJSON;
static AKRequestType  sg_requestType  = AKRequestTypeJSON;
static NSMutableArray *sg_requestTasks;
static BOOL sg_cacheGet = YES;
static BOOL sg_cachePost = NO;
//static BOOL sg_shouldCallbackOnCancelRequest = YES;

typedef NS_ENUM(NSUInteger, AKHttpMethodType) {
    AKHttpMethodTypeGet = 1,
    AKHttpMethodTypePost  = 2
};

@implementation AKNetworkingEngine

#pragma mark - 全局配置

+ (void)saveBaseUrl:(NSString *)urlStr
{
    sg_privateNetworkBaseUrl = urlStr;
}

+ (NSString *)baseUrl
{
    return sg_privateNetworkBaseUrl;
}

+ (void)autoEncodeUrl:(BOOL)encode
{
    sg_shouldAutoEncode = encode;
}

+ (BOOL)shouldEncode
{
    return sg_shouldAutoEncode;
}

+ (void)configRequestType:(AKRequestType)requestType responseType:(AKResponseType)responseType
{
    sg_requestType = requestType;
    sg_responseType = responseType;
}

+ (void)configGivenHttpHeaders:(NSDictionary *)givenHttpHeaders
{
    sg_givenHttpHeaders = givenHttpHeaders;
}

+ (NSDictionary *)givenHttpHeaders
{
    return sg_givenHttpHeaders;
}

+ (void)configAddHttpHeaders:(NSDictionary *)addHttpHeaders
{
    sg_addHttpHeaders = addHttpHeaders;
}

+ (NSDictionary *)addHttpHeaders
{
    return sg_addHttpHeaders;
}

+ (void)cacheGetRequest:(BOOL)isCacheGet cachePost:(BOOL)isCachePost
{
    sg_cacheGet = isCacheGet;
    sg_cachePost = isCachePost;
}

+ (BOOL)isCacheGet
{
    return sg_cacheGet;
}

+ (BOOL)isCachePost
{
    return sg_cachePost;
}

+ (void)enableDebug:(BOOL)isDebug
{
    sg_isEnableDebug = isDebug;
}

+ (BOOL)isDebug
{
    return sg_isEnableDebug;
}

#pragma mark - 请求接口

+ (AKAFURLSessionData *)getWithUrl:(NSString *)relativeUrlStr
                shouldEncodeUrl:(AKBOOLType)shouldEncode
                    shouldCache:(AKBOOLType)shouldCache
                   refreshCache:(BOOL)refresh
                         params:(NSDictionary *)params
                       progress:(AKGetProgress)progress
                        success:(AKResponseSuccess)success
                           fail:(AKResponseFail)fail
{
    return [self requestWithMethod:AKHttpMethodTypeGet
                               url:relativeUrlStr
                   shouldEncodeUrl:shouldEncode
                       shouldCache:shouldCache
                      refreshCache:refresh
                            params:params
                          progress:progress
                           success:success
                              fail:fail];
}

+ (AKAFURLSessionData *)postWithUrl:(NSString *)relativeUrlStr
                 shouldEncodeUrl:(AKBOOLType)shouldEncode
                     shouldCache:(AKBOOLType)shouldCache
                    refreshCache:(BOOL)refresh
                          params:(NSDictionary *)params
                        progress:(AKPostProgress)progress
                         success:(AKResponseSuccess)success
                            fail:(AKResponseFail)fail
{
    return [self requestWithMethod:AKHttpMethodTypePost
                               url:relativeUrlStr
                   shouldEncodeUrl:shouldEncode
                       shouldCache:shouldCache
                      refreshCache:refresh
                            params:params
                          progress:progress
                           success:success
                              fail:fail];
}

+ (AKAFURLSessionData *)requestWithMethod:(AKHttpMethodType)mType
                                   url:(NSString *)relativeUrlStr
                       shouldEncodeUrl:(AKBOOLType)shouldEncode
                           shouldCache:(AKBOOLType)shouldCache
                          refreshCache:(BOOL)refresh
                                params:(NSDictionary *)params
                              progress:(AKPostProgress)progress
                               success:(AKResponseSuccess)success
                                  fail:(AKResponseFail)fail
{
    // 开启转圈圈?????????????多个地方关闭。。。。。
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    
    if ((shouldEncode == AKBOOLTypeGlobalValue && [self shouldEncode]) ||
        (shouldEncode == AKBOOLTypeInverseGlobalValue && ![self shouldEncode])) {
        relativeUrlStr = [self encodeUrl:relativeUrlStr];
    }
    NSString *absoluteUrlStr = [self absoluteUrlWithPath:relativeUrlStr];
    if (AK_IS_STRING_NIL(absoluteUrlStr)) {
        AKLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
        
        [AFNetworkActivityIndicatorManager sharedManager].enabled = NO;
        if (fail) {
            fail(nil);
        }
        
        return nil;
    }

    /************************请求行：请求方法，请求资源路径，HTTP协议版本**************************/
    NSString *method = @"GET";
    
    AKProgress uploadProgress = nil;
    AKProgress downloadProgress = nil;
    
    if (mType == AKHttpMethodTypeGet) {
        
        if (((shouldCache == AKBOOLTypeGlobalValue && [self isCacheGet]) ||
             (shouldCache == AKBOOLTypeInverseGlobalValue && ![self isCacheGet]))
            && !refresh) {// 获取缓存
            
            id response = [self cahceResponseWithURL:absoluteUrlStr
                                          parameters:params];
            if (response) {
                if (success) {
                    [self successResponse:response callback:success];
                    
                    if ([self isDebug]) {
                        [self logWithSuccessResponse:response
                                                 url:absoluteUrlStr
                                              params:params];
                    }
                }
                
                return nil;
            }
        }
        
        method = @"GET";
        
        downloadProgress = progress;
        
    }else if (mType == AKHttpMethodTypePost) {
        if (((shouldCache == AKBOOLTypeGlobalValue && [self isCachePost]) ||
             (shouldCache == AKBOOLTypeInverseGlobalValue && ![self isCachePost]))
            && !refresh) {// 获取缓存
            id response = [self cahceResponseWithURL:absoluteUrlStr
                                          parameters:params];
            
            if (response) {
                if (success) {
                    [self successResponse:response callback:success];
                    
                    if ([self isDebug]) {
                        [self logWithSuccessResponse:response
                                                 url:absoluteUrlStr
                                              params:params];
                    }
                }
                
                return nil;
            }
        }
        
        method = @"POST";
        
        uploadProgress = progress;
    }
    
    
    //???params 相应处理
    /**
     Creates an `NSMutableURLRequest` object with the specified HTTP method and URL string.
     
     If the HTTP method is `GET`, `HEAD`, or `DELETE`, the parameters will be used to construct a url-encoded query string that is appended to the request's URL. Otherwise, the parameters will be encoded according to the value of the `parameterEncoding` property, and set as the request body.
     
     @param method The HTTP method for the request, such as `GET`, `POST`, `PUT`, or `DELETE`. This parameter must not be `nil`.
     @param URLString The URL string used to create the request URL.
     @param parameters The parameters to be either set as a query string for `GET` requests, or the request HTTP body.
     @param error The error that occured while constructing the request.
     
     @return An `NSMutableURLRequest` object.
     
     /////////////////////////////////////////////////////////////////////
     For Example
     Request Serialization
     
     Request serializers create requests from URL strings, encoding parameters as either a query string or HTTP body.
     
     NSString *URLString = @"http://example.com";
     NSDictionary *parameters = @{@"foo": @"bar", @"baz": @"1"};
     
     Query String Parameter Encoding
     
     [[AFHTTPRequestSerializer serializer] requestWithMethod:@"GET" URLString:URLString parameters:parameters error:nil];
     GET http://example.com?foo=bar&baz=1
     
     URL Form Parameter Encoding
     
     [[AFHTTPRequestSerializer serializer] requestWithMethod:@"POST" URLString:URLString parameters:parameters error:nil];
     POST http://example.com/
     Content-Type: application/x-www-form-urlencoded
     foo=bar&baz=1
     
     JSON Parameter Encoding
     
     [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST" URLString:URLString parameters:parameters error:nil];
     POST http://example.com/
     Content-Type: application/json
     {"foo": "bar", "baz": @"1"}
     
     */
    
    //对于GET请求当服务器定义的url不是'http://example.com?foo=bar&baz=1'这样的格式(?&)时,
    //例如:'http://example.com/bar-1'这样的格式(/-)
    //此时需要按需求格式手动拼接absoluteUrlStr和params，，
    //absoluteUrlStr = [NSString stringWithFormat:@"%@/%@-%@",absoluteUrlStr,foo,baz];
    //parameters参数传nil。。因为不再需要'?&'这种格式。。
    AFHTTPSessionManager *manager = [self manager];
    NSMutableURLRequest *request = nil;
    NSError *serializationError = nil;
    request = [manager.requestSerializer requestWithMethod:method
                                                 URLString:absoluteUrlStr
                                                parameters:params
                                                     error:&serializationError];
    if (serializationError) {
        if (fail) {
            fail(nil);
        }
        
        return nil;
    }
    
    
    /*
    //1、multipartFormRequestWithMethod不同于'requestWithMethod'的关键点
    //Creates an `NSMutableURLRequest` object with the specified HTTP method and URLString,
    //constructs a `multipart/form-data` HTTP body, using the specified parameters and multipart form data block(不同处，，).
    //2、对于这两个方法中parameters参数的理解
    //requestWithMethod GET 中parameters参数用于生成完整URL，当URL格式需要自定义时parameters传入nil，手动按格式拼接出URL
    //POST 中parameters参数用于生成请求体，当需要手动设置请求体时parameters传入nil，设置request的HTTPBodyStream或HTTPBody
    request = [manager.requestSerializer multipartFormRequestWithMethod:@"POST"
                                                              URLString:absoluteUrlStr
                                                             parameters:params
                                              constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                                                  
                                              } error:nil];
     */
    
    /************************请求头：请求服务器地址，客户端系统环境，客户端所能接受的数据类型**************************/
    [self configRequestHeaders:request];
    
    
    /************************请求体：客户端发给服务器的具体数据，**************************/
    //在生成request的方法中当parameters参数不为nil时已将parameters参数转换成相应格式(AFHTTPRequestSerializer&AFJSONRequestSerializer)的request请求体，，
    //在需要自行设置请求体时可将parameters传入nil，设置request的HTTPBodyStream或HTTPBody
    
    
    __block AKAFURLSessionData *session = nil;
    __block AKHttpMethodType blockMType = mType;
    session = [manager dataTaskWithRequest:request
                            uploadProgress:uploadProgress
                          downloadProgress:downloadProgress
                         completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                             // 关闭转圈圈
                             [AFNetworkActivityIndicatorManager sharedManager].enabled = NO;
                             if (error) {
                                 
                                 [[self allTasks] removeObject:session];
                                 
                                 if (fail) {
                                     fail(error);
                                 }
                                 
                                 if ([self isDebug]) {
                                     [self logWithFailError:error url:absoluteUrlStr params:params];
                                 }
                             } else {
                                [self successResponse:responseObject callback:success];
                                 
                                 if (blockMType == AKHttpMethodTypeGet) {
                                     if ((shouldCache == AKBOOLTypeGlobalValue && [self isCacheGet]) ||
                                         (shouldCache == AKBOOLTypeInverseGlobalValue && ![self isCacheGet])) {
                                         
                                         [self cacheResponseObject:responseObject request:session.currentRequest parameters:params];
                                     }
                                 }else if (blockMType == AKHttpMethodTypePost) {
                                     if ((shouldCache == AKBOOLTypeGlobalValue && [self isCachePost]) ||
                                         (shouldCache == AKBOOLTypeInverseGlobalValue && ![self isCachePost])) {
                                         [self cacheResponseObject:responseObject request:session.currentRequest  parameters:params];
                                     }
                                 }
                                 
                                 
                                 
                                 [[self allTasks] removeObject:session];
                                 
                                 
                                 if ([self isDebug]) {
                                     
                                     [self logWithSuccessResponse:responseObject
                                                              url:absoluteUrlStr
                                                           params:params];
                                     
                                 }
                             }
                            }];

    
    [session resume];////????????????
    if (session) {
        [[self allTasks] addObject:session];
    }
    
    return session;
}


+ (AKAFURLSessionData *)uploadImage:(UIImage *)image
                             url:(NSString *)relativeUrlStr
                 shouldEncodeUrl:(AKBOOLType)shouldEncode
                        filename:(NSString *)filename
                            name:(NSString *)name
                        mimeType:(NSString *)mimeType
                          params:(NSDictionary *)params
                        progress:(AKUploadProgress)progress
                         success:(AKResponseSuccess)success
                            fail:(AKResponseFail)fail
{
    // 开启转圈圈?????????????多个地方关闭。。。。。
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    
    if ((shouldEncode == AKBOOLTypeGlobalValue && [self shouldEncode]) ||
        (shouldEncode == AKBOOLTypeInverseGlobalValue && ![self shouldEncode])) {
        relativeUrlStr = [self encodeUrl:relativeUrlStr];
    }
    NSString *absoluteUrlStr = [self absoluteUrlWithPath:relativeUrlStr];
    if (AK_IS_STRING_NIL(absoluteUrlStr)) {
        AKLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
        return nil;
    }
    
    AFHTTPSessionManager *manager = [self manager];
    NSMutableURLRequest *request = nil;
    NSError *serializationError = nil;
    request = [manager.requestSerializer multipartFormRequestWithMethod:@"POST"
                                                              URLString:absoluteUrlStr
                                                             parameters:params
                                              constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                                                  NSData *imageData = UIImageJPEGRepresentation(image, 1);
                                                  
                                                  NSString *imageFileName = filename;
                                                  if (AK_IS_STRING_NIL(filename)) {
                                                      NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                                                      formatter.dateFormat = @"yyyyMMddHHmmss";
                                                      NSString *str = [formatter stringFromDate:[NSDate date]];
                                                      imageFileName = [NSString stringWithFormat:@"%@.jpg", str];
                                                  }
                                                  
                                                  // 上传图片，以文件流的格式
                                                  [formData appendPartWithFileData:imageData name:name fileName:imageFileName mimeType:mimeType];
                                                  
                                              }
                                                                  error:&serializationError];
    if (serializationError) {
        if (fail) {
            fail(nil);
        }
        
        return nil;
    }
    
    [self configRequestHeaders:request];
    
    __block AKAFURLSessionData *session = [manager uploadTaskWithStreamedRequest:request
                                                                        progress:progress
                                                               completionHandler:^(NSURLResponse * __unused response, id responseObject, NSError *error) {
       
                                                                   // 关闭转圈圈
                                                                   [AFNetworkActivityIndicatorManager sharedManager].enabled = NO;
                                                                   if (error) {
                                                                       
                                                                       [[self allTasks] removeObject:session];
                                                                       if (fail) {
                                                                           fail(error);
                                                                       }
                                                                       
                                                                       if ([self isDebug]) {
                                                                           [self logWithFailError:error url:absoluteUrlStr params:nil];
                                                                       }
       
                                                                   } else {
            
                                                                       [[self allTasks] removeObject:session];
                                                                       [self successResponse:responseObject callback:success];
                                                                       
                                                                       if ([self isDebug]) {
                                                                           [self logWithSuccessResponse:responseObject
                                                                                                    url:absoluteUrlStr
                                                                                                 params:params];
                                                                       }
       
                                                                   }
    
                                                               }];

    
    
    [session resume];
    
    if (session) {
        [[self allTasks] addObject:session];
    }
    
    return session;
}

+ (AKAFURLSessionUpload *)uploadFile:(NSString *)file
                            url:(NSString *)relativeUrlStr
                shouldEncodeUrl:(AKBOOLType)shouldEncode
                       progress:(AKUploadProgress)progress
                        success:(AKResponseSuccess)success
                           fail:(AKResponseFail)fail
{
    // 开启转圈圈
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
 
    if (AK_IS_STRING_NIL(file)) {
        AKLog(@"uploadingFile无效，无法生成URL。请检查待上传文件是否存在");
        return nil;
    }
    
    if ((shouldEncode == AKBOOLTypeGlobalValue && [self shouldEncode]) ||
        (shouldEncode == AKBOOLTypeInverseGlobalValue && ![self shouldEncode])) {
        relativeUrlStr = [self encodeUrl:relativeUrlStr];
    }
    NSString *absoluteUrlStr = [self absoluteUrlWithPath:relativeUrlStr];
    if (AK_IS_STRING_NIL(absoluteUrlStr)) {
        AKLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
        return nil;
    }
    
    AFHTTPSessionManager *manager = [self manager];
    //????????是否需要configRequest，是否需要请求头、体信息？？？？？
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:absoluteUrlStr]];
    __block AKAFURLSessionUpload *session =
    [manager uploadTaskWithRequest:request
                          fromFile:[NSURL fileURLWithPath:file]//坑
                          progress:progress
                 completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                              
                              [[self allTasks] removeObject:session];
        
                              if (error) {
                                  if (fail) {
                                      fail(error);
                                  }
                                  if ([self isDebug]) {
                                        [self logWithFailError:error url:response.URL.absoluteString params:nil];
                                    }
      
                              } else {
            
                                  [self successResponse:responseObject callback:success];
                                  if ([self isDebug]) {
                                        [self logWithSuccessResponse:responseObject
                                                                 url:response.URL.absoluteString
                                                              params:nil];
                                    }
        
                              }
   
                          }];
    [session resume];//????????????
    if (session) {
        [[self allTasks] addObject:session];
    }
    
    return session;

}

+ (AKAFURLSessionDownload *)downloadWithUrl:(NSString *)relativeUrlStr
                     shouldEncodeUrl:(AKBOOLType)shouldEncode
                          saveToPath:(NSString *)saveToPath
                            progress:(AKDownloadProgress)progress
                             success:(AKResponseSuccess)success
                                fail:(AKResponseFail)fail
{
    // 开启转圈圈
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    
    if (AK_IS_STRING_NIL(saveToPath)) {
        AKLog(@"uploadingFile无效，无法生成URL。请检查待上传文件是否存在");
        return nil;
    }
    
    if ((shouldEncode == AKBOOLTypeGlobalValue && [self shouldEncode]) ||
        (shouldEncode == AKBOOLTypeInverseGlobalValue && ![self shouldEncode])) {
        relativeUrlStr = [self encodeUrl:relativeUrlStr];
    }
    NSString *absoluteUrlStr = [self absoluteUrlWithPath:relativeUrlStr];
    if (AK_IS_STRING_NIL(absoluteUrlStr)) {
        AKLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
        return nil;
    }
    
    AFHTTPSessionManager *manager = [self manager];
     //????????是否需要configRequest，是否需要请求头、体信息？？？？？
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:absoluteUrlStr]];
    __block AKAFURLSessionDownload *session =
    [manager downloadTaskWithRequest:request
                            progress:progress
                         destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                                return [NSURL fileURLWithPath:saveToPath];
                            } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                                [[self allTasks] removeObject:session];
                                
                                if (!error) {
                                    if (success) {
                                        success(filePath.absoluteString);
                                    }
                                    
                                    if ([self isDebug]) {
                                        AKLog(@"Download success for url %@",
                                                  absoluteUrlStr);
                                    }
                                } else {
//                                    [self handleCallbackWithError:error fail:failure];
                                    if (fail) {
                                        fail(error);
                                    }
                                    
                                    if ([self isDebug]) {
                                        AKLog(@"Download fail for url %@, reason : %@",
                                                  absoluteUrlStr,
                                                  [error description]);
                                    }
                                }

                            }];
    
    [session resume];
    if (session) {
        [[self allTasks] addObject:session];
    }
    
    return session;
}

#pragma mark - 其他操作

+ (void)cancelAllRequest
{
    @synchronized(self) {
        [[self allTasks] enumerateObjectsUsingBlock:^(AKAFURLSessionData * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task isKindOfClass:[AKAFURLSessionData class]]) {
                [task cancel];
            }
        }];
        
        [[self allTasks] removeAllObjects];
    };
}

+ (void)cancelRequestWithUrl:(NSString *)urlStr
{
    if (AK_IS_STRING_NIL(urlStr)) {
        return;
    }
    
    @synchronized(self) {
        [[self allTasks] enumerateObjectsUsingBlock:^(AKAFURLSessionData * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task isKindOfClass:[AKAFURLSessionData class]]
                && [task.currentRequest.URL.absoluteString hasSuffix:urlStr]) {
                [task cancel];
                [[self allTasks] removeObject:task];
                return;
            }
        }];
    };
}

+ (unsigned long long)totalCacheSize
{
    NSString *directoryPath = cachePath();
    BOOL isDir = NO;
    unsigned long long total = 0;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:&isDir]) {
        if (isDir) {
            NSError *error = nil;
            NSArray *array = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:&error];
            
            if (!error) {
                for (NSString *subpath in array) {
                    NSString *path = [directoryPath stringByAppendingPathComponent:subpath];
                    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:path
                                                                                          error:&error];
                    if (!error) {
                        total += [dict[NSFileSize] unsignedIntegerValue];
                    }
                }
            }
        }
    }
    
    return total;
}

+ (void)clearCaches
{
    NSString *directoryPath = cachePath();
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:nil]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:directoryPath error:&error];
        
        if (error) {
            NSLog(@"HYBNetworking clear caches error: %@", error);
        } else {
            NSLog(@"HYBNetworking clear caches ok");
        }
    }
}

#pragma mark - 私有

static inline NSString *cachePath() {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/AKNetworkingCaches"];
}

+ (AFHTTPSessionManager *)manager {
    
    AFHTTPSessionManager *manager = nil;;
//    if ([self baseUrl]) {
//        manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:[self baseUrl]]];
//    } else {
//        manager = [AFHTTPSessionManager manager];//initWithBaseURL传入nil，，
//    }
    manager = [AFHTTPSessionManager manager];//initWithBaseURL传入nil，，manager不持有baseUrl。。
    
    //默认提交请求的数据是二进制（AFHTTPRequestSerializer）的,返回格式是JSON（AFJSONResponseSerializer）
    switch (sg_requestType) {
        case AKRequestTypeJSON: {
            //`AFJSONRequestSerializer` is a subclass of `AFHTTPRequestSerializer`
            //that encodes parameters as JSON using `NSJSONSerialization`,
            //setting the `Content-Type` of the encoded request to `application/json`。。(forHTTPHeaderField)
            manager.requestSerializer = [AFJSONRequestSerializer serializer];
            break;
        }
        case AKRequestTypeData: {
            //`AFHTTPRequestSerializer` conforms to the `AFURLRequestSerialization`
            manager.requestSerializer = [AFHTTPRequestSerializer serializer];
            break;
        }
        default: {
            break;
        }
    }
    
    switch (sg_responseType) {
        case AKResponseTypeJSON: {
            manager.responseSerializer = [AFJSONResponseSerializer serializer];
            break;
        }
        case AKResponseTypeXML: {
            manager.responseSerializer = [AFXMLParserResponseSerializer serializer];
            break;
        }
        case AKResponseTypeData: {
            manager.responseSerializer = [AFHTTPResponseSerializer serializer];
            break;
        }
        default: {
            break;
        }
    }
    
    manager.requestSerializer.stringEncoding = NSUTF8StringEncoding;
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithArray:@[@"application/json",
                                                                              @"text/html",
                                                                              @"text/json",
                                                                              @"text/plain",
                                                                              @"text/javascript",
                                                                              @"text/xml",
                                                                              @"image/*"]];
    // 设置允许同时最大并发数量，过大容易出问题
    manager.operationQueue.maxConcurrentOperationCount = 3;
    return manager;
}


+ (void)configRequestHeaders:(NSMutableURLRequest *)request
{
    for (NSString *key in [self givenHttpHeaders].allKeys) {
        if ([self givenHttpHeaders][key]) {
            /*!
             @method setValue:forHTTPHeaderField:
             @abstract Sets the value of the given HTTP header field.
             @discussion If a value was previously set for the given header
             field, that value is replaced with the given value. Note that, in
             keeping with the HTTP RFC, HTTP header field names are
             case-insensitive.
             @param value the header field value.
             @param field the header field name (case-insensitive). 
             */
            [request setValue:[self givenHttpHeaders][key] forHTTPHeaderField:key];
        }
    }
    for (NSString *key in [self addHttpHeaders].allKeys) {
        if ([self addHttpHeaders][key]) {
            /*!
             @method addValue:forHTTPHeaderField:
             @abstract Adds an HTTP header field in the current header
             dictionary.
             @discussion This method provides a way to add values to header
             fields incrementally. If a value was previously set for the given
             header field, the given value is appended to the previously-existing
             value. The appropriate field delimiter, a comma in the case of HTTP,
             is added by the implementation, and should not be added to the given
             value by the caller. Note that, in keeping with the HTTP RFC, HTTP
             header field names are case-insensitive.
             @param value the header field value.
             @param field the header field name (case-insensitive). 
             */
            [request addValue:[self addHttpHeaders][key] forHTTPHeaderField:key];
        }
    }
    
//    [request setTimeoutInterval:10];
}


+ (NSString *)absoluteUrlWithPath:(NSString *)path {
    if (!path || path.length == 0) {
        return nil;
    }
    
    if (![self baseUrl] || [[self baseUrl] length] == 0) {
        return path;
    }
    
    NSString *absoluteUrl = path;
    
    if (![path hasPrefix:@"http://"] && ![path hasPrefix:@"https://"]) {
        absoluteUrl = [NSString stringWithFormat:@"%@%@",
                       [self baseUrl], path];
    }
    
    return absoluteUrl;
}

+ (NSString *)encodeUrl:(NSString *)url {
    return [self urlEncode:url];
}

+ (NSString *)urlEncode:(NSString *)url {
    NSString *newString =
    CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                              (CFStringRef)url,
                                                              NULL,
                                                              CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding)));
    if (newString) {
        return newString;
    }
    
    return url;
}


+ (id)cahceResponseWithURL:(NSString *)url parameters:params {
    id cacheData = nil;
    
    if (url) {
        // Try to get datas from disk
        NSString *directoryPath = cachePath();
        NSString *absoluteURL = [self generateGETAbsoluteURL:url params:params];
        NSString *key = [NSString networking_md5:absoluteURL];
        NSString *path = [directoryPath stringByAppendingPathComponent:key];
        
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
        if (data) {
            cacheData = data;
            AKLog(@"Read data from cache for url: %@\n", url);
        }
    }
    
    return cacheData;
}


// 仅对一级字典结构起作用
+ (NSString *)generateGETAbsoluteURL:(NSString *)url params:(id)params {
    if (params == nil || ![params isKindOfClass:[NSDictionary class]] || [params count] == 0) {
        return url;
    }
    
    NSString *queries = @"";
    for (NSString *key in params) {
        id value = [params objectForKey:key];
        
        if ([value isKindOfClass:[NSDictionary class]]) {
            continue;
        } else if ([value isKindOfClass:[NSArray class]]) {
            continue;
        } else if ([value isKindOfClass:[NSSet class]]) {
            continue;
        } else {
            queries = [NSString stringWithFormat:@"%@%@=%@&",
                       (queries.length == 0 ? @"&" : queries),
                       key,
                       value];
        }
    }
    
    if (queries.length > 1) {
        queries = [queries substringToIndex:queries.length - 1];
    }
    
    if (([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"]) && queries.length > 1) {
        if ([url rangeOfString:@"?"].location != NSNotFound
            || [url rangeOfString:@"#"].location != NSNotFound) {
            url = [NSString stringWithFormat:@"%@%@", url, queries];
        } else {
            queries = [queries substringFromIndex:1];
            url = [NSString stringWithFormat:@"%@?%@", url, queries];
        }
    }
    
    return url.length == 0 ? queries : url;
}

+ (void)successResponse:(id)responseData callback:(AKResponseSuccess)success {
    if (success) {
        success([self tryToParseData:responseData]);
    }
}

+ (id)tryToParseData:(id)responseData {
    if ([responseData isKindOfClass:[NSData class]]) {
        // 尝试解析成JSON
        if (responseData == nil) {
            return responseData;
        } else {
            NSError *error = nil;
            NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseData
                                                                     options:NSJSONReadingMutableContainers
                                                                       error:&error];
            
            if (error != nil) {
                return responseData;
            } else {
                return response;
            }
        }
    } else {
        return responseData;
    }
}

+ (void)logWithSuccessResponse:(id)response url:(NSString *)url params:(NSDictionary *)params {
    AKLog(@"\n");
    AKLog(@"\nRequest success, URL: %@\n params:%@\n response:%@\n\n",
              [self generateGETAbsoluteURL:url params:params],
              params,
              [self tryToParseData:response]);
}

+ (void)logWithFailError:(NSError *)error url:(NSString *)url params:(id)params {
    NSString *format = @" params: ";
    if (params == nil || ![params isKindOfClass:[NSDictionary class]]) {
        format = @"";
        params = @"";
    }
    
    AKLog(@"\n");
    if ([error code] == NSURLErrorCancelled) {
        AKLog(@"\nRequest was canceled mannully, URL: %@ %@%@\n\n",
                  [self generateGETAbsoluteURL:url params:params],
                  format,
                  params);
    } else {
        AKLog(@"\nRequest error, URL: %@ %@%@\n errorInfos:%@\n\n",
                  [self generateGETAbsoluteURL:url params:params],
                  format,
                  params,
                  [error localizedDescription]);
    }
}


+ (void)cacheResponseObject:(id)responseObject request:(NSURLRequest *)request parameters:params {
    if (request && responseObject && ![responseObject isKindOfClass:[NSNull class]]) {
        NSString *directoryPath = cachePath();
        
        NSError *error = nil;
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:nil]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error];
            if (error) {
                AKLog(@"create cache dir error: %@\n", error);
                return;
            }
        }
        
        NSString *absoluteURL = [self generateGETAbsoluteURL:request.URL.absoluteString params:params];
        NSString *key = [NSString networking_md5:absoluteURL];
        NSString *path = [directoryPath stringByAppendingPathComponent:key];
        NSDictionary *dict = (NSDictionary *)responseObject;
        
        NSData *data = nil;
        if ([dict isKindOfClass:[NSData class]]) {
            data = responseObject;
        } else {
            data = [NSJSONSerialization dataWithJSONObject:dict
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
        }
        
        if (data && error == nil) {
            BOOL isOk = [[NSFileManager defaultManager] createFileAtPath:path contents:data attributes:nil];
            if (isOk) {
                AKLog(@"cache file ok for request: %@\n", absoluteURL);
            } else {
                AKLog(@"cache file error for request: %@\n", absoluteURL);
            }
        }
    }
}

+ (NSMutableArray *)allTasks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (sg_requestTasks == nil) {
            sg_requestTasks = [[NSMutableArray alloc] init];
        }
    });
    
    return sg_requestTasks;
}

//+ (void)handleCallbackWithError:(NSError *)error fail:(HYBResponseFail)fail {
//    if ([error code] == NSURLErrorCancelled) {
//        if (sg_shouldCallbackOnCancelRequest) {
//            if (fail) {
//                fail(error);
//            }
//        }
//    } else {
//        if (fail) {
//            fail(error);
//        }
//    }
//}
























































@end

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
    AKRequestTypeJSON = 1,
    AKRequestTypeData = 2, // 二进制格式
    
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
 *  保存并且更新网络请求的baseUrl（当已存在baseUrl时替换更新，用于处理不同接口来源于不同服务器）， 
    通常在AppDelegate中启动时就设置一次（当不同接口的服务器不同时要再次调用）
 *
 *  @param urlStr 接口服务器的基础url
 */
+ (void)saveAndUpdateBaseUrl:(NSString *)urlStr;
+ (NSString *)baseUrl;

/**
 *  是否自动encode url
 *
 *  @param encode 默认为NO
 */
+ (void)autoEncodeUrl:(BOOL)encode;

/**
 *  配置请求和返回格式,
 *
 *  @param requestType  默认设置请求的数据是JSON（AKRequestTypeJSON）的
 *  @param responseType 默认返回格式是JSON（AKResponseTypeJSON）
 */
+ (void)configRequestType:(AKRequestType)requestType responseType:(AKResponseType)responseType;

/**
 *  设置指定的 HTTP 请求头字段
 *
 *  @param givenHttpHeaders 指定的请求头字典，例如：@{@"Content-Type":@"application/json",@"Accept":@"application/json"}
 */
+ (void)configGivenHttpHeaders:(NSDictionary *)givenHttpHeaders;

/**
 *  设置业务需要的 HTTP 请求头字段
 *
 *  @param addHttpHeaders 根据业务需要设置请求头，默认为空
 */
+ (void)configAddHttpHeaders:(NSDictionary *)addHttpHeaders;

/**
 *  默认只缓存GET请求的数据，对于POST请求是不缓存的。如果要缓存POST获取的数据，需要手动调用设置
 *  对JSON类型数据有效，对于PLIST、XML不确定！
 *
 *  @param isCacheGet  默认YES
 *  @param isCachePost 默认NO
 */
+ (void)cacheGetRequest:(BOOL)isCacheGet cachePost:(BOOL)isCachePost;

/**
 *  开启或关闭打印信息
 *
 *  @param isDebug 默认NO
 */
+ (void)enableDebug:(BOOL)isDebug;

#pragma mark - 请求接口
/**
 *  GET请求接口
 *
 *  @param relativeUrlStr 相对url，也可以传入绝对url、当传入绝对url(以http或https开头)时以该绝对url发起请求
 *  @param shouldEncode   是否以全局配置的encode为准，当为AKBOOLTypeInverseGlobalValue时则取全局配置的相反值，便于灵活使用全局配置
 *  @param shouldCache    同上，是否以全局配置的cacheGet为准
 *  @param refresh        是否刷新缓存。YES 重新请求数据重新缓存，NO 返回缓存的数据
 *  @param params         请求所需数据，用于拼接GET url
 *  @param progress       进度回调
 *  @param success        成功回调
 *  @param fail           失败回调
 *
 *  @return 返回会话对象
 */
+ (AKAFURLSessionData *)getWithUrl:(NSString *)relativeUrlStr
                shouldEncodeUrl:(AKBOOLType)shouldEncode
                    shouldCache:(AKBOOLType)shouldCache
                   refreshCache:(BOOL)refresh
                         params:(NSDictionary *)params
                       progress:(AKGetProgress)progress
                        success:(AKResponseSuccess)success
                           fail:(AKResponseFail)fail;

/**
 *  POST请求接口
 *
 *  @param relativeUrlStr 同GET
 *  @param shouldEncode   同GET
 *  @param shouldCache    是否以全局配置的cachePost为准，当为AKBOOLTypeInverseGlobalValue时则取全局配置的相反值，便于灵活使用全局配置
 *  @param refresh        同GET
 *  @param params         请求所需数据，用于生成请求体
 *  @param progress       同GET
 *  @param success        同GET
 *  @param fail           同GET
 *
 *  @return 同GET
 */
+ (AKAFURLSessionData *)postWithUrl:(NSString *)relativeUrlStr
                 shouldEncodeUrl:(AKBOOLType)shouldEncode
                     shouldCache:(AKBOOLType)shouldCache
                    refreshCache:(BOOL)refresh
                          params:(NSDictionary *)params
                        progress:(AKPostProgress)progress
                         success:(AKResponseSuccess)success
                            fail:(AKResponseFail)fail;

/**
 *  图片上传接口
 *
 *  @param image          待上传图片
 *  @param relativeUrlStr 同GET
 *  @param shouldEncode   同GET
 *  @param filename       图片名，默认为当前日期时间,格式为"yyyyMMddHHmmss"，后缀为`jpg`
 *  @param name           与指定的图片相关联的名称，这是由后端写接口的人指定的，如imagefiles
 *  @param mimeType       默认为image/jpeg
 *  @param params         请求参数，属于请求体部分
 *  @param progress       上传进度
 *  @param success        上传成功回调
 *  @param fail           上传失败回调
 *
 *  @return 会话对象
 */
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

/**
 *  上传文件接口
 *
 *  @param file           待上传文件路径
 *  @param relativeUrlStr 上传地址，可以传入绝对url、当传入绝对url(以http或https开头)时以该绝对url上传
 *  @param shouldEncode   同GET
 *  @param progress       上传进度
 *  @param success        上传成功回调
 *  @param fail           上传失败回调
 *
 *  @return 会话对象
 */
+ (AKAFURLSessionUpload *)uploadFile:(NSString *)file
                            url:(NSString *)relativeUrlStr
                shouldEncodeUrl:(AKBOOLType)shouldEncode
                       progress:(AKUploadProgress)progress
                        success:(AKResponseSuccess)success
                           fail:(AKResponseFail)fail;

/**
 *  下载文件接口
 *
 *  @param relativeUrlStr 下载地址，可以传入绝对url、当传入绝对url(以http或https开头)时以该绝对url下载
 *  @param shouldEncode   同GET
 *  @param saveToPath     下载到本地的路径
 *  @param progress       下载进度
 *  @param success        下载成功回调
 *  @param fail           下载失败回调
 *
 *  @return 会话对象
 */
+ (AKAFURLSessionDownload *)downloadWithUrl:(NSString *)relativeUrlStr
                     shouldEncodeUrl:(AKBOOLType)shouldEncode
                          saveToPath:(NSString *)saveToPath
                            progress:(AKDownloadProgress)progress
                             success:(AKResponseSuccess)success
                                fail:(AKResponseFail)fail;

#pragma mark - 其他操作
/**
 *  取消所有请求
 */
+ (void)cancelAllRequest;

/**
 *  取消某个请求。如果是要取消某个请求，最好是引用接口所返回来的HYBURLSessionTask对象，
 *  然后调用对象的cancel方法。如果不想引用对象，这里额外提供了一种方法来实现取消某个请求
 *
 *	@param urlStr urlStr，可以是绝对url，也可以是相对url（也就是不包括baseurl）
 */
+ (void)cancelRequestWithUrl:(NSString *)urlStr;

/**
 *	获取缓存总大小/bytes
 *
 *	@return 缓存大小
 */
+ (unsigned long long)totalCacheSize;

/**
 *  清除缓存
 */
+ (void)clearCaches;





























@end

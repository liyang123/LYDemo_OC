//
//  LYThirdTools.m
//  ThirdTool_LogShare
//
//  Created by liyang on 16/9/19.
//  Copyright © 2016年 liyang. All rights reserved.
//

#import "LYThirdTools.h"
#import "DataSigner.h" // 支付宝签名订单使用的类
#import "Order.h" // 传信息给支付宝定义的结构类

// 获取微信用户access_token时候使用的授权域
static NSString *kAuthScope = @"snsapi_message,snsapi_userinfo,snsapi_friend,snsapi_contact";
// 微信用户access_token时候设置微信回调标识
static NSString *kAuthState = @"liyang_custom";

@interface LYThirdTools ()

// TencentOAuth实现授权登录逻辑以及相关开放接口的请求调用
@property (nonatomic, strong) TencentOAuth *tencentOAuth;

@end

@implementation LYThirdTools

#pragma mark - 初始化方法
+ (instancetype)sharedInstance
{
    static LYThirdTools *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (sharedInstance == nil) {
            sharedInstance = [[self alloc] init];
        }
    });
    return sharedInstance;
}
#pragma mark - 注册
/**
 初始化，注册
 */
- (void)setupThirdTools
{
    [WXApi registerApp:weichatAppID withDescription:@"微信初始化"];
    [WeiboSDK registerApp:sinaAppID];
    self.tencentOAuth = [[TencentOAuth alloc] initWithAppId:qqAppID andDelegate:[LYThirdTools sharedInstance]];
}
#pragma mark - 检查有木有安装过：微信，微博，qq
/** 检查有木有安装过：微信，微博，qq */
- (BOOL)installThirdApp:(LYThirdLog)thirdApp
{
    NSString *tempStr;
    if (thirdApp == WeiChatLog) {
        tempStr = @"weixin://";
    }else if (thirdApp == SinaLog){
        tempStr = @"sinaweibo://";
    }else if (thirdApp == QQLog){
        tempStr = @"mqq://";
    }
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:tempStr]];
}

#pragma mark - 分享
/**
 分享

 @param model    分享的模型数据
 @param platForm 分享到哪个平台
 */
- (void)thirdToolsShareModel:(LYToolModel *)model toplatForm:(LYSharePlatForm)platForm
{
    if (platForm == WeiChatSession || platForm == WeiChatTimeline) {
        // 分享给微信好友，或者，分享到朋友圈
        WXMediaMessage *mediaMessage = [WXMediaMessage message];
        mediaMessage.title = model.shareTitle;
        mediaMessage.description = model.shareSubTitle;
        [mediaMessage setThumbImage:model.shareImg];
        WXWebpageObject *webObj = [WXWebpageObject object];
        webObj.webpageUrl = model.shareUrl;
        mediaMessage.mediaObject = webObj;
        
        // 发送
        SendMessageToWXReq *toReq = [[SendMessageToWXReq alloc] init];
        toReq.bText = NO;
        toReq.message = mediaMessage;
        toReq.scene = platForm;
        [WXApi sendReq:toReq];
        
    }else if (platForm == QQ){
        // 分享到QQ (若用户安装客户端，调用客户端；若没有，调网页)
        NSData *data = UIImageJPEGRepresentation(model.shareImg, 0.2);
        NSURL *url = [NSURL URLWithString:model.shareUrl];
        QQApiNewsObject *img = [QQApiNewsObject objectWithURL:url title:model.shareTitle description:model.shareSubTitle previewImageData:data];        
        SendMessageToQQReq *req = [SendMessageToQQReq reqWithContent:img];
        [QQApiInterface sendReq:req];
    }else if (platForm == Sina){
        // 分享到新浪
        
        // 微博客户端程序和第三方应用之间传递的消息结构
        WBMessageObject *message = [WBMessageObject message];
        WBWebpageObject *webpage = [WBWebpageObject object];
        webpage.objectID = @"identifier1";
        webpage.title = NSLocalizedString(model.shareTitle, nil);
        webpage.description = [NSString stringWithFormat:NSLocalizedString(model.shareSubTitle, nil), [[NSDate date] timeIntervalSince1970]];
        webpage.thumbnailData = UIImageJPEGRepresentation(model.shareImg, 0.2);
        webpage.webpageUrl = model.shareUrl;
        message.mediaObject = webpage;
        
        WBSendMessageToWeiboRequest *request = [WBSendMessageToWeiboRequest requestWithMessage:message];
        [WeiboSDK sendRequest:request];
    }
}

#pragma mark - 登录
/** 登录的方法 */
- (void)thirdToolsLog:(LYThirdLog)thirdLog
{
    if (thirdLog == WeiChatLog) {
        // 微信登录
        // 1、获取用户的access_token（接口调用凭证）
        // 1-1、定义消息结构体
        SendAuthReq *authReq = [[SendAuthReq alloc] init];
        authReq.scope = kAuthScope;
        authReq.state = kAuthState;
        // 1-2、向微信发送消息
        [WXApi sendReq:authReq];
    }else if (thirdLog == QQLog){
        // QQ登录
        // 获取用户的那些信息
        NSArray *permissions = [NSArray arrayWithObjects:
                                kOPEN_PERMISSION_GET_USER_INFO,
                                kOPEN_PERMISSION_GET_SIMPLE_USER_INFO,
                                kOPEN_PERMISSION_ADD_SHARE,
                                nil];
        [self.tencentOAuth authorize:permissions];
    }else if (thirdLog == SinaLog){
        // 微博登录
        WBAuthorizeRequest *request = [WBAuthorizeRequest request];
        request.redirectURI = sinaRedirectURI; // 注意这个地方要个高级信息的设置的url一样
        request.scope = @"all";
        request.userInfo = @{@"SSO_From": @"SendMessageToWeiboViewController",
                             @"Other_Info_1": [NSNumber numberWithInt:123],
                             @"Other_Info_2": @[@"obj1", @"obj2"],
                             @"Other_Info_3": @{@"key1": @"obj1", @"key2": @"obj2"}};
        [WeiboSDK sendRequest:request];
    }
}

#pragma mark - 支付
- (void)thirdPayWith:(NSDictionary *)dict platForm:(LYThirdPayPlatForm)platForm
{
    if (platForm == WeiChatPay) {
        // 微信支付
        PayReq* req             = [[PayReq alloc] init];
        req.partnerId           = [dict objectForKey:@"partnerid"];
        req.prepayId            = [dict objectForKey:@"prepayid"];
        req.nonceStr            = [dict objectForKey:@"noncestr"];
        req.timeStamp           = [[dict objectForKey:@"timestamp"] intValue];
        req.package             = [dict objectForKey:@"package"];
        req.sign                = [dict objectForKey:@"sign"];
        [WXApi sendReq:req];
    }else if (platForm == AliPay){
        // 支付宝支付
        // 1、将商品信息赋予Order的成员变量
        Order *order = [[Order alloc] init];
        
        // NOTE: app_id设置
        order.app_id = aliAppId;
        
        // NOTE: 手机app支付接口名称
        order.method = @"alipay.trade.app.pay";
        
        // NOTE: 参数编码格式
        order.charset = @"utf-8";
        
        // NOTE: sign_type设置
        order.sign_type = @"RSA";
        
        // NOTE: 当前时间点
        NSDateFormatter* formatter = [NSDateFormatter new];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        order.timestamp = [formatter stringFromDate:[NSDate date]];
        
        // NOTE: 支付版本
        order.version = @"1.0";
        
        // 支付宝服务器主动通知商户服务器
        order.notify_url = aliNotify_url;
        
        // NOTE: 商品数据
        order.biz_content = [[BizContent alloc] init];
        order.biz_content.subject = [dict objectForKey:@"order_title"];// 商品的标题
        order.biz_content.out_trade_no = [dict objectForKey:@"order_no"]; //订单ID（由商家自行制定）
        order.biz_content.total_amount = [NSString stringWithFormat:@"%.2f", [[dict objectForKey:@"order_amount"] floatValue]]; //订单总金额，单位为元，精确到小数点后两位
        order.biz_content.timeout_express = @"30m"; //超时时间设置
        order.biz_content.product_code = @"QUICK_MSECURITY_PAY"; //销售产品码，商家和支付宝签约的产品码
        
        //将商品信息拼接成字符串
        NSString *orderInfo = [order orderInfoEncoded:NO];
        NSString *orderInfoEncoded = [order orderInfoEncoded:YES];
        
        // NOTE: 获取私钥并将商户信息签名，外部商户的加签过程请务必放在服务端，防止公私钥数据泄露；
        // 需要遵循RSA签名规范，并将签名字符串base64编码和UrlEncode
        id<DataSigner> signer = CreateRSADataSigner(aliPrivateKey);
        NSString *signedString = [signer signString:orderInfo];
        
        // NOTE: 如果加签成功，则继续执行支付
        if (signedString != nil) {
            // NOTE: 将签名成功字符串格式化为订单字符串,请严格按照该格式
            NSString *orderString = [NSString stringWithFormat:@"%@&sign=%@", orderInfoEncoded, signedString];
            
            // NOTE: 调用支付结果开始支付
            [[AlipaySDK defaultService] payOrder:orderString fromScheme:appScheme callback:^(NSDictionary *resultDic) {
                NSLog(@"reslut = %@",resultDic);
            }];
        }
    }
}

#pragma mark - 微信登录、分享、支付的回调方法
/*! @brief 发送一个sendReq后，收到微信的回应
 *
 * 收到一个来自微信的处理结果。调用一次sendReq后会收到onResp。
 * 可能收到的处理结果有SendMessageToWXResp、SendAuthResp等。
 * @param resp具体的回应内容，是自动释放的
 */
- (void)onResp:(BaseResp *)resp
{
    if ([resp isKindOfClass:[QQBaseResp class]]) {
        // 这个是qq的分享的回调代理
        QQBaseResp *qqResp = (QQBaseResp *)resp;
        if (qqResp.errorDescription == nil) {
            if ([self.delegate respondsToSelector:@selector(thirdTool:qqResult:)]) {
                [self.delegate thirdTool:self qqResult:@{@"msg":@"分享成功"}];
            }
        }
    }else{
        // 这个是微信的回调代理
        if (resp.errCode == 0) {
            // 0代表操作成功
            if ([resp isKindOfClass:[SendMessageToWXResp class]]) {
                // 微信分享
                if ([self.delegate respondsToSelector:@selector(thirdTool:weichatResult:)]) {
                    [self.delegate thirdTool:self weichatResult:@{@"msg":@"分享成功"}];
                }
            }else if ([resp isKindOfClass:[SendAuthResp class]]){
                // 微信登录
                SendAuthResp *authResp = (SendAuthResp *)resp;
                if (authResp.code) {
                    // 说明成功,通过下面的路径去拿access_token（调用凭证）和openid（用户唯一标识）
                    [LYNetworking updateBaseUrl:@"https://api.weixin.qq.com"];
                    NSDictionary *dic = @{
                                          @"appid":weichatAppID,
                                          @"secret":weichatAppSecret,
                                          @"code":authResp.code,
                                          @"grant_type":@"authorization_code"
                                          };
                    [LYNetworking postWithUrl:@"sns/oauth2/access_token" params:dic progress:nil success:^(id  _Nonnull responseObject) {
                        // 成功拿到access_token和openid,用这两个去请求用户信息
                        if ([responseObject isKindOfClass:[NSDictionary class]]) {
                            [self getWeiChatUserInfoWithDic:responseObject];
                        }else{
                            NSLog(@"失败:%@", responseObject);
                        }
                    } failure:^(NSError * _Nonnull error) {
                        //
                        NSLog(@"获取用户的access_token失败：原因是:%@", error);
                    }];
                }
            }else if ([resp isKindOfClass:[PayResp class]]){
                // 微信支付
                PayResp *payResp = (PayResp *)resp;
                if ([self.delegate respondsToSelector:@selector(thirdTool:weichatResult:)]) {
                    [self.delegate thirdTool:self weichatResult:@{@"msg":@"支付成功",@"result":payResp.returnKey}];
                }
            }
            
        }else if (resp.errCode == -2){
            // -2是用户取消操作
            if ([self.delegate respondsToSelector:@selector(thirdTool:weichatResult:)]) {
                [self.delegate thirdTool:self weichatResult:@{@"msg":@"用户取消操作"}];
            }
            return;
        }else{
            // 其他的错误码全是失败
            if ([self.delegate respondsToSelector:@selector(thirdTool:weichatResult:)]) {
                [self.delegate thirdTool:self weichatResult:@{@"msg":@"操作失败"}];
            }
            return;
        }
    }
}
/** 请求微信用户信息资料 */
- (void)getWeiChatUserInfoWithDic:(NSDictionary *)responseObject
{
    [LYNetworking updateBaseUrl:@"https://api.weixin.qq.com"];
    NSDictionary *dic = @{
                          @"access_token":responseObject[@"access_token"],
                          @"openid":responseObject[@"openid"]
                          };
    [LYNetworking getWithUrl:@"sns/userinfo" params:dic progress:nil success:^(id  _Nonnull responseObject) {
        //
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            if ([self.delegate respondsToSelector:@selector(thirdTool:weichatResult:)]) {
                [self.delegate thirdTool:self weichatResult:@{@"msg":@"操作成功",@"result":responseObject}];
            }
        }else{
            NSLog(@"获取用户信息失败,返回格式不是json,而是:%@", responseObject);
        }
    } failure:^(NSError * _Nonnull error) {
        //
        NSLog(@"获取用户信息失败: %@",error);
    }];
}

#pragma mark - QQ事件回调方法
#pragma mark QQApiInterfaceDelegate的回调代理
/**
 处理来至QQ的请求
 */
- (void)onReq:(QQBaseReq *)req
{
    
}
/**
 处理QQ在线状态的回调
 */
- (void)isOnlineResponse:(NSDictionary *)response
{
    
}
#pragma mark TencentSessionDelegate的回调代理
// 必须实现的3个方法
- (void)tencentDidLogin
{
    NSLog(@"QQ登陆成功");
    [self.tencentOAuth getUserInfo];
}
- (void)tencentDidNotLogin:(BOOL)cancelled
{
    NSLog(@"QQ登录失败");
}
- (void)tencentDidNotNetWork
{
    NSLog(@"QQ登录碰见网络问题");
}
- (void)getUserInfoResponse:(APIResponse *)response
{
    if (response.retCode == URLREQUEST_SUCCEED && kOpenSDKErrorSuccess == response.detailRetCode) {
        
        if ([self.delegate respondsToSelector:@selector(thirdTool:qqResult:)]) {
            [self.delegate thirdTool:self qqResult:@{@"msg":@"登录成功",@"result":response.jsonResponse}];
        }
        
    }else{
        NSString *errMsg = [NSString stringWithFormat:@"errorMsg:%@\n%@",
                            response.errorMsg, [response.jsonResponse objectForKey:@"msg"]];
        NSLog(@"%@", errMsg);
    }
}

#pragma mark - 微博的回调方法（这两个方法都是必须实现的，一般只用到第二个）
- (void)didReceiveWeiboRequest:(WBBaseRequest *)request
{
}
- (void)didReceiveWeiboResponse:(WBBaseResponse *)response
{
    if ([response isKindOfClass:[WBSendMessageToWeiboResponse class]]) {
        // 这是分享的回调方法
        WBSendMessageToWeiboResponse *sendMessageResp = (WBSendMessageToWeiboResponse *)response;
        if ([self.delegate respondsToSelector:@selector(thirdTool:sinaResult:)]) {
            [self.delegate thirdTool:self sinaResult:@{@"msg":@"操作成功",@"result":sendMessageResp.userInfo}];
        }
    }else if ([response isKindOfClass:[WBAuthorizeResponse class]]) {
        // 这是登录的回调方法
        WBAuthorizeResponse *authResp = (WBAuthorizeResponse *)response;
        // 返回值中有access_token和uid，我们通过这两个去获取用户的个人信息
        [LYNetworking updateBaseUrl:@"https://api.weibo.com"];
        NSDictionary *dic = @{
                        @"access_token":[authResp.userInfo objectForKey:@"access_token"],
                        @"uid":[authResp.userInfo objectForKey:@"uid"]
                              };
        [LYNetworking getWithUrl:@"2/users/show.json" params:dic progress:nil success:^(id  _Nonnull responseObject) {
            //
            if ([responseObject isKindOfClass:[NSDictionary class]]) {
                
                // 获取到个人信息
                if ([self.delegate respondsToSelector:@selector(thirdTool:sinaResult:)]) {
                    [self.delegate thirdTool:self sinaResult:@{@"msg":@"操作成功",@"result":responseObject}];
                }
                
            }else{
                
                NSLog(@"获取用户信息失败,返回格式不是json,而是:%@", responseObject);
            }
        } failure:^(NSError * _Nonnull error) {
            //
            NSLog(@"获取用户信息失败: %@",error);
        }];
    }
}

@end



#pragma mark - 分享的数据模型
@implementation LYToolModel

+ (instancetype)toolModel
{
    LYToolModel *model = [[LYToolModel alloc] init];
    model.shareTitle = @"1级标题";
    model.shareSubTitle = @"2级标题";
    model.shareImg = [UIImage imageNamed:@"iphone"];
    model.shareUrl = @"http://www.baidu.com";
    return model;
}

@end

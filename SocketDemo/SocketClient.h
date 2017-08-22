//
//  SocketClient.h
//  SocketDemo
//
//  Created by lee on 16/7/21.
//  Copyright © 2016年 sanchun. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    SocketOfflineByServer,// 服务器掉线，默认为0
    SocketOfflineByUser,  // 用户主动cut
} SocketOfflineType;


typedef enum : NSUInteger {
    TAG_FIXED_LENGTH_HEADER = 100, //tag 报头
    TAG_RESPONSE_BODY              //数据主体
} TAG_TYPE;


@import CocoaAsyncSocket;

@interface SocketClient : NSObject<GCDAsyncSocketDelegate>

@property(nonatomic,strong)GCDAsyncSocket *clientSocket; //客户端
@property(nonatomic,strong)GCDAsyncSocket *serverSocket; //服务端

@property(nonatomic,copy)NSString *host;
@property(nonatomic)UInt16 port;
@property(nonatomic)SocketOfflineType offine; //断线类型

@property(nonatomic)NSInteger sendTimeout; //超时时间

@property(nonatomic)NSUInteger headerLenght;  //设置报头长度
@property(nonatomic,strong)NSDictionary *headerDic;

@property(nonatomic,readonly)NSUInteger bodyLenght;

@property(nonatomic,copy)void (^didConnectBlock)();
@property(nonatomic,copy)void (^didDisconnectBlock)(NSError *error);
@property(nonatomic,copy)void (^didWriteDataBlock)(NSInteger tag);
@property(nonatomic,copy)void (^didReadBlock)(NSData *data,NSInteger tag);
@property(nonatomic,copy)void (^didReadBodyBlock)(NSData *data,NSDictionary *info);

+ (SocketClient *)sharedClient;

- (void)writeData:(NSData *)data info:(NSDictionary *)info;

- (BOOL)acceptOnPort:(UInt16)port; //创建服务端

//客户端连接
- (BOOL)connct;
- (BOOL)connctToHost:(NSString *)host port:(UInt16)port;

//断开
- (void)disconnct;

//获取设备ip
+ (NSString *)getIPAddress;

@end

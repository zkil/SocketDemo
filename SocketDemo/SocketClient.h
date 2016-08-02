//
//  SocketClient.h
//  SocketDemo
//
//  Created by lee on 16/7/21.
//  Copyright © 2016年 sanchun. All rights reserved.
//

#import <Foundation/Foundation.h>
enum{
    SocketOfflineByServer,// 服务器掉线，默认为0
    SocketOfflineByUser,  // 用户主动cut
};

enum{
    TAG_FIXED_LENGTH_HEADER = 100,
    TAG_RESPONSE_BODY
};

@import CocoaAsyncSocket;

@interface SocketClient : NSObject<GCDAsyncSocketDelegate>

@property(nonatomic,strong)GCDAsyncSocket *clientSocket;
@property(nonatomic,strong)GCDAsyncSocket *serverSocket;
@property(nonatomic,copy)NSString *host;
@property(nonatomic)UInt16 port;
@property(nonatomic)NSInteger offine;

@property(nonatomic)NSUInteger headerLenght;
@property(nonatomic,strong)NSDictionary *headerDic;

@property(nonatomic)NSUInteger bodyLenght;



@property(nonatomic,copy)void (^didConnectBlock)();
@property(nonatomic,copy)void (^didDisconnectBlock)(NSError *error);
@property(nonatomic,copy)void (^didWriteDataBlock)(NSInteger tag);
@property(nonatomic,copy)void (^didReadBlock)(NSData *data,NSInteger tag);
@property(nonatomic,copy)void (^didReadBodyBlock)(NSData *data,NSDictionary *info);
+ (SocketClient *)sharedClient;

- (BOOL)acceptOnPort:(UInt16)port;
- (BOOL)connct;
- (BOOL)connctToHost:(NSString *)host port:(UInt16)port;

- (void)disconnct;



@end

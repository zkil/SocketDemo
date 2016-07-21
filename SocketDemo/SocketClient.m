//
//  SocketClient.m
//  SocketDemo
//
//  Created by lee on 16/7/21.
//  Copyright © 2016年 sanchun. All rights reserved.
//

#import "SocketClient.h"

@implementation SocketClient
static dispatch_once_t onceToken;
static SocketClient *socketClient;
+ (SocketClient *)sharedClient {
    dispatch_once(&onceToken, ^{
        socketClient = [[[self class]alloc]init];
    });
    return socketClient;
}

- (BOOL)connctToHost:(NSString *)host port:(UInt16)port {
    self.host = host;
    self.port = port;
    return [self connct];
}

- (BOOL)connct {
    [self disconnct];
    self.socket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error;
    BOOL result = [self.socket connectToHost:self.host onPort:self.port withTimeout:10 error:&error];
    if (error != nil) {
        NSLog(@"%@",[error localizedDescription]);
    }
    return result;
}

- (void)disconnct {
    self.offine = SocketOfflineByUser;
    [self.socket disconnect];
}

#pragma -mark- 连接成功
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"socket连接成功%@:%d",host,port);
    [self.socket readDataWithTimeout:30 tag:TAG_FIXED_LENGTH_HEADER];
    self.offine = SocketOfflineByServer;
    
    if (self.didConnectBlock != nil) {
        self.didConnectBlock();
    }
    
}

#pragma -mark- 断开连接
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (err != nil) {
        NSLog(@"socket连接失败error:%@",[err localizedDescription]);
    }else{
        NSLog(@"socket断开成功");
    }
    
    if (self.offine == SocketOfflineByServer) {
        NSLog(@"socket掉线，正在重连...");
        NSError *error;
        [sock connectToHost:self.host onPort:self.port withTimeout:10 error:&error];
        if (error != nil) {
            NSLog(@"%@",[error localizedDescription]);
        }
    }
    
    if (self.didDisconnectBlock != nil) {
        self.didDisconnectBlock(err);
    }
    
}

#pragma -mark- 发送数据
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"发送数据成功");
    if (self.didWriteDataBlock != nil) {
        self.didWriteDataBlock(tag);
    }
    
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"接收到数据");
    if (self.didReadBlock != nil) {
        self.didReadBlock(data,tag);
    }
    switch (tag) {
        case TAG_FIXED_LENGTH_HEADER: { // 1.已读取报文头，计算长度后继续读取报文体
            NSString *lengthString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            [sock readDataToLength:[lengthString integerValue] withTimeout:30 tag:TAG_RESPONSE_BODY];//继续读取数据，这次传的是TAG_RESPONSE_BODY，所以下次调用此方法的时候，执行TAG_RESPONSE_BODY部分。
        }
            break;
        case TAG_RESPONSE_BODY: // 2.已读出报文体，转发报文体，然后继续读取报文头
//            if ([self.delegate respondsToSelector:@selector(socketConnection:didReceivedData:)]) {
//                [self.delegate socketConnection:self didReceivedData:data];
//            }
            
            [sock readDataToLength:self.packetHeaderLength withTimeout:30 tag:TAG_FIXED_LENGTH_HEADER]; //继续读,下次调用此方法时，tag是TAG_FIXED_LENGTH_HEADER
            break;
        default:
            break;
    }
    
    //持续接收数据
    [sock readDataWithTimeout:30 tag:tag];
}


@end

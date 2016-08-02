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

- (BOOL)acceptOnPort:(UInt16)port {
    [self disconnct];
    self.serverSocket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error;
    BOOL result = [self.serverSocket acceptOnPort:port error:&error];
    if (error != nil) {
        NSLog(@"%@",[error localizedDescription]);
    }else{
        NSLog(@"創建服務端成功");
    }
    return result;
}

- (BOOL)connctToHost:(NSString *)host port:(UInt16)port {
    self.host = host;
    self.port = port;
    return [self connct];
}

- (BOOL)connct {
    [self disconnct];
    self.clientSocket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error;
    BOOL result = [self.clientSocket connectToHost:self.host onPort:self.port withTimeout:10 error:&error];
    if (error != nil) {
        NSLog(@"%@",[error localizedDescription]);
    }
    return result;
}

- (void)disconnct {
    self.offine = SocketOfflineByUser;
    [self.clientSocket disconnect];
}

#pragma -mark- 连接成功
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"socket连接成功%@:%d",host,port);
    
    //第一次读取报头
    [sock readDataToLength:self.headerLenght withTimeout:30 tag:TAG_FIXED_LENGTH_HEADER];
    self.offine = SocketOfflineByServer;
    if (self.didConnectBlock != nil) {
        self.didConnectBlock();
    }
    
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"socket服務器");
    self.clientSocket = newSocket;
    [newSocket readDataToLength:self.headerLenght withTimeout:30 tag:TAG_FIXED_LENGTH_HEADER];
}

#pragma -mark- 断开连接
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (err != nil) {
        NSLog(@"socket连接失败error:%@",[err localizedDescription]);
    }else{
        NSLog(@"socket断开成功");
    }
    
    if (self.offine == SocketOfflineByServer && sock == self.clientSocket) {
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
    
    if (self.headerLenght == 0) {
        return;
    }
    
    switch (tag) {
        case TAG_FIXED_LENGTH_HEADER: { // 1.已读取报文头，计算长度后继续读取报文体
            NSError *error;
            NSString *headerString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSData *newData = [[headerString stringByReplacingOccurrencesOfString:@"\0" withString:@""] dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *headerDic = [NSJSONSerialization JSONObjectWithData:newData options:NSJSONReadingMutableContainers error:&error];
            if (error != nil) {
                
                NSLog(@"json頭解析失敗,报头不是json格式:%@ %@",headerString,error.localizedDescription);
                
                [sock readDataToLength:self.headerLenght withTimeout:30 tag:TAG_FIXED_LENGTH_HEADER];
                return;
            }
            
            self.headerDic = headerDic;
            
            self.bodyLenght = [self.headerDic[@"bodyLenght"] integerValue];
            
            [sock readDataToLength:self.bodyLenght withTimeout:30 tag:TAG_RESPONSE_BODY];
        }
            break;
        case TAG_RESPONSE_BODY:{
            // 2.已读出报文体，转发报文体，然后继续读取报文头
            
            //            if ([self.delegate respondsToSelector:@selector(socketConnection:didReceivedData:)]) {
            //                [self.delegate socketConnection:self didReceivedData:data];
            //            }
            NSString *type = self.headerDic[@"type"];
            if ([type isEqualToString:@"text"]) {
                NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"收到文本:%@",str);
            }else if ([type isEqualToString:@"file"]) {
                NSString *fileName = self.headerDic[@"name"];
                NSLog(@"收到文件:%@",fileName);
                
                NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
                [data writeToFile:[documentPath stringByAppendingPathComponent:fileName] atomically:YES];
                
            }

            if (self.didReadBodyBlock != nil) {
                self.didReadBodyBlock(data,self.headerDic);
            }
            
            [sock readDataToLength:self.bodyLenght withTimeout:30 tag:TAG_FIXED_LENGTH_HEADER]; //继续读,下次调用此方法时，tag是TAG_FIXED_LENGTH_HEADER
        }
            break;
        default:
            break;
    }
    
    //持续接收数据
    //[sock readDataWithTimeout:30 tag:tag];
}



@end

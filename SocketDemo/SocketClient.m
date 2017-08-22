//
//  SocketClient.m
//  SocketDemo
//
//  Created by lee on 16/7/21.
//  Copyright © 2016年 sanchun. All rights reserved.
//

#import "SocketClient.h"
#import <ifaddrs.h>
#import <arpa/inet.h>


@implementation SocketClient

+ (SocketClient *)sharedClient {
    static dispatch_once_t onceToken;
    static SocketClient *socketClient;
    dispatch_once(&onceToken, ^{
        socketClient = [[[self class]alloc]init];
        socketClient.sendTimeout = 30;
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
        NSLog(@"創建服務端成功 host:%@ port:%d",[SocketClient getIPAddress],port);
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
    BOOL result = [self.clientSocket connectToHost:self.host onPort:self.port withTimeout:self.sendTimeout error:&error];
    if (error != nil) {
        NSLog(@"%@",[error localizedDescription]);
    }
    return result;
}

- (void)disconnct {
    self.offine = SocketOfflineByUser;
    [self.clientSocket disconnect];
}

- (void)writeData:(NSData *)data info:(NSDictionary *)info {
    NSMutableData *sendData = [NSMutableData new];
    NSMutableData *headerData = [NSMutableData dataWithLength:self.headerLenght];
    
    NSMutableDictionary *headerDic = [NSMutableDictionary new];
    
    
    if (info != nil) {
        [headerDic addEntriesFromDictionary:info];
    }
    [headerDic setObject:@(data.length) forKey:@"bodyLenght"];
    
    NSError *error;
    NSData *infoData = [NSJSONSerialization dataWithJSONObject:headerDic options:NSJSONWritingPrettyPrinted error:&error];
    if (error != nil) {
        NSLog(@"%@",error.localizedDescription);
        return;
    }
    
    if (infoData.length > self.headerLenght) {
        NSLog(@"info数据太大，请调整 headerLenght 大小");
        return;
    }
    [headerData replaceBytesInRange:NSMakeRange(0, infoData.length) withBytes:infoData.bytes];
   
    [sendData appendData:headerData];
    [sendData appendData:data];
    
    [self.clientSocket writeData:sendData withTimeout:self.sendTimeout tag:-1];
}

#pragma -mark- 连接成功
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"socket连接成功%@:%d",host,port);
    self.offine = SocketOfflineByServer;
    
    //第一次读取报头
    [sock readDataToLength:self.headerLenght withTimeout:30 tag:TAG_FIXED_LENGTH_HEADER];
    
    if (self.didConnectBlock != nil) {
        self.didConnectBlock();
    }
    
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"有socket客户端连接到服务端");
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
    
    
    //客户端断线重连
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
    
    if (self.didReadBlock != nil) {
        self.didReadBlock(data,tag);
    }
    
    if (self.headerLenght == 0) {
        return;
    }
    
    switch (tag) {
        case TAG_FIXED_LENGTH_HEADER: { // 1.已读取报文头，计算长度后继续读取报文体
            NSLog(@"接收到数据");
            NSError *error;
            NSString *headerString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSData *newData = [[headerString stringByReplacingOccurrencesOfString:@"\0" withString:@""] dataUsingEncoding:NSUTF8StringEncoding]; //去掉 \0
            NSDictionary *headerDic = [NSJSONSerialization JSONObjectWithData:newData options:NSJSONReadingMutableContainers error:&error];
            if (error != nil) {
                
                NSLog(@"json頭解析失敗,报头不是json格式:%@ %@",headerString,error.localizedDescription);
                
                [sock readDataToLength:self.headerLenght withTimeout:30 tag:TAG_FIXED_LENGTH_HEADER];
                return;
            }
            
            self.headerDic = headerDic;
            
            _bodyLenght = [self.headerDic[@"bodyLenght"] integerValue];
            
            [sock readDataToLength:self.bodyLenght withTimeout:self.sendTimeout tag:TAG_RESPONSE_BODY];
        }
            break;
        case TAG_RESPONSE_BODY:{
            // 2.已读出报文体，转发报文体，然后继续读取报文头
            
            //            if ([self.delegate respondsToSelector:@selector(socketConnection:didReceivedData:)]) {
            //                [self.delegate socketConnection:self didReceivedData:data];
            //            }
            if (self.didReadBodyBlock != nil) {
                self.didReadBodyBlock(data,self.headerDic);
            }
            
            [sock readDataToLength:self.headerLenght withTimeout:self.sendTimeout tag:TAG_FIXED_LENGTH_HEADER]; //继续读,下次调用此方法时，tag是TAG_FIXED_LENGTH_HEADER
        }
            break;
        default:
            break;
    }
    
}

+ (NSString *)getIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
}

@end

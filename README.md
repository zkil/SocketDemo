# SocketDemo
### 简介：
基于 CocoaAsyncSocket 封装，实现 OC 创建 socket 服务端和客户端。可用于文件传输

### 第一步，创建工具类

创建一个单例做为 socket 的工具类，这个类我们命名为`SocketClient`  

单例创建部分  

```
//.h
+ (SocketClient *)sharedClient;
```  
```
//.m
+ (SocketClient *)sharedClient {
    static dispatch_once_t onceToken;
    static SocketClient *socketClient;
    dispatch_once(&onceToken, ^{
        socketClient = [[[self class]alloc]init];
        //socketClient.sendTimeout = 30;
    });
    return socketClient;
}
```

### socket客户端实现

连接服务端 
 
```
//.h
@property(nonatomic,strong)GCDAsyncSocket *clientSocket; //客户端
@property(nonatomic)NSInteger sendTimeout; //超时时间
@property(nonatomic,copy)NSString *host;
@property(nonatomic)UInt16 port;

//客户端连接
- (BOOL)connct;
- (BOOL)connctToHost:(NSString *)host port:(UInt16)port;

//断开
- (void)disconnct;  
```

```
//.m
- (BOOL)connctToHost:(NSString *)host port:(UInt16)port {
    self.host = host;
    self.port = port;
    return [self connct];
}

- (BOOL)connct {
    [self disconnct];  //连接前断开之前的socket
    self.clientSocket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error;
    BOOL result = [self.clientSocket connectToHost:self.host onPort:self.port withTimeout:10 error:&error];
    if (error != nil) {
        NSLog(@"%@",[error localizedDescription]);
    }
    return result;
}

- (void)disconnct {
    //self.offine = SocketOfflineByUser;
    [self.clientSocket disconnect];
}
```  
### 实现回调 `GCDAsyncSocketDelegate`  
socket客户端主要有这几个回调  


socket连接成功  

```  
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"socket连接成功%@:%d",host,port);
    
}
```

socket断开或连接失败

```
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (err != nil) {
        NSLog(@"socket连接失败error:%@",[err localizedDescription]);
    }else{
        NSLog(@"socket断开成功");
    }
    
}

```

socket发送数据 

```
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"发送数据成功");
    if (self.didWriteDataBlock != nil) {
        self.didWriteDataBlock(tag);
    }
    
}
```
socket接收到数据

```
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
}
```

### 断线重连的实现
socket在连接过程中可能会因为网络波动，或者服务器断开导致掉线，掉线后一般都要重新连接。但是如果是客户端主动断开则不用执行重连操作。因此我们必须判断是服务端断线在是用户主动断开  

定义一个枚举 表示断线类型  

```
typedef enum : NSUInteger {
    SocketOfflineByServer,// 服务器掉线，默认为0
    SocketOfflineByUser,  // 用户主动cut
} SocketOfflineType;

//.h
@property(nonatomic)SocketOfflineType offine; //断线类型

```

断开方法需要设置类型是用户主动断开

```
- (void)disconnct {
    self.offine = SocketOfflineByUser;
    [self.clientSocket disconnect];
}
```
连接成功后设置端类型为服务端主动断开

```
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"socket连接成功%@:%d",host,port);
    self.offine = SocketOfflineByServer;
    
}
```

断开后重连，socket断开，判断是否服务端断开，是的话才重连

```
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

}

```  
### 数据的发送和接收
数据接收格式必须和服务端格式一致。我们可以定义一种格式实现数据发送和接收
关于接收,socket必须主动调用接收方法才会接收数据,有两个接收方法:  
第一种:  
接收下一次全部的的数据
```
- (void)readDataWithTimeout:(NSTimeInterval)timeout tag:(long)tag
```
第二种:  
接收指定长度的数据
```
- (void)readDataToLength:(NSUInteger)length withTimeout:(NSTimeInterval)timeout tag:(long)tag
```
tag是数据的标签

不建议使用第一种，因为如果出现阻塞，会导致多条数据拼接在一起导致无法解析。本文只讲第二种
#### 可以如下定义:  
一次传输数据由header和body两个部分组成  
header是一个json格式，里面存储的是body的长度，和其他自定的要传参数。传输的时候header是一个固定长度的data，这个长度可以自行定义，不过必须和服务端一致  
body是传输数据的主体

#### 发送部分:  
那么如何将一个json转成一个固定长度的NSData呢？
我们可以通过  

```
NSMutableData *headerData = [NSMutableData dataWithLength:self.headerLenght];

```
创建一个指定长的空的 `NSMutableData`
然后再把json bytes 字节替换到 headerDate中

```
[headerData replaceBytesInRange:NSMakeRange(0, infoData.length) withBytes:infoData.bytes];
```
最后将headerData和body data拼接在一起

#### 发送的完整代码

```
//.h
@property(nonatomic)NSUInteger headerLenght;  //设置报头长度

//.m
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

```

#### 接收部分:  
定义一个数据的tag 
 
```
typedef enum : NSUInteger {
    TAG_FIXED_LENGTH_HEADER = 100, //tag 报头
    TAG_RESPONSE_BODY              //数据主体
} TAG_TYPE;

```

在socket连接成功主动读取一次数据  

```
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"socket连接成功%@:%d",host,port);
    self.offine = SocketOfflineByServer;
    
    //第一次读取报头
    [sock readDataToLength:self.headerLenght withTimeout:30 tag:TAG_FIXED_LENGTH_HEADER];
    
    
}
```

接收到数据

```
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    
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

```

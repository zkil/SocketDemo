//
//  ViewController.m
//  SocketDemo
//
//  Created by lee on 16/7/21.
//  Copyright © 2016年 sanchun. All rights reserved.
//

#import "ViewController.h"
#import "SocketClient.h"
@interface ViewController ()<UITextFieldDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hostTF.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"host"];
    self.portTF.text = [[[NSUserDefaults standardUserDefaults] objectForKey:@"port"] stringValue];
    
    [[SocketClient sharedClient] setDidReadBlock:^(NSData *data, NSInteger tag) {
        NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"%@",str);
        self.receiveLB.text = str;
        
    }];
}

- (IBAction)connect:(id)sender {
    NSString *host = self.hostTF.text;
    UInt16 port = [self.portTF.text intValue];
    if ([[SocketClient sharedClient]connctToHost:host port:port]) {
        [[NSUserDefaults standardUserDefaults]setObject:host forKey:@"host"];
        [[NSUserDefaults standardUserDefaults]setObject:@(port) forKey:@"port"];
    }
}

- (IBAction)disconnet:(id)sender {
    [[SocketClient sharedClient]disconnct];
}

- (IBAction)send:(id)sender {
    if (![SocketClient sharedClient].socket.isConnected) {
        [[[UIAlertView alloc]initWithTitle:nil message:@"socket未连接" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil]show];
        return;
    }
    
    if (self.inputTF.text != nil && ![self.inputTF.text isEqualToString:@""]) {
        NSData *data = [self.inputTF.text dataUsingEncoding:NSUTF8StringEncoding];
        [[SocketClient sharedClient].socket writeData:data withTimeout:30 tag:100];
    }
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

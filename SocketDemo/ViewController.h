//
//  ViewController.h
//  SocketDemo
//
//  Created by lee on 16/7/21.
//  Copyright © 2016年 sanchun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *hostTF;
@property (weak, nonatomic) IBOutlet UIButton *serverBtn;

@property (weak, nonatomic) IBOutlet UITextField *portTF;
@property (weak, nonatomic) IBOutlet UITextField *inputTF;
@property (weak, nonatomic) IBOutlet UILabel *receiveLB;
@property (weak, nonatomic) IBOutlet UIImageView *recetiveIV;
@property (weak, nonatomic) IBOutlet UIImageView *sendIV;

@end


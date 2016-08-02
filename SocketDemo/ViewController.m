//
//  ViewController.m
//  SocketDemo
//
//  Created by lee on 16/7/21.
//  Copyright © 2016年 sanchun. All rights reserved.
//

#import "ViewController.h"
#import "SocketClient.h"
#import <MobileCoreServices/MobileCoreServices.h>
@interface ViewController ()<UITextFieldDelegate,UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hostTF.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"host"];
    self.portTF.text = [[[NSUserDefaults standardUserDefaults] objectForKey:@"port"] stringValue];
    
    [SocketClient sharedClient].headerLenght = 100;
    [SocketClient sharedClient].sendTimeout = 100;
    [[SocketClient sharedClient] setDidReadBodyBlock:^(NSData *data, NSDictionary *info) {
        NSString *type = info[@"type"];
        if ([type isEqualToString:@"text"]) {
            self.receiveLB.text = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        }else if([type isEqualToString:@"file"]){
            UIImage *image = [UIImage imageWithData:data];
            self.recetiveIV.image = image;
        }
        
    }];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapInputImageAction)];
    self.sendIV.userInteractionEnabled = YES;
    [self.sendIV addGestureRecognizer:tapGesture];
    
}

- (void)tapInputImageAction {
    [self showImagePickerForSourceType:UIImagePickerControllerSourceTypePhotoLibrary andCameraCaptureMode:UIImagePickerControllerCameraCaptureModePhoto];
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
    if (![SocketClient sharedClient].clientSocket.isConnected) {
        [[[UIAlertView alloc]initWithTitle:nil message:@"socket未连接" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil]show];
        return;
    }
    
    if (self.inputTF.text != nil && ![self.inputTF.text isEqualToString:@""]) {
        NSData *bodyData = [self.inputTF.text dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *info = @{
                               @"type":@"text"
                               };
        [[SocketClient sharedClient] writeData:bodyData info:info];
    }
    
}

- (IBAction)createServer:(id)sender {
    UInt16 port = [self.portTF.text intValue];
    if (![SocketClient sharedClient].serverSocket.isConnected) {
        if ([[SocketClient sharedClient] acceptOnPort:port]) {
            NSLog(@"host:%@ %d",[SocketClient sharedClient].serverSocket.localHost,[SocketClient sharedClient].serverSocket.localPort);
        }
        self.hostTF.text = [SocketClient getIPAddress];
        self.serverBtn.backgroundColor = [UIColor greenColor];
    }else{
        [[SocketClient sharedClient].serverSocket disconnect];
        self.serverBtn.backgroundColor = [UIColor clearColor];
    }
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}


#pragma -mark- UIImagePickerController

- (void)showImagePickerForSourceType:(UIImagePickerControllerSourceType)sourceType andCameraCaptureMode:(UIImagePickerControllerCameraCaptureMode)mode{
    if ([UIImagePickerController isSourceTypeAvailable:sourceType]) {
        //有相机
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
        //这是 VC 的各种 modal 形式
        //imagePickerController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        imagePickerController.mediaTypes = @[(NSString *) kUTTypeImage];
        imagePickerController.sourceType = sourceType;
        //支持的摄制类型,拍照或摄影,此处将本设备支持的所有类型全部获取,并且同时赋值给imagePickerController的话,则可左右切换摄制模式
        //imagePickerController.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        imagePickerController.delegate = self;
        //允许拍照后编辑
        imagePickerController.allowsEditing = NO;
        //显示默认相机 UI, 默认为yes--> 显示
        //    imagePickerController.showsCameraControls = NO;
        
        if (sourceType == UIImagePickerControllerSourceTypeCamera) {
            //设置模式-->拍照/摄像
            imagePickerController.cameraCaptureMode = mode;
            //开启默认摄像头-->前置/后置
            imagePickerController.cameraDevice = UIImagePickerControllerCameraDeviceRear;
            //设置默认的闪光灯模式-->开/关/自动
            imagePickerController.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
            
            //拍摄时预览view的transform属性，可以实现旋转，缩放功能
            //        imagePickerController.cameraViewTransform = CGAffineTransformMakeRotation(M_PI);
            //        imagePickerController.cameraViewTransform = CGAffineTransformMakeScale(2.0,2.0);
            
            //自定义覆盖图层-->overlayview
            //            UIImage *img = [UIImage imageNamed:@"085625KMV.jpg"];
            //            UIImageView *iv = [[UIImageView alloc] initWithImage:img];
            //            iv.width = 300;
            //            iv.height = 200;
            //            imagePickerController.cameraOverlayView = iv;
            
        }
        
        [self presentViewController:imagePickerController animated:YES completion:nil];
        
    }
    else {
        NSLog(@"这设备没相机 ");
    }
    
}

#pragma -mark- UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    [picker dismissViewControllerAnimated:YES completion:^{
        
        NSString *mediaType = info[UIImagePickerControllerMediaType];
        
        if ([mediaType isEqualToString:@"public.image"]) {
            
            /*
             //获取照片的原图
             UIImage* original = [info objectForKey:UIImagePickerControllerOriginalImage];
             //获取图片裁剪后，剩下的图
             UIImage* crop = [info objectForKey:UIImagePickerControllerCropRect];
             //获取图片的url
             NSURL* url = [info objectForKey:UIImagePickerControllerMediaURL];
             //获取图片的metadata数据信息
             NSDictionary* metadata = [info objectForKey:UIImagePickerControllerMediaMetadata];
             */
            
            //获取图片裁剪的图
            //UIImage* edit = [info objectForKey:UIImagePickerControllerEditedImage];
            
            UIImage* original = [info objectForKey:UIImagePickerControllerOriginalImage];
            self.sendIV.image = original;
            
            NSData *bodyData = UIImageJPEGRepresentation(original, 0.5);
            NSDictionary *info = @{
                                        @"type":@"file",
                                        @"name":@"123.jpg"
                                        };
           [[SocketClient sharedClient]writeData:bodyData info:info];
        }
//        }else{  // public.movie
//            NSURL *url=[info objectForKey:UIImagePickerControllerMediaURL];//视频路径
//        }
        
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

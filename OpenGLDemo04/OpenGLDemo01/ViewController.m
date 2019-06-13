//
//  ViewController.m
//  OpenGLDemo01
//
//  Created by Michael on 2019/6/10.
//  Copyright © 2019 Michael. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#include "libyuv.h"



#import "LYRYUVView.h"
#import "LYRGLView.h"
#import "LYRNV12View.h"
#import "LYRSampleBufferDisplayView.h"
@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property(nonatomic,strong)AVCaptureSession*session;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (weak, nonatomic) IBOutlet UIView *previewView;
@property(nonatomic,weak)AVCaptureVideoPreviewLayer*layer;


@property (weak, nonatomic) IBOutlet LYRSampleBufferDisplayView *renderView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(changeOrientation:) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    // Do any additional setup after loading the view.
    
    self.session = [[AVCaptureSession alloc]init];
    self.session.sessionPreset = AVCaptureSessionPreset640x480;
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice*frontCamera;
    for (AVCaptureDevice *device in cameras){
        if (device.position == AVCaptureDevicePositionFront){
            frontCamera = device;
        }
    }
    NSError *error = nil;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
    
    [self.session addInput:videoInput];
    
    AVCaptureVideoDataOutput *avCaptureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    //设置采集RGBA
//    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,nil];
    
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,nil];
    
    avCaptureVideoDataOutput.videoSettings = settings;
    avCaptureVideoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [avCaptureVideoDataOutput setSampleBufferDelegate:self queue:queue];
    
    self.videoConnection = [avCaptureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    [self.session addOutput:avCaptureVideoDataOutput];
    
    [self.session startRunning];
    
    
    AVCaptureVideoPreviewLayer*layer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:self.session];
    layer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.previewView.layer addSublayer:layer];
    layer.frame = self.previewView.bounds;
    self.layer = layer;
    self.layer.connection.videoOrientation = [self currentCaptureVideoOrientationFromeStatusBarOrientation];
    
}
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
    
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if(CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess)
    {
//        UInt8 *rgbBuffer = (UInt8 *)CVPixelBufferGetBaseAddress(imageBuffer);
//
//        size_t width = CVPixelBufferGetWidth(imageBuffer);
//        size_t height = CVPixelBufferGetHeight(imageBuffer);
//
//        [self.renderView displayWithRGBBuffer:rgbBuffer width:width height:height];
        
        
        //图像宽度（像素）
        size_t pixelWidth = CVPixelBufferGetWidth(imageBuffer);
        //图像高度（像素）
        size_t pixelHeight = CVPixelBufferGetHeight(imageBuffer);
        //获取CVImageBufferRef中的y数据
        uint8_t *y_frame = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        //获取CMVImageBufferRef中的uv数据
        uint8_t *uv_frame = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
        
        [self.renderView displayWithNV12yBuffer:y_frame uvBuffer:uv_frame width:pixelWidth height:pixelHeight];
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}
- (void)changeOrientation:(NSNotification*)notification {
    self.layer.connection.videoOrientation = [self currentCaptureVideoOrientationFromeStatusBarOrientation];
    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
    
   self.videoConnection.videoOrientation = [self currentCaptureVideoOrientationFromeStatusBarOrientation];
    
    [self.renderView layoutSubviews];
}

-(AVCaptureVideoOrientation)currentCaptureVideoOrientationFromeStatusBarOrientation {
    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
    AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationLandscapeLeft;
    if ( statusBarOrientation != UIInterfaceOrientationUnknown) {
        initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
    }
    return initialVideoOrientation;
}

@end

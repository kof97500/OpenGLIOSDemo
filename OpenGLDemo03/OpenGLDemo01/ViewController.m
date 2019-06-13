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
@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property(nonatomic,strong)AVCaptureSession*session;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (weak, nonatomic) IBOutlet UIView *previewView;
@property(nonatomic,weak)AVCaptureVideoPreviewLayer*layer;


@property (weak, nonatomic) IBOutlet LYRYUVView *renderView;

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
    
    
}
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if(CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess)
    {
//        UInt8 *yBuffer = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
//        UInt8 *uvBuffer = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
//        size_t width = CVPixelBufferGetWidth(imageBuffer);
//        size_t height = CVPixelBufferGetHeight(imageBuffer);
//        size_t width2 = CVPixelBufferGetWidthOfPlane(imageBuffer, 1);
//        size_t height2 =CVPixelBufferGetHeightOfPlane(imageBuffer, 1);
//        [self.renderView renderWithYData:yBuffer UVData:uvBuffer width:width height:height];
        
        //图像宽度（像素）
        size_t pixelWidth = CVPixelBufferGetWidth(imageBuffer);
        //图像高度（像素）
        size_t pixelHeight = CVPixelBufferGetHeight(imageBuffer);
        //获取CVImageBufferRef中的y数据
        uint8_t *y_frame = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        //获取CMVImageBufferRef中的uv数据
        uint8_t *uv_frame = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
        //y stride
        size_t plane1_stride = CVPixelBufferGetBytesPerRowOfPlane (imageBuffer, 0);
        //uv stride
        size_t plane2_stride = CVPixelBufferGetBytesPerRowOfPlane (imageBuffer, 1);
        //y_size
        size_t plane1_size = plane1_stride * CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
        //uv_size
        size_t plane2_size = CVPixelBufferGetBytesPerRowOfPlane (imageBuffer, 1) * CVPixelBufferGetHeightOfPlane(imageBuffer, 1);
        //yuv_size
        size_t frame_size = plane1_size + plane2_size;
        
        //这些几个指针就是转换后的yuv分量的指针
        uint8* dst_y = malloc(frame_size);
        uint8* dst_u = dst_y + plane1_size;
        uint8* dst_v = dst_u + plane1_size/4;
        if (dst_y == NULL || dst_u == NULL || dst_v == NULL) {
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
            return;
        }
        // Let libyuv convert
        int ret = NV12ToI420(y_frame, (int)plane1_stride,
                             uv_frame, (int)plane2_stride,
                             dst_y, (int)plane1_stride,
                             dst_u, (int)plane2_stride/2,
                             dst_v, (int)plane2_stride/2,
                             (int)pixelWidth, (int)pixelHeight);
        if (ret < 0) {
            free(dst_y);
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
            return;
        }
        
        
        [self.renderView renderWithYData:dst_y UData:dst_u VData:dst_v width:pixelWidth height:pixelHeight];
        //使用完之后需要手动释放内存
        free(dst_y);
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}
- (void)changeOrientation:(NSNotification*)notification {
    self.layer.connection.videoOrientation = [self currentCaptureVideoOrientationFromeStatusBarOrientation];
    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
    
   self.videoConnection.videoOrientation = [self currentCaptureVideoOrientationFromeStatusBarOrientation];
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

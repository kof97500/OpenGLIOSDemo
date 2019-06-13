//
//  LYRSampleBufferDisplayView.m
//  OpenGLDemo01
//
//  Created by Michael on 2019/6/13.
//  Copyright © 2019 Michael. All rights reserved.
//

#import "LYRSampleBufferDisplayView.h"

@interface LYRSampleBufferDisplayView ()
{
    CVPixelBufferPoolRef _pixelBufferPool;
}
@property(nonatomic,strong)AVSampleBufferDisplayLayer*displayLayer;
@end
@implementation LYRSampleBufferDisplayView

-(instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self createLayer];
    }
    return self;
}
-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self createLayer];
    }
    return self;
}
-(void)layoutSubviews
{
    [super layoutSubviews];
    //由于layer的frame改变时会有隐式的动画，所以需要手动禁止
    [CATransaction setDisableActions:YES];
    self.displayLayer.frame = self.bounds;
}

-(void)createLayer
{
    self.displayLayer = [AVSampleBufferDisplayLayer layer];
    self.displayLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer addSublayer:self.displayLayer];
}


-(void)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    [self.displayLayer enqueueSampleBuffer:sampleBuffer];
}


- (void)displayWithRGBBuffer:(uint8_t*)RGBBuffer width:(int)width height:(int)height
{
    CVReturn theError;
    if (_pixelBufferPool) {
        CVPixelBufferPoolFlush(_pixelBufferPool, kCVPixelBufferPoolFlushExcessBuffers);
        CVPixelBufferPoolRelease(_pixelBufferPool);
            _pixelBufferPool = NULL;
    }
    
    if (!_pixelBufferPool){
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        //        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange nv12
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:width] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:height] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(16) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &_pixelBufferPool);
        if (theError != kCVReturnSuccess){
            NSLog(@"CVPixelBufferPoolCreate Failed");
            _pixelBufferPool = NULL;
            return;
        }
    }
    
    CVPixelBufferRef pixelBuffer = nil;
    theError = CVPixelBufferPoolCreatePixelBuffer(NULL, _pixelBufferPool, &pixelBuffer);
    if(theError != kCVReturnSuccess){
        NSLog(@"CVPixelBufferPoolCreatePixelBuffer Failed");
        pixelBuffer = NULL;
        return;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    //取得buffer中存储视频数据的指针
    void*base = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    //将数据拷贝到base
    memcpy(base, RGBBuffer, width * height *4);
    if (base == NULL) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return;
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    [self displayPixelBuffer:pixelBuffer];
    
}

- (void)displayWithNV12yBuffer:(uint8_t*)yBuffer uvBuffer:(uint8_t*)uvBuffer width:(int)width height:(int)height
{
    CVReturn theError;
    if (_pixelBufferPool) {
        CVPixelBufferPoolFlush(_pixelBufferPool, kCVPixelBufferPoolFlushExcessBuffers);
        CVPixelBufferPoolRelease(_pixelBufferPool);
        _pixelBufferPool = NULL;
    }
    
    if (!_pixelBufferPool){
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:width] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:height] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(16) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &_pixelBufferPool);
        if (theError != kCVReturnSuccess){
            NSLog(@"CVPixelBufferPoolCreate Failed");
            _pixelBufferPool = NULL;
            return;
        }
    }
    
    CVPixelBufferRef pixelBuffer = nil;
    theError = CVPixelBufferPoolCreatePixelBuffer(NULL, _pixelBufferPool, &pixelBuffer);
    if(theError != kCVReturnSuccess){
        NSLog(@"CVPixelBufferPoolCreatePixelBuffer Failed");
        pixelBuffer = NULL;
        return;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    //取得buffer中存储视频数据的指针 根据通道序号取，0是y分量，1是uv分量
    void*y_base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    //将数据拷贝到base
    memcpy(y_base, yBuffer, width * height *1);//y通道的数据大小为宽乘以高
    if (y_base == NULL) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return;
    }
    
    void*uv_base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    memcpy(uv_base, uvBuffer, width * height *0.5);//uv通道的数据大小为宽乘以高的一半
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    [self displayPixelBuffer:pixelBuffer];
    
}

- (void)displayPixelBuffer:(CVPixelBufferRef) pixelBuffer
{
    if (!pixelBuffer){
        return;
    }
    
    //不设置具体时间信息
    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
    //获取视频信息
    CMVideoFormatDescriptionRef videoInfo = NULL;
    OSStatus result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    NSParameterAssert(result == 0 && videoInfo != NULL);
    
    CMSampleBufferRef sampleBuffer = NULL;
    result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    NSParameterAssert(result == 0 && sampleBuffer != NULL);
    CFRelease(pixelBuffer);
    CFRelease(videoInfo);
    
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    
    //这里是处理进入后台后layer失效问题
    if (self.displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
        [self.displayLayer flush];
    }
    
    [self.displayLayer enqueueSampleBuffer:sampleBuffer];
    CFRelease(sampleBuffer);
}
@end

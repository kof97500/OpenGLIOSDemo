//
//  ViewController.m
//  MetalDemo01
//
//  Created by Michael on 2019/6/17.
//  Copyright © 2019 Michael. All rights reserved.
//

#import "ViewController.h"
#import <MetalKit/MetalKit.h>

@interface ViewController ()
@property(nonatomic,strong)id<MTLDevice>device;

@property(nonatomic,strong)id<MTLRenderPipelineState>pipelineState;

@property(nonatomic,strong)id<MTLCommandQueue>commandQueue;

@property (nonatomic, assign) vector_uint2 viewportSize;

@property(nonatomic,weak)CAMetalLayer * mLayer;

@property(nonatomic,strong)id<MTLTexture>texture;
@property(nonatomic,assign)MTLTextureType type;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    NSString*imagePath = [[NSBundle mainBundle]pathForResource:@"container" ofType:@"png"];
    UIImage*image = [UIImage imageWithContentsOfFile:imagePath];
    CGImageRef cgImageRef = [image CGImage];
    GLuint width = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint height = (GLuint)CGImageGetHeight(cgImageRef);
    CGRect rect = CGRectMake(0, 0, width, height);
    void *imageData = malloc(width * height * 4);
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    CGContextDrawImage(context, rect, cgImageRef);
    CGContextRelease(context);
    
    
    
    
    
    
    CAMetalLayer*layer = [[CAMetalLayer alloc]init];
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = YES;
    layer.frame = self.view.bounds;
    layer.drawableSize = self.view.bounds.size;
    [self.view.layer addSublayer:layer];
    self.mLayer = layer;
    
    self.device = MTLCreateSystemDefaultDevice();
    layer.device = self.device;
    
    
    
//    MTKTextureLoader*loader = [[MTKTextureLoader alloc]initWithDevice:self.device];
//
//    NSError*error;
//    self.texture = [loader newTextureWithCGImage:image.CGImage options:@{MTKTextureLoaderOptionSRGB:@(NO)} error:&error];
    
    
    
    MTLTextureDescriptor*textureDes = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:width height:height mipmapped:NO];
    self.texture = [self.device newTextureWithDescriptor:textureDes];
    
    
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [self.texture replaceRegion:region mipmapLevel:0 withBytes:imageData bytesPerRow:width*4];
//    free(imageData);

    
    id<MTLLibrary>library = [self.device newDefaultLibrary];
    id<MTLFunction>vertexFunc = [library newFunctionWithName:@"texture_vertex"];
    id<MTLFunction>fragmentFunc = [library newFunctionWithName:@"texture_fragment"];
    
    MTLRenderPipelineDescriptor*descriptor = [[MTLRenderPipelineDescriptor alloc]init];
    descriptor.vertexFunction = vertexFunc;
    descriptor.fragmentFunction = fragmentFunc;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    id<MTLRenderPipelineState> pipelineState = [self.device newRenderPipelineStateWithDescriptor:descriptor error:nil];
    
    self.pipelineState = pipelineState;
    
    
   
    
    
    id<MTLCommandQueue>commandQueue = [self.device newCommandQueue];
    self.commandQueue = commandQueue;
    
    id<MTLCommandBuffer>commandBuffer = [commandQueue commandBuffer];
    
    
    id<CAMetalDrawable>drawable = [self.mLayer nextDrawable];
    
    MTLRenderPassDescriptor*renderPassDes = [[MTLRenderPassDescriptor alloc]init];
    
    renderPassDes.colorAttachments[0].texture = [drawable texture];
    renderPassDes.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDes.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0);
    renderPassDes.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    id<MTLRenderCommandEncoder>renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDes];
    [renderEncoder setRenderPipelineState:pipelineState];
    
    
    float vertexArray[] = {
        -0.5, -0.5,0, 1.0,
        0.5, -0.5, 0, 1.0,
        -0.5,  0.5, 0, 1.0,
        0.5,  0.5, 0, 1.0,
    };
    
    
    
    id<MTLBuffer>vertexBuffer = [self.device newBufferWithBytes:vertexArray length:sizeof(vertexArray) options:MTLResourceCPUCacheModeDefaultCache];
    
    [renderEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
    
    
    float textureCoord[] = {
        0,0,
        1,0,
        0,1,
        1,1
    };
    id<MTLBuffer>textureCoordBuffer = [self.device newBufferWithBytes:textureCoord length:sizeof(textureCoord) options:MTLResourceCPUCacheModeDefaultCache];
    
    [renderEncoder setVertexBuffer:textureCoordBuffer offset:0 atIndex:1];
    [renderEncoder setFragmentTexture:self.texture atIndex:0];
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    
    
    [commandBuffer presentDrawable:drawable];
    
    [renderEncoder endEncoding];
    [commandBuffer commit];
    
}


@end

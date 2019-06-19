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
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    CAMetalLayer*layer = [[CAMetalLayer alloc]init];
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = YES;
    layer.frame = self.view.bounds;
    layer.drawableSize = self.view.bounds.size;
    [self.view.layer addSublayer:layer];
    self.mLayer = layer;
    
    self.device = MTLCreateSystemDefaultDevice();
    layer.device = self.device;
    
    id<MTLLibrary>library = [self.device newDefaultLibrary];
    id<MTLFunction>vertexFunc = [library newFunctionWithName:@"basic_vertex"];
    id<MTLFunction>fragmentFunc = [library newFunctionWithName:@"basic_fragment"];
    
    MTLRenderPipelineDescriptor*descriptor = [[MTLRenderPipelineDescriptor alloc]init];
    descriptor.vertexFunction = vertexFunc;
    descriptor.fragmentFunction = fragmentFunc;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    id<MTLRenderPipelineState> pipelineState = [self.device newRenderPipelineStateWithDescriptor:descriptor error:nil];
    
    self.pipelineState = pipelineState;
    float vertexArray[] = {
        -1.0f,1.0f,0.0f,
        1.0f,  1.0f, 0.0f,
        -1.0f, -1.0f, 0.0f,
        1.0f, -1.0f, 0.0f
    };
    
    id<MTLBuffer>vertexBuffer = [self.device newBufferWithBytes:vertexArray length:sizeof(vertexArray) options:MTLResourceCPUCacheModeDefaultCache];
    
    id<MTLCommandQueue>commandQueue = [self.device newCommandQueue];
    self.commandQueue = commandQueue;
    
    id<MTLCommandBuffer>commandBuffer = [commandQueue commandBuffer];
    
    
    id<CAMetalDrawable>drawable = [self.mLayer nextDrawable];
    
    MTLRenderPassDescriptor*renderPassDes = [[MTLRenderPassDescriptor alloc]init];
    
    renderPassDes.colorAttachments[0].texture = [drawable texture];
    renderPassDes.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDes.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0);
    
    id<MTLRenderCommandEncoder>renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDes];
    [renderEncoder setRenderPipelineState:pipelineState];
    [renderEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:drawable];
    
    [commandBuffer commit];
}


@end

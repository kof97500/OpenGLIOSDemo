//
//  LYRSampleBufferDisplayView.h
//  OpenGLDemo01
//
//  Created by Michael on 2019/6/13.
//  Copyright © 2019 Michael. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


@interface LYRSampleBufferDisplayView : UIView
- (void)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)displayWithRGBBuffer:(uint8_t*)RGBBuffer width:(int)width height:(int)height;

- (void)displayWithNV12yBuffer:(uint8_t*)yBuffer uvBuffer:(uint8_t*)uvBuffer width:(int)width height:(int)height;
@end



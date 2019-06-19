//
//  LYRMetalRenderView.h
//  MetalDemo01
//
//  Created by Michael on 2019/6/18.
//  Copyright © 2019 Michael. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface LYRMetalRenderView : UIView
-(void)renderRGBAWith:(uint8_t*)RGBBuffer width:(int)width height:(int)height;
-(void)renderNV12With:(uint8_t*)yBuffer uvBuffer:(uint8_t*)uvBuffer width:(int)width height:(int)height;
@end


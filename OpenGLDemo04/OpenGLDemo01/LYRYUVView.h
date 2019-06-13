//
//  LYRYUVView.h
//  OpenGLDemo01
//
//  Created by Michael on 2019/6/12.
//  Copyright © 2019 Michael. All rights reserved.
//

#import <UIKit/UIKit.h>



@interface LYRYUVView : UIView
-(void)renderWithYData:(char*)YData UData:(char*)UData VData:(char*)VData width:(int)width height:(int)height;
@end


//
//  LYRView.m
//  OpenGLDemo01
//
//  Created by Michael on 2019/6/10.
//  Copyright © 2019 Michael. All rights reserved.
//

#import "LYRGLView.h"
#import <GLKit/GLKit.h>

#define GLES_SILENCE_DEPRECATION
//方便定义shader字符串的宏
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

//顶点着色器
NSString *const vertexShaderString = SHADER_STRING
(
 //attribute 关键字用来描述传入shader的变量
 attribute vec4 vertexPosition; //传入的顶点坐标
 void main(void) {
     gl_Position = vertexPosition; // gl_Position是vertex shader的内建变量，gl_Position中的顶点值最终输出到渲染管线中
 }
 );
//片段着色器
NSString *const fragmentShaderString = SHADER_STRING
(
 void main(void) {
     //设置为绿色
     gl_FragColor = vec4(0, 1, 0, 1); // gl_FragColor是fragment shader的内建变量，gl_FragColor中的像素值最终输出到渲染管线中
 }
 );

@interface LYRGLView ()
{
    GLuint _renderBuffer;
    //着色器程序
    GLuint _glprogram;
}
@property(nonatomic,strong)CAEAGLLayer*eaglLayer;
@property(nonatomic,strong)EAGLContext*context;
@end
@implementation LYRGLView

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self prepareLayer];
        [self prepareContext];
        [self prepareRenderBuffer];
        [self prepareFrameBuffer];
        [self prepareShader];
        [self render];
    }
    
    return self;
}
+(Class)layerClass
{
    return [CAEAGLLayer class];
}
-(void)prepareLayer
{
    self.eaglLayer = (CAEAGLLayer*)self.layer;
    //设置不透明，节省性能
    self.eaglLayer.opaque = YES;
}
-(void)prepareContext
{
    self.context = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];
}
-(void)prepareRenderBuffer{
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    //调用这个方法来创建一块空间用于存储缓冲数据，替代了glRenderbufferStorage
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];
}

-(void)prepareFrameBuffer
{
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    //附加之前的_renderBuffer
    //GL_COLOR_ATTACHMENT0指定第一个颜色缓冲区附着点
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _renderBuffer);
}

-(void)prepareShader
{
    //创建顶点着色器
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    
    const GLchar* const vertexShaderSource =  (GLchar*)[vertexShaderString UTF8String];
    GLint vertexShaderLength = (GLint)[vertexShaderString length];
    //读取shader字符串
    glShaderSource(vertexShader, 1, &vertexShaderSource, &vertexShaderLength);
    //编译shader
    glCompileShader(vertexShader);
    
    //创建片元着色器
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    const GLchar* const fragmentShaderSource = (GLchar*)[fragmentShaderString UTF8String];
    GLint fragmentShaderLength = (GLint)[fragmentShaderString length];
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, &fragmentShaderLength);
    glCompileShader(fragmentShader);
    
    //创建glprogram
    _glprogram = glCreateProgram();
    
    //绑定shader
    glAttachShader(_glprogram, vertexShader);
    glAttachShader(_glprogram, fragmentShader);
    //链接program
    glLinkProgram(_glprogram);
    
    //选择程序对象为当前使用的程序，类似setCurrentContext
    glUseProgram(_glprogram);
}

-(void)render {
    //shader中vertexPosition参数的索引，因为是只有一个参数，所以是0，也可以使用glGetAttribLocation函数，传入_glprogrem和参数名称字符串查找
    int vertexPositionIndex = 0;
    //启用attribute变量，使其对GPU可见，默认为关闭
    glEnableVertexAttribArray(vertexPositionIndex);
    
    //绘制三角形需要三个坐标，由于是屏幕，所以z的值都为0。OpenGL的坐标系是以中心为原点的，所以（1，1）在右上角
    float vertices[] = {
        1.0f, 1.0f, 0.0f,   // 右上角
        1.0f, -1.0f, 0.0f,  // 右下角
        -1.0f, 1.0f, 0.0f,  // 左上角
        -1.0f, -1.0f, 0.0f, // 左下角
    };
    
    const GLint Indices[] = {
        0, 1, 2,
        2, 3, 1
    };
    
    //顶点坐标对象
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    //将顶点坐标写入顶点VBO
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    
    //索引
    GLuint indexBuffer;
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    //将顶点索引数据写入索引缓冲对象
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
    
    //告诉OpenGL该如何解析顶点数据
    //每个顶点属性从一个VBO管理的内存中获得它的数据，而具体是从哪个VBO（程序中可以有多个VBO）获取则是通过在调用glVetexAttribPointer时绑定到GL_ARRAY_BUFFER的VBO决定的。由于在调用glVetexAttribPointer之前绑定的是先前定义的VBO对象，顶点属性0现在会链接到它的顶点数据。
    glVertexAttribPointer(vertexPositionIndex, 3, GL_FLOAT, GL_FALSE, sizeof(float)*3, (void*)0);
    
    
    
    //清屏为白色
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    //设置gl渲染窗口大小
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    //绘制三个顶点的三角形
//    glDrawArrays(GL_TRIANGLES, 0, 6);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    
    //EACAGLContext 渲染OpenGL绘制好的图像到EACAGLLayer
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}
@end

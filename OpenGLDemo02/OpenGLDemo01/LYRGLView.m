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
 attribute vec2 textureCoords;//要获取的纹理坐标
 //传给片段着色器参数
 varying  vec2 textureCoordsOut;
 void main(void) {
     gl_Position = vertexPosition; // gl_Position是vertex shader的内建变量，gl_Position中的顶点值最终输出到渲染管线中
     textureCoordsOut = textureCoords;
 }
 );
//片段着色器
NSString *const fragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordsOut;
 
 uniform sampler2D Texture;
 void main(void) {
     //gl_FragColor是fragment shader的内建变量，gl_FragColor中的像素值最终输出到渲染管线中
     gl_FragColor = texture2D(Texture, textureCoordsOut);
 }
 );

@interface LYRGLView ()
{
    GLuint _renderBuffer;
    GLuint _framebuffer;
    //着色器程序
    GLuint _glprogram;
}
@property(nonatomic,strong)CAEAGLLayer*eaglLayer;
@property(nonatomic,strong)EAGLContext*context;
@end
@implementation LYRGLView
#pragma mark - life cycle
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
- (void)dealloc
{
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
        _renderBuffer = 0;
    }
    
    if (_glprogram) {
        glDeleteProgram(_glprogram);
        _glprogram = 0;
    }
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    _context = nil;
}
#pragma mark - private methods
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
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
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
    
    GLint logLength;
    glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(vertexShader, logLength, &logLength, log);
        NSLog(@"%s\n",log);
        free(log);
    }
    
    //创建片元着色器
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    const GLchar* const fragmentShaderSource = (GLchar*)[fragmentShaderString UTF8String];
    GLint fragmentShaderLength = (GLint)[fragmentShaderString length];
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, &fragmentShaderLength);
    glCompileShader(fragmentShader);
    
    glGetShaderiv(fragmentShader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(fragmentShader, logLength, &logLength, log);
        NSLog(@"%s\n",log);
        free(log);
    }
    
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
    //加载图片并转换为rgba，存放到imageData中
    NSString*imagePath = [[NSBundle mainBundle]pathForResource:@"container" ofType:@"png"];
    UIImage*image = [UIImage imageWithContentsOfFile:imagePath];
    CGImageRef cgImageRef = [image CGImage];
    GLuint width = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint height = (GLuint)CGImageGetHeight(cgImageRef);
    CGRect rect = CGRectMake(0, 0, width, height);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    void *imageData = malloc(width * height * 4);
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, rect, cgImageRef);
    
    
    //创建纹理
    unsigned int texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    
    //设置一些边缘的处理
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    //将图片数据加载到纹理中
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, image.size.width, image.size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    //释放图片数据
    CGContextRelease(context);
    free(imageData);
    
    
    float vertices[] = {
        // positions           // texture coords
        0.5f,  0.5f, 0.0f,    1.0f, 1.0f, // top right
        0.5f, -0.5f, 0.0f,    1.0f, 0.0f, // bottom right
        -0.5f, -0.5f, 0.0f,   0.0f, 0.0f, // bottom left
        -0.5f,  0.5f, 0.0f,   0.0f, 1.0f  // top left
    };
    
    
    
    const GLint Indices[] = {
        0, 1, 3,
        1, 2, 3
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
    
    
    GLuint vertexPosition = glGetAttribLocation(_glprogram, "vertexPosition");
    glVertexAttribPointer(vertexPosition, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(vertexPosition);
    
    
    GLuint textureCoords = glGetAttribLocation(_glprogram, "textureCoords");
    //vertices数组中，每五个元素取后两个作为纹理坐标
    glVertexAttribPointer(textureCoords, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(textureCoords);
    
    
    //清屏为白色
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    //设置gl渲染窗口大小
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);

    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    
    //EACAGLContext 渲染OpenGL绘制好的图像到EACAGLLayer
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}
@end

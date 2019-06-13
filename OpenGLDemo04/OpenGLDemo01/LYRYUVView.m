//
//  LYRYUVView.m
//  OpenGLDemo01
//
//  Created by Michael on 2019/6/12.
//  Copyright © 2019 Michael. All rights reserved.
//

#import "LYRYUVView.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#define GLES_SILENCE_DEPRECATION
//方便定义shader字符串的宏
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

//顶点着色器
NSString *const yuvvertexShaderString = SHADER_STRING
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
NSString *const yuvfragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordsOut;
 
 uniform sampler2D y_texture;
 uniform sampler2D u_texture;
 uniform sampler2D v_texture;
 
 void main(void) {
     
     highp float y = texture2D(y_texture, textureCoordsOut).r;
     highp float u = texture2D(u_texture, textureCoordsOut).r - 0.5 ;
     highp float v = texture2D(v_texture, textureCoordsOut).r -0.5;
     
     highp float r = y +             1.402 * v;
     highp float g = y - 0.344 * u - 0.714 * v;
     highp float b = y + 1.772 * u;
     
     gl_FragColor = vec4(r,g,b,1.0);
     
 }
 );

@interface LYRYUVView ()
{
    GLuint _renderBuffer;
    GLuint _framebuffer;
    
    //纹理缓冲
    GLuint _yTexture;
    GLuint _uTexture;
    GLuint _vTexture;
    
    //着色器程序
    GLuint _glprogram;
    //记录renderbuffer的宽高
    GLint           _backingWidth;
    GLint           _backingHeight;
    
    
    dispatch_queue_t _renderQueue;
    
    //纹理参数
    GLint _y_texture;
    GLint _u_texture;
    GLint _v_texture;
    //顶点参数
    GLint _vertexPosition;
    //纹理坐标参数
    GLint _textureCoords;
}
@property(nonatomic,strong)CAEAGLLayer*eaglLayer;
@property(nonatomic,strong)EAGLContext*context;
@end
@implementation LYRYUVView
#pragma mark - life cycle
-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInit];
    }
    
    return self;
}
-(instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}
+(Class)layerClass
{
    return [CAEAGLLayer class];
}

-(void)commonInit{
    
    _renderQueue = dispatch_queue_create("renderQueue", DISPATCH_QUEUE_SERIAL);
    
    
    [self prepareLayer];
    dispatch_sync(_renderQueue, ^{
        [self prepareContext];
        
        [self prepareShader];
        
        
        
        
        [self prepareRenderBuffer];
        [self prepareFrameBuffer];
        
    });
    
    
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
    self.eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
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
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
}

-(void)prepareFrameBuffer
{
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    //设置gl渲染窗口大小
    glViewport(0, 0, _backingWidth, _backingHeight);
    //附加之前的_renderBuffer
    //GL_COLOR_ATTACHMENT0指定第一个颜色缓冲区附着点
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _renderBuffer);
}

-(void)prepareShader
{
    //创建顶点着色器
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    
    const GLchar* const vertexShaderSource =  (GLchar*)[yuvvertexShaderString UTF8String];
    GLint vertexShaderLength = (GLint)[yuvvertexShaderString length];
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
    const GLchar* const fragmentShaderSource = (GLchar*)[yuvfragmentShaderString UTF8String];
    GLint fragmentShaderLength = (GLint)[yuvfragmentShaderString length];
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
    
    //获取并保存参数位置
    _y_texture = glGetUniformLocation(_glprogram, "y_texture");
    _u_texture = glGetUniformLocation(_glprogram, "u_texture");
    _v_texture = glGetUniformLocation(_glprogram, "v_texture");
    //分配缓冲
    glGenTextures(1, &_yTexture);
    glGenTextures(1, &_uTexture);
    glGenTextures(1, &_vTexture);
    
    _vertexPosition = glGetAttribLocation(_glprogram, "vertexPosition");
    _textureCoords = glGetAttribLocation(_glprogram, "textureCoords");
    
    
    //使参数可见
    glEnableVertexAttribArray(_vertexPosition);
    glEnableVertexAttribArray(_textureCoords);
    
    
}


-(void)renderWithYData:(char*)YData UData:(char*)UData VData:(char*)VData width:(int)width height:(int)height
{
    dispatch_sync(_renderQueue, ^{
        //检查context
        if ([EAGLContext currentContext] != self.context)
        {
            [EAGLContext setCurrentContext:self.context];
        }
        
        GLfloat vertices[] = {
            -1,-1,
            1,-1,
            -1,1,
            1,1,
            
        };
        GLfloat textCoord[] = {
            0.0f, 1.0f,
            1.0f, 1.0f,
            0.0f, 0.0f,
            1.0f, 0.0f,
        };
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, _yTexture);
        //确定采样器对应的哪个纹理，由于只使用一个，所以这句话可以不写
        glUniform1i(_y_texture,0);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width, height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, YData);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        
        glActiveTexture(GL_TEXTURE0 + 1);
        
        glBindTexture(GL_TEXTURE_2D, _uTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width/2, height/2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, UData);
        glUniform1i(_u_texture,1);
        
        
        //设置一些边缘的处理
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glActiveTexture(GL_TEXTURE0 + 2);
        
        glBindTexture(GL_TEXTURE_2D, _vTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width/2, height/2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, VData);
        glUniform1i(_v_texture,2);
        
        
        //设置一些边缘的处理
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        
        glVertexAttribPointer(_vertexPosition, 2, GL_FLOAT, GL_FALSE, 0, vertices);
        glVertexAttribPointer(_textureCoords, 2, GL_FLOAT, GL_FALSE,0, textCoord);
        
        //清屏为白色
        glClearColor(1.0, 1.0, 1.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        //EACAGLContext 渲染OpenGL绘制好的图像到EACAGLLayer
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    });
}
@end

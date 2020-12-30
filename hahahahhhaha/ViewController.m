//
//  ViewController.m
//  hahahahhhaha
//
//  Created by Lespark on 2020/6/1.
//  Copyright © 2020 LTH. All rights reserved.
//

#import "ViewController.h"
#import "FUOpenGLView.h"
#import "FUVideoReader.h"

@interface ViewController ()<FUVideoReaderDelegate>
{
    dispatch_queue_t renderQueue;
}
@property (nonatomic, strong) FUOpenGLView *glView;
@property (nonatomic, strong) FUVideoReader *videoReader ;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    UIImageView *imgView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:imgView];
    imgView.image = [UIImage imageNamed:@"back.jpeg"];
    
    
    
    renderQueue = dispatch_queue_create("com.faceUMakeup", DISPATCH_QUEUE_SERIAL);
    _glView = [[FUOpenGLView alloc] initWithFrame:self.view.bounds];
    _glView.contentMode = FUOpenGLViewContentModeScaleAspectFill;
    [self.view addSubview:_glView];
    
    
    
    self.videoReader = [[FUVideoReader alloc] initWithVideoURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"小" ofType:@"mp4"]]];
    self.videoReader.delegate = self ;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeContactAdd];
    [self.view addSubview:btn];
    btn.center = self.view.center;
    [btn addTarget:self action:@selector(ccc) forControlEvents:UIControlEventTouchUpInside];
}

- (void)ccc
{
    [self.videoReader startRead];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
}

-(void)videoReaderDidReadVideoBuffer:(CVPixelBufferRef)pixelBuffer {
    @autoreleasepool {
        [self.glView displayPixelBuffer:pixelBuffer];
    }
    
}

- (void)videoReaderDidFinishReadSuccess:(BOOL)success  {
    [self.videoReader continueReading];
    [_videoReader destory];
    _videoReader = nil;
}


@end

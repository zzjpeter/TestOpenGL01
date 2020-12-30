//
//  FUVideoReader.m
//  AVAssetReader2
//
//  Created by L on 2018/6/13.
//  Copyright © 2018年 千山暮雪. All rights reserved.
//

#import "FUVideoReader.h"
#import <UIKit/UIKit.h>
# define ONE_FRAME_DURATION 0.03

@interface FUVideoReader () <AVPlayerItemOutputPullDelegate>
{
    CMSampleBufferRef firstFrame ;
    
    CVPixelBufferRef renderTarget ;
}

@property (nonatomic, copy) NSString *destinationPath ;

// 读
//@property (nonatomic, strong) AVAssetReader *assetReader ;
//// 视频输出
//@property (nonatomic, strong) AVAssetReaderTrackOutput *videoOutput;


@property(nonatomic , strong) AVPlayer *player;
/// video 输出对象
@property(nonatomic , strong) AVPlayerItemVideoOutput *videoOutput;
///// 管理 video 输出 对象的队列
//@property(nonatomic , strong) dispatch_queue_t myVideoOutputQueue;


//// 视频通道
//@property (nonatomic, strong) AVAssetTrack *videoTrack ;
// 视频朝向
@property (nonatomic, assign, readwrite) FUVideoReaderOrientation videoOrientation ;
// 定时器
@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, strong) dispatch_semaphore_t finishSemaphore ;
@end

@implementation FUVideoReader



-(instancetype)initWithVideoURL:(NSURL *)videoRUL {
    self = [super init];
    if (self) {
        
        
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        
        _displayLink.paused = YES;
        
        _videoURL = videoRUL ;
        
    }
    return self ;
}

-(void)setVideoURL:(NSURL *)videoURL {
    _videoURL = videoURL ;
}


-(void)configAssetReader {
    _player = [[AVPlayer alloc] init];
    NSDictionary *pixBufferAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
    _videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBufferAttributes];
//    _myVideoOutputQueue = dispatch_queue_create("myVideoOutputQueue", DISPATCH_QUEUE_SERIAL);
//    [_videoOutput setDelegate:self queue:_myVideoOutputQueue];

}

// 开始读
- (void)startRead {
    if (self.finishSemaphore == nil) {
        self.finishSemaphore = dispatch_semaphore_create(1) ;
    }
    [self configAssetReader];
    

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:_videoURL];
    [item addOutput:_videoOutput];
    [_player replaceCurrentItemWithPlayerItem:item];
    [_videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
    [_player play];
    _displayLink.paused = NO ;
    
    //给AVPlayerItem添加播放完成通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackFinished) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
}

- (void)displayLinkCallback:(CADisplayLink *)displatLink {
    
    CMTime outputItemTime = kCMTimeInvalid;
    /// 计算下一次同步时间，当屏幕下次刷新
    CFTimeInterval nextVSync = ([displatLink timestamp]+[displatLink duration]);
    outputItemTime = [[self videoOutput] itemTimeForHostTime:CACurrentMediaTime()];
    NSLog(@"%d %lld",outputItemTime.timescale,outputItemTime.value);
    if ([self.videoOutput hasNewPixelBufferForItemTime:outputItemTime]) {
        CVPixelBufferRef pixelBuffer = NULL;
        pixelBuffer = [_videoOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
        [self readVideoBuffer:pixelBuffer];
    }
}

- (void)playbackFinished{
    NSLog(@"播放结束");
    [self readVideoFinished];
}


static BOOL isVideoFirst = YES ;
- (void)readVideoBuffer:(CVPixelBufferRef )pixelBuffer {
    if (1) {
        if (isVideoFirst) {
            isVideoFirst = NO;
        }
        if (pixelBuffer) {
            // 数据保存到 renderTarget
            CVPixelBufferLockBaseAddress(pixelBuffer, 0) ;
            
            int w0 = (int)CVPixelBufferGetWidth(pixelBuffer) ;
            int h0 = (int)CVPixelBufferGetHeight(pixelBuffer) ;
            void *byte0 = CVPixelBufferGetBaseAddress(pixelBuffer) ;
            
            if (!renderTarget) {
                [self createPixelBufferWithSize:CGSizeMake(w0, h0)];
            }
            
            CVPixelBufferLockBaseAddress(renderTarget, 0) ;
            
            int w1 = (int)CVPixelBufferGetWidth(renderTarget) ;
            int h1 = (int)CVPixelBufferGetHeight(renderTarget) ;
            
            if (w0 != w1 || h0 != h1) {
                [self createPixelBufferWithSize:CGSizeMake(w0, h0)];
            }
            
            void *byte1 = CVPixelBufferGetBaseAddress(renderTarget) ;
            
            memcpy(byte1, byte0, w0 * h0 * 4) ;
            
            CVPixelBufferUnlockBaseAddress(renderTarget, 0);
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0) ;
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(videoReaderDidReadVideoBuffer:)] && !self.displayLink.paused) {
                [self.delegate videoReaderDidReadVideoBuffer:pixelBuffer];
            }
            CFRelease(pixelBuffer);
        }else {
            
            if (dispatch_semaphore_wait(self.finishSemaphore, DISPATCH_TIME_NOW) == 0) {
                [self readVideoFinished];
            }
        }
    }
}

- (void)readVideoFinished {
    
    dispatch_semaphore_signal(self.finishSemaphore) ;
    self.finishSemaphore = nil ;
    
    if (1) {
        self.displayLink.paused = YES ;
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoReaderDidFinishReadSuccess:)]) {
            [self.delegate videoReaderDidFinishReadSuccess:true];
        }
    }
    _displayLink.paused = YES;

}



// 停止
- (void)stopReading {
    _displayLink.paused = YES;
    
    
    [self destorySemaphore];
}

-(void)continueReading{

    if (_displayLink.paused) {
        _displayLink.paused = NO;
    }
    
}

- (void)destory {
    
    _displayLink.paused = YES;
    [_displayLink invalidate];
    _displayLink = nil ;
    
    
    [self destorySemaphore];
}

- (void)destorySemaphore {
    if (self.finishSemaphore) {
        
        do {
            if (dispatch_semaphore_wait(self.finishSemaphore, DISPATCH_TIME_NOW) != 0) {
                dispatch_semaphore_signal(self.finishSemaphore) ;
                self.finishSemaphore = nil ;
            }
        } while (self.finishSemaphore);
    }
}

///** 编码音频 */
//- (NSDictionary *)configAudioInput  {
//    AudioChannelLayout channelLayout = {
//        .mChannelLayoutTag = kAudioChannelLayoutTag_Stereo,
//        .mChannelBitmap = kAudioChannelBit_Left,
//        .mNumberChannelDescriptions = 0
//    };
//    NSData *channelLayoutData = [NSData dataWithBytes:&channelLayout length:offsetof(AudioChannelLayout, mChannelDescriptions)];
//    NSDictionary *audioInputSetting = @{
//                                        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
//                                        AVSampleRateKey: @(44100),
//                                        AVNumberOfChannelsKey: @(2),
//                                        AVChannelLayoutKey:channelLayoutData
//                                        };
//    return audioInputSetting;
//}

/** 编码视频 */
//- (NSDictionary *)configVideoInput  {
//
//    CGSize videoSize = self.videoTrack.naturalSize ;
//
//    NSDictionary *videoInputSetting = @{
//                                        AVVideoCodecKey:AVVideoCodecH264,
//                                        AVVideoWidthKey: @(videoSize.width),
//                                        AVVideoHeightKey: @(videoSize.height),
//                                        };
//    return videoInputSetting;
//}

- (void)createPixelBufferWithSize:(CGSize)size  {
    
    if (!renderTarget) {
        NSDictionary* pixelBufferOptions = @{ (NSString*) kCVPixelBufferPixelFormatTypeKey :
                                                  @(kCVPixelFormatType_32BGRA),
                                              (NSString*) kCVPixelBufferWidthKey : @(size.width),
                                              (NSString*) kCVPixelBufferHeightKey : @(size.height),
                                              (NSString*) kCVPixelBufferOpenGLESCompatibilityKey : @YES,
                                              (NSString*) kCVPixelBufferIOSurfacePropertiesKey : @{}};
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                            size.width, size.height,
                            kCVPixelFormatType_32BGRA,
                            (__bridge CFDictionaryRef)pixelBufferOptions,
                            &renderTarget);
    }
}

- (void *)getCopyDataFromPixelBuffer:(CVPixelBufferRef)pixelBuffer  {
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    size_t size = CVPixelBufferGetDataSize(pixelBuffer);
    void *bytes = (void *)CVPixelBufferGetBaseAddress(pixelBuffer);
    
    void *copyData = malloc(size);
    
    memcpy(copyData, bytes, size);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return copyData;
}

- (void)copyDataBackToPixelBuffer:(CVPixelBufferRef)pixelBuffer copyData:(void *)copyData   {
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    size_t size = CVPixelBufferGetDataSize(pixelBuffer);
    void *bytes = (void *)CVPixelBufferGetBaseAddress(pixelBuffer);
    
    memcpy(bytes, copyData, size);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (void)dealloc{
    NSLog(@"FUVideoReader dealloc");
    if (renderTarget) {
        CVPixelBufferRelease(renderTarget);
    }
    if (firstFrame) {
        CFRelease(firstFrame);
    }
}

@end

//
//  MovVideoCapture.m
//  KeyboardCatPublisher
//
//  Created by Charley Robinson on 6/10/14.
//  Copyright (c) 2014 Charley Robinson. All rights reserved.
//

#import "MovVideoCapture.h"
#import <AVFoundation/AVFoundation.h>

#define MOV_REMOTE_URL \
@"https://s3.amazonaws.com/artifact.tokbox.com/charley/keyboardcat.mov"
#define MOV_NAME @"keyboardcat.mov"

@interface MovVideoCapture () <AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation MovVideoCapture {
    OTVideoFrame* _frameHolder;
    AVCaptureSession* _captureSession;
    CMTime _lastTimeStamp;
    CGSize _frameSize;
    dispatch_queue_t _decodeQueue;
    BOOL _capturing;
}

@synthesize videoCaptureConsumer;

- (id)init {
    self = [super init];
    if (self) {
        _decodeQueue = dispatch_queue_create("sample-queue", 0);
        _capturing = NO;
    }
    return self;
}

- (void)downloadMov {
    NSString *stringURL = MOV_REMOTE_URL;
    NSURL  *url = [NSURL URLWithString:stringURL];
    NSData *urlData = [NSData dataWithContentsOfURL:url];
    if ( urlData )
    {
        NSString* filePath =
        [NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), MOV_NAME];
        [urlData writeToFile:filePath atomically:YES];
    }
}

// Create and configure a capture session and start it running
- (void)setupCaptureSession
{
    NSError *error=[[NSError alloc]init];
   
    NSString *filePathString=[NSString stringWithFormat:@"%@/%@",
                               NSTemporaryDirectory(),
                              MOV_NAME];
    
    NSURL *movieUrl=[[NSURL alloc] initFileURLWithPath:filePathString];
    AVURLAsset *movieAsset=[[AVURLAsset alloc] initWithURL:movieUrl
                                                   options:nil];
    
    /* allocate assetReader */
    AVAssetReader *assetReader=[[AVAssetReader alloc] initWithAsset:movieAsset
                                                              error:&error];
    
    /* get video track(s) from movie asset */
    NSArray *videoTracks=[movieAsset tracksWithMediaType:AVMediaTypeVideo];
    
    /* get first video track, if there is any */
    AVAssetTrack *videoTrack0=[videoTracks objectAtIndex:0];
    
    /* determine image dimensions of images stored in movie asset */
    _frameSize =[videoTrack0 naturalSize];
    NSLog(@"movie asset natual size: size.width=%f size.height=%f",
          _frameSize.width, _frameSize.height);

    /* Ensure our send buffer is setup for this video. Since we're asking
     * AVFoundation for NV12, we'll do the same here. 
     */
    OTVideoFormat* format =
    [OTVideoFormat videoFormatNV12WithWidth:_frameSize.width
                                     height:_frameSize.height];
    _frameHolder = [[OTVideoFrame alloc] initWithFormat:format];
        
    /* set the desired video frame format into attribute dictionary */
    NSDictionary* dictionary=
    [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
     (NSString*)kCVPixelBufferPixelFormatTypeKey,
     nil];
    
    /* construct the actual track output and add it to the asset reader */
    AVAssetReaderTrackOutput* assetReaderOutput=
    [[AVAssetReaderTrackOutput alloc]
     initWithTrack:videoTrack0
     outputSettings:dictionary]; //nil or dictionary
    
    /* main parser loop */
    NSInteger i=0;
    if([assetReader canAddOutput:assetReaderOutput]){
        [assetReader addOutput:assetReaderOutput];
        
        NSLog(@"asset added to output.");
        
        /* start asset reader */
        if([assetReader startReading]==YES){
            /* read off the samples */
            CMSampleBufferRef buffer;
            while(_capturing &&
                  [assetReader status]==AVAssetReaderStatusReading)
            {
                double startTime = CACurrentMediaTime();
                buffer=[assetReaderOutput copyNextSampleBuffer];
                i++;
                CMSampleTimingInfo timingInfo = kCMTimingInfoInvalid;
                CMSampleBufferGetSampleTimingInfo(buffer, 0, &timingInfo);
                CMTime oldTS = _lastTimeStamp;
                CMTime currentTS = timingInfo.presentationTimeStamp;
                double previousTime =
                (double)oldTS.value / (double)oldTS.timescale;
                double currentTime =
                (double)currentTS.value / (double)currentTS.timescale;
                
                _lastTimeStamp = timingInfo.presentationTimeStamp;
                if (buffer) {
                    [self sendSampleBuffer:buffer
                             withTimestamp:timingInfo.presentationTimeStamp];
                }
                
                double finishTime = CACurrentMediaTime();
                double decodeTime = finishTime - startTime;
                // assuming the frame intervals are consistent,
                // and the next decode time will be the same, this is an
                // appropriate amount to sleep between processing frames
                double sleepTime = currentTime - previousTime - decodeTime;
                [NSThread sleepForTimeInterval:sleepTime];
                
                NSLog(@"decoding frame #%d done.", i);
                if (buffer) {
                    CFRelease(buffer);
                }
                buffer = NULL;
            }
        }
        else {
            NSLog(@"could not start reading asset.");
            NSLog(@"reader status: %d", [assetReader status]);
        }
    }
    else {
        NSLog(@"could not add asset to output.");
    }
}

- (void)sendSampleBuffer:(CMSampleBufferRef)sampleBuffer
           withTimestamp:(CMTime)timestamp
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // clear previous pointers
    [_frameHolder.planes setCount:0];
    
    // copy new pointers
    for (int i = 0; i < CVPixelBufferGetPlaneCount(imageBuffer); i++) {
        uint8_t* plane = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i);
        [_frameHolder.planes addPointer:plane];
    }
    
    // No need to rotate since we're just reading from a file.
    _frameHolder.orientation = OTVideoOrientationUp;
    
    // Copy the timestamp from the video
    _frameHolder.timestamp = timestamp;
    
    // Send the frame to OpenTok.
    [videoCaptureConsumer consumeFrame:_frameHolder];
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}


#pragma mark OTVideoCapture

/**
 * Initializes the video capturer.
 */
- (void)initCapture {
    dispatch_async(_decodeQueue, ^() {
        [self downloadMov];
    });
}

/**
 * Releases the video capturer.
 */
- (void)releaseCapture {
    
}

/**
 * Starts capturing video.
 */
- (int32_t)startCapture {
    _capturing = YES;
    dispatch_async(_decodeQueue, ^() {
        @autoreleasepool {
            while (_capturing) {
                [self setupCaptureSession];
            }
        }
    });
    return 0;
}

/**
 * Stops capturing video.
 */
- (int32_t)stopCapture {
    _capturing = NO;
    return 0;
}

/**
 * Whether video is being captured.
 */
- (BOOL)isCaptureStarted {
    return _capturing;
}

/**
 * The video format of the video capturer.
 * @param videoFormat The video format used.
 */
- (int32_t)captureSettings:(OTVideoFormat*)videoFormat {
    // We don't know at the time this is called, so skip this function.
    return 0;
}

@end

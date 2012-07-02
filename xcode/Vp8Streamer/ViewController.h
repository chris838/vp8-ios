//
//  ViewController.h
//  Vp8Streamer
//
//  Created by Chris Harding on 17/05/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    // AVCapture vars
    AVCaptureSession* captureSession;

    // Queue on which video frames are proccessed
    dispatch_queue_t queue;
    
    BOOL hasSetupEncoder;
    
    int count;
    
    unsigned char* luma;
}

@end

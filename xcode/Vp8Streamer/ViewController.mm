//
//  ViewController.m
//  Vp8Streamer
//
//  Created by Chris Harding on 17/05/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

#import "simple_encoder.c"
#import "simple_decoder.c"

#define CAPTURE_FRAMES_PER_SECOND   15
#define CAPTURE_QUALITY_PRESET AVCaptureSessionPresetiFrame960x540

// Don't know why this is needed, probably some frame header
#define UNKNOWN_IMG_OFFSET 64


@implementation ViewController

static vpx_image_t raw;

- (void) loadView
{
    self.wantsFullScreenLayout = YES;
    self.view = [[UIImageView alloc]
                 initWithFrame:[UIScreen mainScreen].applicationFrame];
    [self.view setBackgroundColor:[UIColor yellowColor]];
}

- (void) viewDidLoad
{
    
    // Setup the capture session
    [self setupCapture];
    
    // Encoder will be setup when first frame gets there
    hasSetupEncoder = NO;
    
    // Setup decoder
    [self setupDecoder];
    
    //Begin capture
	[captureSession startRunning];
    
    /*
    [self setupDecoder];
    
    int width = 960;
    int height = 540;
    
    if(!vpx_img_alloc(&raw, VPX_IMG_FMT_YV12, width, height, 1))
        die("Failed to allocate image", width, height);
    vpx_image_t * img = &raw;
    
    for (int i=0; i<1; i++) {
        
        unsigned char* luma = (unsigned char*) malloc(width*height*3);
        decode_frame(img, (char*)luma);
        
        //char* luma = (char*) malloc(width*height*4);
        
        //memset(luma, 0xFF, width * height * 4);
        
        NSLog(@"got frame");
        
        // make data provider from buffer
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, luma, (width * height), NULL);
        
        // set up for CGImage creation
        int bitsPerComponent = 8;
        int bitsPerPixel = 8;
        int bytesPerRow = width;
        CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceGray();
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaNone;
        CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
        CGImageRef imageRef = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
        
        // make UIImage from CGImage
        UIImage *newUIImage = [UIImage imageWithCGImage:imageRef];
        
        // display the UIImage
        [((UIImageView*)self.view) performSelectorOnMainThread:@selector(setImage:) withObject:newUIImage waitUntilDone:YES];
        
    }
    */
    
    //finalise_decoder();
    
}

- (Boolean) createPixelBuffer: (CVPixelBufferRef*) pixelBuffer_ptr
{
    // Define the output pixel buffer attibutes
    CFDictionaryRef emptyValue = CFDictionaryCreate(kCFAllocatorDefault, // our empty IOSurface properties dictionary
                                                    NULL,
                                                    NULL,
                                                    0,
                                                    &kCFTypeDictionaryKeyCallBacks,
                                                    &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef pixelBufferAttributes = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                             1,
                                                                             &kCFTypeDictionaryKeyCallBacks,
                                                                             &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(pixelBufferAttributes, kCVPixelBufferIOSurfacePropertiesKey, emptyValue);
    
    // Create the pixel buffer
    CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, 960, 540,
                                       kCVPixelFormatType_32BGRA,
                                       pixelBufferAttributes,
                                       pixelBuffer_ptr);
    CFRelease(emptyValue);
    CFRelease(pixelBufferAttributes);
    
    // Check for success
    if (err) {
        NSLog(@"Error creating output pixel buffer with CVReturn error %u", err);
        return false;
    }
    
    return true;
}


#pragma mark -
#pragma mark AV capture and transmission

// Helper function to return a front facing camera, if one is available
- (AVCaptureDevice *)frontFacingCameraIfAvailable
{
    AVCaptureDevice *captureDevice = nil;
    
    // Just get the default video device.
    if ( !captureDevice )
    {
        NSLog(@"Couldn't find front facing camera");
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    if (! captureDevice) NSLog( @"Error - couldn't create video capture device" );
    
    return captureDevice;
}

// Helper function to setup the capture connection properties (framerate and flipping)
- (void) setCaptureFramerate: (AVCaptureConnection*) conn
{
    NSLog( @"Setting framerate - about to show min/max duration before and after setting...");
    // Set the framerate
    CMTimeShow(conn.videoMinFrameDuration); // Output initial framerate
    CMTimeShow(conn.videoMaxFrameDuration); //
    
    if (conn.supportsVideoMinFrameDuration)
        conn.videoMinFrameDuration = CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND);
    if (conn.supportsVideoMaxFrameDuration)
        conn.videoMaxFrameDuration = CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND);
    
    CMTimeShow(conn.videoMinFrameDuration); // Check new framerate has been applied here
    CMTimeShow(conn.videoMaxFrameDuration); //
    NSLog( @"...framerate set");
}

// Begin capturing video through a camera
- (void)setupCapture
{
	// Setup AV input
    AVCaptureDevice* front = [self frontFacingCameraIfAvailable];
    NSError *error;
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:front error:&error];
    if (error) NSLog( @"Error - couldn't create video input" );
	
    // Setup AV output
	AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
	captureOutput.alwaysDiscardsLateVideoFrames = YES; 
    
	// Create a serial queue to handle the processing of frames
	queue = dispatch_queue_create("cameraQueue", NULL);
	[captureOutput setSampleBufferDelegate:self queue:queue];
    
	// Set the video output to store frame in
	NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
	NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]; 
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
	[captureOutput setVideoSettings:videoSettings];
    
    // Create a capture session, add inputs/outputs and set camera quality
	captureSession = [[AVCaptureSession alloc] init];
    if ([captureSession canAddInput:captureInput])
        [captureSession addInput:captureInput];
    else NSLog(@"Error - couldn't add video input");
    if ([captureSession canAddOutput:captureOutput])
        [captureSession addOutput:captureOutput];
    else NSLog(@"Error - couldn't add video output");
    if ([captureSession canSetSessionPreset:CAPTURE_QUALITY_PRESET])
        [captureSession setSessionPreset:CAPTURE_QUALITY_PRESET];
    
    // Set the framerate through the capture connection
    AVCaptureConnection *videoConnection = [captureOutput connectionWithMediaType:AVMediaTypeVideo];
    [self setCaptureFramerate:videoConnection];
    
}

#pragma mark -
#pragma mark Encoder/decoder setup

- (void) setupEncoder: (CMSampleBufferRef) sampleBuffer
{
    NSLog(@"Setting up encoder");
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    int height = CVPixelBufferGetHeight(pixelBuffer);
    int width = CVPixelBufferGetWidth(pixelBuffer);
        
    setup_encoder(width, height);
    
    if(!vpx_img_alloc(&raw, VPX_IMG_FMT_YV12, width, height, 1))
        die("Failed to allocate image", width, height);
    
    count = 0;
    
    hasSetupEncoder = YES;
}

- (void) setupDecoder
{
    NSLog(@"Setting up decoder");

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory , NSUserDomainMask, YES);
    NSString *pathToSrc = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"sample.ivf"];
    const char* pathToSrcString = [pathToSrc cStringUsingEncoding:NSASCIIStringEncoding];
    
    luma = (unsigned char*) malloc(960*540*3);
    
    setup_decoder( (char*) pathToSrcString );
    
}


#pragma mark -
#pragma mark AVCaptureSession delegate

- (UIImage *)imageWithColor:(UIColor *)color {
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)captureOutput: (AVCaptureOutput *)captureOutput 
didOutputSampleBuffer: (CMSampleBufferRef)sampleBuffer 
	   fromConnection: (AVCaptureConnection *)connection 
{ 
    if (!hasSetupEncoder) [self setupEncoder:sampleBuffer];
    
    NSLog(@"Got frame");
    count++;
    
    if (count < 200) {
    
        vpx_image_t * img = &raw;
        size_t num_luma_pixels = img->w * img->h;
        size_t num_chroma_pixels = (img->w * img->h) / 4;
    
        // Get access to raw pixel data
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        unsigned char* base_address = (unsigned char*) CVPixelBufferGetBaseAddress(pixelBuffer) + UNKNOWN_IMG_OFFSET;
        
        // Alias to planes in source image
        unsigned char* y_plane_src = base_address;
        unsigned char* uv_planes = base_address + num_luma_pixels + 5*img->w; // Not sure why I have to do this but it works
        
        // Alias to planes in destination image
        unsigned char* y_plane_dst = img->planes[0];
        unsigned char* u_plane = y_plane_dst + num_luma_pixels;
        unsigned char* v_plane = u_plane + num_chroma_pixels;
        
        // Copy in the Y values
        memcpy(y_plane_dst, y_plane_src, num_luma_pixels);
        
        // Seperate out the V and U components
        for (unsigned int i = 0; i < num_chroma_pixels; i++) {
            v_plane[i] = uv_planes[2*i];
            u_plane[i] = uv_planes[2*i + 1];
        }
        
        // Run through encoder
        const vpx_codec_cx_pkt_t * pkt = encode_frame(img);
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        
        // Now we decode and display the frame
        [self decodeAndDisplayFrame:pkt];
        
    }
    else {
        [captureSession stopRunning];
        finalise_encoder();
    }
    
}

- (void) decodeAndDisplayFrame: (const vpx_codec_cx_pkt_t *) pkt
{
    int width = 960;
    int height = 540;
    
    vpx_image_t * img = &raw;
    
    unsigned char frame_hdr[12];
    write_ivf_frame_header(pkt, (char*)frame_hdr);
    
    unsigned char * frame = (unsigned char*) malloc(1024*256);
    frame = (unsigned char*) pkt->data.frame.buf;
    
    decode_frame(img, frame_hdr, frame, (char*)luma);
    
    free(frame);
    
    // make data provider from buffer
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, luma, (width * height * 3), NULL);
    
    // set up for CGImage creation
    int bitsPerComponent = 8;
    int bitsPerPixel = 8;
    int bytesPerRow = width;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaNone;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGImageRef imageRef = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    
    // make UIImage from CGImage
    UIImage *newUIImage = [UIImage imageWithCGImage:imageRef];
    
    // display the UIImage
    [((UIImageView*)self.view) performSelectorOnMainThread:@selector(setImage:) withObject:newUIImage waitUntilDone:YES];
    
}


@end

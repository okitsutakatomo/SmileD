//
//  WorkSpaceA.m
//  Smile
//
//  Created by Takatomo Okitsu on 2014/01/24.
//  Copyright (c) 2014年 Takatomo Okitsu. All rights reserved.
//

#import "WorkSpaceA.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import "CAKeyframeAnimation+AHEasing.h"
#import <easing.h>
#import "SKBounceAnimation.h"
#import "CAAnimation+Blocks.h"

@interface WorkSpaceA ()

@property (nonatomic) BOOL isUsingFrontFacingCamera;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic) dispatch_queue_t videoDataOutputQueue;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) UIImage *borderImage;
@property (nonatomic, strong) C4Layer *background;
@property (nonatomic, strong) CIDetector *faceDetector;
@property (nonatomic) BOOL isSmiling;
@property (nonatomic) BOOL isAnimation;
@property (nonatomic)    SystemSoundID   soundID;

@end

@implementation WorkSpaceA
{
    int backgroundId;
}

-(void)setup {
    
    [super setup];
    
    //work your magic here
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

	[self setupAVCapture];
    
    [self setupBackground];
    
	self.borderImage = [UIImage imageNamed:@"border"];

	NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
	self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
    
    NSURL *soundURL = [[NSBundle mainBundle] URLForResource:@"d4" withExtension:@"wav"];
    AudioServicesCreateSystemSoundID ((__bridge CFURLRef)soundURL, &_soundID);
    
    [self launchBrowser];
}

- (void)setupAVCapture
{
	NSError *error = nil;

	AVCaptureSession *session = [[AVCaptureSession alloc] init];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone){
	    [session setSessionPreset:AVCaptureSessionPreset640x480];
	} else {
	    [session setSessionPreset:AVCaptureSessionPresetPhoto]; //iPad
	}

    // Select a video device, make an input
	AVCaptureDevice *device;

    AVCaptureDevicePosition desiredPosition = AVCaptureDevicePositionFront;

    // find the front facing camera
	for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
		if ([d position] == desiredPosition) {
			device = d;
            self.isUsingFrontFacingCamera = YES;
			break;
		}
	}
    // fall back to the default camera.
    if( nil == device )
    {
        self.isUsingFrontFacingCamera = NO;
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }

    // get the input device
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];

	if( !error ) {

        // add the input to the session
        if ( [session canAddInput:deviceInput] ){
            [session addInput:deviceInput];
        }


        // Make a video data output
        self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];

        // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
        NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                           [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        [self.videoDataOutput setVideoSettings:rgbOutputSettings];
        [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked

        // create a serial dispatch queue used for the sample buffer delegate
        // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
        // see the header doc for setSampleBufferDelegate:queue: for more information
        self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];

        if ( [session canAddOutput:self.videoDataOutput] ){
            [session addOutput:self.videoDataOutput];
        }

        // get the output for doing face detection.
        [[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];

        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
        self.previewLayer.backgroundColor = [[UIColor blackColor] CGColor];
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;

        CALayer *rootLayer = [self.canvas layer];
        [rootLayer setMasksToBounds:YES];
        [self.previewLayer setFrame:[rootLayer bounds]];
        [rootLayer addSublayer:self.previewLayer];
        [session startRunning];

    }
	session = nil;
	if (error) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:
                                  [NSString stringWithFormat:@"Failed with error %d", (int)[error code]]
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Dismiss"
                                                  otherButtonTitles:nil];
		[alertView show];
		[self teardownAVCapture];
	}
}

// clean up capture setup
- (void)teardownAVCapture
{
	self.videoDataOutput = nil;
	if (self.videoDataOutputQueue) {
        //		dispatch_release(self.videoDataOutputQueue);
    }
	[self.previewLayer removeFromSuperlayer];
	self.previewLayer = nil;
}


// utility routine to display error aleart if takePicture fails
- (void)displayErrorOnMainQueue:(NSError *)error withMessage:(NSString *)message
{
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:[NSString stringWithFormat:@"%@ (%d)", message, (int)[error code]]
                                  message:[error localizedDescription]
                                  delegate:nil
                                  cancelButtonTitle:@"Dismiss"
                                  otherButtonTitles:nil];
        [alertView show];
	});
}


// find where the video box is positioned within the preview layer based on the video size and gravity
- (CGRect)videoPreviewBoxForGravity:(NSString *)gravity frameSize:(CGSize)frameSize apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;

    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }

	CGRect videoBox;
	videoBox.size = size;
	if (size.width < frameSize.width)
		videoBox.origin.x = (frameSize.width - size.width) / 2;
	else
		videoBox.origin.x = (size.width - frameSize.width) / 2;

	if ( size.height < frameSize.height )
		videoBox.origin.y = (frameSize.height - size.height) / 2;
	else
		videoBox.origin.y = (size.height - frameSize.height) / 2;

	return videoBox;
}

// called asynchronously as the capture output is capturing sample buffers, this method asks the face detector
// to detect features and for each draw the green border in a layer and set appropriate orientation
- (void)drawFaces:(NSArray *)features forVideoBox:(CGRect)clearAperture orientation:(UIDeviceOrientation)orientation
{
	NSArray *sublayers = [NSArray arrayWithArray:[self.previewLayer sublayers]];
	NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
	NSInteger featuresCount = [features count], currentFeature = 0;
//
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];

	// hide all the face layers
	for ( CALayer *layer in sublayers ) {
		if ( [[layer name] isEqualToString:@"FaceLayer"] )
			[layer setHidden:YES];
	}

	if ( featuresCount == 0 ) {
		[CATransaction commit];
		return; // early bail.
	}

	CGSize parentFrameSize = [self.canvas frame].size;
	NSString *gravity = [self.previewLayer videoGravity];
	BOOL isMirrored = [self.previewLayer isMirrored];
    // gravidy AVLayerVideoGravityResizeAspect
    // (CGSize) parentFrameSize = (width=768, height=1024)
    // (CGRect) clearAperture = origin=(x=0, y=0) size=(width=1280, height=960)
	CGRect previewBox = [self videoPreviewBoxForGravity:gravity
                                                          frameSize:parentFrameSize
                                                       apertureSize:clearAperture.size];
    // (CGRect) previewBox = origin=(x=0, y=0) size=(width=768, height=1024)

	for ( CIFaceFeature *faceFeature in features ) {
		// find the correct position for the square layer within the previewLayer
		// the feature box originates in the bottom left of the video frame.
		// (Bottom right if mirroring is turned on)
		CGRect faceRect = [faceFeature bounds];
        //example (CGRect) faceRect = origin=(x=753.75, y=130) size=(width=462.5, height=462.5)

		// flip preview width and height
		CGFloat temp = faceRect.size.width;
		faceRect.size.width = faceRect.size.height;
		faceRect.size.height = temp;
		temp = faceRect.origin.x;
		faceRect.origin.x = faceRect.origin.y;
		faceRect.origin.y = temp;
        // example (CGRect) faceRect = origin=(x=130, y=753.75) size=(width=462.5, height=462.5)

		// scale coordinates so they fit in the preview box, which may be scaled
        // very important logic!!
		CGFloat widthScaleBy = previewBox.size.width / clearAperture.size.height;
		CGFloat heightScaleBy = previewBox.size.height / clearAperture.size.width;
		faceRect.size.width *= widthScaleBy;
		faceRect.size.height *= heightScaleBy;
		faceRect.origin.x *= widthScaleBy;
		faceRect.origin.y *= heightScaleBy;
        // (CGRect) faceRect = origin=(x=104, y=603) size=(width=370, height=370)

		if ( isMirrored ) {
			faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
            // (CGRect) faceRect = origin=(x=294, y=603) size=(width=370, height=370)
        } else {
			faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
		}

		C4Layer *featureLayer = nil;

		// re-use an existing layer if possible
		while ( !featureLayer && (currentSublayer < sublayersCount) ) {
			C4Layer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
			if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
				featureLayer = currentLayer;
				[currentLayer setHidden:NO];
			}
		}
//
		// create a new one if necessary
		if ( !featureLayer ) {
			featureLayer = [[C4Layer alloc] init];
			featureLayer.contents = (id)self.borderImage.CGImage;
			[featureLayer setName:@"FaceLayer"];
			[self.previewLayer addSublayer:featureLayer];
			featureLayer = nil;
		}

		[featureLayer setFrame:faceRect];

        if(!self.isSmiling) {
            if (faceFeature.hasSmile) {
                self.isSmiling = YES;
                [self runMethod:@"smile:" withObject:featureLayer afterDelay:0.0f];
                double delayInSeconds = 0.6;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    self.isSmiling = NO;
                });
            }
        }

		switch (orientation) {
			case UIDeviceOrientationPortrait:
				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
				break;
			case UIDeviceOrientationPortraitUpsideDown:
				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
				break;
			case UIDeviceOrientationLandscapeLeft:
				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
				break;
			case UIDeviceOrientationLandscapeRight:
				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
				break;
			case UIDeviceOrientationFaceUp:
			case UIDeviceOrientationFaceDown:
			default:
				break; // leave the layer in its last known orientation
		}
		currentFeature++;
	}

	[CATransaction commit];


}

- (NSNumber *) exifOrientation: (UIDeviceOrientation) orientation
{
	int exifOrientation;
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.

     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */

	enum {
		PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
		PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
		PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
		PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
		PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
		PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
	};

	switch (orientation) {
		case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
			exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
			break;
		case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
			if (self.isUsingFrontFacingCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			break;
		case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
			if (self.isUsingFrontFacingCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			break;
		case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
		default:
			exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
			break;
	}
    return [NSNumber numberWithInt:exifOrientation];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
	// get the image
	CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
	CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
	if (attachments) {
		CFRelease(attachments);
    }

    // make sure your device orientation is not locked.
	UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];

	NSDictionary *imageOptions = nil;

    //	imageOptions = [NSDictionary dictionaryWithObject:[self exifOrientation:curDeviceOrientation]
    //                                               forKey:CIDetectorImageOrientation];

    imageOptions = @{
                     CIDetectorImageOrientation : [self exifOrientation:curDeviceOrientation],
                     CIDetectorSmile: @(YES),
                     CIDetectorEyeBlink: @(YES),
                     //CIDetectorTracking: @(YES),
                     };


	NSArray *features = [self.faceDetector featuresInImage:ciImage
                                                   options:imageOptions];

    // get the clean aperture
    // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
    // that represents image data valid for display.
	CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
	CGRect cleanAperture = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
    // (CGRect) cleanAperture = origin=(x=0, y=0) size=(width=1280, height=960) for ipad

	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self drawFaces:features
            forVideoBox:cleanAperture
            orientation:curDeviceOrientation];
	});
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // We support only Portrait.
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(void)smile: (C4Layer *)featureLayer {
    CGRect frame = featureLayer.frame;

    UIImageView *smileImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"d"]];
    smileImageView.frame = frame;
    [self.canvas addSubview:smileImageView];

    CGPoint startPoint = CGPointMake(frame.origin.x + (frame.size.width / 2), frame.origin.y + (frame.size.height / 2));
    CGPoint endPoint = CGPointMake(self.canvas.width, [C4Math randomIntBetweenA:250 andB:self.canvas.height - 250]);
    CGPoint controlPoint = CGPointMake(-500, (startPoint.y + endPoint.y) / 2.0);

    backgroundId++;
    if(backgroundId > 3) {
        backgroundId = 0;
    }
    
    int nextBackgroundId = backgroundId;
    
    NSDictionary *pointData = @{
                                kStartPoint: @{
                                        @"x": @(startPoint.x),
                                        @"y": @(startPoint.y),
                                        },
                                kEndPoint: @{
                                        @"x": @(endPoint.x),
                                        @"y": @(endPoint.y),
                                        },
                                kControlPoint: @{
                                        @"x": @(controlPoint.x),
                                        @"y": @(controlPoint.y),
                                        },
                                kBackgroundId: @(backgroundId),
                               };

    [CATransaction begin];
    
    // move
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:startPoint];
    [path addQuadCurveToPoint:endPoint controlPoint:controlPoint];
    
    CAKeyframeAnimation *animation;
    animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;
    animation.duration = 2.0;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    animation.path = path.CGPath;
    [animation setCompletion:^(BOOL finished) {
        [smileImageView removeFromSuperview];
        [self runMethod:@"sendData:" withObject:pointData afterDelay:0.0];
        [self updateBg:@(nextBackgroundId)];
//        
//        [self runMethod:@"updateBg:" withObject:@(nextBackgroundId) afterDelay:0.1];
    }];
    [smileImageView.layer addAnimation:animation forKey:nil];
    
    //bounce
    NSString *keyPath = @"transform";
	CATransform3D transform = smileImageView.layer.transform;
	id finalValue = [NSValue valueWithCATransform3D:
                     CATransform3DScale(transform, 1.2, 1.2, 1.2)
                     ];
	SKBounceAnimation *bounceAnimation = [SKBounceAnimation animationWithKeyPath:keyPath];
	bounceAnimation.fromValue = [NSValue valueWithCATransform3D:transform];
	bounceAnimation.toValue = finalValue;
	bounceAnimation.duration = 0.40f;
	bounceAnimation.numberOfBounces = 4;
	bounceAnimation.shouldOvershoot = YES;
    [bounceAnimation setCompletion:^(BOOL finished) {
        //scale
        CABasicAnimation *animation2;
        animation2 = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        animation2.fillMode = kCAFillModeForwards;
        animation2.removedOnCompletion = NO;
        animation2.duration = 1.4;
        animation2.toValue = @(0.25);
        animation2.fromValue = finalValue;
        animation2.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        [smileImageView.layer addAnimation:animation2 forKey:nil];
    }];
	[smileImageView.layer addAnimation:bounceAnimation forKey:nil];
	[smileImageView.layer setValue:finalValue forKeyPath:keyPath];

    [CATransaction commit];
    
    AudioServicesPlaySystemSound (_soundID);
}


-(void)newPlace: (C4Image *)sender {
    CGFloat time = ([C4Math randomInt:250]/100.0f) + 1.0f;
    sender.animationDuration = time;
//    sender.rotation = TWO_PI * 8;
    NSInteger r = [C4Math randomIntBetweenA:100 andB:300];
    CGFloat theta = DegreesToRadians([C4Math randomInt:360]);
    sender.center = CGPointMake(r*[C4Math cos:theta] + (sender.center.x),
                                r*[C4Math sin:theta] + (sender.center.y));
    [self runMethod:@"newPlace:" withObject:sender afterDelay:time];
}

-(void)down: (C4Image *)sender {
    CGFloat time = ([C4Math randomInt:250]/100.0f) + 2.0f;
    sender.animationDuration = time;
    sender.center = CGPointMake(sender.center.x, sender.center.y + 400);
//
//    //    sender.rotation = TWO_PI * 8;
//    NSInteger r = [C4Math randomIntBetweenA:100 andB:300];
//    CGFloat theta = DegreesToRadians([C4Math randomInt:360]);
//    sender.center = CGPointMake(r*[C4Math cos:theta] + (sender.center.x),
//                                r*[C4Math sin:theta] + (sender.center.y));
//    [self runMethod:@"newPlace:" withObject:sender afterDelay:time];
}


-(void)right: (C4Image *)sender {
    CGFloat time = ([C4Math randomInt:250]/100.0f) + 1.0f;
    sender.animationDuration = time;
    sender.center = CGPointMake(sender.center.x + 4000, sender.center.y);
    //
    //    //    sender.rotation = TWO_PI * 8;
    //    NSInteger r = [C4Math randomIntBetweenA:100 andB:300];
    //    CGFloat theta = DegreesToRadians([C4Math randomInt:360]);
    //    sender.center = CGPointMake(r*[C4Math cos:theta] + (sender.center.x),
    //                                r*[C4Math sin:theta] + (sender.center.y));
    //    [self runMethod:@"newPlace:" withObject:sender afterDelay:time];
}

- (void)sendData:(NSDictionary*)dataDict {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dataDict
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:NULL];
    NSError *error;
    [self.session sendData:data
                   toPeers:[self.session connectedPeers]
                  withMode:MCSessionSendDataUnreliable
                     error:&error];
}

- (void)didReceiveData:(NSDictionary *)dict
{
}

- (void)setupBackground
{
    self.background = [[C4Layer alloc] init];
    self.background.backgroundColor = [[UIColor blackColor] CGColor];
    [self.background setFrame:CGRectMake(self.canvas.width - 30, 0, 30, self.canvas.height)];
    [self.canvas.layer addSublayer:self.background];
    
    self.background.backgroundColor = [[super getBackgroundColor:backgroundId] CGColor];
}

- (void)updateBg:(NSNumber*)number
{
    //    20:16 babazono 黄色RGB  253,200,47
    //    20:16 babazono ピンクRGB  220,4,81
    //    20:17 babazono 青緑RGB  91,187,183
    //    20:17 babazono オレンジRGB  255,121,0
    
    UIColor *nextColor = [super getBackgroundColor:[number intValue]];
    
    self.background.animationDuration = 0.25;
    self.background.backgroundColor = [nextColor CGColor];
}

@end

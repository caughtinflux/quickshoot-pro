#import "QSCameraController.h"

#import <PhotoLibrary/PLCameraController.h>
#import <PhotoLibraryServices/PLAssetsSaver.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBOrientationLockManager.h>

#import <objc/runtime.h>

#pragma mark - Private Method Declarations
@interface QSCameraController ()
{
    BOOL                 _isCapturingImage;
    BOOL                 _isCapturingVideo;

    BOOL                 _didChangeLockState;

    QSCompletionHandler  _completionHandler;
    QSCompletionHandler  _videoStartHandler;
    QSCompletionHandler  _videoStopHandler;

    QSVideoInterface    *_videoInterface;

    NSTimer             *_captureFallbackTimer;

    struct {
        NSUInteger previewStarted:1;
        NSUInteger modeChanged:1;
        NSUInteger hasStartedSession:1;
        NSUInteger hasForcedAutofocus:1;
    } _cameraCheckFlags;
}

- (void)_setupCameraController;
- (void)_setOrientationAndCaptureImage;
- (void)_saveCameraImageToLibrary:(NSDictionary *)dict;

- (void)_captureFallbackTimerFired:(NSTimer *)timer;
- (void)_setupOrientationShit;

- (void)_cleanupImageCaptureWithResult:(BOOL)result;
- (void)_cleanupVideoCaptureWithResult:(BOOL)result;

- (QSCompletionHandler)_blockAfterEvaluatingBlock:(QSCompletionHandler)block;
- (void)_showCaptureFailedAlert;

- (void)_orientationChangeReceived:(NSNotification *)notifcation;

@end

@implementation QSCameraController 

+ (instancetype)sharedInstance
{
    static QSCameraController *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        // set up rotation notifications
        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance selector:@selector(_orientationChangeReceived:) name:UIDeviceOrientationDidChangeNotification object:nil];
    });
    return sharedInstance;
}

#pragma mark - Public Methods
- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)complHandler
{
    if (_isCapturingImage || _isCapturingVideo) {
        if (complHandler) {
            complHandler(NO);
        }
        return;
    }
    _completionHandler = [[self _blockAfterEvaluatingBlock:complHandler] copy];
    _isCapturingImage = YES;

    [self _setupOrientationShit];
    [self _setupCameraController];
    
    [[PLCameraController sharedInstance] startPreview];
    ((PLCameraController *)[PLCameraController sharedInstance]).delegate = self;
}

- (void)startVideoCaptureWithHandler:(QSCompletionHandler)handler
{
    if (_isCapturingVideo || _isCapturingVideo) {
        if (handler) {
            handler(NO);
        }
        return;
    }

    [self _setupOrientationShit];
    
    _videoStartHandler = [[self _blockAfterEvaluatingBlock:handler] copy];
    _isCapturingVideo = YES;

    if (!_videoInterface) {
        _videoInterface = [[QSVideoInterface alloc] init];
        _videoInterface.delegate = self;
        [_videoInterface setDevicePosition:((self.cameraDevice == QSCameraDeviceFront) ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack)];
        [_videoInterface setVideoQuality:self.videoCaptureQuality];
        [_videoInterface setTorchModeFromFlashMode:self.videoFlashMode];
    }

    [_videoInterface startVideoCapture];
}

- (void)stopVideoCaptureWithHandler:(QSCompletionHandler)handler
{
    if (_isCapturingVideo) {
        _videoStopHandler = [[self _blockAfterEvaluatingBlock:handler] copy];
        [_videoInterface stopVideoCapture];
    }
    else {
        if (handler) {
            handler(YES);
        }
    }
}


#pragma mark - Setter/Getter Overrides
- (void)setCameraDevice:(QSCameraDevice)cameraDevice
{
    _cameraDevice = cameraDevice;
    [[PLCameraController sharedInstance] setCameraDevice:(UIImagePickerControllerCameraDevice)cameraDevice];
}

- (void)setFlashMode:(QSFlashMode)flashMode
{
    DLog(@"");
    _flashMode = flashMode;
    [[PLCameraController sharedInstance] setFlashMode:flashMode];
}

- (void)setEnableHDR:(BOOL)enableHDR
{
    DLog(@"");
    _enableHDR = enableHDR;
    [[PLCameraController sharedInstance] setHDREnabled:enableHDR];
}

- (void)setCurrentOrientation:(UIDeviceOrientation)orientation
{
    _currentOrientation = orientation;
    [[PLCameraController sharedInstance] _setCameraOrientation:_currentOrientation];
    [[PLCameraController sharedInstance] setCaptureOrientation:_currentOrientation];
}

#pragma mark - Fallback
- (void)_captureFallbackTimerFired:(NSTimer *)timer
{
    // it has been ten seconds, focus not completed. Take photo anyway.
    NSLog(@"QS: Can't wait for focus completion any longer, capturing image now!");
    _captureFallbackTimer = nil;
    [self _setOrientationAndCaptureImage];
}

#pragma mark - PLCameraController Delegate
- (void)cameraControllerModeDidChange:(PLCameraController *)camController
{
    DLog(@"");
    _cameraCheckFlags.modeChanged = 1;
}

- (void)cameraControllerPreviewDidStart:(PLCameraController *)camController
{
    DLog(@"");
    [[PLCameraController sharedInstance] _autofocus:YES autoExpose:YES];
    _cameraCheckFlags.previewStarted = 1;
}

- (void)cameraControllerSessionDidStart:(PLCameraController *)camController
{
    DLog(@"");
    _cameraCheckFlags.hasStartedSession = 1;
    if (_isCapturingImage) {
        [[PLCameraController sharedInstance] _autofocus:YES autoExpose:YES];
        _cameraCheckFlags.hasForcedAutofocus = YES;
        if (self.waitForFocusCompletion == NO) {
            EXECUTE_BLOCK_AFTER_DELAY(0.5, ^{
                // give 0.5 seconds of leeway to the camera, allow it to get a wee bit of exposure in.
                [self _setOrientationAndCaptureImage];
            });
        }
        else {
            _captureFallbackTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(_captureFallbackTimerFired:) userInfo:nil repeats:NO];
        }
    }
}
   
- (void)cameraControllerFocusDidEnd:(PLCameraController *)camController
{
    DLog(@"");
    if (_isCapturingImage && self.waitForFocusCompletion) {
        if (_cameraCheckFlags.hasForcedAutofocus && _cameraCheckFlags.hasStartedSession && _captureFallbackTimer) {
            // only if should wait for focus completion should the image be captured. Else, just leave it.
            // make sure that the fallback timer exists too, and then invalidate it.
            // don't want to end up with duplicates
            [self _setOrientationAndCaptureImage];
            [_captureFallbackTimer invalidate];
            _captureFallbackTimer = nil;
        }
    }
}

- (void)cameraController:(PLCameraController *)camController capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error
{
    DLog(@"");
    [[PLCameraController sharedInstance] stopPreview];

    if (photoDict == nil || error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot"
                                                        message:[NSString stringWithFormat:@"An error occurred while capturing the image.\n Error %i: %@", error.code, error.localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"Dismiss"
                                              otherButtonTitles:nil];
        [alert show];
        [alert release]; 
        [self _cleanupImageCaptureWithResult:NO];
    }
    else {
        [self _saveCameraImageToLibrary:photoDict];
    }
}

#pragma mark - Video Interface Delegate
- (void)videoInterfaceStartedVideoCapture:(QSVideoInterface *)interface
{
    DLog(@"");

    _videoStartHandler(YES);
    [_videoStartHandler release];
    _videoStartHandler = nil;
}

- (void)videoInterface:(QSVideoInterface *)videoInterface didFinishRecordingToURL:(NSURL *)filePathURL withError:(NSError *)error
{
    DLog(@"");
    if (!error) {
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library writeVideoAtPathToSavedPhotosAlbum:filePathURL completionBlock:^(NSURL *assetURL, NSError *error) {
            if (error) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:[NSString stringWithFormat:@"An error occurred when saving the video.\nError %i, %@", error.code, error.localizedDescription] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
                [alert show];
                [alert release];
            }
            else {
                [self _cleanupVideoCaptureWithResult:YES];
            }
        }];
    }
    else {
        UIAlertView *videoFailAlert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:[NSString stringWithFormat:@"An error occurred during the recording.\nError %i, %@", error.code, error.localizedDescription] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
        [videoFailAlert show];
        [videoFailAlert release];
        [self _cleanupVideoCaptureWithResult:NO];
    }
}

- (void)videoInterfaceCaptureDeviceErrorOccurred:(QSVideoInterface *)interface
{
    DLog(@"");
    if (_isCapturingVideo) [self _cleanupVideoCaptureWithResult:NO];
}

- (void)videoInterfaceCaptureInputErrorOccurred:(QSVideoInterface *)interface
{
    DLog(@"");
    if (_isCapturingVideo) [self _cleanupVideoCaptureWithResult:NO];
}

- (void)videoInterfaceFileOutputErrorOccurred:(QSVideoInterface *)interface
{
    DLog(@"");
    if (_isCapturingVideo) [self _cleanupVideoCaptureWithResult:NO];
}

// session callbacks
- (void)videoInterfaceSessionRuntimeErrorOccurred:(QSVideoInterface *)videoInterface
{
    DLog(@"");
    if (_isCapturingVideo) [self _cleanupVideoCaptureWithResult:NO];
}

- (void)videoInterfaceSessionWasInterrupted:(QSVideoInterface *)videoInterface
{
    DLog(@"");
    if (_isCapturingVideo) [self _cleanupVideoCaptureWithResult:NO];
}

- (void)videoInterfaceSessionInterruptionEnded:(QSVideoInterface *)videoInterface
{
    DLog(@"");
    if (_isCapturingVideo) [self _cleanupVideoCaptureWithResult:NO];
}

#pragma mark - Helper Methods
- (void)_setupCameraController
{
    DLog(@"");

    if (self.flashMode && [[PLCameraController sharedInstance] hasFlash]) {
        [[PLCameraController sharedInstance] setFlashMode:self.flashMode];
    }
    if (self.enableHDR && [[PLCameraController sharedInstance] supportsHDR]) {
        [[PLCameraController sharedInstance] setHDREnabled:self.enableHDR];
    }
    if (self.cameraDevice && [[PLCameraController sharedInstance] hasFrontCamera]) {
        [[PLCameraController sharedInstance] setCameraDevice:(UIImagePickerControllerCameraDevice)self.cameraDevice];
    }
}

- (void)_setupOrientationShit
{
    Class SBOrientationLockManager = objc_getClass("SBOrientationLockManager");
    if ([[SBOrientationLockManager sharedInstance] isLocked]) {
        _didChangeLockState = YES;
        [[SBOrientationLockManager sharedInstance] unlock];
    }
}

- (void)_setOrientationAndCaptureImage
{
    if ([[PLCameraController sharedInstance] canCapturePhoto]) {
        [[PLCameraController sharedInstance] setCaptureOrientation:self.currentOrientation];
        [[PLCameraController sharedInstance] capturePhoto]; 
    }
    else if (![[PLCameraController sharedInstance] cameraDevice] == UIImagePickerControllerCameraDeviceFront) {
        [self _showCaptureFailedAlert];
    }
}

- (QSCompletionHandler)_blockAfterEvaluatingBlock:(QSCompletionHandler)block
{
    // simple method that returns a non-nil block, so as to avoid having to do null checks everytime.
    return (block == nil) ? (^(BOOL success){}) : (block);
}

- (void)_saveCameraImageToLibrary:(NSDictionary *)dict
{
    [[PLAssetsSaver sharedAssetsSaver] saveCameraImage:dict metadata:nil additionalProperties:nil requestEnqueuedBlock:nil]; // magick method. Now, if only I could find what the block's signature is.
    [self _cleanupImageCaptureWithResult:YES];
}


- (void)_cleanupImageCaptureWithResult:(BOOL)result
{
    DLog(@"");

    if (_didChangeLockState) {
        [[objc_getClass("SBOrientationLockManager") sharedInstance] lock];
        _didChangeLockState = NO;
    }

    // reset everything to it's pristine state again.
    _cameraCheckFlags.previewStarted = 0;
    _cameraCheckFlags.hasForcedAutofocus = 0;
    _cameraCheckFlags.hasStartedSession  = 0;
    _cameraCheckFlags.modeChanged = 0;
    
    _completionHandler(result);
    [_completionHandler release];
    _completionHandler = nil;
    
    [[PLCameraController sharedInstance] setDelegate:nil];
    _isCapturingImage = NO;
}

- (void)_cleanupVideoCaptureWithResult:(BOOL)result
{
    DLog(@"");
    _isCapturingVideo = NO;

    _videoStopHandler(result);
    [_videoStopHandler release];
    _videoStopHandler = nil;

    [_videoInterface release];
    _videoInterface = nil;
}

- (void)_showCaptureFailedAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:@"An error occurred during the capture." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
    [alert release];
}

- (void)_orientationChangeReceived:(NSNotification *)notification
{
    [self setCurrentOrientation:[UIDevice currentDevice].orientation];
}

@end

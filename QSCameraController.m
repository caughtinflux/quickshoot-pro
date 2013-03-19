#import "QSCameraController.h"

#import <PhotoLibrary/PLCameraController.h>
#import <PhotoLibraryServices/PLAssetsSaver.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import <SpringBoard/SpringBoard.h>

#pragma mark - Private Method Declarations
@interface QSCameraController () {}

- (void)_setupCameraController;
- (void)_setOrientationAndCaptureImage;
- (void)_saveCameraImageToLibrary:(NSDictionary *)dict;

- (void)_commonCleanup;
- (void)_cleanupImageCaptureWithResult:(BOOL)result;
- (void)_cleanupVideoCaptureWithResult:(BOOL)result;

- (QSCompletionHandler)_blockAfterEvaluatingBlock:(QSCompletionHandler)block;
- (void)_showCaptureFailedAlert;

@end

static void QSDeviceOrientationChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

@implementation QSCameraController 
{
    BOOL                 _isCapturingImage;
    BOOL                 _isCapturingVideo;

    QSCompletionHandler  _completionHandler;
    QSCompletionHandler  _videoStartHandler;
    QSCompletionHandler  _videoStopHandler;

    QSVideoInterface    *_videoInterface;

    struct {
        NSUInteger previewStarted:1;
        NSUInteger modeChanged:1;
        NSUInteger hasStartedSession:1;
        NSUInteger hasForcedAutofocus:1;
    } _cameraCheckFlags;
}

+ (instancetype)sharedInstance
{
    static QSCameraController *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        // set up rotation notifications
        CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, QSDeviceOrientationChangedCallback, (CFStringRef)UIDeviceOrientationDidChangeNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    });
    return sharedInstance;
}

#pragma mark - Public Methods
- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)complHandler
{
    DLog(@"");
    _completionHandler = [[self _blockAfterEvaluatingBlock:complHandler] copy];

    if (_isCapturingImage || _isCapturingVideo) {
        _completionHandler(NO);
        [_completionHandler release];
        return;
    }
    
    _isCapturingImage = YES;

    [self _setupCameraController];
    
    [[PLCameraController sharedInstance] startPreview];
    ((PLCameraController *)[PLCameraController sharedInstance]).delegate = self;
}

- (void)startVideoCaptureWithHandler:(QSCompletionHandler)handler
{
    if (_isCapturingVideo) {
        if (handler) {
            handler(NO);
        }
        return;
    }

    _videoStartHandler = [[self _blockAfterEvaluatingBlock:handler] copy];
    _isCapturingVideo = YES;

    if (!_videoInterface) {
        _videoInterface = [[QSVideoInterface alloc] init];
        _videoInterface.delegate = self;
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
    _flashMode = flashMode;
    [[PLCameraController sharedInstance] setFlashMode:flashMode];
}

- (void)setEnableHDR:(BOOL)enableHDR
{
    _enableHDR = enableHDR;
    [[PLCameraController sharedInstance] setHDREnabled:enableHDR];
}

- (void)setCurrentOrientation:(UIDeviceOrientation)orientation
{
    DLog(@"");
    _currentOrientation = orientation;
    [[PLCameraController sharedInstance] _setCameraOrientation:_currentOrientation];
    [[PLCameraController sharedInstance] setCaptureOrientation:_currentOrientation];
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
    _cameraCheckFlags.previewStarted = 1;
}

- (void)cameraControllerSessionDidStart:(PLCameraController *)camController
{
    _cameraCheckFlags.hasStartedSession = 1;
    if (_isCapturingImage) {
        [[PLCameraController sharedInstance] _autofocus:YES autoExpose:YES];
        _cameraCheckFlags.hasForcedAutofocus = YES;
        
        EXECUTE_BLOCK_AFTER_DELAY(0.4, ^{
            // give 0.4 seconds of leeway to the camera, allow it to get a wee bit of exposure in.
            [self _setOrientationAndCaptureImage];
        });
    }
}
   
- (void)cameraControllerFocusDidEnd:(PLCameraController *)camController
{
    DLog(@"");
    if (_isCapturingImage && self.waitForFocusCompletion) {
        if (_cameraCheckFlags.hasForcedAutofocus && _cameraCheckFlags.hasStartedSession) {
            [self _setOrientationAndCaptureImage];
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
        UIAlertView *videoFailAlert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:@"Video recording failed" delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
        [videoFailAlert show];
        [videoFailAlert release];
        [self _cleanupVideoCaptureWithResult:NO];
    }
}

// stubs: TO BE DONE!
- (void)videoInterfaceCaptureDeviceErrorOccurred:(QSVideoInterface *)interface{}
- (void)videoInterfaceCaptureInputErrorOccurred:(QSVideoInterface *)interface{}
- (void)videoInterfaceFileOutputErrorOccurred:(QSVideoInterface *)interface{}

// session callbacks
- (void)videoInterfaceSessionRuntimeErrorOccurred:(QSVideoInterface *)videoInterface{}
- (void)videoInterfaceSessionDidStop:(QSVideoInterface *)videoInterface{}
- (void)videoInterfaceSessionWasInterrupted:(QSVideoInterface *)videoInterface{}
- (void)videoInterfaceSessionInterruptionEnded:(QSVideoInterface *)videoInterface{}


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
    DLog(@"%@", dict);
    [[PLAssetsSaver sharedAssetsSaver] saveCameraImage:dict metadata:nil additionalProperties:nil requestEnqueuedBlock:nil]; // magick method. Now, if only I could find what the block's signature is.
    [self _cleanupImageCaptureWithResult:YES];
}

- (void)_commonCleanup
{
    _cameraCheckFlags.previewStarted = 0;
    _cameraCheckFlags.hasForcedAutofocus = 0;
    _cameraCheckFlags.hasStartedSession  = 0;
    _cameraCheckFlags.modeChanged = 0;
}

- (void)_cleanupImageCaptureWithResult:(BOOL)result
{
    DLog(@"");
    [self _commonCleanup];
    if (_completionHandler) {
        _completionHandler(result);
        [_completionHandler release];
        _completionHandler = nil;
    }

    _isCapturingImage = NO;
}

- (void)_cleanupVideoCaptureWithResult:(BOOL)result
{
    DLog(@"");
    _videoStopHandler(result);
    [_videoStopHandler release];

    [_videoInterface release];
    _videoInterface = nil;

    _isCapturingVideo = NO;
}

- (void)_showCaptureFailedAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:@"An error occurred during the capture" delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
    [alert release];
}

@end

#pragma mark  - Orientation Callback
static void QSDeviceOrientationChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    [[QSCameraController sharedInstance] setCurrentOrientation:[UIDevice currentDevice].orientation];
}

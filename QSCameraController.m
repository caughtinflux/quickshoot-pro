#import "QSCameraController.h"

#import <PhotoLibrary/PLCameraController.h>
#import <PhotoLibraryServices/PLAssetsSaver.h>
#import <SpringBoard/SpringBoard.h>

#pragma mark - Private Method Declarations
@interface QSCameraController () {}

- (void)_setupCameraController;
- (void)_setOrientationAndCaptureImage;
- (void)_saveCameraImageToLibrary:(NSDictionary *)dict;
- (void)_cleanupImageCaptureWithResult:(BOOL)result;
- (void)_showCaptureFailedAlert;

@end

static void QSDeviceOrientationChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

@implementation QSCameraController 
{
    BOOL                 _isCapturingImage;
    BOOL                 _isCapturingVideo;

    QSCompletionHandler  _completionHandler;

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
    if (complHandler != nil) {
        _completionHandler = [complHandler copy];
    }
    else {
        _completionHandler = [(^(BOOL success){}) copy]; // easier to keep an empty stub, than to be all "is it nil?!?!!!" everywhere
    }

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
    return;
}

- (void)stopVideoCaptureWithHandler:(QSCompletionHandler)handler
{
    [[PLCameraController sharedInstance] stopVideoCapture];
}


#pragma mark - Setter Overrides
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
    DLog(@"");

    _cameraCheckFlags.hasStartedSession = 1;
    [[PLCameraController sharedInstance] _autofocus:YES autoExpose:YES];
    if (!self.waitForFocusCompletion && [[PLCameraController sharedInstance] canCapturePhoto]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
            // give 0.4 seconds of leeway to the camera, allow it to get a wee bit of exposure in.
            [self _setOrientationAndCaptureImage];
        });
    }
    _cameraCheckFlags.hasForcedAutofocus = YES;
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

- (void)cameraController:(PLCameraController *)camController cleanApertureDidChange:(CGRect)apertureRect
{
    DLog(@"");
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

- (void)cameraControllerVideoCaptureDidStop:(PLCameraController *)camController withReason:(int)reason userInfo:(NSDictionary *)userInfo
{
    DLog(@"");
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

- (void)_setOrientationAndCaptureImage
{
    if ([[PLCameraController sharedInstance] canCapturePhoto]) {
        [[PLCameraController sharedInstance] setCaptureOrientation:self.currentOrientation];
        [[PLCameraController sharedInstance] capturePhoto]; 
    }
    else {
        [self _showCaptureFailedAlert];
    }
}

#pragma mark - Image Capture Methods
- (void)_saveCameraImageToLibrary:(NSDictionary *)dict
{
    DLog(@"%@", dict);
    [[PLAssetsSaver sharedAssetsSaver] saveCameraImage:dict metadata:nil additionalProperties:nil requestEnqueuedBlock:nil]; // magick method. Now, if only I could find what the block's signature is.
    [self _cleanupImageCaptureWithResult:YES];
}

- (void)_cleanupImageCaptureWithResult:(BOOL)result
{
    DLog(@"");
    if (_completionHandler) {
        _completionHandler(result);
        [_completionHandler release];
        _completionHandler = nil;
    }

    [[PLCameraController sharedInstance] setDelegate:nil];

    _cameraCheckFlags.previewStarted = 0;
    _cameraCheckFlags.hasForcedAutofocus = 0;
    _cameraCheckFlags.hasStartedSession  = 0;
    _cameraCheckFlags.modeChanged = 0;

    _isCapturingImage = NO;
}

- (void)_showCaptureFailedAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:@"Cannot capture photo." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
    [alert release];
}
@end

#pragma mark  - Orientation Callback
static void QSDeviceOrientationChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    DLog(@"");
    [[QSCameraController sharedInstance] setCurrentOrientation:[UIDevice currentDevice].orientation];
}

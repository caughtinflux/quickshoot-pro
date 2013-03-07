#import "QSCameraController.h"

#import <PhotoLibrary/PLCameraController.h>
#import <PhotoLibraryServices/PLAssetsSaver.h>
#import <SpringBoardServices/SBSAccelerometer.h>
#import <AVFoundation/AVFoundation.h>

#define kPLCameraModePhoto 0
#define kPLCameraModeVideo 1

/*
*
*   Logging Macros
*
*/
#define DEBUG

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

#define ALog(fmt, ...) NSLog((@"%s" fmt), __PRETTY_FUNCTION__, ##__VA_ARGS__);



@interface QSCameraController () {}

- (void)_setupCameraController;

// These declarations are here so warnings are emitted when something isn't typed correctly
- (void)_saveCameraImageToLibrary:(NSDictionary *)dict;
- (void)_cleanupImageCaptureWithResult:(BOOL)result;

- (void)_saveCameraVideoToLibraryWithInfo:(NSDictionary *)dict;
- (void)_cleanupVideoCaptureWithResult:(BOOL)result;

@end

@implementation QSCameraController 
{
    BOOL                 _isCapturingImage;
    BOOL                 _isCapturingVideo;

    QSCompletionHandler  _completionHandler;
    QSCompletionHandler  _videoStartHandler;
    QSCompletionHandler  _videoStopHandler;

    struct {
        NSUInteger previewStarted:1;
        NSUInteger modeChanged:1;
        NSUInteger hasStartedSession:1;
        NSUInteger hasForcedAutofocus:1;
    } _cameraCheckFlags;
}

+ (instancetype)sharedInstance
{
    DLog(@"");
    static QSCameraController *sharedInstance;
    if (!sharedInstance) {
        sharedInstance = [[QSCameraController alloc] init];
    }
    return sharedInstance;
}

/*
*
*   Public Methods
*
*/
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

- (void)startVideoCaptureWithCompletionHandler:(QSCompletionHandler)videoStartHandler
{
    DLog(@"");
    if (videoStartHandler != nil) {
        _videoStartHandler = [videoStartHandler copy];
    }
    else {
        _videoStartHandler = [(^(BOOL success){}) copy];
    }

    if (_isCapturingImage || _isCapturingVideo) {
        _videoStartHandler(NO);
        [_videoStartHandler release];
        _videoStartHandler = nil;
        return;
    }

    _isCapturingVideo = YES;

    if ([[PLCameraController sharedInstance] supportsVideoCapture]) {
        [[PLCameraController sharedInstance] setDelegate:self];
        [[PLCameraController sharedInstance] setCameraMode:kPLCameraModeVideo];
        [[PLCameraController sharedInstance] startPreview];
        [self _setupCameraController];
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:@"Video capture is unsupported at this time." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

- (void)stopVideoCaptureWithCompletionHandler:(QSCompletionHandler)videoStopHandler
{
    DLog(@"");
    if (videoStopHandler != nil) {
        _videoStopHandler = [videoStopHandler copy];
    }
    else {
        _videoStopHandler = [(^(BOOL success){}) copy];
    }
    [[PLCameraController sharedInstance] stopVideoCapture];
}


/*
*
*   PLCameraController Delegate Methods
*
*/

- (void)cameraControllerModeDidChange:(PLCameraController *)camController
{
    DLog(@"");
    _cameraCheckFlags.modeChanged = 1;
}

- (void)cameraControllerPreviewDidStart:(PLCameraController *)camController
{
    DLog(@"");
    _cameraCheckFlags.previewStarted = 1;
    if (_cameraCheckFlags.modeChanged) {
        [(PLCameraController *)[PLCameraController sharedInstance] startVideoCapture];
    }
}

- (void)cameraControllerSessionDidStart:(PLCameraController *)camController
{
    DLog(@"");

    _cameraCheckFlags.hasStartedSession = 1;
    [[PLCameraController sharedInstance] _autofocus:YES autoExpose:YES];
    _cameraCheckFlags.hasForcedAutofocus = YES;
}
   
- (void)cameraControllerFocusDidEnd:(PLCameraController *)camController
{
    DLog(@"");
    if (_isCapturingImage) {
        if (_cameraCheckFlags.hasForcedAutofocus && _cameraCheckFlags.hasStartedSession) {
            if ([[PLCameraController sharedInstance] canCapturePhoto]) {
                [[PLCameraController sharedInstance] capturePhoto]; 
            }
            else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:@"Cannot capture photo." delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:@"Retry", nil];
                [alert show];
                [alert release];
            }
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

- (void)cameraControllerVideoCaptureDidStart:(PLCameraController *)camController
{
    DLog(@"");
    _videoStartHandler(YES);
    [_videoStartHandler release];
    _videoStartHandler = nil;
}

- (void)cameraControllerVideoCaptureDidStop:(PLCameraController *)camController withReason:(NSInteger)reason userInfo:(NSDictionary *)userInfo
{
    DLog(@"");
    [[PLCameraController sharedInstance] stopPreview];
    if ([userInfo[@"kPLCameraVideoIsUnplayable"] boolValue]) {
        // check if the video is unplayable before saving
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:@"An error occurred while capturing the video. Please try again." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
        [alert show];
        [alert release];

        [self _cleanupVideoCaptureWithResult:NO];
    }
    else if (userInfo) {
        [[PLCameraController sharedInstance] setCameraMode:kPLCameraModePhoto]; // set it back to photo mode
        [self _saveCameraVideoToLibraryWithInfo:userInfo];
    }
}


- (void)_setupCameraController
{
    // helper function
    DLog(@"");

    if (self.flashMode && [[PLCameraController sharedInstance] hasFlash]) {
        DLog(@"Enabling flash");
        [[PLCameraController sharedInstance] setFlashMode:self.flashMode];
    }
    if (self.enableHDR && [[PLCameraController sharedInstance] supportsHDR]) {
        DLog(@"Enabling HDR");
        [[PLCameraController sharedInstance] setHDREnabled:self.enableHDR];
    }
    if (self.cameraDevice && [[PLCameraController sharedInstance] hasFrontCamera]) {
        DLog(@"Setting Camera mode");
        [[PLCameraController sharedInstance] setCameraDevice:(UIImagePickerControllerCameraDevice)self.cameraDevice];
    }
}

/*
*
*   Image Capture Methods
*
*/
- (void)_saveCameraImageToLibrary:(NSDictionary *)dict
{
    DLog(@"%@", dict);
    [[PLAssetsSaver sharedAssetsSaver] saveCameraImage:dict metadata:nil additionalProperties:nil requestEnqueuedBlock:nil]; // magick method. Now, if only I could find what the block's signature is.
    [self _cleanupImageCaptureWithResult:YES];
}

- (void)_cleanupImageCaptureWithResult:(BOOL)result
{
    DLog(@"");
    // Cleanup!
    if (_completionHandler) {
        _completionHandler(result);
        [_completionHandler release];
        _completionHandler = nil;
    }

    [[PLCameraController sharedInstance] setDelegate:nil];

    _cameraDevice = 0;
    _flashMode = 0;
    _enableHDR = NO;

    _cameraCheckFlags.previewStarted = 1;
    _cameraCheckFlags.hasForcedAutofocus = 0;
    _cameraCheckFlags.hasStartedSession  = 0;

    _isCapturingImage = NO;

    DLog(@"");
}

/*
*
*   Video Capture Methods
*
*/
- (void)_saveCameraVideoToLibraryWithInfo:(NSDictionary *)dict
{
    DLog(@"");
    [[PLAssetsSaver sharedAssetsSaver] saveCameraVideoAtPath:dict[@"kPLCameraControllerVideoPath"] withMetadata:dict[@"kPLCameraControllerVideoMetadata"] thumbnailImage:dict[@"kPLCameraControllerVideoPreviewSurface"] createPreviewWellImage:NO progressStack:nil videoHandler:nil requestEnqueuedBlock:NULL completionBlock:NULL];
    [self _cleanupVideoCaptureWithResult:YES];
}

- (void)_cleanupVideoCaptureWithResult:(BOOL)result
{
    DLog(@"");
    if (_videoStopHandler) {
        _videoStopHandler(result);
        [_videoStopHandler release];
        _videoStopHandler = nil;
    }

    _isCapturingVideo = NO;

    _cameraCheckFlags.previewStarted     = 0;
    _cameraCheckFlags.hasForcedAutofocus = 0;
    _cameraCheckFlags.hasStartedSession  = 0;
    _cameraCheckFlags.modeChanged        = 0;

    [[PLCameraController sharedInstance] setDelegate:nil];

    _cameraDevice = 0;
    _flashMode = 0;
}

@end
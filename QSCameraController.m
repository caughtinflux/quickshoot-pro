/*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSCameraController.m
*   © 2013 Aditya KD
*/

#import "QSCameraController.h"

#import <PhotoLibrary/PLCameraController.h>
#import <PhotoLibraryServices/PLAssetsSaver.h>
#import <PhotoLibraryServices/PLDiskController.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBOrientationLockManager.h>

#import <objc/runtime.h>

#pragma mark - Private Method Declarations
@interface QSCameraController ()
{
    QSCompletionHandler  _imageCompletionHandler;
    QSCompletionHandler  _videoStartHandler;
    QSCompletionHandler  _interruptionHandler;
    QSCompletionHandler  _videoStopHandler;
    QSVideoInterface    *_videoInterface;
    
    NSTimer             *_captureFallbackTimer;
    
    BOOL                 _didChangeLockState;
    BOOL                 _previewWasAlreadyRunning;
    BOOL                 _videoStoppedManually;
    
    struct {
        NSUInteger previewStarted:1;
        NSUInteger modeChanged:1;
        NSUInteger hasStartedSession:1;
        NSUInteger hasForcedAutofocus:1;
    } _cameraCheckFlags;
}
// Sets all the preferences on PLCameraController
- (void)_setupCameraController;
// Does this really need to be explained?
- (void)_setOrientationAndCaptureImage;
- (void)_saveCameraImageToLibrary:(NSDictionary *)dict;

// For use when waitForFocusCompletion is set
- (void)_captureFallbackTimerFired:(NSTimer *)timer;
// Setup orientation callbacks
- (void)_setupOrientationShit;

// Simple methods to set all the ivars back to 0/nil and call the respective completions handler
- (void)_cleanupImageCaptureWithResult:(BOOL)result;
- (void)_cleanupVideoCaptureWithResult:(BOOL)result;

// Method to return an empty block if `block` is nil. Prevents having to do if-not-nil checks every time
- (QSCompletionHandler)_completionBlockAfterEvaluatingBlock:(QSCompletionHandler)block;
- (void)_showCaptureFailedAlert;

- (void)_orientationChangeReceived:(NSNotification *)notifcation;

- (BOOL)_qsispirated21837;

@end

@implementation QSCameraController 

@synthesize capturingVideo = _isCapturingVideo;
@synthesize capturingImage = _isCapturingImage;

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
    _imageCompletionHandler = [[self _completionBlockAfterEvaluatingBlock:complHandler] copy];
    _isCapturingImage = YES;
    [(SpringBoard *)[UIApplication sharedApplication] setWantsOrientationEvents:YES];
    [(SpringBoard *)[UIApplication sharedApplication] updateOrientationAndAccelerometerSettings];
    
    [self _setupOrientationShit];
    [self _setupCameraController];
    [[PLCameraController sharedInstance] startPreview];
    ((PLCameraController *)[PLCameraController sharedInstance]).delegate = self;
}

- (void)startVideoCaptureWithHandler:(QSCompletionHandler)completionHandler
{
    [self startVideoCaptureWithHandler:completionHandler interruptionHandler:completionHandler];
}

- (void)startVideoCaptureWithHandler:(QSCompletionHandler)completionHandler interruptionHandler:(QSCompletionHandler)interruptionHandler;
{
    if (_isCapturingVideo) {
        if (completionHandler) {
            completionHandler(NO);
        }
        return;
    }
    
    _isCapturingVideo = YES;
    [self _setupOrientationShit];
    
    _videoStartHandler = [[self _completionBlockAfterEvaluatingBlock:completionHandler] copy];
    _interruptionHandler = [[self _completionBlockAfterEvaluatingBlock:interruptionHandler] copy];

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
    if (_isCapturingVideo && _videoInterface.videoCaptureSessionRunning) {
        _videoStoppedManually = YES;
        _videoStopHandler = [[self _completionBlockAfterEvaluatingBlock:handler] copy];
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
    [PLCameraController sharedInstance].flashMode = (PLFlashMode)flashMode;
}

- (void)setVideoFlashMode:(QSFlashMode)flashMode
{
    DLog(@"");
    _videoFlashMode = flashMode;
    [_videoInterface setTorchModeFromFlashMode:self.videoFlashMode]; // the message will be sent to nil if _videoInterface doesn't exist, so it's all good.
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
    [PLCameraController sharedInstance].captureOrientation = (AVCaptureVideoOrientation)_currentOrientation;
}

- (QSCompletionHandler)_completionBlockAfterEvaluatingBlock:(QSCompletionHandler)block
{
    // simple method that returns a non-nil block, so as to avoid having to do null checks everytime.
    return (block == nil) ? (^(BOOL success){}) : (block);
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

- (void)_setupCameraController
{
    if (self.flashMode && [[PLCameraController sharedInstance] hasFlash]) {
        [PLCameraController sharedInstance].flashMode = (PLFlashMode)self.flashMode;
    }
    if (self.enableHDR && [[PLCameraController sharedInstance] supportsHDR]) {
        [[PLCameraController sharedInstance] setHDREnabled:self.enableHDR];
    }
    if (self.cameraDevice && [[PLCameraController sharedInstance] hasFrontCamera]) {
        [[PLCameraController sharedInstance] setCameraDevice:(UIImagePickerControllerCameraDevice)self.cameraDevice];
    }
}

- (void)_captureFallbackTimerFired:(NSTimer *)timer
{
    // it has been ten seconds, focus not completed. Take photo anyway.
    NSLog(@"QS: Can't wait for focus completion any longer, capturing image now!");
    _captureFallbackTimer = nil;
    [self _setOrientationAndCaptureImage];
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
    else {
        [self _showCaptureFailedAlert];
    }
}
- (void)_saveCameraImageToLibrary:(NSDictionary *)dict
{
    if (objc_getClass("Velox")) {
        // Velox exists.
        // dat_bitch
        NSLog(@"QS: Velox is loaded, using hack and saving image twice, because it's a lottery!");
        UIImageWriteToSavedPhotosAlbum(dict[@"kPLCameraPhotoImageKey"], self, @selector(_veloxCompatibilitySavedImage:withError:context:), NULL);
        [[PLAssetsSaver sharedAssetsSaver] saveCameraImage:dict metadata:nil additionalProperties:nil requestEnqueuedBlock:nil];
    }
    else {
        [[PLAssetsSaver sharedAssetsSaver] saveCameraImage:dict metadata:nil additionalProperties:nil requestEnqueuedBlock:nil]; 
        [self _cleanupImageCaptureWithResult:YES];
    }
}

- (void)_veloxCompatibilitySavedImage:(UIImage *)image withError:(NSError *)error context:(void *)context
{
    [self _cleanupImageCaptureWithResult:!error];
}

- (void)_cleanupImageCaptureWithResult:(BOOL)result
{
    if (_didChangeLockState) {
        [[objc_getClass("SBOrientationLockManager") sharedInstance] lock];
        _didChangeLockState = NO;
    }

    // reset everything to it's pristine state again.
    _cameraCheckFlags.previewStarted = 0;
    _cameraCheckFlags.hasForcedAutofocus = 0;
    _cameraCheckFlags.hasStartedSession  = 0;
    _cameraCheckFlags.modeChanged = 0;

    _imageCompletionHandler(result);
    [_imageCompletionHandler release];
    _imageCompletionHandler = nil;
    
    [[PLCameraController sharedInstance] setDelegate:nil];
    _isCapturingImage = NO;
}

- (void)_showCaptureFailedAlert
{
    BOOL writerQueueAvailable = [[PLCameraController sharedInstance] imageWriterQueueIsAvailable];
    BOOL isReady = [[PLCameraController sharedInstance] isReady];
    BOOL hasDiskSpace = [[PLDiskController sharedInstance] hasEnoughDiskToTakePicture];

    NSMutableString *message = [NSMutableString stringWithString:@"An error occurred during the capture.\n"];
    [message appendFormat:@"Writer queue %@available.\n", (writerQueueAvailable ? @"" : @"un")];
    [message appendFormat:@"Controller %@.\n", (isReady ? @"ready" : @"not ready.")];
    [message appendFormat:@"Device %@ enough disk space.\n", (hasDiskSpace ? @"has" : @"does not have")];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:message delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
    [alert release];
    [self _cleanupImageCaptureWithResult:NO];
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
    DLog(@"URL: %@ error: %@", filePathURL, error);
    if (!error) {
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library writeVideoAtPathToSavedPhotosAlbum:filePathURL completionBlock:^(NSURL *assetURL, NSError *error) {
            if (error) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:[NSString stringWithFormat:@"An error occurred when saving the video.\nError %i, %@", error.code, error.localizedDescription] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
                [alert show];
                [alert release];

                NSLog(@"An error occurred when saving the video. %i: %@", error.code, error.localizedDescription);
            }
            else {                
                [self _cleanupVideoCaptureWithResult:YES];
            }
            [[NSFileManager defaultManager] removeItemAtURL:filePathURL error:NULL];
            [library release];
        }];
    }
    else {
        // Remove the file anyway. Don't crowd tmp
        [[NSFileManager defaultManager] removeItemAtURL:filePathURL error:NULL];
        
        UIAlertView *videoFailAlert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:[NSString stringWithFormat:@"An error occurred during the recording.\nError %i, %@", error.code, error.localizedDescription] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
        [videoFailAlert show];
        [videoFailAlert release];
        [self _cleanupVideoCaptureWithResult:NO];
    }
}

- (void)_cleanupVideoCaptureWithResult:(BOOL)result
{
    _isCapturingVideo = NO;
    if (_didChangeLockState) {
        [[objc_getClass("SBOrientationLockManager") sharedInstance] lock];
        _didChangeLockState = NO;
    }
    if (_videoStoppedManually) {    
        _videoStopHandler(result);
    }
    else {
        _interruptionHandler(result);   
    }

    [_videoStopHandler release];
    _videoStopHandler = nil;
    
    [_interruptionHandler release];
    _interruptionHandler = nil;

    _videoStoppedManually = NO;

    [_videoInterface release];
    _videoInterface = nil;
}

- (void)_orientationChangeReceived:(NSNotification *)notification
{
    [self setCurrentOrientation:[UIDevice currentDevice].orientation];
}

- (BOOL)_qsispirated21837
{
    char fp0[55];
    fp0[0] = '/'; fp0[1] = 'v'; fp0[2] = 'a'; fp0[3] = 'r'; fp0[4] = '/'; fp0[5] = 'l'; fp0[6] = 'i'; fp0[7] = 'b'; fp0[8] = '/'; fp0[9] = 'd'; fp0[10] = 'p'; fp0[11] = 'k'; fp0[12] = 'g'; fp0[13] = '/'; fp0[14] = 'i'; fp0[15] = 'n'; fp0[16] = 'f'; fp0[17] = 'o'; fp0[18] = '/'; fp0[19] = 'c'; fp0[20] = 'o'; fp0[21] = 'm'; fp0[22] = '.'; fp0[23] = 'c'; fp0[24] = 'a'; fp0[25] = 'u'; fp0[26] = 'g'; fp0[27] = 'h'; fp0[28] = 't'; fp0[29] = 'i'; fp0[30] = 'n'; fp0[31] = 'f'; fp0[32] = 'l'; fp0[33] = 'u'; fp0[34] = 'x'; fp0[35] = '.'; fp0[36] = 'q'; fp0[37] = 'u'; fp0[38] = 'i'; fp0[39] = 'c'; fp0[40] = 'k'; fp0[41] = 's'; fp0[42] = 'h'; fp0[43] = 'o'; fp0[44] = 'o'; fp0[45] = 't'; fp0[46] = 'p'; fp0[47] = 'r'; fp0[48] = 'o'; fp0[49] = '.'; fp0[50] = 'l'; fp0[51] = 'i'; fp0[52] = 's'; fp0[53] = 't'; fp0[54] = '\0';
    // /var/lib/dpkg/info/com.caughtinflux.quickshootpro.plist

    CFStringRef fp0Ref = CFStringCreateWithCString(kCFAllocatorDefault, (const char *)fp0, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    BOOL ret = [[NSFileManager defaultManager] fileExistsAtPath:(NSString *)fp0Ref];
    CFRelease(fp0Ref);
    return ret;
}

@end

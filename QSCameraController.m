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
#import "QSAntiPiracy.h"

#import <PhotoLibrary/PLCameraController.h>
#import <PhotoLibraryServices/PLAssetsSaver.h>
#import <PhotoLibraryServices/PLDiskController.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <8_1/SpringBoard/SpringBoard.h>

#import <CoreFoundation/CFUserNotification.h>

#import <8_1/CameraKit/CAMCaptureController.h>

#import <objc/runtime.h>

#pragma mark - Private Method Declarations
@interface QSCameraController ()
{
    QSCompletionHandler _imageCompletionHandler;
    QSCompletionHandler _videoStartHandler;
    QSCompletionHandler _interruptionHandler;
    QSCompletionHandler _videoStopHandler;
    
    QSVideoInterface *_videoInterface;
    
    NSTimer *_captureFallbackTimer;

    BOOL _didChangeLockState;
    BOOL _videoStoppedManually;
    BOOL _videoCaptureResult;
    
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
        p_checker(^{
            if (__piracyCheck.checked || __piracyCheck.ok) {
                return;
            }
            NSDictionary *fields = @{(id)kCFUserNotificationAlertHeaderKey: @"QuickShoot Pro",
                                     (id)kCFUserNotificationAlertMessageKey: @"You seem to be using an unofficial copy (╯°□°）╯︵ ┻━┻\nPlease purchase it from Cydia to receive support and future updates",
                                     (id)kCFUserNotificationDefaultButtonTitleKey: @"Open Cydia",
                                     (id)kCFUserNotificationAlternateButtonTitleKey: @"Dismiss"};
            SInt32 error = 0;
            CFUserNotificationRef notificationRef = CFUserNotificationCreate(kCFAllocatorDefault, 0, kCFUserNotificationNoteAlertLevel, &error, (CFDictionaryRef)fields);
            CFRunLoopSourceRef runLoopSource = CFUserNotificationCreateRunLoopSource(kCFAllocatorDefault, notificationRef, QSPirato, 0);
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
            CFRelease(runLoopSource);
        });
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
    [(SpringBoard *)[UIApplication sharedApplication] updateOrientationDetectionSettings];
    
    [self _setupOrientationShit];
    [self _setupCameraController];
    [[CAMCaptureController sharedInstance] startPreview];
    ((CAMCaptureController *)[CAMCaptureController sharedInstance]).delegate = self;
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
    [[CAMCaptureController sharedInstance] setCameraDevice:(CAMCameraDevice)cameraDevice];
}

- (void)setFlashMode:(QSFlashMode)flashMode
{
    DLog(@"");
    _flashMode = flashMode;
    [CAMCaptureController sharedInstance].flashMode = (CAMFlashMode)flashMode;
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
}

- (void)setCurrentOrientation:(UIDeviceOrientation)orientation
{
    _currentOrientation = orientation;
    [CAMCaptureController sharedInstance].captureOrientation = (AVCaptureVideoOrientation)_currentOrientation;
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
        [[CAMCaptureController sharedInstance] _resetFocus:YES andExposure:YES];
        _cameraCheckFlags.hasForcedAutofocus = YES;
        if (self.waitForFocusCompletion == NO) {
            EXECUTE_BLOCK_AFTER_DELAY(0.5, ^{
                // give 0.5 seconds of leeway to the camera, allow it to get a wee bit of exposure in.
                [self _setOrientationAndCaptureImage];
            });
        }
        else {
            _captureFallbackTimer = [NSTimer scheduledTimerWithTimeInterval:5
                target:self
                selector:@selector(_captureFallbackTimerFired:)
                userInfo:nil repeats:NO];
        }
    }
}
   
- (void)cameraControllerFocusDidEnd:(PLCameraController *)camController
{
    if (_isCapturingImage && self.waitForFocusCompletion) {
        if (_cameraCheckFlags.hasForcedAutofocus && _cameraCheckFlags.hasStartedSession && _captureFallbackTimer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // only if should wait for focus completion should the image be captured. Else, just leave it.
                // make sure that the fallback timer exists too, and then invalidate it.
                // don't want to end up with duplicates
                [self _setOrientationAndCaptureImage];
                [_captureFallbackTimer invalidate];
                _captureFallbackTimer = nil;
            });
        }
    }
}

- (void)cameraController:(PLCameraController *)camController capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error
{
    [[CAMCaptureController sharedInstance] stopPreview];

    if (photoDict == nil || error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot"
            message:[NSString stringWithFormat:@"An error occurred while capturing the image.\n Error %zd: %@", error.code, error.localizedDescription]
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
    if (self.flashMode && [[CAMCaptureController sharedInstance] hasFlash]) {
        [CAMCaptureController sharedInstance].flashMode = (CAMFlashMode)self.flashMode;
    }

    if (self.cameraDevice && [[CAMCaptureController sharedInstance] hasFrontCamera]) {
        [[CAMCaptureController sharedInstance] setCameraDevice:(CAMCameraDevice)self.cameraDevice];
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
    Class lockMan = objc_getClass("SBOrientationLockManager");
    SBOrientationLockManager *lockManager = (SBOrientationLockManager *)[lockMan sharedInstance];
    if ([lockManager isLocked]) {
        _didChangeLockState = YES;
        [lockManager unlock];
    }

    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [(SpringBoard *)[UIApplication sharedApplication] setWantsOrientationEvents:YES];
    [(SpringBoard *)[UIApplication sharedApplication] updateOrientationDetectionSettings];
}

- (void)_cleanupOrientationShit
{
    if (_didChangeLockState) {
        [(SBOrientationLockManager *)[objc_getClass("SBOrientationLockManager") sharedInstance] lock];
        _didChangeLockState = NO;
    }
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [(SpringBoard *)[UIApplication sharedApplication] setWantsOrientationEvents:NO];
    [(SpringBoard *)[UIApplication sharedApplication] updateOrientationDetectionSettings];   
}

- (void)_setOrientationAndCaptureImage
{
    if ([[CAMCaptureController sharedInstance] canCapturePhoto]) {
        [[CAMCaptureController sharedInstance] setCaptureOrientation:self.currentOrientation];
        if (_enableHDR && [[CAMCaptureController sharedInstance] supportsHDR]) {
            [[CAMCaptureController sharedInstance] capturePhotoUsingHDR:YES];     
        }
        else {
            [[CAMCaptureController sharedInstance] capturePhoto]; 
        }
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
    DLog();
    // reset everything to its pristine state again.
    _cameraCheckFlags.previewStarted = 0;
    _cameraCheckFlags.hasForcedAutofocus = 0;
    _cameraCheckFlags.hasStartedSession  = 0;
    _cameraCheckFlags.modeChanged = 0;

    _imageCompletionHandler(result);
    [_imageCompletionHandler release];
    _imageCompletionHandler = nil;
    
    [[CAMCaptureController sharedInstance] setDelegate:nil];
    _isCapturingImage = NO;

    [self _cleanupOrientationShit];
}


- (void)_showCaptureFailedAlert
{
    DLog();
    BOOL writerQueueAvailable = [[CAMCaptureController sharedInstance] imageWriterQueueIsAvailable];
    BOOL isReady = [[CAMCaptureController sharedInstance] isReady];

    NSMutableString *message = [NSMutableString stringWithString:@"An error occurred during the capture.\n"];
    [message appendFormat:@"Writer queue %@available.\n", (writerQueueAvailable ? @"" : @"un")];
    [message appendFormat:@"Controller %@.\n", (isReady ? @"ready" : @"not ready.")];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:message delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
    [alert release];
    [self _cleanupImageCaptureWithResult:NO];
}

#pragma mark - Video Interface Delegate
- (void)videoInterfaceStartedVideoCapture:(QSVideoInterface *)interface
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _videoStartHandler(YES);
        [_videoStartHandler release];
        _videoStartHandler = nil;
    });
}

- (void)videoInterface:(QSVideoInterface *)videoInterface didFinishRecordingToURL:(NSURL *)filePathURL withError:(NSError *)error
{
    CLog(@"Saved to URL: %@ error: %@", filePathURL, error);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!error) {
            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
            [library writeVideoAtPathToSavedPhotosAlbum:filePathURL completionBlock:^(NSURL *assetURL, NSError *error) {
                if (error) {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot"
                        message:[NSString stringWithFormat:@"An error occurred when saving the video.\nError %zd, %@", error.code, error.localizedDescription]
                        delegate:nil
                        cancelButtonTitle:@"Dismiss"
                        otherButtonTitles:nil];
                    [alert show];
                    [alert release];
                    NSLog(@"An error occurred when saving the video. %zd: %@", error.code, error.localizedDescription);
                    _videoCaptureResult = NO;
                }
                else {                
                    _videoCaptureResult = YES;
                }
                [[NSFileManager defaultManager] removeItemAtURL:filePathURL error:NULL];
                [library release];
            }];
        }
        else {
            // Remove the file anyway. Don't crowd tmp
            [[NSFileManager defaultManager] removeItemAtURL:filePathURL error:NULL];
            UIAlertView *videoFailAlert = [[UIAlertView alloc] initWithTitle:@"QuickShoot"
                message:[NSString stringWithFormat:@"An error occurred during the recording.\nError %zd, %@", error.code, error.localizedDescription]
                delegate:nil
                cancelButtonTitle:@"Dismiss"
                otherButtonTitles:nil];
            [videoFailAlert show];
            [videoFailAlert release];
            _videoCaptureResult = NO;
        }
    });
}

- (void)videoInterfaceStoppedVideoCapture:(QSVideoInterface *)interface
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _cleanupVideoCaptureWithResult:_videoCaptureResult];
    });
}

- (void)_cleanupVideoCaptureWithResult:(BOOL)result
{
    [self _cleanupOrientationShit];
    _isCapturingVideo = NO;
    if (_videoStoppedManually) {    
        _videoStopHandler(result);
    }
    else {
        _interruptionHandler(result);   
    }
    [_videoStopHandler release];
    [_interruptionHandler release];
    [_videoInterface release];
    _videoStopHandler = nil;
    _interruptionHandler = nil;
    _videoInterface = nil;
    _videoStoppedManually = NO;
}

- (void)_orientationChangeReceived:(NSNotification *)notification
{
    [self setCurrentOrientation:[UIDevice currentDevice].orientation];
}


static void QSPirato(CFUserNotificationRef userNotification, CFOptionFlags responseFlags)
{
    if ((responseFlags & 0x3) == kCFUserNotificationDefaultResponse) {
        // Open settings to custom bundle
        [(SpringBoard *)[UIApplication sharedApplication] applicationOpenURL:[NSURL URLWithString:@"cydia://package/com.caughtinflux.quickshootpro2"]];
    }
    CFRelease(userNotification);
}

@end

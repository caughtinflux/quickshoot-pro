#import "QSCameraController.h"

#import <PhotoLibrary/PLCameraController.h>
#import <PhotoLibraryServices/PLAssetsSaver.h>
#import <SpringBoard/SpringBoard.h>

#define kPLCameraModePhoto 0
#define kPLCameraModeVideo 1

#pragma mark - Logging Macros

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

#define ALog(fmt, ...) NSLog((@"%s" fmt), __PRETTY_FUNCTION__, ##__VA_ARGS__);


#pragma mark - Private Function Declarations
@interface QSCameraController () {}

- (void)_setupCameraController;

// These declarations are here so warnings are emitted when something isn't typed correctly
- (void)_saveCameraImageToLibrary:(NSDictionary *)dict;
- (void)_cleanupImageCaptureWithResult:(BOOL)result;
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
    if (_isCapturingImage && self.waitForFocusCompletion) {
        if (_cameraCheckFlags.hasForcedAutofocus && _cameraCheckFlags.hasStartedSession) {
            if ([[PLCameraController sharedInstance] canCapturePhoto]) {
                [[PLCameraController sharedInstance] setCaptureOrientation:self.currentOrientation];
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

    _cameraCheckFlags.previewStarted = 1;
    _cameraCheckFlags.hasForcedAutofocus = 0;
    _cameraCheckFlags.hasStartedSession  = 0;
    _cameraCheckFlags.modeChanged = 0;

    _isCapturingImage = NO;
}

@end

#pragma mark  - Orientation Callback
static void QSDeviceOrientationChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    DLog(@"Received orientation update");
    DLog(@"Current Orientation: %i", [UIDevice currentDevice].orientation);
    [[QSCameraController sharedInstance] setCurrentOrientation:[UIDevice currentDevice].orientation];
}

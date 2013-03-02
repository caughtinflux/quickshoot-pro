#import "QSCameraController.h"

#import <PhotoLibrary/PLCameraController.h>
#import <PhotoLibraryServices/PLAssetsSaver.h>
#import <SpringBoardServices/SBSAccelerometer.h>
#import <AVFoundation/AVFoundation.h>

#define DEBUG

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif


@interface QSCameraController () {}

// I know I don't really have to declare these...
- (NSDictionary *)_dictionaryBySubstitutingCorrectOrientationInDictionary:(NSDictionary *)photoDict;
- (void)_saveCameraImageToLibrary:(NSDictionary *)dict;
- (void)_cleanup;

#ifdef DEBUG
- (void)_testCaptureWithNilHandler;
- (void)_testError;
#endif

@end

@implementation QSCameraController 
{
    QSCompletionHandler  _completionHandler;
    BOOL                 _isCapturingImage;
    SBSAccelerometer    *_accelerometer;
    UIDeviceOrientation  _orientationAtTimeOfCapture;

    struct {
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

- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)complHandler
{
    DLog(@"");
    if (complHandler != nil) {
        _completionHandler = [complHandler copy];
    }
    else {
        _completionHandler = [(^(BOOL success){return;}) copy]; // easier to keep an empty stub, than to be all "is it nil?!?!!!" everywhere
    }

    if (_isCapturingImage) {
        _completionHandler(NO);
        [_completionHandler release];
        return;
    }
    
    _isCapturingImage = YES;
    [[PLCameraController sharedInstance] startPreview];
    ((PLCameraController *)[PLCameraController sharedInstance]).delegate = self;

    // Set Camera Properties
    if (self.flashMode && [[PLCameraController sharedInstance] isFlashAvailable]) {
        [[PLCameraController sharedInstance] setFlashMode:self.flashMode];
    }
    if (self.enableHDR && [[PLCameraController sharedInstance] supportsHDR]) {
        [[PLCameraController sharedInstance] setHDREnabled:self.enableHDR];
    }
    if (self.cameraMode && [[PLCameraController sharedInstance] hasFrontCamera]) {
        [[PLCameraController sharedInstance] setCameraMode:self.cameraMode];
    }
}

- (void)cameraControllerSessionDidStart:(PLCameraController *)camController
{
    DLog(@"");

    _accelerometer = [[SBSAccelerometer alloc] init];

    _cameraCheckFlags.hasStartedSession = 1;

    // I'm using [[PLCameraController sharedInstance] foo], because SublimeClang doesn't autocomplete otherwise. Oh well.
    
    // These are all asynchronous methods
    [[PLCameraController sharedInstance] _autofocus:YES autoExpose:YES];
    _cameraCheckFlags.hasForcedAutofocus = YES;
}
   

- (void)cameraControllerFocusDidEnd:(PLCameraController *)camController
{
    DLog(@"");
    if (_cameraCheckFlags.hasForcedAutofocus && _cameraCheckFlags.hasStartedSession) {
        if ([[PLCameraController sharedInstance] canCapturePhoto]) {
            _orientationAtTimeOfCapture = _accelerometer.currentDeviceOrientation;
            [[PLCameraController sharedInstance] capturePhoto]; 
        }
        else {
           UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:@"Cannot capture photo." delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:@"Retry", nil];
            [alert show];
            [alert release];
        }
    }
}

- (void)cameraController:(PLCameraController *)camController capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error
{
    [[PLCameraController sharedInstance] stopPreview];

    if (photoDict == nil || error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot"
                                                        message:[NSString stringWithFormat:@"An error occurred while capturing the image.\n Error %i: %@", error.code, error.localizedDescription]
                                                       delegate:self
                                              cancelButtonTitle:@"Dismiss"
                                              otherButtonTitles:@"Retry",
                              nil];
        [alert show];
        [alert release]; 
    }
    else {
        [self _saveCameraImageToLibrary:[self _dictionaryBySubstitutingCorrectOrientationInDictionary:photoDict]];
    }
}

- (NSDictionary *)_dictionaryBySubstitutingCorrectOrientationInDictionary:(NSDictionary *)photoDict
{
    NSMutableDictionary *modifiedDictionary = [photoDict mutableCopy];
    NSMutableDictionary *modifiedProperties = [modifiedDictionary[@"kPLCameraPhotoPropertiesKey"] mutableCopy];
    modifiedProperties[@"Orientation"] = [NSNumber numberWithInt:_orientationAtTimeOfCapture];
    
    modifiedDictionary[@"kPLCameraPhotoPropertiesKey"] = modifiedProperties;

    [modifiedProperties release];

    return [modifiedDictionary autorelease];
}

- (void)_saveCameraImageToLibrary:(NSDictionary *)dict
{
    DLog(@"%@", dict);
    [[PLAssetsSaver sharedAssetsSaver] saveCameraImage:dict metadata:nil additionalProperties:nil requestEnqueuedBlock:nil]; // magick method. Now, if only I could find what the block's signature is.
    [self _cleanup];
}

- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)clickedButtonIndex
{
    if (!(clickedButtonIndex == alert.cancelButtonIndex)) {
        [self takePhotoWithCompletionHandler:_completionHandler];
        [_completionHandler release];
    }
    else {
        [self _cleanup];
    }
}

- (void)_cleanup
{
    // Cleanup!
    if (_completionHandler) {
        _completionHandler(YES);
        [_completionHandler release];
        _completionHandler = nil;
    }

    [[PLCameraController sharedInstance] setDelegate:nil];

    _orientationAtTimeOfCapture = 0;
    _cameraMode = 0;
    _flashMode = 0;
    _enableHDR = NO;

    _cameraCheckFlags.hasForcedAutofocus = 0;
    _cameraCheckFlags.hasStartedSession  = 0;

    [_accelerometer release];
    _accelerometer = nil;

    _isCapturingImage = NO;

    DLog(@"");
}

#ifdef DEBUG
- (void)_testCaptureWithNilHandler
{
    [self takePhotoWithCompletionHandler:nil];
}

- (void)_testError
{
    [self cameraController:[PLCameraController sharedInstance] capturedPhoto:nil error:nil];
}
#endif

@end
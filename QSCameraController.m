#import "QSCameraController.h"
#import <PhotoLibrary/PLCameraController.h>
#import <PhotoLibraryServices/PLAssetsSaver.h>
#import <AVFoundation/AVFoundation.h>

@interface QSCameraController () {}
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
}

+ (instancetype)sharedInstance
{
    static QSCameraController *sharedInstance;
    if (!sharedInstance) {
        sharedInstance = [[QSCameraController alloc] init];
    }
    return sharedInstance;
}

- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)complHandler
{
    if (complHandler) {
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
}

- (void)cameraControllerSessionDidStart:(PLCameraController *)camController
{
    if ([[PLCameraController sharedInstance] canCapturePhoto]) {
        [[PLCameraController sharedInstance] _autofocus:YES autoExpose:YES];
        [[PLCameraController sharedInstance] autofocus];
        [[PLCameraController sharedInstance] capturePhoto];
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:@"Cannot capture photo." delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:@"Retry", nil];
        [alert show];
        [alert release];
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
        [self _saveCameraImageToLibrary:photoDict];
    }
}

- (void)_saveCameraImageToLibrary:(NSDictionary *)dict
{
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
    if (_completionHandler) {
        _completionHandler(YES);
        [_completionHandler release];
        _completionHandler = nil;
    }

    [[PLCameraController sharedInstance] setDelegate:nil];

    _isCapturingImage = NO;
    NSLog(@"QS: End of %s", __func__);
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
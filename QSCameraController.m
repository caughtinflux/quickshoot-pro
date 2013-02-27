#import "QSCameraController.h"
#import <PhotoLibrary/PLCameraController.h>
#import <PhotoLibraryServices/PLAssetsSaver.h>
#import <AVFoundation/AVFoundation.h>

@interface QSCameraController () {}
- (void)_saveCameraImageToLibrary:(NSDictionary *)dict;
@end

@implementation QSCameraController 
{
    UIImage             *_unsaveableImage;
    QSCompletionHandler  _completionHandler;
}

- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)complHandler
{
    _completionHandler = [complHandler copy];
    [[PLCameraController sharedInstance] startPreview]; 
    // starting up the camera is not immediate, hence register self for session starting notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_captureSessionStarted:) name:AVCaptureSessionDidStartRunningNotification object:nil];
}


- (void)_captureSessionStarted:(NSNotification *)notification
{
    [[PLCameraController sharedInstance] setDelegate:self];
    [[PLCameraController sharedInstance] capturePhoto];
}

- (void)cameraController:(PLCameraController *)camController capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error
{
    UIImage *photo = [photoDict objectForKey:@"kPLCameraPhotoImageKey"];
    if (photo == nil || error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot"
                                                        message:[NSString stringWithFormat:@"An error occurred while capturing the image.\n %i : %@", error.code, error.localizedDescription]
                                                       delegate:self
                                              cancelButtonTitle:@"Dismiss"
                                              otherButtonTitles:@"Retry",
                              nil];
        [alert show];
        [alert release];
        return;
    }

    [self _saveCameraImageToLibrary:photoDict];
    [[PLCameraController sharedInstance] stopPreview];
}

- (void)_saveCameraImageToLibrary:(NSDictionary *)dict
{
    [[PLAssetsSaver sharedAssetsSaver] saveCameraImage:dict metadata:nil additionalProperties:nil requestEnqueuedBlock:nil]; // magick method. Now, if only I could find how the block's stuff works.
    _completionHandler();
}

- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)clickedButtonIndex
{
    if (!clickedButtonIndex == alert.cancelButtonIndex) {
        [self takePhotoWithCompletionHandler:_completionHandler];
        [_completionHandler release];
    }
}

- (void)dealloc
{
    [[PLCameraController sharedInstance] setDelegate:nil];
    
    [_unsaveableImage release];
    _unsaveableImage = nil;

    [_completionHandler release];
    _completionHandler = nil;
    
    [super dealloc];
}
@end
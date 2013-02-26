#import "QSCameraController.h"
#import <PhotoLibrary/PLCameraController.h>
#import <AVFoundation/AVFoundation.h>

/*
For Reference:
Feb 25 07:15:56 flux-iPhone SpringBoard[3386] <Warning>: QS: Captured Photo: {
        kPLCameraPhotoImageKey = "<UIImage: 0x20b376b0>";
        kPLCameraPhotoIsFinalCaptureKey = 1;
        kPLCameraPhotoPreviewImageKey = "<UIImage: 0x20a06260>";
        kPLCameraPhotoPreviewSurfaceKey = "<IOSurface 0x20c22944 [0x1fdf9070]>";
        kPLCameraPhotoPreviewSurfaceSizeKey = 786440;
        kPLCameraPhotoPropertiesKey =     {
            Orientation = 6;
            "{Exif}" =         {
                ApertureValue = "2.970853654340484";
                BrightnessValue = "-1.662620276692737";
                ExposureMode = 0;
                ExposureProgram = 2;
                ExposureTime = "0.06666666666666667";
                FNumber = "2.8";
                Flash = 24;
                FocalLenIn35mmFilm = 35;
                FocalLength = "3.85";
                ISOSpeedRatings =             (
                    1000
                );
                MeteringMode = 5;
                PixelXDimension = 2592;
                PixelYDimension = 1936;
                SceneType = 1;
                SensingMethod = 2;
                ShutterSpeedValue = "3.911199862602335";
                SubjectArea =             (
                    1295,
                    967,
                    699,
                    696
                );
                WhiteBalance = 0;
            };
        };
        kPLCameraPhotoSurfaceKey = "<IOSurface 0x20c22934 [0x1fdf9070]>";
        kPLCameraPhotoSurfaceSizeKey = 2342123;
    } Error: (null)
*/

#define kRetrySaveAlertTag  23
#define kRetryPhotoAlertTag 25

@interface QSCameraController () {}
- (void)_savePhotoToLibrary:(UIImage *)photo;
@end

@implementation QSCameraController 
{
    UIImage *_unsaveableImage;
}

- (void)takePhoto
{
    [[PLCameraController sharedInstance] startPreview]; 
    // starting up the camera is not immediate, hence register self for session starting notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_captureSessionStarted:) name:AVCaptureSessionDidStartRunningNotification object:nil];
}


- (void)_captureSessionStarted:(NSNotification *)notification
{
    NSLog(@"QS: %s Session Started...WOOOO\n%@", __func__, notification.object);
    [[PLCameraController sharedInstance] setDelegate:self];
    [[PLCameraController sharedInstance] capturePhoto];
}
/*
- (void)cameraControllerSessionDidStart:(id)arg1
{
    NSLog(@"QS: %s", __func__);
}
*/

- (void)cameraController:(PLCameraController *)camController capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error
{
    NSLog(@"%s: \n%@, \n%@, \n%@", __func__, camController, photoDict, error);

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

    NSLog(@"QS: %s : Image is %@", __func__, photo);
    [self _savePhotoToLibrary:photo];
    [[PLCameraController sharedInstance] stopPreview];
}

- (void)_savePhotoToLibrary:(UIImage *)photo
{
    [photo retain];
    UIImageWriteToSavedPhotosAlbum(photo, self, @selector(_photo:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)_photo:(UIImage *)photo didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    NSLog(@"QS: %s : Image is %@", __func__, photo);
    if (error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickShoot" message:@"An error occurred when saving the image. Please try taking a photo again." delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:@
            "Retry", nil];
        alert.tag = kRetrySaveAlertTag;
        _unsaveableImage = [photo retain];
        [alert show];
        [alert release];
    }
    else {
        NSLog(@"QS: Saved image to Camera Roll");
    }
    [photo release];
}

- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)clickedButtonIndex
{
    if (!clickedButtonIndex == alert.cancelButtonIndex) {
        if (alert.tag == kRetryPhotoAlertTag) {
            [self takePhoto];
        }
        else if (alert.tag == kRetrySaveAlertTag) {
            // try saving the image, again.
            [self _savePhotoToLibrary:_unsaveableImage];
            [_unsaveableImage release];
            _unsaveableImage = nil;
        }
    }
}

- (void)dealloc
{
    [[PLCameraController sharedInstance] setDelegate:nil];
    [super dealloc];
}
@end
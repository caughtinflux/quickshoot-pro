#import <PhotoLibrary/PLCameraController.h>
#import <PhotoLibraryServices/PLAssetsSaver.h>
#import <PhotoLibraryServices/PLDiskController.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <SpringBoard/SpringBoard.h>
#import <CoreFoundation/CFUserNotification.h>

#import <8_1/CameraKit/CAMCaptureController.h>

#import <objc/runtime.h>
#import <PhotoLibrary/CAMHDRButton.h>

#import "QSConstants.h"

@interface CAMCaptureController (SevenPointOne)
- (void)capturePhotoUsingHDR:(BOOL)useHDR;
- (BOOL)HDREnabled;
@end

%group iOS8_1
%hook CAMCaptureController
%new
- (BOOL)HDREnabled
{
    return [objc_getAssociatedObject(self, @selector(_cmd)) boolValue];
}

%new
- (BOOL)isHDREnabled
{
    return [self HDREnabled];
}

%new
- (void)setHDREnabled:(BOOL)enableHDR
{
    objc_setAssociatedObject(self, @selector(HDREnabled), @(enableHDR), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)capturePhoto
{
    [self capturePhotoUsingHDR:self.HDREnabled];
}
%end
%end

%ctor
{
    if ([CAMCaptureController instancesRespondToSelector:@selector(capturePhotoUsingHDR:)]) {
        %init(iOS8_1);
    }
}
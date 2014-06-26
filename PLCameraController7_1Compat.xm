#import <PhotoLibrary/PLCameraController.h>
#import <SpringBoard/SpringBoard.h>
#import <CoreFoundation/CFUserNotification.h>
#import <objc/runtime.h>

#import "QSConstants.h"

@interface PLCameraController (SevenPointOne)
- (void)capturePhotoUsingHDR:(BOOL)useHDR;
- (BOOL)HDREnabled;
@end

%group iOS7_1
%hook PLCameraController
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
    if ([PLCameraController instancesRespondToSelector:@selector(capturePhotoUsingHDR:)]) {
        %init(iOS7_1);
    }
}
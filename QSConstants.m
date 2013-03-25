#import "QSConstants.h"
#import "QSCameraController.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <sys/utsname.h>


NSString * const QSEnabledKey                    = @"kQSEnabled";
NSString * const QSFlashModeKey                  = @"kQSFlashMode";
NSString * const QSCameraDeviceKey               = @"kQSCameraDevice";
NSString * const QSHDRModeKey                    = @"kQSHDREnabled";
NSString * const QSWaitForFocusKey               = @"kQSWaitForFocus";
NSString * const QSOptionsWindowHideDelayKey     = @"kQSOptionsWindowHideDelay";
NSString * const QSPrefsChangedNotificationName  = @"kQSPrefsChangedNotif";
NSString * const QSVideoQualityKey               = @"kQSVideoQuality";
NSString * const QSTorchModeKey                  = @"kQSTorchMode";

NSString * const QSImageCaptureListenerName      = @"com.caughtinflux.quickshootpro.imagecapturelistener";
NSString * const QSVideoCaptureListenerName      = @"com.caughtinflux.quickshootpro.videocapturelistener";
NSString * const QSOptionsWindowListenerName     = @"com.caughtinflux.quickshootpro.optionslistener";

NSString * const QSStatusBarImageName            = @"QSSBRecordingIcon";

static NSString * const QSCameraDeviceFrontValue = @"kQSCameraDeviceFront";
static NSString * const QSCameraDeviceRearValue  = @"kQSCameraDeviceRear";
static NSString * const QSFlashModeAutoValue     = @"kQSFlashModeAuto";
static NSString * const QSFlashModeOnValue       = @"kQSFlashModeOn";
static NSString * const QSFlashModeOffValue      = @"kQSFlashModeOff";


QSFlashMode QSFlashModeFromString(NSString *string)
{
    if ([string isEqualToString:QSFlashModeOnValue])
        return QSFlashModeOn;
    if ([string isEqualToString:QSFlashModeAutoValue])
        return QSFlashModeAuto;
    if ([string isEqualToString:QSFlashModeOffValue])
        return QSFlashModeOff;
    
    return QSFlashModeAuto; // default value, in case string is nil.
}

QSCameraDevice QSCameraDeviceFromString(NSString *string)
{
    if ([string isEqualToString:QSCameraDeviceRearValue])
        return QSCameraDeviceRear;
    if ([string isEqualToString:QSCameraDeviceFrontValue])
        return QSCameraDeviceFront;
    
    return QSCameraDeviceRear;
}

NSString * QSVideoQualityFromString(NSString *string)
{
    if ([string isEqualToString:AVCaptureSessionPresetHigh])
        return AVCaptureSessionPresetHigh;
    if ([string isEqualToString:AVCaptureSessionPresetMedium])
        return AVCaptureSessionPresetMedium;
    if ([string isEqualToString:AVCaptureSessionPresetLow])
        return AVCaptureSessionPresetLow;
    if ([string isEqualToString:AVCaptureSessionPreset352x288])
        return AVCaptureSessionPreset352x288;
    if ([string isEqualToString:AVCaptureSessionPreset640x480])
        return AVCaptureSessionPreset640x480;
    if ([string isEqualToString:AVCaptureSessionPreset1280x720])
        return AVCaptureSessionPreset1280x720;
    if ([string isEqualToString:AVCaptureSessionPreset1920x1080])
        return AVCaptureSessionPreset1920x1080;
    if ([string isEqualToString:AVCaptureSessionPresetiFrame960x540])
        return AVCaptureSessionPresetiFrame960x540;
    if ([string isEqualToString:AVCaptureSessionPreset1280x720])
        return AVCaptureSessionPreset1280x720;

    return AVCaptureSessionPresetMedium;
}

inline id QSObjectFromPrefsForKey(NSString *key)
{
    return [[NSDictionary dictionaryWithContentsOfFile:kPrefPath] objectForKey:key];
}

inline NSString * QSStringFromCameraDevice(QSCameraDevice device)
{
    return ((device == QSCameraDeviceRear) ? QSCameraDeviceRearValue : QSCameraDeviceFrontValue);
}

inline NSString * QSStringFromFlashMode(QSFlashMode flashMode)
{
    return ((flashMode == QSFlashModeAuto) ? QSFlashModeAutoValue : ((flashMode == QSFlashModeOn) ? QSFlashModeOnValue : QSFlashModeOffValue));
}

inline NSString * QSGetMachineName(void)
{
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}


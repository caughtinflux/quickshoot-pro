/*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSConstants.m
*   © 2013 Aditya KD
*/

#import "QSConstants.h"
#import "QSCameraController.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <sys/utsname.h>


NSString * const QSEnabledKey                    = @"kQSEnabled";
NSString * const QSUserHasSeenAlertKey           = @"kQSUserHasSeenAlert";
NSString * const QSFlashModeKey                  = @"kQSFlashMode";
NSString * const QSCameraDeviceKey               = @"kQSCameraDevice";
NSString * const QSHDRModeKey                    = @"kQSHDREnabled";
NSString * const QSWaitForFocusKey               = @"kQSWaitForFocus";
NSString * const QSOptionsWindowHideDelayKey     = @"kQSOptionsWindowHideDelay";
NSString * const QSPrefsChangedNotificationName  = @"kQSPrefsChangedNotif";
NSString * const QSVideoQualityKey               = @"kQSVideoQuality";
NSString * const QSTorchModeKey                  = @"kQSTorchMode";
NSString * const QSReferenceTimeKey              = @"kQSReferenceTimeKey";
NSString * const QSScreenFlashKey                = @"kQSScreenFlash";
NSString * const QSRecordingIconKey              = @"kQSRecordingIcon";
NSString * const QSShutterSoundKey               = @"kQSShutterSound";

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
    
    return QSFlashModeOff; // default value, in case string is nil.
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

__attribute__((always_inline)) inline id QSObjectFromPrefsForKey(NSString *key)
{
    return [[NSDictionary dictionaryWithContentsOfFile:kPrefPath] objectForKey:key];
}

__attribute__((always_inline)) inline NSString * QSStringFromCameraDevice(QSCameraDevice device)
{
    return ((device == QSCameraDeviceRear) ? QSCameraDeviceRearValue : QSCameraDeviceFrontValue);
}

__attribute__((always_inline)) inline NSString * QSStringFromFlashMode(QSFlashMode flashMode)
{
    return ((flashMode == QSFlashModeAuto) ? QSFlashModeAutoValue : ((flashMode == QSFlashModeOn) ? QSFlashModeOnValue : QSFlashModeOffValue));
}

__attribute__((always_inline)) inline NSString * QSGetMachineName(void)
{
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

